import 'dart:math' as math;

import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;
}

class PremiumBackdrop extends StatelessWidget {
  const PremiumBackdrop({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                colors.bgPage,
                colors.bgDeep.withValues(alpha: dark ? .88 : .56),
                colors.bgPage,
              ],
              stops: const [0, .58, 1],
            ),
          ),
        ),
        PositionedDirectional(
          top: -180,
          end: -120,
          child: _AmbientOrb(
            size: 420,
            color: colors.primary.withValues(alpha: dark ? .10 : .13),
          ),
        ),
        PositionedDirectional(
          bottom: -220,
          start: 90,
          child: _AmbientOrb(
            size: 470,
            color: colors.secondary.withValues(alpha: dark ? .07 : .11),
          ),
        ),
        Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class PremiumPage extends StatelessWidget {
  const PremiumPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 32),
    this.maxWidth = 1440,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return PremiumBackdrop(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth < 760 ? 16.0 : 28.0;
          return SingleChildScrollView(
            padding: padding.resolve(Directionality.of(context)).copyWith(
                  left: horizontal,
                  right: horizontal,
                ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 18,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 760),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: .20),
                        colors.secondary.withValues(alpha: .16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.primary.withValues(alpha: .20)),
                  ),
                  child: Icon(icon, color: colors.primary, size: 23),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            letterSpacing: -.5,
                            height: 1.15,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              height: 1.55,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: _spaced(actions, 8)),
      ],
    );
  }
}

class PremiumPanel extends StatefulWidget {
  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.accent,
    this.borderRadius = 22,
    this.hoverLift = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final double borderRadius;
  final bool hoverLift;

  @override
  State<PremiumPanel> createState() => _PremiumPanelState();
}

class _PremiumPanelState extends State<PremiumPanel> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.accent ?? colors.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lift = widget.hoverLift && _hovering;

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: Matrix4.translationValues(0, lift ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: colors.bgElevated.withValues(alpha: dark ? .94 : .96),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: lift
                ? accent.withValues(alpha: .26)
                : colors.border.withValues(alpha: dark ? .85 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .045),
              blurRadius: lift ? 30 : 20,
              spreadRadius: lift ? -8 : -10,
              offset: Offset(0, lift ? 12 : 8),
            ),
            if (lift)
              BoxShadow(
                color: accent.withValues(alpha: .08),
                blurRadius: 30,
                spreadRadius: -12,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: accent.withValues(alpha: .07),
            highlightColor: accent.withValues(alpha: .035),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
    this.onTap,
    this.badge,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PremiumPanel(
      onTap: onTap,
      accent: accent,
      hoverLift: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .17)),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const Spacer(),
              if (badge != null)
                StatusPill(label: badge!, color: accent, compact: true),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
              letterSpacing: -.35,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: colors.textDim),
            ),
          ],
        ],
      ),
    );
  }
}

class QuickActionTile extends StatefulWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  State<QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<QuickActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.accent ?? colors.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover ? accent.withValues(alpha: .10) : colors.muted.withValues(alpha: .60),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover ? accent.withValues(alpha: .22) : colors.border,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.normal,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _hover ? .18 : .11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedScale(
                  duration: AppMotion.fast,
                  scale: _hover ? 1.08 : 1,
                  child: Icon(widget.icon, color: accent, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        )),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textDim, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              AnimatedSlide(
                duration: AppMotion.normal,
                offset: _hover ? Offset.zero : const Offset(-.12, 0),
                child: Icon(Icons.chevron_left_rounded, size: 17, color: _hover ? accent : colors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  )),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: TextStyle(color: colors.textDim, fontSize: 11.5)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: compact ? 11 : 13),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumSearchField extends StatelessWidget {
  const PremiumSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: trailing,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Iconsax.box,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.primaryTint, colors.secondary.withValues(alpha: .12)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.primary.withValues(alpha: .16)),
              ),
              child: Icon(icon, size: 30, color: colors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, height: 1.5, fontSize: 12.5)),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .06),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        offset: _visible ? Offset.zero : widget.offset,
        child: widget.child,
      ),
    );
  }
}

class PulseStatusDot extends StatefulWidget {
  const PulseStatusDot({super.key, required this.color, this.active = true, this.size = 8});
  final Color color;
  final bool active;
  final double size;

  @override
  State<PulseStatusDot> createState() => _PulseStatusDotState();
}

class _PulseStatusDotState extends State<PulseStatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulseStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = widget.active ? _controller.value : 0.0;
        return SizedBox(
          width: widget.size + 10,
          height: widget.size + 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + (10 * value),
                height: widget.size + (10 * value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: .16 * (1 - value)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.color, this.height = 56});

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1.0 : math.max(1.0, values.reduce((a, b) => math.max(a, b).toDouble()));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value / maxValue),
                  duration: AppMotion.page,
                  curve: AppMotion.curve,
                  builder: (context, t, child) => FractionallySizedBox(
                    heightFactor: math.max(.08, t),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: .25)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<Widget> _spaced(List<Widget> widgets, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < widgets.length; i++) {
    if (i > 0) out.add(SizedBox(width: gap));
    out.add(widgets[i]);
  }
  return out;
}

