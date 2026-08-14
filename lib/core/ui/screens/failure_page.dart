import 'dart:ui';
import 'package:accounting_system/core/ui/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ModernErrorPage extends StatefulWidget {
  final String error;
  final VoidCallback? onRetry;
  final bool isNetworkError;

  const ModernErrorPage({
    super.key,
    required this.error,
    this.onRetry,
    this.isNetworkError = true,
  });

  @override
  State<ModernErrorPage> createState() => _ModernErrorPageState();
}

class _ModernErrorPageState extends State<ModernErrorPage>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _slide;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _slide = Tween<double>(
      begin: 16,
      end: 0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedBuilder(
            animation: _enterCtrl,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _slide.value),
              child: Opacity(
                opacity: _fade.value,
                child: Transform.scale(scale: _scale.value, child: child),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.surface.withValues(alpha: 0.95),
                        cs.surfaceContainerHighest.withValues(alpha: 0.75),
                      ],
                    ),
                    border: Border.all(
                      color: cs.error.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 40,
                        spreadRadius: -8,
                        offset: const Offset(0, 20),
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// ICON
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: size.width * 0.22,
                              height: size.width * 0.22,
                              constraints: const BoxConstraints(
                                maxWidth: 130,
                                maxHeight: 130,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    cs.error.withValues(alpha: 0.15),
                                    cs.error.withValues(alpha: 0.03),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),

                            /// GLOW (pulsing)
                            Transform.scale(
                              scale: _pulse.value,
                              child: Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 45,
                                      spreadRadius: 4,
                                      color: cs.error.withValues(alpha: 0.18),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            /// RING
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cs.error.withValues(alpha: 0.25),
                                  width: 1.4,
                                ),
                              ),
                            ),

                            /// MAIN ICON
                            SizedBox(
                              width: 86,
                              height: 86,
                              child: Icon(
                                widget.isNetworkError
                                    ? Iconsax.cloud_cross
                                    : Iconsax.warning_2,
                                color: cs.error,
                                size: 38,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// TITLE
                      Text(
                        widget.isNetworkError
                            ? "فشل تحميل البيانات"
                            : "حدث خطأ",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -.6,
                        ),
                      ),

                      const SizedBox(height: 6),

                      /// HINT
                      Text(
                        widget.isNetworkError
                            ? "تأكد من اتصالك بالإنترنت وحاول مرة تانية"
                            : "صار في خطأ غير متوقع، جرّب مرة تانية",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: MyButton(
                          text: "إعادة المحاولة",
                          icon: Iconsax.refresh,
                          onPressed: widget.onRetry,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
