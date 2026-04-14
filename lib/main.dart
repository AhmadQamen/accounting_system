import 'package:accounting_system/accounting_system.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  testFirebase();
  runApp(const AccountingSystem());
}

Future<void> testFirebase() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token");
}
