import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class AccountingHome extends ConsumerWidget {
  const AccountingHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);
    final repo = ref.read(reportsRepositoryProvider);

    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('لوحة التحكم')) : null,
      body: FutureBuilder<DashboardData>(
        future: repo.dashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DashboardLoading();
          }
          if (snapshot.hasError) {
            return PremiumBackdrop(
              child: EmptyState(
                icon: Iconsax.warning_2,
                title: 'تعذر تحميل لوحة التحكم',
                subtitle: '${snapshot.error}',
              ),
            );
          }

          final dashboard = snapshot.data!;
          final data = dashboard.metrics;
          final trends = dashboard.trends;
          final activity = dashboard.recentActivity;
          final lowStock = dashboard.lowStockItems;
          String money(int value) => _money(context, value, currency);

          return PremiumPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedEntrance(
                  child: PageIntro(
                    eyebrow: 'OVERVIEW',
                    title: 'أعمالك، بصورة أوضح',
                    subtitle: 'ملخص مالي ومخزني مباشر من قاعدة البيانات المحلية — سريع حتى بدون إنترنت.',
                    icon: Icons.dashboard_outlined,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => AppNavigation.open(const AppRoute(type: RouteType.reports)),
                        icon: const Icon(Iconsax.chart_2, size: 18),
                        label: const Text('التقارير'),
                      ),
                      FilledButton.icon(
                        onPressed: () => AppNavigation.open(const AppRoute(type: RouteType.newSale)),
                        icon: const Icon(Iconsax.receipt_add, size: 18),
                        label: const Text('فاتورة بيع'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: _HeroOverview(
                    cash: money(data.cash),
                    salesToday: money(data.salesToday),
                    purchasesToday: money(data.purchasesToday),
                    pendingSync: data.pendingSync,
                    salesTrend: trends.sales.map((e) => e.toDouble()).toList(),
                    purchasesTrend: trends.purchases.map((e) => e.toDouble()).toList(),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1120 ? 4 : width >= 840 ? 3 : width >= 540 ? 2 : 1;
                    final itemWidth = (width - ((columns - 1) * 12)) / columns;
                    final metrics = [
                      ('مبيعات اليوم', money(data.salesToday), Iconsax.receipt_1, context.colors.success, RouteType.sales, 'المبيعات المعتمدة'),
                      ('مشتريات اليوم', money(data.purchasesToday), Iconsax.shopping_cart, context.colors.secondary, RouteType.purchases, 'المشتريات المعتمدة'),
                      ('ذمم العملاء', money(data.customerReceivables), Iconsax.people, context.colors.info, RouteType.customers, 'مبالغ مستحقة لنا'),
                      ('ذمم الموردين', money(data.supplierPayables), Iconsax.truck_fast, context.colors.warning, RouteType.suppliers, 'مبالغ مستحقة علينا'),
                      ('قيمة المخزون', money(data.inventoryValue), Iconsax.box_1, context.colors.primary, RouteType.inventory, 'حسب التكلفة الحالية'),
                      ('مخزون منخفض', '${data.lowStock}', Iconsax.warning_2, context.colors.error, RouteType.inventory, 'يحتاج متابعة'),
                      ('رصيد الصناديق', money(data.cash), Iconsax.wallet_money, context.colors.primary, RouteType.cashboxes, 'جميع الصناديق'),
                      ('المزامنة', '${data.pendingSync}', Iconsax.refresh, context.colors.textSecondary, RouteType.settings, 'عمليات بانتظار الإرسال'),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < metrics.length; i++)
                          SizedBox(
                            width: itemWidth,
                            child: AnimatedEntrance(
                              delay: Duration(milliseconds: 120 + (i * 28)),
                              child: MetricCard(
                                label: metrics[i].$1,
                                value: metrics[i].$2,
                                icon: metrics[i].$3,
                                accent: metrics[i].$4,
                                caption: metrics[i].$6,
                                onTap: () => AppNavigation.open(AppRoute(type: metrics[i].$5)),
                                badge: i == 7 && (data.pendingSync) == 0 ? 'متزامن' : null,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 980;
                    final recent = _RecentActivity(activity: activity, currency: currency);
                    final stock = _StockAttention(rows: lowStock);
                    if (stacked) {
                      return Column(
                        children: [recent, const SizedBox(height: 14), stock],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: recent),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: stock),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _money(BuildContext context, int value, String currency) {
    return Money(value).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
  }
}

class _HeroOverview extends StatelessWidget {
  const _HeroOverview({
    required this.cash,
    required this.salesToday,
    required this.purchasesToday,
    required this.pendingSync,
    required this.salesTrend,
    required this.purchasesTrend,
  });

  final String cash;
  final String salesToday;
  final String purchasesToday;
  final int pendingSync;
  final List<double> salesTrend;
  final List<double> purchasesTrend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PremiumPanel(
      padding: EdgeInsets.zero,
      borderRadius: 26,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -90,
              end: -65,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 900;
                  final balance = _BalanceBlock(
                    cash: cash,
                    salesToday: salesToday,
                    purchasesToday: purchasesToday,
                    pendingSync: pendingSync,
                  );
                  final chart = _TrendBlock(sales: salesTrend, purchases: purchasesTrend);
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [balance, const SizedBox(height: 24), chart],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: balance),
                      Container(
                        width: 1,
                        height: 220,
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        color: colors.border,
                      ),
                      Expanded(flex: 5, child: chart),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({required this.cash, required this.salesToday, required this.purchasesToday, required this.pendingSync});
  final String cash;
  final String salesToday;
  final String purchasesToday;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final identity = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: .72)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: colors.primary.withValues(alpha: .20), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Iconsax.wallet_3, color: Color(0xFF08111F), size: 22),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('السيولة المتاحة', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('رصيد جميع الصناديق', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            );
            final sync = StatusPill(
              label: pendingSync == 0 ? 'محلي محفوظ' : '$pendingSync بانتظار المزامنة',
              color: pendingSync == 0 ? colors.success : colors.warning,
              icon: pendingSync == 0 ? Iconsax.tick_circle : Iconsax.refresh,
            );
            if (constraints.maxWidth < 430) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 12), Align(alignment: AlignmentDirectional.centerStart, child: sync)],
              );
            }
            return Row(children: [Expanded(child: identity), const SizedBox(width: 12), Flexible(child: sync)]);
          },
        ),
        const SizedBox(height: 18),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            cash,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroStat(label: 'مبيعات اليوم', value: salesToday, color: colors.success, icon: Icons.north_rounded),
            _HeroStat(label: 'مشتريات اليوم', value: purchasesToday, color: colors.secondary, icon: Icons.south_rounded),
          ],
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .075),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700))),
            const SizedBox(width: 7),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w900)))),
          ],
        ),
      ),
    );
  }
}

class _TrendBlock extends StatelessWidget {
  const _TrendBlock({required this.sales, required this.purchases});
  final List<double> sales;
  final List<double> purchases;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SectionHeader(title: 'نبض آخر 7 أيام', subtitle: 'حركة المبيعات والمشتريات اليومية'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final salesCard = _TrendSeries(label: 'المبيعات', values: sales, color: colors.success);
            final purchaseCard = _TrendSeries(label: 'المشتريات', values: purchases, color: colors.secondary);
            if (constraints.maxWidth < 430) {
              return Column(children: [salesCard, const SizedBox(height: 12), purchaseCard]);
            }
            return Row(children: [Expanded(child: salesCard), const SizedBox(width: 12), Expanded(child: purchaseCard)]);
          },
        ),
      ],
    );
  }
}

class _TrendSeries extends StatelessWidget {
  const _TrendSeries({required this.label, required this.values, required this.color});
  final String label;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)), const SizedBox(width: 6), Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          MiniBars(values: values.isEmpty ? const [0, 0, 0, 0, 0, 0, 0] : values, color: color, height: 62),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.activity, required this.currency});
  final List<ActivityItem> activity;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 300),
      child: PremiumPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'آخر الحركات',
              subtitle: 'أحدث العمليات المعتمدة محلياً',
              trailing: TextButton(
                onPressed: () => AppNavigation.open(const AppRoute(type: RouteType.sales)),
                child: const Text('عرض السجل'),
              ),
            ),
            const SizedBox(height: 12),
            if (activity.isEmpty)
              const EmptyState(title: 'لا توجد حركات بعد', subtitle: 'ستظهر هنا آخر المبيعات والمشتريات والمصاريف.', icon: Icons.timeline_rounded)
            else
              for (var i = 0; i < activity.length; i++) ...[
                _ActivityRow(row: activity[i], currency: currency),
                if (i != activity.length - 1) Divider(height: 1, color: colors.border),
              ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.row, required this.currency});
  final ActivityItem row;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = row.kind;
    final (icon, color, label) = switch (kind) {
      'sale' => (Iconsax.receipt_1, colors.success, 'بيع'),
      'purchase' => (Iconsax.shopping_cart, colors.secondary, 'شراء'),
      _ => (Iconsax.money_send, colors.error, 'مصروف'),
    };
    final amount = row.amountMinor;
    final date = row.occurredAt?.toLocal();
    final dateLabel = date == null ? '' : '${date.day}/${date.month} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final amountLabel = Money(amount).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final identity = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label • ${row.displayNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${row.partyName ?? dateLabel}${row.partyName == null ? '' : ' • $dateLabel'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 49),
                  child: Text(amountLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              Flexible(
                child: Text(amountLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StockAttention extends StatelessWidget {
  const _StockAttention({required this.rows});
  final List<LowStockItem> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 340),
      child: PremiumPanel(
        accent: colors.error,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'يحتاج انتباهك',
              subtitle: rows.isEmpty ? 'المخزون ضمن الحدود المحددة' : 'أصناف وصلت للحد الأدنى',
              trailing: rows.isEmpty
                  ? StatusPill(label: 'ممتاز', color: colors.success, icon: Iconsax.tick_circle)
                  : StatusPill(label: '${rows.length} تنبيه', color: colors.error, icon: Iconsax.warning_2),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const EmptyState(title: 'لا توجد تنبيهات مخزون', subtitle: 'كل الأصناف حالياً فوق الحد الأدنى.', icon: Icons.verified_user_outlined)
            else
              for (var i = 0; i < rows.length; i++) ...[
                _StockRow(row: rows[i]),
                if (i != rows.length - 1) Divider(height: 1, color: colors.border),
              ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => AppNavigation.open(const AppRoute(type: RouteType.inventory)),
                icon: const Icon(Iconsax.box_1, size: 17),
                label: const Text('فتح المخزون'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.row});
  final LowStockItem row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qty = row.currentQuantity;
    final min = row.minQuantity;
    final ratio = min <= 0 ? 0.0 : (qty / min).clamp(0.0, 1.0);
    final quantityLabel = '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} / ${min.toStringAsFixed(min.truncateToDouble() == min ? 0 : 2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(quantityLabel, style: TextStyle(color: colors.error, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: Text(row.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                  Text(quantityLabel, style: TextStyle(color: colors.error, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(row.warehouseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              color: colors.error,
              backgroundColor: colors.error.withValues(alpha: .09),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PremiumBackdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary)),
            const SizedBox(height: 14),
            Text('نجهّز ملخص أعمالك…', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
