import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'app_route.dart';

/// Manages a stack of [AppRoute]s for the desktop shell.
///
/// push            -> Navigate forward.
/// pop             -> Go back.
/// popUntil        -> Go back until a specific route.
/// replaceRoot     -> Replace the entire stack.
/// navigateInSection -> Reset breadcrumb to section root then open page.
class DesktopNavigationController extends ChangeNotifier {
  DesktopNavigationController(this.ref);

  final Ref ref;

  final List<AppRoute> _stack = [AppRoute(type: RouteType.accounting)];

  List<AppRoute> get stack => List.unmodifiable(_stack);

  AppRoute get current {
    assert(_stack.isNotEmpty, 'Navigation stack is empty.');
    return _stack.last;
  }

  bool get canPop => _stack.length > 1;

  int get length => _stack.length;

  bool contains(RouteType type) {
    return _stack.any((e) => e.type == type);
  }

  void push(AppRoute route) {
    // Already on this page.
    if (_stack.isNotEmpty && _stack.last.type == route.type) {
      return;
    }

    // Remove duplicated page from the stack.
    final index = _stack.indexWhere((e) => e.type == route.type);

    if (index != -1) {
      _stack.removeRange(index, _stack.length);
    }

    _stack.add(route);
    notifyListeners();
  }

  void pop() {
    if (!canPop) return;

    _stack.removeLast();
    notifyListeners();
  }

  void popUntil(RouteType type) {
    while (_stack.length > 1 && _stack.last.type != type) {
      _stack.removeLast();
    }

    notifyListeners();
  }

  void replaceRoot(AppRoute route) {
    _stack
      ..clear()
      ..add(route);

    notifyListeners();
  }

  void clear() {
    _stack.clear();
    notifyListeners();
  }

  /// Clears the stack and starts a new breadcrumb.
  void navigateInSection(AppRoute sectionRoot, AppRoute page) {
    _stack
      ..clear()
      ..add(sectionRoot);

    if (sectionRoot.type != page.type) {
      _stack.add(page);
    }

    notifyListeners();
  }
}

///────────────────────────────────────────────────────────
/// Providers
///────────────────────────────────────────────────────────

final desktopNavControllerProvider =
    ChangeNotifierProvider<DesktopNavigationController>((ref) {
      return DesktopNavigationController(ref);
    });

/// Current page.
final currentRouteProvider = Provider<AppRoute>((ref) {
  return ref.watch(desktopNavControllerProvider.select((c) => c.current));
});

/// Breadcrumb.
final breadcrumbRoutesProvider = Provider<List<AppRoute>>((ref) {
  return ref.watch(desktopNavControllerProvider.select((c) => c.stack));
});

/// Can navigate back?
final canPopDesktopProvider = Provider<bool>((ref) {
  return ref.watch(desktopNavControllerProvider.select((c) => c.canPop));
});
