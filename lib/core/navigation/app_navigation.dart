import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'app_route.dart';
import 'desktop_navigation_controller.dart';
import 'route_builder.dart';

class AppNavigation{
 static bool get _desktop=>!kIsWeb&&(defaultTargetPlatform==TargetPlatform.windows||defaultTargetPlatform==TargetPlatform.linux||defaultTargetPlatform==TargetPlatform.macOS);
 static void open(AppRoute route){if(_desktop){globalContainer.read(appNavigatorProvider).open(route);}else{final c=AccountingSystem.navigatorKey.currentContext;if(c!=null)Navigator.of(c).push(MaterialPageRoute(builder:(_)=>buildPage(route)));}}
 static void openReplacement(AppRoute route){if(_desktop){globalContainer.read(desktopNavControllerProvider).replaceRoot(route);}else{final c=AccountingSystem.navigatorKey.currentContext;if(c!=null)Navigator.of(c).pushReplacement(MaterialPageRoute(builder:(_)=>buildPage(route)));}}
 static void back(){if(_desktop){globalContainer.read(desktopNavControllerProvider).pop();}else{AccountingSystem.navigatorKey.currentState?.maybePop();}}
}
