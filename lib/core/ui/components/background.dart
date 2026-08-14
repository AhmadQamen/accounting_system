import 'dart:math' as math;
import 'dart:ui';

import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';

/// ============================================
/// 💊 AMBIENT BACKGROUND — pharmacy-themed, calm, static
/// ============================================
/// Two layers, both fully static (no `AnimationController`, nothing on a
/// timer):
///
/// 1. A faint tiled pattern of capsule/pill outlines, rotated like a
///    blister pack — this is what actually reads as "pharmacy" at a
///    glance, instead of a generic abstract background.
/// 2. Soft purple/amber glow blobs behind the pattern for depth, same
///    brand palette as the rest of the app.
///
/// Both layers sit at very low opacity so they stay strictly ambient —
/// content on top is always what the eye lands on.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IgnorePointer(
      child: Stack(
        children: [
          // Soft glow, blurred.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -60,
                  child: _Blob(
                    color: colors.purple.withValues(alpha: 0.22),
                    size: 260,
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -70,
                  child: _Blob(
                    color: colors.amber.withValues(alpha: 0.10),
                    size: 300,
                  ),
                ),
              ],
            ),
          ),

          // Pharmacy motif: tiled capsule (pill) outlines, blister-pack
          // style — the detail that actually says "pharmacy".
          Positioned.fill(
            child: CustomPaint(
              painter: _PillPatternPainter(
                color: colors.purple.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }
}

/// Paints a diagonal, repeating grid of capsule (pill) outlines — evokes
/// a blister pack without being literal or noisy. Fully static: the
/// painter's inputs never change, so `shouldRepaint` only reacts to a
/// theme (color) change.
class _PillPatternPainter extends CustomPainter {
  const _PillPatternPainter({required this.color});

  final Color color;

  static const double _tileSize = 150;
  static const double _capsuleWidth = 70;
  static const double _capsuleHeight = 30;
  static const double _rotationDegrees = -24;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final dotPaint = Paint()..color = color.withValues(alpha: color.a * 0.6);

    final capsuleRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: _capsuleWidth,
        height: _capsuleHeight,
      ),
      const Radius.circular(_capsuleHeight / 2),
    );

    // Slightly overshoot the bounds so rotated tiles still cover corners.
    final cols = (size.width / _tileSize).ceil() + 2;
    final rows = (size.height / _tileSize).ceil() + 2;

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final offsetX = col * _tileSize + (row.isOdd ? _tileSize / 2 : 0);
        final offsetY = row * _tileSize * 0.86;

        canvas.save();
        canvas.translate(offsetX, offsetY);
        canvas.rotate(_rotationDegrees * math.pi / 180);
        canvas.drawRRect(capsuleRRect, paint);
        // Midline dividing the two halves of the capsule, like a real pill.
        canvas.drawLine(
          const Offset(0, -_capsuleHeight / 2 + 1),
          const Offset(0, _capsuleHeight / 2 - 1),
          paint,
        );
        canvas.restore();

        // A tiny plus/cross accent between capsules, sparingly.
        if ((row + col) % 3 == 0) {
          _drawCross(
            canvas,
            Offset(offsetX + _tileSize / 2, offsetY + _tileSize / 2),
            dotPaint,
          );
        }
      }
    }
  }

  void _drawCross(Canvas canvas, Offset center, Paint paint) {
    const armLength = 5.0;
    const thickness = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: armLength * 2,
          height: thickness,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: thickness,
          height: armLength * 2,
        ),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PillPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
