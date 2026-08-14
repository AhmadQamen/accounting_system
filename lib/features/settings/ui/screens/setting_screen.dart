<<<<<<< HEAD
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/ui/components/my_scaffold.dart';
import '../../domain/models/setting_model.dart';
import '../../domain/provider/setting_prov.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ar':
      default:
        return 'العربية';
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'فاتح';
      case ThemeMode.dark:
        return 'غامق';
      case ThemeMode.system:
        return 'تلقائي (حسب الجهاز)';
    }
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Iconsax.sun_1;
      case ThemeMode.dark:
        return Iconsax.moon;
      case ThemeMode.system:
        return Iconsax.mobile;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    return MyScaffold(
      appBar: BlurAppbar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _SectionLabel(text: 'التفضيلات', colors: colors),
            const SizedBox(height: 10),
            _NavGroup(
              colors: colors,
              children: [
                _NavRow(
                  icon: Iconsax.language_square,
                  label: 'اللغة',
                  value: _languageLabel(settings.language),
                  colors: colors,
                  onTap: () =>
                      _showLanguageSheet(context, colors, settings, notifier),
                ),
                _NavRow(
                  icon: _themeIcon(settings.themeMode),
                  label: 'المظهر',
                  value: _themeLabel(settings.themeMode),
                  colors: colors,
                  showDivider: false,
                  onTap: () =>
                      _showThemeSheet(context, colors, settings, notifier),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionLabel(text: 'الإشعارات', colors: colors),
            const SizedBox(height: 10),
            _NavGroup(
              colors: colors,
              children: [
                _SwitchRow(
                  icon: Iconsax.notification,
                  label: 'إشعارات التطبيق',
                  value: settings.notificationsEnabled,
                  colors: colors,
                  showDivider: false,
                  onChanged: (_) => notifier.toggleNotifications(),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionLabel(text: 'البيانات والتخزين', colors: colors),
            const SizedBox(height: 10),
            _NavGroup(
              colors: colors,
              children: [
                _NavRow(
                  icon: Iconsax.trash,
                  label: 'حذف جميع البيانات المحفوظة',
                  colors: colors,
                  showDivider: false,
                  onTap: () => _confirmDelepurplel(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionLabel(text: 'عن التطبيق', colors: colors),
            const SizedBox(height: 10),
            _NavGroup(
              colors: colors,
              children: [
                _NavRow(
                  icon: Iconsax.shield_tick,
                  label: 'سياسة الخصوصية',
                  colors: colors,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
                _NavRow(
                  icon: Iconsax.document_text,
                  label: 'شروط الاستخدام',
                  colors: colors,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                  ),
                ),
                _NavRow(
                  icon: Iconsax.info_circle,
                  label: 'حول NerdX',
                  value: 'الإصدار 1.0.0',
                  colors: colors,
                  showDivider: false,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── LANGUAGE SHEET ──────────────────────────────────────────────────────────
  void _showLanguageSheet(
    BuildContext context,
    AppThemeColors colors,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    _showOptionsSheet(
      context: context,
      colors: colors,
      title: 'اللغة',
      options: [
        _SheetOption(
          icon: Iconsax.language_square,
          label: 'العربية',
          selected: settings.language == 'ar',
          onTap: () {
            notifier.changeLanguage('ar');
            Navigator.pop(context);
          },
        ),
        _SheetOption(
          icon: Iconsax.language_square,
          label: 'English',
          selected: settings.language == 'en',
          onTap: () {
            notifier.changeLanguage('en');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  // ── THEME SHEET ──────────────────────────────────────────────────────────────
  void _showThemeSheet(
    BuildContext context,
    AppThemeColors colors,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    _showOptionsSheet(
      context: context,
      colors: colors,
      title: 'المظهر',
      options: [
        _SheetOption(
          icon: Iconsax.sun_1,
          label: 'فاتح',
          selected: settings.themeMode == ThemeMode.light,
          onTap: () {
            notifier.changeTheme(ThemeMode.light);
            Navigator.pop(context);
          },
        ),
        _SheetOption(
          icon: Iconsax.moon,
          label: 'غامق',
          selected: settings.themeMode == ThemeMode.dark,
          onTap: () {
            notifier.changeTheme(ThemeMode.dark);
            Navigator.pop(context);
          },
        ),
        _SheetOption(
          icon: Iconsax.mobile,
          label: 'تلقائي (حسب الجهاز)',
          selected: settings.themeMode == ThemeMode.system,
          onTap: () {
            notifier.changeTheme(ThemeMode.system);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showOptionsSheet({
    required BuildContext context,
    required AppThemeColors colors,
    required String title,
    required List<_SheetOption> options,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...options,
          ],
        ),
      ),
    );
  }

  void _confirmDelepurplel(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'حذف جميع البيانات',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'سيتم حذف جميع الملفات المحملّلة وقاعدة البيانات المحلية. هذا الإجراء لا يمكن التراجع عنه.',
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: colors.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _delepurplelData(ref);
              if (context.mounted) {
                CustomSnackBar.showSuccessSnackbar(
                  'تم حذف جميع البيانات بنجاح',
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            child: const Text(
              'حذف',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delepurplelData(WidgetRef ref) async {}
}

// ── SECTION LABEL ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.colors});

  final String text;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: colors.textDim,
        ),
      ),
    );
  }
}

// ── GROUPED CONTAINER ─────────────────────────────────────────────────────────
class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.colors, required this.children});

  final AppThemeColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ── NAV ROW (label + current value + chevron) ─────────────────────────────────
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String? value;
  final AppThemeColors colors;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: colors.textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (value != null) ...[
                    Text(
                      value!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: colors.textDim,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    Icons.chevron_left_rounded,
                    color: colors.textDim,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, indent: 48, color: colors.border),
      ],
    );
  }
}

// ── SWITCH ROW ─────────────────────────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final bool value;
  final AppThemeColors colors;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 19, color: colors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: colors.purple,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, indent: 48, color: colors.border),
      ],
    );
  }
}

// ── BOTTOM SHEET OPTION ─────────────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final colors = context.colors;
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.purple : colors.muted,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? colors.purple : colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? colors.purple : colors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.purple,
                    size: 20,
                  )
                else
                  Icon(Icons.circle_outlined, color: colors.border, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
=======
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/features/settings/domain/provider/setting_prov.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget{const SettingsScreen({super.key});
 @override Widget build(BuildContext context,WidgetRef ref){final settings=ref.watch(settingsControllerProvider);final sync=ref.watch(syncStatusProvider);return Scaffold(appBar:AppBar(title:const Text('الإعدادات')),body:ListView(padding:const EdgeInsets.all(20),children:[Card(child:Column(children:[ListTile(title:const Text('اللغة'),trailing:DropdownButton<String>(value:settings.language,items:const [DropdownMenuItem(value:'ar',child:Text('العربية')),DropdownMenuItem(value:'en',child:Text('English'))],onChanged:(v){if(v!=null)ref.read(settingsControllerProvider.notifier).changeLanguage(v);})),ListTile(title:const Text('المظهر'),trailing:DropdownButton<ThemeMode>(value:settings.themeMode,items:const [DropdownMenuItem(value:ThemeMode.system,child:Text('تلقائي')),DropdownMenuItem(value:ThemeMode.light,child:Text('فاتح')),DropdownMenuItem(value:ThemeMode.dark,child:Text('داكن'))],onChanged:(v){if(v!=null)ref.read(settingsControllerProvider.notifier).changeTheme(v);})),])),const SizedBox(height:12),Card(child:sync.when(loading:()=>const ListTile(title:Text('المزامنة'),trailing:CircularProgressIndicator()),error:(e,_)=>ListTile(title:const Text('المزامنة'),subtitle:Text('$e')),data:(s)=>Column(children:[ListTile(title:const Text('حالة المزامنة'),subtitle:Text((s['backend_configured'] as bool)?'جاهزة':'Backend غير مربوط بعد'),trailing:Chip(label:Text('${s['pending']} معلّق • ${s['conflicts']??0} تعارض'))),ListTile(title:const Text('مزامنة الآن'),subtitle:Text('آخر مزامنة: ${s['last_sync_at']??'—'}'),trailing:const Icon(Icons.sync),onTap:()async{try{await ref.read(syncEngineProvider).syncNow();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}ref.invalidate(syncStatusProvider);})]))),const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.delete_forever),title:const Text('حذف قاعدة البيانات المحلية'),subtitle:const Text('للتطوير فقط. يحذف كل البيانات المحلية.'),onTap:()async{final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('تأكيد الحذف'),content:const Text('هل أنت متأكد؟'),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('حذف'))]));if(ok==true){await AppDatabase.instance.deleteDB();LocalContextService.instance.clearCache();ref.invalidate(localContextProvider);ref.read(dataRevisionProvider.notifier).state++;}}))]));}
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
}
