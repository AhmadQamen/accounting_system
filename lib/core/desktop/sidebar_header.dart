import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/app_logo_icon.dart';
import 'package:flutter/material.dart';

class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    super.key,
    this.appName = 'نظام المحاسبة',
    this.subtitle = 'إدارة مالية • Offline‑First',
    this.collapsed = false,
  });

  final String appName;
  final String subtitle;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logo = Container(
      width: collapsed ? 42 : 50,
      height: collapsed ? 42 : 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(collapsed ? 14 : 17),
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
          borderRadius: BorderRadius.circular(collapsed ? 13 : 16),
        ),
        child: Center(
          child: AppLogoIcon(
            width: collapsed ? 25 : 30,
            height: collapsed ? 25 : 30,
            colored: true,
          ),
        ),
      ),
    );

    if (collapsed) {
      return SizedBox(
        height: 82,
        child: Center(child: Semantics(label: appName, child: logo)),
      );
    }

    return Container(
      height: 106,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          logo,
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
