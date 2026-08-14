<<<<<<< HEAD
import 'package:accounting_system/core/configs/assets.dart';
import 'package:flutter/material.dart';
=======
import 'package:flutter/material.dart';
import 'package:accounting_system/core/configs/assets.dart';
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e

class AppLogoIcon extends StatelessWidget {
  const AppLogoIcon({
    super.key,
    this.width,
    this.height,
    this.colored = false,
    this.color,
  });
  final double? width;
  final double? height;
  final bool colored;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Image.asset(
        ImageAssets.logo,
        color: colored
            ? null
            : color ?? theme.colorScheme.onSurface.withValues(alpha: 0.8),
        width: width,
        height: height,
      ),
    );
  }
}
