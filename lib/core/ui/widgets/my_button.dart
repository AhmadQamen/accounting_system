import 'dart:ui';
import 'package:flutter/material.dart';

import 'waiting_animation.dart';

class MyButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onPressed;

  const MyButton({
    super.key,
    required this.text,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.height = 48,
    this.borderRadius = 12,
    this.padding,
    this.color,
    this.onPressed,
  });

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primary = widget.color ?? theme.colorScheme.primary;

    final danger = const Color(0xFFFF4D6D);

    final buttonColor = widget.isDanger ? danger : primary;

    final enabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _isPressed ? 0.985 : 1,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: enabled
              ? () => setState(() => _isPressed = false)
              : null,
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: widget.isOutlined
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: enabled
                                ? [
                                    buttonColor.withOpacity(
                                      _isHovered ? 1 : 0.95,
                                    ),
                                    buttonColor.withOpacity(
                                      _isHovered ? 0.85 : 0.75,
                                    ),
                                  ]
                                : [
                                    Colors.grey.withOpacity(.4),
                                    Colors.grey.withOpacity(.3),
                                  ],
                          ),
                    color: widget.isOutlined
                        ? buttonColor.withOpacity(enabled ? 0.08 : 0.04)
                        : null,
                    border: Border.all(
                      color: widget.isOutlined
                          ? buttonColor.withOpacity(enabled ? .55 : .2)
                          : Colors.white.withOpacity(.08),
                      width: 1.2,
                    ),
                    boxShadow: enabled && !widget.isOutlined
                        ? [
                            BoxShadow(
                              color: buttonColor.withOpacity(.28),
                              blurRadius: _isHovered ? 30 : 22,
                              spreadRadius: 1,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(.15),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled ? widget.onPressed : null,
                      splashColor: Colors.white.withOpacity(.08),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding:
                            widget.padding ??
                            const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: widget.isLoading
                                ? SizedBox(
                                    key: const ValueKey("loading"),
                                    height: 24,
                                    width: 24,
                                    child: const MyWaitingAnimation(),
                                  )
                                : Row(
                                    key: const ValueKey("content"),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.icon != null)
                                        Icon(
                                          widget.icon,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      if (widget.icon != null)
                                        const SizedBox(width: 12),
                                      Text(
                                        widget.text,
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .2,
                                          color: widget.isOutlined
                                              ? buttonColor
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
