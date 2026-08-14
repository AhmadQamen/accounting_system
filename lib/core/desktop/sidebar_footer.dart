import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum SubscriptionStatus { premium, trial, expired }

/// Pinned footer of the desktop sidebar — a compact user card with name,
/// email, and a subscription status pill. Never scrolls with the nav list.
class SidebarFooter extends StatefulWidget {
  const SidebarFooter({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.status,
    this.avatarUrl,
    this.onTap,
  });

  final String userName;
  final String userEmail;
  final SubscriptionStatus status;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  State<SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<SidebarFooter> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hovering ? colors.bgElevated : colors.muted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Row(
              children: [
                _Avatar(name: widget.userName, avatarUrl: widget.avatarUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _SubscriptionBadge(status: widget.status),
                    ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [colors.purple, colors.purpleLight]),
      ),
      alignment: Alignment.center,
      child: avatarUrl != null
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialText(initial),
              ),
            )
          : _InitialText(initial),
    );
  }
}

class _InitialText extends StatelessWidget {
  const _InitialText(this.initial);

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  const _SubscriptionBadge({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (Color color, IconData icon, String label) = switch (status) {
      SubscriptionStatus.premium => (
        colors.success,
        Iconsax.crown_1,
        'Premium',
      ),
      SubscriptionStatus.trial => (colors.amber, Iconsax.clock, 'Trial'),
      SubscriptionStatus.expired => (
        colors.error,
        Iconsax.warning_2,
        'Expired',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
