import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_route.dart';
import 'desktop_navigation_controller.dart';
import 'route_builder.dart';

/// Abstract navigation interface — used by both desktop and mobile.
///
/// * Desktop: routes are pushed onto [DesktopNavigationController]'s stack.
/// * Mobile: routes are pushed onto Flutter's root [Navigator].
abstract class AppNavigator {
  void open(AppRoute route);
  void back();
  void backTo(RouteType routeType);
}

/// Desktop implementation — pushes onto the controller stack (no Navigator).
class DesktopNavigator extends AppNavigator {
  final DesktopNavigationController controller;
  DesktopNavigator(this.controller);

  @override
  void open(AppRoute route) => controller.push(route);

  @override
  void back() => controller.pop();

  @override
  void backTo(RouteType routeType) => controller.popUntil(routeType);
}

/// Mobile implementation — pushes onto Flutter's [Navigator].
class MobileNavigator extends AppNavigator {
  final BuildContext context;
  MobileNavigator(this.context);

  @override
  void open(AppRoute route) {
    final page = buildPage(route);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  void back() => Navigator.pop(context);

  @override
  void backTo(RouteType routeType) => Navigator.popUntil(
    context,
    (route) => route.settings.name == routeType.toString(),
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provides the correct [AppNavigator] based on the platform.
///
/// Must be overridden at app level with a [MobileNavigator] bound to the
/// correct [BuildContext] if used on mobile. On desktop the [DesktopNavigator]
/// is self-sufficient.
final appNavigatorProvider = Provider<AppNavigator>((ref) {
  final controller = ref.read(desktopNavControllerProvider.notifier);
  return DesktopNavigator(controller);
});
