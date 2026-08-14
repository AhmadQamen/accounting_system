import 'dart:ui';

import 'package:accounting_system/accounting_system.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CustomSnackBar {
  static String? _lastMessage;
  static DateTime? _lastShownAt;
  static const Duration _dedupWindow = Duration(seconds: 4);

  static bool _isDuplicate(String message) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _dedupWindow) {
      return true;
    }
    _lastMessage = message;
    _lastShownAt = now;
    return false;
  }

  static void showSuccessSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _show(
      context,
      message: text,
      icon: Iconsax.tick_circle,
      accent: const Color(0xFF16A34A),
    );
  }

  static void showErrorSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _show(
      context,
      message: text,
      icon: Iconsax.close_circle,
      accent: const Color(0xFFDC2626),
    );
  }

  static void showWarningSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _show(
      context,
      message: text,
      icon: Iconsax.warning_2,
      accent: const Color(0xFFD97706),
    );
  }

  static void showInfoSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _show(
      context,
      message: text,
      icon: Iconsax.info_circle,
      accent: const Color(0xFF2563EB),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    if (_isDuplicate(message)) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final duration = const Duration(seconds: 3);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.fixed,
        dismissDirection: DismissDirection.horizontal,
        duration: duration,
        content: _SnackContent(
          message: message,
          duration: duration,
          icon: icon,
          accent: accent,
          isDesktop: false,
        ),
      ),
    );
  }
}

// ── SNACK CONTENT ─────────────────────────────────────────────────────────────

class _SnackContent extends StatefulWidget {
  final String message;
  final IconData icon;
  final Duration duration;
  final Color accent;
  final bool isDesktop;

  const _SnackContent({
    required this.message,
    required this.icon,
    required this.accent,
    required this.isDesktop,
    required this.duration,
  });

  @override
  State<_SnackContent> createState() => _SnackContentState();
}

class _SnackContentState extends State<_SnackContent>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  /// Countdown ring around the icon — replaces the old bottom progress
  /// bar with something that reads more like a native "liquid glass" toast.
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _entryScale = Tween<double>(
      begin: 0.86,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _entryFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;

    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final glassBase = isDark ? const Color(0xFF1C1F26) : Colors.white;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: widget.isDesktop
              ? const BoxConstraints(maxWidth: 340, minWidth: 260)
              : const BoxConstraints(maxWidth: double.infinity),
          // Gradient "glass" border trick: outer padding of 1.2px filled
          // with a soft diagonal gradient, inner content clipped on top.
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.22 : 0.9),
                accent.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: isDark ? 0.05 : 0.3),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Base glass fill
              Container(
                decoration: BoxDecoration(
                  color: glassBase.withValues(alpha: isDark ? 0.55 : 0.65),
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              // Specular highlight — soft light sheen top-left, mimics a
              // curved glass surface catching light.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.45),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              // Faint accent tint wash
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: accent.withValues(alpha: isDark ? 0.06 : 0.04),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: widget.isDesktop
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIconWithRing(accent),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: ScaleTransition(
          scale: _entryScale,
          alignment: Alignment.center,
          child: widget.isDesktop
              ? Align(alignment: Alignment.bottomRight, child: card)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: card,
                ),
        ),
      ),
    );
  }

  // Icon sitting inside a soft accent-tinted circle, with a thin countdown
  // ring drawn around it instead of a separate linear progress bar.
  Widget _buildIconWithRing(Color accent) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow behind the ring
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: _progressAnimation.value,
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 15, color: accent),
              ),
            ],
          );
        },
      ),
    );
  }
}
