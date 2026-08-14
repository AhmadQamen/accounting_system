import 'package:accounting_system/core/desktop/desktop_shell.dart';
import 'package:accounting_system/core/theme/app_theme.dart';
import 'package:accounting_system/core/ui/components/scroll_behavior.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';
import 'package:accounting_system/features/auth/ui/screens/login_screen.dart';
import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'error_page.dart';
import 'features/settings/domain/models/setting_model.dart';
import 'features/settings/domain/provider/setting_prov.dart';
import 'splash_screen.dart';

class AccountingSystem extends ConsumerWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const AccountingSystem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitializerProvider);
    final settings = ref.watch(settingsControllerProvider);

    return initState.when(
      loading: () => _buildApp(
        settings: settings,
        context: context,
        home: ModernSplashScreen(),
      ),
      error: (err, stack) => _buildApp(
        settings: settings,
        context: context,
        home: ErrorPage(error: err, stack: stack, onRestart: () {}),
      ),
      data: (_) => _buildApp(
        settings: settings,
        context: context,
        home: _resolveHome(ref),
      ),
    );
  }

  /// 🔥 Decide Home Screen
  Widget _resolveHome(WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    return AppShell();
  }

  /// 🔥 Core MaterialApp (no duplication)
  Widget _buildApp({
    required AppSettings settings,
    required Widget home,
    required BuildContext context,
  }) {
    return MaterialApp(
      navigatorKey: AccountingSystem.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppLocalizations.of(context)?.appTitle,

      /// 🌍 Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(settings.language),

      /// 🎨 Theme
      themeMode: settings.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,

      /// 🧠 Behavior
      scrollBehavior: NoScrollGlowBehavior(),

      /// 📱 Screen
      home: home,
    );
  }
}
