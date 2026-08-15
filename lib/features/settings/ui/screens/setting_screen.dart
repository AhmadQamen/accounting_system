import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/settings/domain/provider/setting_prov.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final sync = ref.watch(syncStatusProvider);
    final compact = showCompactPageAppBar(context);

    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('الإعدادات')) : null,
      body: PremiumPage(
        maxWidth: 1180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'PREFERENCES',
                title: 'الإعدادات',
                subtitle: 'المظهر واللغة والمزامنة وإدارة البيانات المحلية.',
                icon: Iconsax.setting_2,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 840;
                final appearance = AnimatedEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: PremiumPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'تجربة التطبيق', subtitle: 'المظهر واللغة المفضلة'),
                        const SizedBox(height: 14),
                        _SettingRow(
                          icon: Icons.language_outlined,
                          title: 'اللغة',
                          subtitle: 'لغة واجهة التطبيق',
                          trailing: DropdownButton<String>(
                            value: settings.language,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 'ar', child: Text('العربية')),
                              DropdownMenuItem(value: 'en', child: Text('English')),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(settingsControllerProvider.notifier).changeLanguage(v);
                            },
                          ),
                        ),
                        Divider(height: 1, color: context.colors.border),
                        _SettingRow(
                          icon: Icons.light_mode_outlined,
                          title: 'المظهر',
                          subtitle: 'فاتح، داكن أو حسب النظام',
                          trailing: DropdownButton<ThemeMode>(
                            value: settings.themeMode,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: ThemeMode.system, child: Text('تلقائي')),
                              DropdownMenuItem(value: ThemeMode.light, child: Text('فاتح')),
                              DropdownMenuItem(value: ThemeMode.dark, child: Text('داكن')),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(settingsControllerProvider.notifier).changeTheme(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final syncCard = AnimatedEntrance(
                  delay: const Duration(milliseconds: 110),
                  child: PremiumPanel(
                    child: sync.when(
                      loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                      error: (e, _) => EmptyState(icon: Iconsax.warning_2, title: 'تعذر قراءة حالة المزامنة', subtitle: '$e'),
                      data: (s) {
                        final pending = s.pending;
                        final conflicts = s.conflicts;
                        final configured = s.backendConfigured;
                        final statusColor = conflicts > 0
                            ? context.colors.error
                            : pending > 0
                                ? context.colors.warning
                                : context.colors.success;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              title: 'المزامنة',
                              subtitle: configured ? 'الاتصال الخلفي مهيأ' : 'يعمل التطبيق محلياً — الـBackend غير مربوط بعد',
                              trailing: StatusPill(
                                label: conflicts > 0 ? '$conflicts تعارض' : pending > 0 ? '$pending معلّق' : 'مستقر',
                                color: statusColor,
                                icon: conflicts > 0 ? Iconsax.warning_2 : pending > 0 ? Iconsax.refresh : Iconsax.tick_circle,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: statusColor.withValues(alpha: .13)),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 430;
                                  final status = Row(
                                    children: [
                                      PulseStatusDot(color: statusColor, active: pending > 0, size: 8),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('آخر مزامنة', style: TextStyle(color: context.colors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(s.lastSyncAt?.toLocal().toString() ?? 'لم تتم المزامنة بعد', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.colors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                  final button = FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await ref.read(syncEngineProvider).syncNow();
                                      } catch (e) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                      ref.invalidate(syncStatusProvider);
                                    },
                                    icon: const Icon(Iconsax.refresh, size: 16),
                                    label: const Text('مزامنة الآن'),
                                  );
                                  if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [status, const SizedBox(height: 10), button]);
                                  return Row(children: [Expanded(child: status), const SizedBox(width: 10), button]);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );

                if (stacked) return Column(children: [appearance, const SizedBox(height: 14), syncCard]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: appearance), const SizedBox(width: 14), Expanded(child: syncCard)]);
              },
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
              child: PremiumPanel(
                accent: context.colors.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'منطقة حساسة', subtitle: 'عمليات تطوير أو صيانة تؤثر على البيانات المحلية'),
                    const SizedBox(height: 12),
                    Material(
                      color: context.colors.error.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 500;
                          final identity = Row(
                            children: [
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: context.colors.error.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.delete_outline_rounded, color: context.colors.error, size: 19)),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('حذف قاعدة البيانات المحلية', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 2),
                                    Text('للتطوير فقط. يحذف كل البيانات المحلية من هذا الجهاز.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.colors.textDim)),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final button = OutlinedButton(onPressed: () => _deleteDatabase(context, ref), child: const Text('حذف'));
                          if (narrow) return Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerEnd, child: button)]));
                          return Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: identity), const SizedBox(width: 12), button]));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDatabase(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('سيتم حذف جميع البيانات المحلية من هذا الجهاز. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('حذف البيانات')),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteDB();
      LocalContextService.instance.clearCache();
      ref.invalidate(localContextProvider);
      ref.read(dataRevisionProvider.notifier).state++;
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 390;
          final identity = Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: colors.primary, size: 19)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          );
          if (narrow) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 7), Align(alignment: AlignmentDirectional.centerEnd, child: trailing)]);
          return Row(children: [Expanded(child: identity), const SizedBox(width: 10), Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing))]);
        },
      ),
    );
  }
}
