<<<<<<< HEAD
import 'package:accounting_system/core/theme/app_theme_colors.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'core/theme/theme_extension.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:accounting_system/core/theme/app_theme_colors.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:shimmer/shimmer.dart';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e

/// Desktop breakpoint — matches the pattern used across the app.
const double _kDesktopBreakpoint = 720;

class ErrorPage extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  final VoidCallback onRestart;

  const ErrorPage({
    super.key,
    required this.error,
    required this.stack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MyScaffold(
      forceWindowsBackground: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;

            if (isDesktop) {
              return _DesktopErrorLayout(
                colors: colors,
                error: error,
                stack: stack,
                onRestart: onRestart,
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _ErrorIcon(),
                      const SizedBox(height: 28),
                      _ErrorTitle(colors: colors),
                      const SizedBox(height: 14),
                      const _ErrorSubtitle(),
                      const SizedBox(height: 32),
                      _RestartButton(onTap: onRestart, colors: colors),
                      const SizedBox(height: 10),
                      _CopyButton(error: error, stack: stack, colors: colors),
                      const SizedBox(height: 24),
                      _TechnicalDetails(error: error, stack: stack),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ============================================
/// 🖥️ DESKTOP / WINDOWS LAYOUT
/// Two columns: message + actions on one side, technical details
/// panel (always visible, roomier) on the other — makes better use
/// of the extra width instead of a stretched narrow mobile column.
/// ============================================
class _DesktopErrorLayout extends StatelessWidget {
  const _DesktopErrorLayout({
    required this.colors,
    required this.error,
    required this.stack,
    required this.onRestart,
  });

  final AppThemeColors colors;
  final Object error;
  final StackTrace stack;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: icon, title, subtitle, actions
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _ErrorIcon(),
                    const SizedBox(height: 28),
                    _ErrorTitle(colors: colors),
                    const SizedBox(height: 14),
                    const _ErrorSubtitle(),
                    const SizedBox(height: 32),
                    _RestartButton(onTap: onRestart, colors: colors),
                    const SizedBox(height: 10),
                    _CopyButton(error: error, stack: stack, colors: colors),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right: technical details, expanded by default on desktop
              Expanded(
                flex: 6,
                child: _TechnicalDetails(
                  error: error,
                  stack: stack,
                  initiallyOpen: true,
                  maxHeight: 420,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TITLE / SUBTITLE (shared between mobile & desktop) ─────────────────────

class _ErrorTitle extends StatelessWidget {
  const _ErrorTitle({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: colors.textPrimary.withAlpha(150),
      highlightColor: colors.amber,
      period: const Duration(milliseconds: 2000),
      child: Text(
        "حدث خطأ غير متوقع",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
          letterSpacing: -0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorSubtitle extends StatelessWidget {
  const _ErrorSubtitle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.amberTint,
        border: Border.all(color: colors.amber.withAlpha(45), width: 0.5),
      ),
      child: Text(
        "نأسف للإزعاج. يرجى إعادة تشغيل التطبيق أو نسخ تفاصيل الخطأ وإرسالها لفريق الدعم.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          height: 1.7,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

// ── ANIMATED ERROR ICON ───────────────────────────────────────────────────────

class _ErrorIcon extends StatefulWidget {
  const _ErrorIcon();

  @override
  State<_ErrorIcon> createState() => _ErrorIconState();
}

class _ErrorIconState extends State<_ErrorIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.3, curve: Curves.easeIn),
      ),
    );

    _pulse = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 1, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final isPulsing = _ctrl.value > 0.5;
        final pulseValue = isPulsing
            ? 1 + (_pulse.value - 1) * ((_ctrl.value - 0.5) / 0.5)
            : 1;

        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value * pulseValue,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.error.withAlpha(20),
                    colors.error.withAlpha(5),
                  ],
                  radius: 0.8,
                ),
                border: Border.all(
                  color: colors.error.withAlpha(45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.error.withAlpha(30),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: colors.error,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── RESTART BUTTON ────────────────────────────────────────────────────────────

class _RestartButton extends StatefulWidget {
  final VoidCallback onTap;
  final AppThemeColors colors;

  const _RestartButton({required this.onTap, required this.colors});

  @override
  State<_RestartButton> createState() => _RestartButtonState();
}

class _RestartButtonState extends State<_RestartButton> {
  bool _pressed = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovering ? 1.01 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.colors.purple, widget.colors.purpleLight],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.purple.withAlpha(_hovering ? 60 : 40),
                  blurRadius: _hovering ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
                  "إعادة تشغيل التطبيق",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── COPY BUTTON ───────────────────────────────────────────────────────────────

class _CopyButton extends StatefulWidget {
  final Object error;
  final StackTrace stack;
  final AppThemeColors colors;

  const _CopyButton({
    required this.error,
    required this.stack,
    required this.colors,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: _hovering ? colors.purpleTint : colors.bgElevated,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text: "Error: ${widget.error}\n\nStackTrace:\n${widget.stack}",
              ),
            );

            CustomSnackBar.showSuccessSnackbar("تم نسخ تفاصيل الخطأ");
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: colors.borderPurple.withAlpha(_hovering ? 60 : 30),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, size: 16, color: colors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  "نسخ تفاصيل الخطأ",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── TECHNICAL DETAILS ─────────────────────────────────────────────────────────

class _TechnicalDetails extends StatefulWidget {
  final Object error;
  final StackTrace stack;

  /// When true (desktop), the panel starts expanded and the code block
  /// scrolls internally up to [maxHeight] instead of pushing the layout.
  final bool initiallyOpen;
  final double? maxHeight;

  const _TechnicalDetails({
    required this.error,
    required this.stack,
    this.initiallyOpen = false,
    this.maxHeight,
  });

  @override
  State<_TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<_TechnicalDetails>
    with SingleTickerProviderStateMixin {
  late bool _open;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _open ? 1 : 0,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final codeBlock = Container(
      width: double.infinity,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgDeep.withAlpha(50),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: colors.borderPurple.withAlpha(15),
          width: 0.5,
        ),
      ),
      child: SelectableText(
        "${widget.error}\n\n${widget.stack}",
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 11,
          height: 1.6,
          fontFamily: 'monospace',
          color: colors.textSecondary,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: colors.borderPurple.withAlpha(20),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          children: [
            /// Toggle header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.code_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "التفاصيل التقنية",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 280),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// Expandable content
            SizeTransition(
              sizeFactor: _expandAnim,
              child: FadeTransition(
                opacity: _expandAnim,
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colors.borderPurple.withAlpha(20),
                    ),
                    if (widget.maxHeight != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxHeight!,
                        ),
                        child: SingleChildScrollView(child: codeBlock),
                      )
                    else
                      codeBlock,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
