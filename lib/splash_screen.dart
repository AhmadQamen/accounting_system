import 'dart:math' as math;
import 'package:accounting_system/core/ui/components/app_logo_icon.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme_colors.dart';
import 'core/theme/theme_extension.dart';
import 'main.dart';

/// Desktop breakpoint — matches the pattern used across the app.
const double _kDesktopBreakpoint = 720;

class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _ambientController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _logoFloat;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Slow ambient loop for background blobs + glow pulse (runs forever)
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.3, curve: Curves.easeIn),
      ),
    );

    _ringScale = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _ringFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.7, curve: Curves.elasticOut),
      ),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.45, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );

    _subtitleSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 0.9, curve: Curves.easeIn),
      ),
    );

    _logoFloat = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.03))
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.7, 1, curve: Curves.easeInOut),
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return MyScaffold(
      forceWindowsBackground: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;
          // Desktop windows get a slightly larger, more spacious composition
          // instead of the same mobile-sized logo stretched on a huge canvas.
          final ringBoxSize = isDesktop ? 320.0 : 260.0;
          final nameSize = isDesktop ? 48.0 : 40.0;
          final footerBottom = isDesktop ? 56.0 : 44.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Subtle radial glow expanding from center
              _buildCenterGlow(colors),

              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoWithRings(colors, boxSize: ringBoxSize),
                    SizedBox(height: isDesktop ? 44 : 36),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Opacity(opacity: _textFade.value, child: child),
                      ),
                      child: _buildAppName(colors, fontSize: nameSize),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _subtitleSlide.value),
                        child: Opacity(
                          opacity: _subtitleFade.value,
                          child: child,
                        ),
                      ),
                      child: _buildTagline(colors),
                    ),
                  ],
                ),
              ),

              // Footer
              Positioned(
                bottom: footerBottom,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildLoadingIndicator(colors),
                      const SizedBox(height: 14),
                      _buildVersionText(colors, theme),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Center glow behind everything, breathing subtly
  // ---------------------------------------------------------------------
  Widget _buildCenterGlow(AppThemeColors colors) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final pulse =
            0.85 + 0.15 * math.sin(_ambientController.value * 2 * math.pi);
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.55 * pulse,
                colors: [
                  colors.purple.withValues(alpha: 0.10),
                  colors.amber.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Logo + concentric animated rings + rotating dashed ring
  // ---------------------------------------------------------------------
  Widget _buildLogoWithRings(AppThemeColors colors, {required double boxSize}) {
    final ringSize = boxSize * (190 / 260);
    final glassSize = boxSize * (150 / 260);
    final logoSize = boxSize * (108 / 260);

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner soft glow ring
          AnimatedBuilder(
            animation: Listenable.merge([_controller, _ambientController]),
            builder: (context, child) {
              final pulse =
                  0.9 + 0.1 * math.sin(_ambientController.value * 2 * math.pi);
              return Opacity(
                opacity: _ringFade.value,
                child: Transform.scale(
                  scale: _ringScale.value * pulse,
                  child: Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.purple.withValues(alpha: 0.25),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Glass card behind the logo
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(scale: _logoScale.value, child: child),
              );
            },
            child: Container(
              width: glassSize,
              height: glassSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.bgElevated,
                border: Border.all(color: colors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: colors.purple.withValues(alpha: 0.18),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: colors.amber.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),

          // The actual logo, floating gently, full brand colors
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: SlideTransition(position: _logoFloat, child: child),
                ),
              );
            },
            child: AppLogoIcon(
              width: logoSize,
              height: logoSize,
              colored: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppName(AppThemeColors colors, {required double fontSize}) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [colors.purple, colors.amber],
      ).createShader(bounds),
      child: Text(
        'PharmaX',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTagline(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.purpleTint,
        border: Border.all(color: colors.borderPurple, width: 0.5),
      ),
      child: Text(
        'إدارة صيدليتك بذكاء وسهولة',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.purple,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoadingIndicator(AppThemeColors colors) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 130,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _controller.value,
              minHeight: 4,
              backgroundColor: colors.muted,
              valueColor: AlwaysStoppedAnimation<Color>(colors.purple),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionText(AppThemeColors colors, ThemeData theme) {
    return Text(
      packageInfo.version,
      style: TextStyle(
        fontSize: 12,
        color: colors.textDim,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
