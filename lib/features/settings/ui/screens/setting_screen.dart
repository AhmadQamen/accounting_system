import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';
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
    final auth = ref.watch(authNotifierProvider);
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
                        const SectionHeader(
                          title: 'تجربة التطبيق',
                          subtitle: 'المظهر واللغة المفضلة',
                        ),
                        const SizedBox(height: 14),
                        _SettingRow(
                          icon: Icons.language_outlined,
                          title: 'اللغة',
                          subtitle: 'لغة واجهة التطبيق',
                          trailing: DropdownButton<String>(
                            value: settings.language,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'ar',
                                child: Text('العربية'),
                              ),
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null)
                                ref
                                    .read(settingsControllerProvider.notifier)
                                    .changeLanguage(v);
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
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('تلقائي'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('فاتح'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('داكن'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null)
                                ref
                                    .read(settingsControllerProvider.notifier)
                                    .changeTheme(v);
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
                      loading:
                          () => const SizedBox(
                            height: 150,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      error:
                          (e, _) => EmptyState(
                            icon: Iconsax.warning_2,
                            title: 'تعذر قراءة حالة المزامنة',
                            subtitle: '$e',
                          ),
                      data: (s) {
                        final pending = s.pending;
                        final conflicts = s.conflicts;
                        final rejected = s.rejected;
                        final hasFailure = s.lastError != null || rejected > 0;
                        final configured = s.backendConfigured;
                        final statusColor =
                            s.deviceRevoked
                                ? context.colors.error
                                : hasFailure
                                ? context.colors.error
                                : conflicts > 0
                                ? context.colors.error
                                : pending > 0
                                ? context.colors.warning
                                : context.colors.success;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              title: 'المزامنة',
                              subtitle:
                                  s.deviceRevoked
                                      ? 'ألغت الإدارة هذا الجهاز؛ المزامنة متوقفة'
                                      : !s.initializationComplete
                                      ? 'البيانات المحلية متاحة، لكن استعادة تاريخ المؤسسة لم تكتمل بعد'
                                      : s.lastError != null
                                      ? 'لم تكتمل آخر مزامنة: ${s.lastError}'
                                      : rejected > 0
                                      ? 'هناك $rejected حدث مرفوض يحتاج إلى مراجعة'
                                      : configured
                                      ? 'الاتصال الخلفي مهيأ'
                                      : 'يعمل التطبيق محلياً — الـBackend غير مربوط بعد',
                              trailing: StatusPill(
                                label:
                                    s.deviceRevoked
                                        ? 'الجهاز ملغى'
                                        : rejected > 0
                                        ? '$rejected مرفوض'
                                        : conflicts > 0
                                        ? '$conflicts تعارض'
                                        : pending > 0
                                        ? '$pending معلّق'
                                        : 'مستقر',
                                color: statusColor,
                                icon:
                                    conflicts > 0
                                        ? Iconsax.warning_2
                                        : hasFailure
                                        ? Iconsax.close_circle
                                        : pending > 0
                                        ? Iconsax.refresh
                                        : Iconsax.tick_circle,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.initializationComplete
                                  ? 'الحفظ محلي وفوري. المزامنة مع الخادم مكتملة حتى آخر وقت ظاهر أدناه.'
                                  : 'الحفظ المحلي لا يعني وصول البيانات لبقية الأجهزة. شغّل المزامنة يدويًا بعد عودة الاتصال.',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الوضع الحالي: المزامنة يدوية من هذا الزر؛ لا تعمل تلقائيًا في الخلفية.',
                              style: TextStyle(
                                color: context.colors.textDim,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusPill(
                                  label: '$pending حدث معلّق',
                                  color:
                                      pending > 0
                                          ? context.colors.warning
                                          : context.colors.success,
                                  icon: Iconsax.refresh,
                                ),
                                StatusPill(
                                  label: '$conflicts تعارض',
                                  color:
                                      conflicts > 0
                                          ? context.colors.error
                                          : context.colors.success,
                                  icon: Iconsax.warning_2,
                                ),
                                StatusPill(
                                  label:
                                      rejected > 0
                                          ? '$rejected حدث مرفوض'
                                          : 'لا أحداث مرفوضة',
                                  color:
                                      rejected > 0
                                          ? context.colors.error
                                          : context.colors.success,
                                  icon:
                                      rejected > 0
                                          ? Iconsax.close_circle
                                          : Iconsax.tick_circle,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: .13),
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 430;
                                  final status = Row(
                                    children: [
                                      PulseStatusDot(
                                        color: statusColor,
                                        active: pending > 0,
                                        size: 8,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'آخر مزامنة',
                                              style: TextStyle(
                                                color:
                                                    context
                                                        .colors
                                                        .textSecondary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              s.lastSyncAt
                                                      ?.toLocal()
                                                      .toString() ??
                                                  'لم تتم المزامنة بعد',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    context.colors.textPrimary,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                  final button = FilledButton.icon(
                                    onPressed:
                                        s.deviceRevoked
                                            ? null
                                            : () async {
                                              var completed = false;
                                              try {
                                                await ref
                                                    .read(syncEngineProvider)
                                                    .syncNow();
                                                ref.invalidate(
                                                  syncStatusProvider,
                                                );
                                                final result = await ref.read(
                                                  syncStatusProvider.future,
                                                );
                                                completed =
                                                    result.pending == 0 &&
                                                    result.conflicts == 0 &&
                                                    result.rejected == 0 &&
                                                    result.lastError == null &&
                                                    !result.deviceRevoked;
                                              } catch (e) {
                                                if (context.mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text('$e'),
                                                    ),
                                                  );
                                              }
                                              if (context.mounted &&
                                                  completed) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'اكتملت المزامنة بنجاح.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              ref.invalidate(
                                                syncStatusProvider,
                                              );
                                            },
                                    icon: const Icon(Iconsax.refresh, size: 16),
                                    label: const Text('مزامنة الآن'),
                                  );
                                  if (narrow)
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        status,
                                        const SizedBox(height: 10),
                                        button,
                                      ],
                                    );
                                  return Row(
                                    children: [
                                      Expanded(child: status),
                                      const SizedBox(width: 10),
                                      button,
                                    ],
                                  );
                                },
                              ),
                            ),
                            if (s.quarantinedLegacyOperations > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                'تم عزل ${s.quarantinedLegacyOperations} عملية مزامنة قديمة لأنها لا تملك eventType وإصدارًا موثوقًا. بقيت البيانات المحلية محفوظة ولم تُرسل إلى الخادم.',
                                style: TextStyle(
                                  color: context.colors.warning,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                );

                if (stacked)
                  return Column(
                    children: [
                      appearance,
                      const SizedBox(height: 14),
                      syncCard,
                    ],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: appearance),
                    const SizedBox(width: 14),
                    Expanded(child: syncCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 135),
              child: PremiumPanel(
                child: _SettingRow(
                  icon: Icons.person_outline_rounded,
                  title: auth.user?.name ?? 'الحساب',
                  subtitle:
                      auth.selectedMembership == null
                          ? (auth.user?.email ?? '')
                          : '${auth.selectedMembership!.entityName} • ${auth.user?.email ?? ''}',
                  trailing: OutlinedButton.icon(
                    onPressed:
                        auth.isActivatingOrganization
                            ? null
                            : auth.chooseAnotherMembership,
                    icon: const Icon(Icons.domain_rounded, size: 18),
                    label: Text(
                      auth.isActivatingOrganization
                          ? 'جاري التبديل…'
                          : 'تغيير المؤسسة',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
              child: PremiumPanel(
                accent: context.colors.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'منطقة حساسة',
                      subtitle:
                          'عمليات تطوير أو صيانة تؤثر على البيانات المحلية',
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: context.colors.error.withValues(alpha: .055),
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 500;
                          final identity = Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.colors.error.withValues(
                                    alpha: .10,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: context.colors.error,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'حذف قاعدة البيانات المحلية',
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'للتطوير فقط. يحذف كل البيانات المحلية من هذا الجهاز.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.colors.textDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                          final button = OutlinedButton(
                            onPressed: () => _deleteDatabase(context, ref),
                            child: const Text('حذف'),
                          );
                          if (narrow)
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  identity,
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: button,
                                  ),
                                ],
                              ),
                            );
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(child: identity),
                                const SizedBox(width: 12),
                                button,
                              ],
                            ),
                          );
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
      builder:
          (x) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text(
              'سيتم حذف جميع البيانات المحلية من هذا الجهاز. هل أنت متأكد؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(x, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(x, true),
                child: const Text('حذف البيانات'),
              ),
            ],
          ),
    );
    if (ok == true) {
      try {
        await AppDatabase.instance.deleteDB();
        LocalContextService.instance.clearCache();
        ref.invalidate(localContextProvider);
        ref.read(dataRevisionProvider.notifier).state++;
      } on DatabaseDeletionBlockedException catch (error) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('تعذر حذف البيانات بأمان'),
                content: Text(error.toString()),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('حسنًا'),
                  ),
                ],
              ),
        );
      }
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: colors.primary, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textDim, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (narrow)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 7),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ],
            );
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
