import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
void main() async{WidgetsFlutterBinding.ensureInitialized();runApp(UncontrolledProviderScope(container:globalContainer,child:const AccountingSystem()));}
