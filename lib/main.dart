import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/features/notifications/domain/provider/notification_proider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  testFirebase();
  runApp(
    UncontrolledProviderScope(
      container: globalContainer,
      child: const AccountingSystem(),
    ),
  );
}

Future<void> testFirebase() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token");
}
