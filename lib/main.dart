import 'package:accounting_system/accounting_system.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  await Firebase.initializeApp();
  runApp(const AccountingSystem());
}
