import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                colors.secondary.withValues(alpha: .10),
                colors.bgPage,
                colors.primary.withValues(alpha: .08),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
