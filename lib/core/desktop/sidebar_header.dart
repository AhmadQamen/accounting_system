import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/app_logo_icon.dart';
import 'package:flutter/material.dart';

/// Top section of the desktop sidebar: logo + app name + subtitle.
///
/// Fixed height (~96px), never scrolls — sits above the navigation list.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    super.key,
<<<<<<< HEAD
    this.appName = 'Pharma X',
    this.subtitle = 'Pharmacy Management',
=======
    this.appName = 'Accounting System',
    this.subtitle = 'Offline Accounting',
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
  });

  final String appName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.bgElevated,
              border: Border.all(color: colors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: colors.purple.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const AppLogoIcon(width: 30, height: 30, colored: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
