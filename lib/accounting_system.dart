import 'package:accounting_system/core/desktop/desktop_shell.dart';
import 'package:accounting_system/core/theme/app_theme.dart';
import 'package:accounting_system/core/ui/components/scroll_behavior.dart';
import 'package:accounting_system/error_page.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';
import 'package:accounting_system/features/auth/ui/screens/login_screen.dart';
import 'package:accounting_system/features/settings/domain/models/setting_model.dart';
import 'package:accounting_system/features/settings/domain/provider/setting_prov.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:accounting_system/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';

class AccountingSystem extends ConsumerWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  const AccountingSystem({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitializerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final home = init.when(
      loading: () => const ModernSplashScreen(),
      error: (e, s) => ErrorPage(
        error: e,
        stack: s,
        onRestart: () => ref.invalidate(appInitializerProvider),
      ),
      data: (_) => ref.watch(authNotifierProvider).isAuthenticated
          ? const AppShell()
          : const LoginScreen(),
    );
    return _app(settings, home);
  }

  Widget _app(AppSettings settings, Widget home) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'Accounting System',
    locale: Locale(settings.language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    themeMode: settings.themeMode,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    scrollBehavior: NoScrollGlowBehavior(),
    home: home,
  );
}
