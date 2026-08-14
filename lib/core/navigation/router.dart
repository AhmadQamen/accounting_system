import 'package:accounting_system/core/configs/breakpoints.dart';
import 'package:flutter/material.dart';

extension NavigatorExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isDesktop => screenWidth >= Breakpoints.desktop;
  // Basic navigation
  Future<T?> push<T>(Widget page) =>
      Navigator.push<T>(this, MaterialPageRoute(builder: (_) => page));

  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.pushNamed<T>(this, routeName, arguments: arguments);

  Future<T?> pushReplacement<T, TO>(Widget page) =>
      Navigator.pushReplacement<T, TO>(
        this,
        MaterialPageRoute(builder: (_) => page),
      );

  Future<T?> pushReplacementNamed<T, TO>(
    String routeName, {
    Object? arguments,
  }) => Navigator.pushReplacementNamed<T, TO>(
    this,
    routeName,
    arguments: arguments,
  );

  Future<T?> pushAndRemoveUntil<T>(Widget page) =>
      Navigator.pushAndRemoveUntil<T>(
        this,
        MaterialPageRoute(builder: (_) => page),
        (route) => false,
      );

  Future<T?> pushNamedAndRemoveUntil<T>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) => Navigator.pushNamedAndRemoveUntil<T>(
    this,
    routeName,
    predicate,
    arguments: arguments,
  );

  // Named route with arguments
  Future<T?> pushNamedWithArgs<T>(
    String routeName, {
    Object? arguments,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) => Navigator.pushNamed<T>(this, routeName, arguments: arguments);

  // Dialog navigation
  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) => Navigator.of(this, rootNavigator: useRootNavigator).push<T>(
    DialogRoute(
      context: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
    ),
  );

  // Bottom sheet navigation
  Future<T?> showBottomSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool enableDrag = true,
    bool isDismissible = true,
    bool useRootNavigator = false,
    bool isScrollControlled = false,
    RouteSettings? routeSettings,
  }) => Navigator.of(this, rootNavigator: useRootNavigator).push<T>(
    ModalBottomSheetRoute(
      builder: builder,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      isScrollControlled: isScrollControlled,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      settings: routeSettings,
    ),
  );

  // Pop navigation
  void pop<T>([T? result]) => Navigator.pop<T>(this, result);

  bool canPop() => Navigator.canPop(this);

  void maybePop<T>([T? result]) => Navigator.maybePop<T>(this, result);

  // Custom transitions
  Future<T?> fadeTo<T>(Widget page) => Navigator.push<T>(
    this,
    PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );

  Future<T?> slideFromRight<T>(Widget page) => Navigator.push<T>(
    this,
    PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, c) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(a),
        child: c,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );

  Future<T?> slideFromBottom<T>(Widget page) => Navigator.push<T>(
    this,
    PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, c) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(a),
        child: c,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );

  // Utility methods
  void popUntilFirst() => Navigator.popUntil(this, (route) => route.isFirst);

  void popUntilNamed(String routeName) =>
      Navigator.popUntil(this, ModalRoute.withName(routeName));

  void popToRoot() => Navigator.popUntil(this, (route) => route.isFirst);

  // Replacement with transition
  Future<T?> replaceWith<T, TO>(Widget page) =>
      Navigator.pushReplacement<T, TO>(
        this,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );

  // Remove all routes and push new one
  Future<T?> removeAllAndPush<T>(Widget page) =>
      Navigator.pushAndRemoveUntil<T>(
        this,
        MaterialPageRoute(builder: (_) => page),
        (route) => false,
      );

  Future<T?> removeAllAndPushNamed<T>(String routeName, {Object? arguments}) =>
      Navigator.pushNamedAndRemoveUntil<T>(
        this,
        routeName,
        (route) => false,
        arguments: arguments,
      );
}
