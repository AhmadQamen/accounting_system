import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/theme_extension.dart';

/// ============================================
/// 💜 HOME HEADER — Cash box balance card (v3)
/// ============================================
/// Compact, calm, on-brand: sits on the app's regular card surface
/// (`bgElevated` + thin border), same as every other card in the app —
/// no full-bleed purple gradient block. The accent color shows up only
/// where it should: the icon tile and the balance figure.
///
/// Motion stays minimal — the balance counts up once on load, nothing
/// loops or keeps animating.
class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.balance,
    this.currency = 'ل.س',
    this.todayIncome,
    this.todayExpense,
    this.onTap,
    this.onNotificationsTap,
  });

  /// Cash box balance, already as a raw number (e.g. 4250000).
  final double balance;
  final String currency;

  /// Optional quick-stats shown as small pills under the balance.
  final double? todayIncome;
  final double? todayExpense;

  final VoidCallback? onTap;
  final VoidCallback? onNotificationsTap;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  bool _visible = true;

  String _format(double value) {
    final isNegative = value < 0;
    final abs = value.abs();
    final s = abs
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '${isNegative ? '-' : ''}$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasStats = widget.todayIncome != null || widget.todayExpense != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: colors.purpleTint,
                      border: Border.all(
                        color: colors.purple.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Iconsax.wallet_3,
                      color: colors.purple,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'رصيد الصندوق',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _visible
                            ? _AnimatedBalance(
                                value: widget.balance,
                                currency: widget.currency,
                                formatter: _format,
                                color: colors.textPrimary,
                                currencyColor: colors.textSecondary,
                              )
                            : Text(
                                '••••••',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                  letterSpacing: 2,
                                ),
                              ),
                      ],
                    ),
                  ),
                  if (widget.onNotificationsTap != null) ...[
                    _IconButton(
                      icon: Iconsax.notification,
                      onTap: widget.onNotificationsTap!,
                      colors: colors,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _IconButton(
                    icon: _visible ? Iconsax.eye : Iconsax.eye_slash,
                    onTap: () => setState(() => _visible = !_visible),
                    colors: colors,
                  ),
                ],
              ),

              if (hasStats) ...[
                const SizedBox(height: 14),
                _QuickStatsRow(
                  income: widget.todayIncome,
                  expense: widget.todayExpense,
                  formatter: _format,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Balance figure that counts up once (0 → value) when it first appears.
class _AnimatedBalance extends StatelessWidget {
  const _AnimatedBalance({
    required this.value,
    required this.currency,
    required this.formatter,
    required this.color,
    required this.currencyColor,
  });

  final double value;
  final String currency;
  final String Function(double) formatter;
  final Color color;
  final Color currencyColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatter(animatedValue),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currency,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: currencyColor,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small tinted pills for today's income / expense — flat, calm, no glass.
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.income,
    required this.expense,
    required this.formatter,
  });

  final double? income;
  final double? expense;
  final String Function(double) formatter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (income != null)
          Expanded(
            child: _StatPill(
              icon: Iconsax.arrow_down_1,
              label: 'دخل اليوم',
              value: formatter(income!),
              isPositive: true,
            ),
          ),
        if (income != null && expense != null) const SizedBox(width: 10),
        if (expense != null)
          Expanded(
            child: _StatPill(
              icon: Iconsax.arrow_up_2,
              label: 'مصروف اليوم',
              value: formatter(expense!),
              isPositive: false,
            ),
          ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = isPositive ? colors.success : colors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(icon, size: 12, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
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

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final VoidCallback onTap;
  final dynamic colors;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovering ? colors.muted : Colors.transparent,
          ),
          child: Icon(widget.icon, color: colors.textSecondary, size: 16),
        ),
      ),
    );
  }
}
