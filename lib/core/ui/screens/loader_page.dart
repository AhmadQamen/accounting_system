import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// =======================================================
/// PAGE LOADING WIDGET
/// =======================================================

class ModernPageLoader extends StatelessWidget {
  final bool hasAppBar;
  final int listItems;

  const ModernPageLoader({
    super.key,
    this.hasAppBar = true,
    this.listItems = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: listItems,
      itemBuilder: (_, index) {
        return _ModernLoadingCard(large: index == 0);
      },
    );
  }
}

class _ModernLoadingCard extends StatelessWidget {
  final bool large;

  const _ModernLoadingCard({required this.large});

  @override
  Widget build(BuildContext context) {
    final random = Random();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainer.withValues(alpha: 0.35),
      ),
      child: Column(
        children: [
          /// TOP
          Row(
            children: [
              Skeleton(
                width: large ? 62 : 54,
                height: large ? 62 : 54,
                radius: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(
                      width: 140 + random.nextInt(80).toDouble(),
                      height: 15,
                      radius: 99,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 10),
                    Skeleton(
                      width: 80 + random.nextInt(60).toDouble(),
                      height: 11,
                      radius: 99,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const Skeleton(width: 40, height: 40, radius: 14),
            ],
          ),

          const SizedBox(height: 20),

          /// CONTENT
          Skeleton(
            height: large ? 150 : 80,
            radius: 24,
            padding: EdgeInsets.zero,
          ),

          const SizedBox(height: 18),

          /// FOOTER
          Row(
            children: [
              Expanded(
                child: Skeleton(
                  height: 14,
                  width: 120,
                  radius: 99,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              const Skeleton(
                width: 90,
                height: 36,
                radius: 12,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final EdgeInsets padding;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.radius = 18,
    this.padding = const EdgeInsets.all(6),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Shimmer(
        period: const Duration(milliseconds: 1400),
        direction: ShimmerDirection.ltr,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.35),
            cs.surfaceBright.withValues(alpha: 0.9),
            cs.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
          stops: const [0.25, 0.5, 0.75],
        ),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outline.withValues(alpha: 0.05)),
          ),
        ),
      ),
    );
  }
}
