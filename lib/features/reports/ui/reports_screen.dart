import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final compact = showCompactPageAppBar(context);

    return DefaultTabController(
      length: 5,
      child: MyScaffold(
        appBar: compact ? const BlurAppBar(title: Text('التقارير')) : null,
        body: PremiumBackdrop(
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 22, compact ? 16 : 28, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AnimatedEntrance(
                      child: PageIntro(
                        eyebrow: 'REPORTING',
                        title: 'التقارير',
                        subtitle: 'قراءة مالية ومخزنية هادئة تساعدك على اتخاذ القرار بسرعة.',
                        icon: Iconsax.chart_2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 70),
                      child: PremiumPanel(
                        padding: const EdgeInsets.all(5),
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: const [
                            Tab(text: 'المبيعات', icon: Icon(Iconsax.receipt_1, size: 17)),
                            Tab(text: 'المشتريات', icon: Icon(Iconsax.shopping_cart, size: 17)),
                            Tab(text: 'المخزون', icon: Icon(Iconsax.box_1, size: 17)),
                            Tab(text: 'الأطراف', icon: Icon(Iconsax.people, size: 17)),
                            Tab(text: 'الصناديق', icon: Icon(Iconsax.wallet_money, size: 17)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _moneySummary<SalesReport>(
                            context,
                            ref.read(reportsRepositoryProvider).salesReport(from, to),
                            currency,
                            [
                              ('إجمالي المبيعات', (r) => r.grossSales, Iconsax.receipt_1),
                              ('الخصومات', (r) => r.discounts, Icons.discount_outlined),
                              ('المرتجعات', (r) => r.returns, Iconsax.rotate_left),
                              ('صافي المبيعات', (r) => r.netSales, Icons.payments_outlined),
                              ('تكلفة البضاعة', (r) => r.cogs, Iconsax.box),
                              ('مجمل الربح', (r) => r.grossProfit, Icons.trending_up_rounded),
                            ],
                            invoiceCount: (r) => r.invoiceCount,
                          ),
                          _moneySummary<PurchasesReport>(
                            context,
                            ref.read(reportsRepositoryProvider).purchasesReport(from, to),
                            currency,
                            [
                              ('إجمالي المشتريات', (r) => r.grossPurchases, Iconsax.shopping_cart),
                              ('الخصومات', (r) => r.discounts, Icons.discount_outlined),
                              ('مرتجعات الشراء', (r) => r.returns, Iconsax.undo),
                              ('صافي المشتريات', (r) => r.netPurchases, Iconsax.money_send),
                            ],
                            invoiceCount: (r) => r.invoiceCount,
                          ),
                          _inventory(context, ref, currency),
                          _parties(context, ref, currency),
                          _cash(context, ref, currency, from, to),
                        ],
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

  Widget _moneySummary<T extends Object>(
    BuildContext context,
    Future<T> future,
    String currency,
    List<(String, int Function(T), IconData)> fields, {
    int Function(T)? invoiceCount,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل التقرير',
            subtitle: '${snapshot.error}',
          );
        }
        final report = snapshot.data;
        if (report == null) {
          return const EmptyState(
            title: 'لا توجد بيانات',
            icon: Icons.description_outlined,
          );
        }
        final count = invoiceCount?.call(report);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'ملخص الشهر الحالي',
                  subtitle: '${DateTime.now().month}/${DateTime.now().year} • بيانات المستندات المعتمدة',
                  trailing: count == null
                      ? null
                      : StatusPill(
                          label: '$count فاتورة',
                          color: context.colors.primary,
                          icon: Icons.description_outlined,
                        ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 620
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - ((cols - 1) * 12)) / cols;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < fields.length; i++)
                          SizedBox(
                            width: width,
                            child: MetricCard(
                              label: fields[i].$1,
                              value: Money(fields[i].$2(report)).format(
                                locale: Localizations.localeOf(context).toString(),
                                currencyCode: currency,
                              ),
                              icon: fields[i].$3,
                              accent: i == fields.length - 1
                                  ? context.colors.success
                                  : context.colors.primary,
                              caption: 'الشهر الحالي',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _inventory(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<List<InventoryBalanceReport>>(
      future: ref.read(reportsRepositoryProvider).inventoryBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل تقرير المخزون', subtitle: '${snapshot.error}');
        final rows = snapshot.data ?? const <InventoryBalanceReport>[];
        final total = rows.fold<int>(0, (sum, row) => sum + row.inventoryValueMinor);
        return _reportList(
          context,
          title: 'أرصدة المخزون',
          subtitle: 'القيمة الكلية ${_money(context, total, currency)}',
          emptyTitle: 'لا توجد أرصدة مخزون',
          rows: rows.indexed.map((entry) {
            final row = entry.$2;
            final qty = row.currentQuantity;
            final low = row.isLowStock;
            return _ReportRow(
              icon: low ? Iconsax.warning_2 : Iconsax.box,
              accent: low ? context.colors.error : context.colors.primary,
              title: row.productName,
              subtitle: '${row.warehouseName} • الكمية ${_qty(qty)}',
              value: _money(context, row.inventoryValueMinor, currency),
              divider: entry.$1 != rows.length - 1,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _parties(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<List<PartyBalanceReport>>(
      future: ref.read(reportsRepositoryProvider).partyBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل تقرير الأطراف', subtitle: '${snapshot.error}');
        final rows = snapshot.data ?? const <PartyBalanceReport>[];
        return _reportList(
          context,
          title: 'أرصدة الأطراف',
          subtitle: 'العملاء والموردون حسب الرصيد الحالي',
          emptyTitle: 'لا توجد أطراف',
          rows: rows.indexed.map((entry) {
            final row = entry.$2;
            final balance = row.currentBalanceMinor;
            final color = balance > 0 ? context.colors.success : balance < 0 ? context.colors.warning : context.colors.textSecondary;
            return _ReportRow(
              icon: Icons.person_outline_rounded,
              accent: color,
              title: row.name,
              subtitle: balance > 0 ? 'مدين لنا' : balance < 0 ? 'نحن مدينون له' : 'متوازن',
              value: _money(context, balance.abs(), currency),
              divider: entry.$1 != rows.length - 1,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _cash(BuildContext context, WidgetRef ref, String currency, DateTime from, DateTime to) {
    return FutureBuilder<CashReportData>(
      future: ref.read(reportsRepositoryProvider).cashReportData(from, to),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل تقرير الصناديق', subtitle: '${snapshot.error}');
        final data = snapshot.data!;
        final boxes = data.balances;
        final flow = data.flow;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumPanel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
                    final width = (constraints.maxWidth - ((cols - 1) * 12)) / cols;
                    final data = [
                      ('الداخل', flow.totalIn, Icons.south_rounded, context.colors.success),
                      ('الخارج', flow.totalOut, Iconsax.arrow_up_2, context.colors.error),
                      ('صافي التدفق', flow.netFlow, Icons.trending_up_rounded, context.colors.primary),
                      ('المصروفات', flow.expenses, Iconsax.money_send, context.colors.warning),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in data)
                          SizedBox(
                            width: width,
                            child: MetricCard(
                              label: item.$1,
                              value: _money(context, item.$2, currency),
                              icon: item.$3,
                              accent: item.$4,
                              caption: 'الشهر الحالي',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _reportList(
                context,
                title: 'أرصدة الصناديق',
                subtitle: 'الرصيد الحالي حسب دفتر الحركات',
                emptyTitle: 'لا توجد صناديق',
                rows: boxes.indexed.map((entry) => _ReportRow(
                      icon: Iconsax.wallet_3,
                      accent: context.colors.primary,
                      title: entry.$2.name,
                      subtitle: 'الرصيد الحالي',
                      value: _money(context, entry.$2.currentBalanceMinor, currency),
                      divider: entry.$1 != boxes.length - 1,
                    )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reportList(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String emptyTitle,
    required List<Widget> rows,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: PremiumPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 12),
            if (rows.isEmpty) EmptyState(title: emptyTitle, icon: Icons.description_outlined) else ...rows,
          ],
        ),
      ),
    );
  }

  String _money(BuildContext context, int value, String currency) => Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  String _qty(double value) => value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.icon, required this.accent, required this.title, required this.subtitle, required this.value, required this.divider});
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final identity = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
                    child: Icon(icon, color: accent, size: 19),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              );
              final amount = Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w900));
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, const SizedBox(height: 8), Padding(padding: const EdgeInsetsDirectional.only(start: 51), child: amount)],
                );
              }
              return Row(children: [Expanded(child: identity), const SizedBox(width: 12), Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: amount))]);
            },
          ),
        ),
        if (divider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
