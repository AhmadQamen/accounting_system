import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/domain/party_balance.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/services/excel_export_service.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/cash/ui/cashbox_details_screen.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime from;
  late DateTime to;
  String salesFilter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, 1);
    to = DateTime(now.year, now.month + 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);

    return DefaultTabController(
      length: 5,
      child: MyScaffold(
        appBar: compact ? const BlurAppBar(title: Text('التقارير')) : null,
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
                    AnimatedEntrance(
                      child: PageIntro(
                        eyebrow: 'REPORTING',
                        title: 'التقارير',
                        subtitle:
                            'قراءة مالية ومخزنية هادئة تساعدك على اتخاذ القرار بسرعة.',
                        icon: Iconsax.chart_2,
                        actions: [
                          OutlinedButton.icon(
                            onPressed: _pickPeriod,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              '${from.year}/${from.month}/${from.day} — ${to.subtract(const Duration(days: 1)).year}/${to.subtract(const Duration(days: 1)).month}/${to.subtract(const Duration(days: 1)).day}',
                            ),
                          ),
                        ],
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
                          _sales(context, ref, currency),
                          _moneySummary<PurchasesReport>(
                            context,
                            ref
                                .read(reportsRepositoryProvider)
                                .purchasesReport(from, to),
                            currency,
                            [
                              (
                                'إجمالي المشتريات',
                                (r) => r.grossPurchases,
                                Iconsax.shopping_cart,
                              ),
                              (
                                'الخصومات',
                                (r) => r.discounts,
                                Icons.discount_outlined,
                              ),
                              (
                                'مرتجعات الشراء',
                                (r) => r.returns,
                                Iconsax.undo,
                              ),
                              (
                                'صافي المشتريات',
                                (r) => r.netPurchases,
                                Iconsax.money_send,
                              ),
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

  Future<_SalesData> _loadSales(WidgetRef ref) async {
    final repository = ref.read(reportsRepositoryProvider);
    return _SalesData(
      summary: await repository.salesReport(from, to),
      invoices: await repository.salesInvoiceProfitability(from, to),
    );
  }

  Widget _sales(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<_SalesData>(
      future: _loadSales(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير المبيعات',
            subtitle: '${snapshot.error}',
          );
        }
        final data = snapshot.data!;
        final rows = switch (salesFilter) {
          'loss' => data.invoices.where((row) => row.isLoss).toList(),
          'profit' => data.invoices.where((row) => !row.isLoss).toList(),
          _ => data.invoices,
        };
        final totalLoss = data.invoices.fold<int>(
          0,
          (sum, row) => sum + row.lossMinor,
        );
        final fields = <(String, int, IconData, Color)>[
          (
            'صافي المبيعات',
            data.summary.netSales,
            Icons.payments_outlined,
            context.colors.primary,
          ),
          (
            'تكلفة البضاعة',
            data.summary.cogs,
            Iconsax.box,
            context.colors.warning,
          ),
          (
            data.summary.grossProfit >= 0 ? 'مجمل الربح' : 'مجمل الخسارة',
            data.summary.grossProfit.abs(),
            data.summary.grossProfit >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            data.summary.grossProfit >= 0
                ? context.colors.success
                : context.colors.error,
          ),
          (
            'خسائر الفواتير',
            totalLoss,
            Iconsax.warning_2,
            context.colors.error,
          ),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumPanel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width =
                        (constraints.maxWidth -
                            (constraints.maxWidth < 650 ? 12 : 36)) /
                        (constraints.maxWidth < 650 ? 2 : 4);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final field in fields)
                          SizedBox(
                            width: width,
                            child: MetricCard(
                              label: field.$1,
                              value: _money(context, field.$2, currency),
                              icon: field.$3,
                              accent: field.$4,
                              caption: 'ضمن الفترة المحددة',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              PremiumPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 10,
                      spacing: 12,
                      children: [
                        const SectionHeader(
                          title: 'ربحية الفواتير',
                          subtitle:
                              'صافي المبيع بعد المرتجعات المرتبطة ناقص صافي تكلفة البنود',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: 'all',
                                  label: Text('الكل'),
                                ),
                                ButtonSegment(
                                  value: 'profit',
                                  label: Text('رابحة'),
                                ),
                                ButtonSegment(
                                  value: 'loss',
                                  label: Text('خاسرة'),
                                ),
                              ],
                              selected: {salesFilter},
                              onSelectionChanged:
                                  (value) =>
                                      setState(() => salesFilter = value.first),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  rows.isEmpty
                                      ? null
                                      : () => _exportSales(rows, currency),
                              icon: const Icon(
                                Iconsax.document_download,
                                size: 18,
                              ),
                              label: const Text('تصدير Excel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      EmptyState(
                        icon: Iconsax.receipt,
                        title:
                            salesFilter == 'loss'
                                ? 'لا توجد فواتير خاسرة'
                                : 'لا توجد فواتير ضمن الفلتر',
                      )
                    else
                      ...rows.indexed.map((entry) {
                        final row = entry.$2;
                        return _ReportRow(
                          icon:
                              row.isLoss
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded,
                          accent:
                              row.isLoss
                                  ? context.colors.error
                                  : context.colors.success,
                          title: row.invoiceNumber,
                          subtitle:
                              '${row.partyName ?? 'بيع نقدي'} • ${_date(row.occurredAt)} • كلفة ${_money(context, row.costMinor, currency)}',
                          value:
                              '${row.isLoss ? 'خسارة' : 'ربح'} ${_money(context, row.profitMinor.abs(), currency)}',
                          divider: entry.$1 != rows.length - 1,
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportSales(
    List<SalesInvoiceProfitRow> rows,
    String currency,
  ) async {
    try {
      final path = await ExcelExportService.export(
        fileName: 'تقرير_ربحية_المبيعات',
        sheetName: 'ربحية المبيعات',
        title: 'تقرير ربحية فواتير المبيعات',
        contextLines: [
          'الفترة: ${_date(from)} إلى ${_date(to.subtract(const Duration(days: 1)))}',
          'الفلتر: ${salesFilter == 'loss'
              ? 'الفواتير الخاسرة'
              : salesFilter == 'profit'
              ? 'الفواتير الرابحة'
              : 'كل الفواتير'}',
          'العملة: $currency',
          'الربحية تشمل المرتجعات المعتمدة المرتبطة بكل فاتورة.',
        ],
        columns: const [
          ExcelColumn('رقم الفاتورة', width: 28),
          ExcelColumn('التاريخ', width: 22),
          ExcelColumn('الطرف', width: 22),
          ExcelColumn('صافي المبيع', width: 18),
          ExcelColumn('التكلفة', width: 18),
          ExcelColumn('الربح/الخسارة', width: 18),
          ExcelColumn('النتيجة', width: 13),
        ],
        rows: [
          for (final row in rows)
            [
              row.invoiceNumber,
              row.occurredAt?.toLocal(),
              row.partyName ?? 'بيع نقدي',
              row.salesMinor / 100,
              row.costMinor / 100,
              row.profitMinor / 100,
              row.isLoss ? 'خاسرة' : 'رابحة',
            ],
        ],
      );
      CustomSnackBar.showSuccessSnackbar('تم حفظ ملف Excel في: $path');
    } catch (error) {
      CustomSnackBar.showErrorSnackbar(
        'تعذر تصدير تقرير المبيعات',
        copyText: '$error',
      );
    }
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: from,
        end: to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked != null)
      setState(() {
        from = picked.start;
        to = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
      });
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
                  subtitle:
                      '${DateTime.now().month}/${DateTime.now().year} • بيانات المستندات المعتمدة',
                  trailing:
                      count == null
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
                    final cols =
                        constraints.maxWidth >= 1000
                            ? 3
                            : constraints.maxWidth >= 620
                            ? 2
                            : 2;
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
    return FutureBuilder<List<InventoryBalanceReport>>(
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
        final rows = snapshot.data ?? const <InventoryBalanceReport>[];
        final total = rows.fold<int>(
          0,
          (sum, row) => sum + row.inventoryValueMinor,
        );
        return _reportList(
          context,
          title: 'أرصدة المخزون',
          subtitle: 'القيمة الكلية ${_money(context, total, currency)}',
          emptyTitle: 'لا توجد أرصدة مخزون',
          rows:
              rows.indexed.map((entry) {
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
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير الأطراف',
            subtitle: '${snapshot.error}',
          );
        final rows = snapshot.data ?? const <PartyBalanceReport>[];
        return _reportList(
          context,
          title: 'أرصدة الأطراف',
          subtitle: 'العملاء والموردون حسب الرصيد الحالي',
          emptyTitle: 'لا توجد أطراف',
          rows:
              rows.indexed.map((entry) {
                final row = entry.$2;
                final balance = row.currentBalanceMinor;
                final color =
                    balance > 0
                        ? context.colors.success
                        : balance < 0
                        ? context.colors.warning
                        : context.colors.textSecondary;
                return _ReportRow(
                  icon: Icons.person_outline_rounded,
                  accent: color,
                  title: row.name,
                  subtitle: balance.partyBalanceLabel,
                  value: _money(
                    context,
                    balance.partyDisplayAmountMinor,
                    currency,
                  ),
                  divider: entry.$1 != rows.length - 1,
                  onTap:
                      () => AppNavigation.open(
                        AppRoute(
                          type: RouteType.partyDetails,
                          args: Party(
                            id: row.id,
                            name: row.name,
                            phone: row.phone,
                            type: row.type,
                            currentBalanceMinor: row.currentBalanceMinor,
                          ),
                        ),
                      ),
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
    return FutureBuilder<CashReportData>(
      future: ref.read(reportsRepositoryProvider).cashReportData(from, to),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return EmptyState(
            icon: Iconsax.warning_2,
            title: 'تعذر تحميل تقرير الصناديق',
            subtitle: '${snapshot.error}',
          );
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
                    final cols =
                        constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 560
                            ? 2
                            : 2;
                    final width =
                        (constraints.maxWidth - ((cols - 1) * 12)) / cols;
                    final data = [
                      (
                        'الداخل',
                        flow.totalIn,
                        Icons.south_rounded,
                        context.colors.success,
                      ),
                      (
                        'الخارج',
                        flow.totalOut,
                        Iconsax.arrow_up_2,
                        context.colors.error,
                      ),
                      (
                        'صافي التدفق',
                        flow.netFlow,
                        Icons.trending_up_rounded,
                        context.colors.primary,
                      ),
                      (
                        'المصروفات',
                        flow.expenses,
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
                rows:
                    boxes.indexed
                        .map(
                          (entry) => _ReportRow(
                            icon: Iconsax.wallet_3,
                            accent: context.colors.primary,
                            title: entry.$2.name,
                            subtitle: 'الرصيد الحالي',
                            value: _money(
                              context,
                              entry.$2.currentBalanceMinor,
                              currency,
                            ),
                            divider: entry.$1 != boxes.length - 1,
                            onTap:
                                () => AppNavigation.open(
                                  AppRoute(
                                    type: RouteType.cashboxDetails,
                                    args: CashboxDetailsArgs(
                                      id: entry.$2.id,
                                      name: entry.$2.name,
                                    ),
                                  ),
                                ),
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

  String _date(DateTime? value) {
    final date = value?.toLocal();
    if (date == null) return '—';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class _SalesData {
  const _SalesData({required this.summary, required this.invoices});
  final SalesReport summary;
  final List<SalesInvoiceProfitRow> invoices;
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.divider,
    this.onTap,
  });
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String value;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final identity = Row(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textDim,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final amount = Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 51),
                        child: amount,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: amount,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (divider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
