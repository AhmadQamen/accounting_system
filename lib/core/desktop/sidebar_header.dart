import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/app_logo_icon.dart';
import 'package:flutter/material.dart';

class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    super.key,
    this.appName = 'نظام المحاسبة',
    this.subtitle = 'إدارة مالية • Offline‑First',
  });

  final String appName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .20),
                  blurRadius: 22,
                  spreadRadius: -7,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: colors.bgElevated.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: AppLogoIcon(width: 30, height: 30, colored: true)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textDim,
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
