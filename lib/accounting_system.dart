import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/core/ui/components/scroll_behavior.dart';
import 'package:accounting_system/features/settings/domain/provider/setting_prov.dart';
import 'package:accounting_system/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/domain/models/setting_model.dart';

class AccountingSystem extends ConsumerWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const AccountingSystem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitializerProvider);
    final settings = ref.watch(settingsControllerProvider);

    return initState.when(
      loading: () => _buildApp(settings: settings, home: const Text("splash")),
      error: (err, _) => _buildApp(
        settings: settings,
        home: Scaffold(
          body: SafeArea(
            child: Center(child: Text('Initialization failed:\n$err')),
          ),
        ),
      ),
      data: (_) => _buildApp(
        settings: settings,
        home: Builder(
          builder: (context) => Text(Localization.of(context).appTitle),
        ),
      ),
    );
  }

  /// 🔥 Core MaterialApp (no duplication)
  Widget _buildApp({required AppSettings settings, required Widget home}) {
    return MaterialApp(
      navigatorKey: AccountingSystem.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "AccountingSystem",

      /// 🌍 Localization
      localizationsDelegates: const [
        Localization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Localization.supportedLocales,
      locale: Locale(settings.language),

      /// 🎨 Theme
      themeMode: settings.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),

      /// 🧠 Behavior
      scrollBehavior: NoScrollGlowBehavior(),

      /// 📱 Screen
      home: home,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData.light().copyWith(
      colorScheme: ColorScheme.light(
        primary: Colors.green,
        primaryContainer: const Color(0xFFDCDCDC),
        secondary: Colors.green[700]!,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFDCDCDC),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.green
              : Colors.grey[600]!;
        }),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: Colors.green,
        surface: const Color(0xFF184C3F),
        primaryContainer: const Color(0xFF112B25),
        secondary: Colors.green[200]!,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFF112B25),
      ),
    );
  }
}
