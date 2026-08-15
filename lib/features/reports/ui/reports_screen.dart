import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    final compact = MediaQuery.sizeOf(context).width < 900;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: compact ? AppBar(title: const Text('التقارير')) : null,
        body: PremiumBackdrop(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              22,
              compact ? 16 : 28,
              24,
            ),
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
                        subtitle:
                            'قراءة مالية ومخزنية هادئة تساعدك على اتخاذ القرار بسرعة.',
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
                            Tab(
                              text: 'المبيعات',
                              icon: Icon(Iconsax.receipt_1, size: 17),
                            ),
                            Tab(
                              text: 'المشتريات',
                              icon: Icon(Iconsax.shopping_cart, size: 17),
                            ),
                            Tab(
                              text: 'المخزون',
                              icon: Icon(Iconsax.box_1, size: 17),
                            ),
                            Tab(
                              text: 'الأطراف',
                              icon: Icon(Iconsax.people, size: 17),
                            ),
                            Tab(
                              text: 'الصناديق',
                              icon: Icon(Iconsax.wallet_money, size: 17),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _moneySummary(
                            context,
                            ref
                                .read(reportsRepositoryProvider)
                                .salesReport(from, to),
                            currency,
                            const [
                              (
                                'إجمالي المبيعات',
                                'gross_sales',
                                Iconsax.receipt_1,
                              ),
                              (
                                'الخصومات',
                                'discounts',
                                Icons.discount_outlined,
                              ),
                              ('المرتجعات', 'returns', Iconsax.rotate_left),
                              (
                                'صافي المبيعات',
                                'net_sales',
                                Icons.payments_outlined,
                              ),
                              ('تكلفة البضاعة', 'cogs', Iconsax.box),
                              (
                                'مجمل الربح',
                                'gross_profit',
                                Icons.trending_up_rounded,
                              ),
                            ],
                          ),
                          _moneySummary(
                            context,
                            ref
                                .read(reportsRepositoryProvider)
                                .purchasesReport(from, to),
                            currency,
                            const [
                              (
                                'إجمالي المشتريات',
                                'gross_purchases',
                                Iconsax.shopping_cart,
                              ),
                              (
                                'الخصومات',
                                'discounts',
                                Icons.discount_outlined,
                              ),
                              ('مرتجعات الشراء', 'returns', Iconsax.undo),
                              (
                                'صافي المشتريات',
                                'net_purchases',
                                Iconsax.money_send,
                              ),
                            ],
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

  Widget _moneySummary(
    BuildContext context,
    Future<Map<String, Object?>> future,
    String currency,
    List<(String, String, IconData)> fields,
  ) {
    return FutureBuilder<Map<String, Object?>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل التقرير',
            subtitle: '${snapshot.error}',
          );
        final row = snapshot.data ?? const <String, Object?>{};
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'ملخص الشهر الحالي',
                  subtitle:
                      '${DateTime.now().month}/${DateTime.now().year} • بيانات المستندات المعتمدة',
                  trailing:
                      row['invoice_count'] == null
                          ? null
                          : StatusPill(
                            label: '${row['invoice_count']} فاتورة',
                            color: context.colors.primary,
                            icon: Icons.description_outlined,
                          ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols =
                        constraints.maxWidth >= 1000
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
                            height: 135,
                            child: MetricCard(
                              label: fields[i].$1,
                              value: Money(
                                ((row[fields[i].$2] ?? 0) as num).toInt(),
                              ).format(
                                locale:
                                    Localizations.localeOf(context).toString(),
                                currencyCode: currency,
                              ),
                              icon: fields[i].$3,
                              accent:
                                  i == fields.length - 1
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
    return FutureBuilder<List<Map<String, Object?>>>(
      future: ref.read(reportsRepositoryProvider).inventoryBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير المخزون',
            subtitle: '${snapshot.error}',
          );
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        final total = rows.fold<int>(
          0,
          (s, r) => s + (((r['inventory_value_minor'] as num?) ?? 0).toInt()),
        );
        return _reportList(
          context,
          title: 'أرصدة المخزون',
          subtitle: 'القيمة الكلية ${_money(context, total, currency)}',
          emptyTitle: 'لا توجد أرصدة مخزون',
          rows:
              rows.indexed.map((entry) {
                final row = entry.$2;
                final qty = ((row['current_quantity'] as num?) ?? 0).toDouble();
                final min = ((row['min_quantity'] as num?) ?? 0).toDouble();
                final low = min > 0 && qty <= min;
                return _ReportRow(
                  icon: low ? Iconsax.warning_2 : Iconsax.box,
                  accent: low ? context.colors.error : context.colors.primary,
                  title: '${row['product_name']}',
                  subtitle: '${row['warehouse_name']} • الكمية ${_qty(qty)}',
                  value: _money(
                    context,
                    ((row['inventory_value_minor'] as num?) ?? 0).toInt(),
                    currency,
                  ),
                  divider: entry.$1 != rows.length - 1,
                );
              }).toList(),
        );
      },
    );
  }

  Widget _parties(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: ref.read(reportsRepositoryProvider).partyBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير الأطراف',
            subtitle: '${snapshot.error}',
          );
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        return _reportList(
          context,
          title: 'أرصدة الأطراف',
          subtitle: 'العملاء والموردون حسب الرصيد الحالي',
          emptyTitle: 'لا توجد أطراف',
          rows:
              rows.indexed.map((entry) {
                final row = entry.$2;
                final balance =
                    ((row['current_balance_minor'] as num?) ?? 0).toInt();
                final color =
                    balance > 0
                        ? context.colors.success
                        : balance < 0
                        ? context.colors.warning
                        : context.colors.textSecondary;
                return _ReportRow(
                  icon: Icons.person_outline_rounded,
                  accent: color,
                  title: '${row['name']}',
                  subtitle:
                      balance > 0
                          ? 'مدين لنا'
                          : balance < 0
                          ? 'نحن مدينون له'
                          : 'متوازن',
                  value: _money(context, balance.abs(), currency),
                  divider: entry.$1 != rows.length - 1,
                );
              }).toList(),
        );
      },
    );
  }

  Widget _cash(
    BuildContext context,
    WidgetRef ref,
    String currency,
    DateTime from,
    DateTime to,
  ) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        ref.read(reportsRepositoryProvider).cashBalances(),
        ref.read(reportsRepositoryProvider).cashFlowReport(from, to),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير الصناديق',
            subtitle: '${snapshot.error}',
          );
        final boxes = snapshot.data![0] as List<Map<String, Object?>>;
        final flow = snapshot.data![1] as Map<String, Object?>;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumPanel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols =
                        constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 560
                            ? 2
                            : 1;
                    final width =
                        (constraints.maxWidth - ((cols - 1) * 12)) / cols;
                    final data = [
                      (
                        'الداخل',
                        'total_in',
                        Icons.abc_sharp,
                        context.colors.success,
                      ),
                      (
                        'الخارج',
                        'total_out',
                        Iconsax.arrow_up_2,
                        context.colors.error,
                      ),
                      (
                        'صافي التدفق',
                        'net_flow',
                        Icons.trending_up_rounded,
                        context.colors.primary,
                      ),
                      (
                        'المصروفات',
                        'expenses',
                        Iconsax.money_send,
                        context.colors.warning,
                      ),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in data)
                          SizedBox(
                            width: width,
                            height: 132,
                            child: MetricCard(
                              label: item.$1,
                              value: _money(
                                context,
                                ((flow[item.$2] as num?) ?? 0).toInt(),
                                currency,
                              ),
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
                rows:
                    boxes.indexed
                        .map(
                          (entry) => _ReportRow(
                            icon: Iconsax.wallet_3,
                            accent: context.colors.primary,
                            title: '${entry.$2['name']}',
                            subtitle: 'الرصيد الحالي',
                            value: _money(
                              context,
                              ((entry.$2['current_balance_minor'] as num?) ?? 0)
                                  .toInt(),
                              currency,
                            ),
                            divider: entry.$1 != boxes.length - 1,
                          ),
                        )
                        .toList(),
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
            if (rows.isEmpty)
              EmptyState(title: emptyTitle, icon: Icons.description_outlined)
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  String _money(BuildContext context, int value, String currency) =>
      Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  String _qty(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.divider,
  });
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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textDim, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (divider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
