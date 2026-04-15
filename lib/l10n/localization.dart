import 'package:accounting_system/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class Localization {
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizations.delegate;
}
