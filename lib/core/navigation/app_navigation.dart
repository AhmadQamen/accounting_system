<<<<<<< HEAD
import 'dart:io' show Platform;
import 'package:accounting_system/accounting_system.dart';
import 'package:flutter/material.dart';
import '../providers/app_providers.dart';
=======
import 'package:accounting_system/accounting_system.dart';
import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
import 'app_navigator.dart';
import 'app_route.dart';
import 'desktop_navigation_controller.dart';
import 'route_builder.dart';
<<<<<<< HEAD
import 'router.dart';

/// Unified navigation — one call works on both desktop and mobile.
///
/// Desktop: routes are pushed onto [DesktopNavigationController]'s stack.
/// Mobile:  routes are pushed onto Flutter's root [Navigator].
class AppNavigation {
  static void open(AppRoute route) {
    if (Platform.isWindows) {
      globalContainer.read(appNavigatorProvider).open(route);
    } else {
      final ctx = AccountingSystem.navigatorKey.currentContext;
      if (ctx != null) {
        final page = buildPage(route);
        ctx.push(page);
      }
    }
  }

  /// Navigate to a route, replacing the current one.
  static void openReplacement(AppRoute route) {
    if (Platform.isWindows) {
      globalContainer.read(appNavigatorProvider).back();
      globalContainer.read(appNavigatorProvider).open(route);
    } else {
      final ctx = AccountingSystem.navigatorKey.currentContext;
      if (ctx != null) {
        final page = buildPage(route);
        ctx.pushReplacement(page);
      }
    }
  }

  /// Navigate back — platform-aware.
  ///
  /// Desktop: pops from [DesktopNavigationController]'s stack.
  /// Mobile:  pops from Flutter's [Navigator].
  static void back() {
    if (Platform.isWindows) {
      globalContainer.read(desktopNavControllerProvider.notifier).pop();
    } else {
      final ctx = AccountingSystem.navigatorKey.currentContext;
      if (ctx != null) {
        ctx.pop();
      }
    }
  }
=======

class AppNavigation{
 static bool get _desktop=>!kIsWeb&&defaultTargetPlatform==TargetPlatform.windows;
 static void open(AppRoute route){if(_desktop){globalContainer.read(appNavigatorProvider).open(route);}else{final c=AccountingSystem.navigatorKey.currentContext;if(c!=null)Navigator.of(c).push(MaterialPageRoute(builder:(_)=>buildPage(route)));}}
 static void openReplacement(AppRoute route){if(_desktop){globalContainer.read(desktopNavControllerProvider).replaceRoot(route);}else{final c=AccountingSystem.navigatorKey.currentContext;if(c!=null)Navigator.of(c).pushReplacement(MaterialPageRoute(builder:(_)=>buildPage(route)));}}
 static void back(){if(_desktop){globalContainer.read(desktopNavControllerProvider).pop();}else{AccountingSystem.navigatorKey.currentState?.maybePop();}}
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
}
