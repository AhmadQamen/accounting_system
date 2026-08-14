import 'dart:ui';

import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class AccountingHome extends ConsumerStatefulWidget {
  const AccountingHome({super.key});

  @override
  ConsumerState<AccountingHome> createState() => _AccountingHomeState();
}

class _AccountingHomeState extends ConsumerState<AccountingHome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _dashboardFuture = ref.read(reportsRepositoryProvider).dashboard();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = ref.read(reportsRepositoryProvider).dashboard();
    setState(() => _dashboardFuture = future);
    await future;
    _entrance
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgPage,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: colors.bgPage.withValues(alpha: .85),
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.border, width: .5),
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              'لوحة التحكم',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _refresh,
            builder: (
              context,
              refreshState,
              pulledExtent,
              refreshTriggerPullDistance,
              refreshIndicatorExtent,
            ) {
              final progress = (pulledExtent / refreshIndicatorExtent).clamp(
                0.0,
                1.0,
              );
              final active =
                  refreshState == RefreshIndicatorMode.armed ||
                  refreshState == RefreshIndicatorMode.refresh;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(
                        alpha: active ? .18 : .10,
                      ),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .35),
                        width: .5,
                      ),
                    ),
                    child:
                        refreshState == RefreshIndicatorMode.refresh
                            ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                            : Transform.rotate(
                              angle: progress * 3.14,
                              child: Icon(
                                Iconsax.refresh,
                                size: 16,
                                color: colors.primary,
                              ),
                            ),
                  ),
                ),
              );
            },
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _dashboardFuture,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (s.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('${s.error}')),
                );
              }
              final d = s.data ?? {};
              String money(String k) => Money((d[k] ?? 0)).format(
                locale: Localizations.localeOf(context).toString(),
                currencyCode: currency,
              );

              final cards = <_DashCard>[
                _DashCard(
                  'رصيد الصناديق',
                  money('cash'),
                  Iconsax.wallet_money,
                  colors.primary,
                  RouteType.cashboxes,
                ),
                _DashCard(
                  'مبيعات اليوم',
                  money('salesToday'),
                  Iconsax.receipt_1,
                  colors.success,
                  RouteType.sales,
                ),
                _DashCard(
                  'مشتريات اليوم',
                  money('purchasesToday'),
                  Iconsax.shopping_cart,
                  colors.secondary,
                  RouteType.purchases,
                ),
                _DashCard(
                  'ذمم العملاء',
                  money('customerReceivables'),
                  Iconsax.people,
                  colors.info,
                  RouteType.customers,
                ),
                _DashCard(
                  'ذمم الموردين',
                  money('supplierPayables'),
                  Iconsax.truck_fast,
                  colors.warning,
                  RouteType.suppliers,
                ),
                _DashCard(
                  'قيمة المخزون',
                  money('inventoryValue'),
                  Iconsax.box_1,
                  colors.primary,
                  RouteType.inventory,
                ),
                _DashCard(
                  'مخزون منخفض',
                  '${d['lowStock'] ?? 0}',
                  Iconsax.warning_2,
                  colors.error,
                  RouteType.inventory,
                ),
                _DashCard(
                  'بانتظار المزامنة',
                  '${d['pendingSync'] ?? 0}',
                  Iconsax.refresh,
                  colors.textSecondary,
                  RouteType.settings,
                ),
              ];

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeroActionCard(controller: _entrance),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisExtent: 152,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _AnimatedDashTile(
                          controller: _entrance,
                          index: i,
                          total: cards.length,
                          card: cards[i],
                        ),
                        childCount: cards.length,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final RouteType route;
  _DashCard(this.title, this.value, this.icon, this.color, this.route);
}

/// ============================================
/// 🌟 Hero Action Card — فاتورة بيع جديدة
/// ============================================
class _HeroActionCard extends StatefulWidget {
  final AnimationController controller;
  const _HeroActionCard({required this.controller});

  @override
  State<_HeroActionCard> createState() => _HeroActionCardState();
}

class _HeroActionCardState extends State<_HeroActionCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final anim = CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap:
                () =>
                    AppNavigation.open(const AppRoute(type: RouteType.newSale)),
            child: AnimatedScale(
              scale: _pressed ? 0.98 : (_hover ? 1.01 : 1.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: _hover ? .28 : .20),
                      colors.secondary.withValues(alpha: _hover ? .20 : .14),
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: _hover ? .5 : .3),
                    width: .5,
                  ),
                  boxShadow:
                      _hover
                          ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .18),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ]
                          : [],
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(
                          alpha: _hover ? .3 : .22,
                        ),
                      ),
                      child: Icon(
                        Iconsax.receipt_add,
                        color: colors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فاتورة بيع جديدة',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ابدأ عملية بيع جديدة بضغطة واحدة',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _hover ? -0.02 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Iconsax.arrow_left_2,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================
/// 💳 Animated Dashboard Tile
/// ============================================
class _AnimatedDashTile extends StatefulWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final _DashCard card;

  const _AnimatedDashTile({
    required this.controller,
    required this.index,
    required this.total,
    required this.card,
  });

  @override
  State<_AnimatedDashTile> createState() => _AnimatedDashTileState();
}

class _AnimatedDashTileState extends State<_AnimatedDashTile> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final start = 0.15 + (widget.index / widget.total) * 0.5;
    final end = (start + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(anim),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: () => AppNavigation.open(AppRoute(type: widget.card.route)),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : (_hover ? 1.02 : 1.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: colors.bgElevated,
                  border: Border.all(
                    color:
                        _hover
                            ? widget.card.color.withValues(alpha: .5)
                            : colors.border,
                    width: .5,
                  ),
                  boxShadow:
                      _hover
                          ? [
                            BoxShadow(
                              color: widget.card.color.withValues(alpha: .16),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                          : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.card.color.withValues(
                              alpha: _hover ? .22 : .14,
                            ),
                          ),
                          child: Icon(
                            widget.card.icon,
                            color: widget.card.color,
                            size: 20,
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _hover ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Iconsax.arrow_left_2,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      widget.card.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.card.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
