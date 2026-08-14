import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── DATA MODEL ────────────────────────────────────────────────────────────────
class BottomNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int? badgeCount;

  const BottomNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

// ── FLOATING NAV BAR WITH TAB CONTROLLER ─────────────────────────────────────
class MyBottomNavBar extends ConsumerStatefulWidget {
  final PageController pageController;
  final List<BottomNavItem> items;

  final double bottomMargin;
  final double horizontalMargin;

  const MyBottomNavBar({
    super.key,
    required this.pageController,
    required this.items,
    this.bottomMargin = 8,
    this.horizontalMargin = 20,
  });

  @override
  ConsumerState<MyBottomNavBar> createState() => _MyBottomNavBarState();
}

class _MyBottomNavBarState extends ConsumerState<MyBottomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _bounceCtrl;
  late List<Animation<double>> _bounceAnim;

  late List<AnimationController> _rippleCtrl;
  late List<Animation<double>> _rippleAnim;

  double _currentPage = 0;
  @override
  void initState() {
    super.initState();

    _currentPage = widget.pageController.initialPage.toDouble();

    _initializeControllers();

    widget.pageController.addListener(_handlePageScroll);
  }

  void _handlePageScroll() {
    if (!mounted) return;

    final page = widget.pageController.hasClients
        ? (widget.pageController.page ??
              widget.pageController.initialPage.toDouble())
        : widget.pageController.initialPage.toDouble();

    final oldIndex = _currentPage.round();
    final newIndex = page.round();

    if (oldIndex != newIndex) {
      if (newIndex < _bounceCtrl.length) {
        _bounceCtrl[newIndex]
          ..reset()
          ..forward();
      }

      if (newIndex < _rippleCtrl.length) {
        _rippleCtrl[newIndex]
          ..reset()
          ..forward();
      }
    }

    setState(() {
      _currentPage = page;
    });
  }

  void _initializeControllers() {
    final count = widget.items.length;

    _bounceCtrl = List.generate(
      count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _bounceAnim = _bounceCtrl.map((ctrl) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 1.3,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.3,
            end: 0.88,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 0.88,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30,
        ),
      ]).animate(ctrl);
    }).toList();

    _rippleCtrl = List.generate(
      count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _rippleAnim = _rippleCtrl.map((ctrl) {
      return Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }).toList();
  }

  void _reinitializeControllers() {
    for (final c in _bounceCtrl) {
      c.dispose();
    }

    for (final c in _rippleCtrl) {
      c.dispose();
    }

    _initializeControllers();
  }

  @override
  void didUpdateWidget(MyBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController.removeListener(_handlePageScroll);

      widget.pageController.addListener(_handlePageScroll);

      _currentPage = widget.pageController.hasClients
          ? (widget.pageController.page ??
                widget.pageController.initialPage.toDouble())
          : widget.pageController.initialPage.toDouble();
    }

    if (oldWidget.items.length != widget.items.length) {
      _reinitializeControllers();
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_handlePageScroll);

    for (final c in _bounceCtrl) {
      c.dispose();
    }

    for (final c in _rippleCtrl) {
      c.dispose();
    }

    super.dispose();
  }

  Color lighter(Color color, [double amount = .05]) {
    return Color.lerp(color, Colors.grey, amount)!;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    return ClipRRect(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.horizontalMargin,
          0,
          widget.horizontalMargin,
          widget.bottomMargin,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const maxWidth = 600.0;
            final width = constraints.maxWidth.clamp(0, maxWidth).toDouble();

            return Container(
              height: 60,
              width: width,
              decoration: BoxDecoration(
                color: lighter(context.colors.bgElevated),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  /// ── SLIDING INDICATOR (with animation based on tab controller) ──
                  if (count > 1)
                    Positioned(
                      bottom: 5,
                      right: _indicatorLeft(_currentPage, count, width),
                      child: Container(
                        width: 22,
                        height: 3,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                  /// ── NAV ITEMS ──
                  Row(
                    children: List.generate(count, (index) {
                      final isSelected = index == _currentPage.round();
                      final item = widget.items[index];

                      final bounceAnim = index < _bounceAnim.length
                          ? _bounceAnim[index]
                          : const AlwaysStoppedAnimation(1.0);
                      final rippleAnim = index < _rippleAnim.length
                          ? _rippleAnim[index]
                          : const AlwaysStoppedAnimation(0.0);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: _NavItem(
                            item: item,
                            isSelected: isSelected,
                            bounceAnim: bounceAnim,
                            rippleAnim: rippleAnim,
                            colorScheme: cs,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _indicatorLeft(double page, int count, double width) {
    const indicatorWidth = 22.0;
    final itemWidth = width / count;
    final centerX = itemWidth * (page + 0.5);
    return centerX - (indicatorWidth / 2);
  }
}

class _NavItem extends StatelessWidget {
  final BottomNavItem item;
  final bool isSelected;
  final Animation<double> bounceAnim;
  final Animation<double> rippleAnim;
  final ColorScheme colorScheme;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.bounceAnim,
    required this.rippleAnim,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant;
    final hasBadge = item.badgeCount != null && item.badgeCount! > 0;

    return SizedBox(
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: bounceAnim,
            builder: (_, child) => Transform.scale(
              scale: isSelected ? bounceAnim.value : 1.0,
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        key: ValueKey(isSelected),
                        isSelected && item.activeIcon != null
                            ? item.activeIcon!
                            : item.icon,
                        size: 22,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                    if (hasBadge)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: _Badge(
                          count: item.badgeCount!,
                          color: activeColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  child: Text(item.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        display,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
