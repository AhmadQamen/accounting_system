import 'dart:math' as math;
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    _animate = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (_animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // 🎨 الخلفية الأساسية
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    colors.bgDeep,
                    colors.bgPage,
                    colors.primary.withValues(alpha: .13),
                  ],
                ),
              ),
            ),
            // 📒 شبكة دفتر الحسابات + منحنى النمو + توهج ناعم متحرك
            _animate
                ? AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _ledgerCanvas(colors, _controller.value),
                  )
                : RepaintBoundary(child: _ledgerCanvas(colors, 0)),
          ],
        ),
      ),
    );
  }

  Widget _ledgerCanvas(dynamic colors, double progress) => CustomPaint(
    painter: _LedgerPainter(progress: progress, primary: colors.primary, secondary: colors.secondary, success: colors.success, lineColor: colors.textPrimary),
    size: Size.infinite,
  );
}

class _LedgerPainter extends CustomPainter {
  final double progress;
  final Color primary;
  final Color secondary;
  final Color success;
  final Color lineColor;

  _LedgerPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.success,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintLedgerGrid(canvas, size);
    _paintJournalColumns(canvas, size);
    _paintGrowthCurve(canvas, size);
    _paintGlowOrbs(canvas, size);
  }

  /// إشارات دفتر الأستاذ: أعمدة مدين/دائن وأعمدة مالية هادئة في الخلفية.
  void _paintJournalColumns(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = lineColor.withValues(alpha: .075)
          ..strokeWidth = 1;
    final columns = [size.width * .58, size.width * .74, size.width * .90];
    for (final x in columns) {
      canvas.drawLine(
        Offset(x, size.height * .12),
        Offset(x, size.height * .48),
        line,
      );
    }
    for (var row = 0; row < 5; row++) {
      final y = size.height * (.17 + row * .06);
      canvas.drawLine(
        Offset(size.width * .46, y),
        Offset(size.width * .96, y),
        line,
      );
    }
    final barPaint = Paint()..color = lineColor.withValues(alpha: .07);
    for (var index = 0; index < 5; index++) {
      final height = 18.0 + (index % 3) * 14;
      final left = size.width * (.18 + index * .045);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height * .24 - height, 14, height),
          const Radius.circular(4),
        ),
        barPaint,
      );
    }
  }

  /// خطوط دفتر الحسابات — أفقية وعمودية خفيفة جداً
  void _paintLedgerGrid(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = lineColor.withValues(alpha: .045)
          ..strokeWidth = .6;

    const gap = 42.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // خط هامش بستايل الدفاتر المحاسبية التقليدية
    final marginPaint =
        Paint()
          ..color = lineColor.withValues(alpha: .10)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * .12, 0),
      Offset(size.width * .12, size.height),
      marginPaint,
    );
  }

  /// منحنى نمو صاعد شفاف — يرمز للأداء المالي
  void _paintGrowthCurve(Canvas canvas, Size size) {
    final path = Path();
    final baseY = size.height * .72;
    final points = [
      Offset(size.width * -.05, baseY + 40),
      Offset(size.width * .18, baseY + 10),
      Offset(size.width * .38, baseY - 30),
      Offset(size.width * .55, baseY - 15),
      Offset(size.width * .75, baseY - 90),
      Offset(size.width * .95, baseY - 60),
      Offset(size.width * 1.1, baseY - 130),
    ];

    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    final linePaint =
        Paint()
          ..color = lineColor.withValues(alpha: .14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // تعبئة ناعمة تحت المنحنى
    final fillPath =
        Path.from(path)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close();
    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: .08),
              success.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // نقاط صغيرة على المنحنى (محطات بيانات)
    final dotPaint = Paint()..color = lineColor.withValues(alpha: .20);
    for (final p in [points[2], points[4], points[6]]) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  /// كتل توهج ناعمة تتنفس ببطء
  void _paintGlowOrbs(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    void orb(Offset center, double radius, Color color, double phase) {
      final pulse = (math.sin(t + phase) + 1) / 2; // 0..1
      final r = radius * (0.85 + pulse * 0.15);
      final paint =
          Paint()
            ..color = color.withValues(alpha: .08 + pulse * .05)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .6);
      canvas.drawCircle(center, r, paint);
    }

    orb(Offset(size.width * .82, size.height * .18), 120, lineColor, 0);
    orb(
      Offset(size.width * .10, size.height * .85),
      140,
      lineColor,
      math.pi / 2,
    );
    orb(Offset(size.width * .55, size.height * .45), 100, lineColor, math.pi);
  }

  @override
  bool shouldRepaint(covariant _LedgerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.success != success;
}
