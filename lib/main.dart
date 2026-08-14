import 'package:accounting_system/accounting_system.dart';
<<<<<<< HEAD
=======
import 'package:accounting_system/core/providers/app_providers.dart';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/providers/app_providers.dart';

late PackageInfo packageInfo;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< HEAD

  packageInfo = await PackageInfo.fromPlatform();
=======
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
  runApp(
    UncontrolledProviderScope(
      container: globalContainer,
      child: const AccountingSystem(),
    ),
  );
}
