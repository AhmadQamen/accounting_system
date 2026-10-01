import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/services/closing_accounts_service.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ClosingAccountsScreen extends ConsumerWidget {
  const ClosingAccountsScreen({super.key});

  bool _allowed(String role) => const {
    'owner',
    'admin',
    'accountant',
    'manager',
  }.contains(role.toLowerCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(localContextProvider).asData?.value;
    if (local == null) {
      return const MyScaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed(local.role)) {
      return const MyScaffold(
        body: PremiumPage(
          child: EmptyState(
            title: 'الحسابات الختامية للمحاسب أو المدير فقط',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    final database = ref.read(appDatabaseProvider);
    return DefaultTabController(
      length: 3,
      child: MyScaffold(
        appBar: const BlurAppBar(title: Text('الحسابات الختامية')),
        body: PremiumBackdrop(
          child: FutureBuilder<ClosingAccountsReport>(
            future: database.database.then(
              (db) => const ClosingAccountsService().build(
                db,
                entityId: local.entityId,
                financialYearId: local.financialYearId,
              ),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'تعذر إعداد الحسابات الختامية: ${snapshot.error}',
                  ),
                );
              }
              final report = snapshot.requireData;
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReportHeader(report: report),
                    const SizedBox(height: 10),
                    _CurrencyReferenceStrip(report: report),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(text: 'حساب المتاجرة'),
                        Tab(text: 'الأرباح والخسائر'),
                        Tab(text: 'الميزانية'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _TradingStatement(report: report),
                          _ProfitAndLossStatement(report: report),
                          _BalanceSheet(report: report),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CurrencyReferenceStrip extends ConsumerStatefulWidget {
  const _CurrencyReferenceStrip({required this.report});

  final ClosingAccountsReport report;

  @override
  ConsumerState<_CurrencyReferenceStrip> createState() =>
      _CurrencyReferenceStripState();
}

class _CurrencyReferenceStripState
    extends ConsumerState<_CurrencyReferenceStrip> {
  String? selectedCode;

  @override
  Widget build(BuildContext context) {
    final asyncCurrencies = ref.watch(currenciesProvider);
    return asyncCurrencies.maybeWhen(
      data: (currencies) {
        if (currencies.isEmpty) return const SizedBox.shrink();
        selectedCode ??= widget.report.currencyCode;
        final selected = currencies.firstWhere(
          (item) => item.code == selectedCode && item.rateMicros > 0,
          orElse: () => currencies.first,
        );
        final colors = context.colors;
        String converted(int baseMinor) => Money(
          CurrencyMath.fromBaseMinor(baseMinor, selected.rateMicros),
          decimals: selected.decimalDigits,
        ).format(
          locale: Localizations.localeOf(context).toString(),
          currencyCode: selected.code,
        );

        Widget metric(String label, int amount) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.textDim, fontSize: 9.5),
              ),
              const SizedBox(height: 2),
              Text(
                converted(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: colors.bgElevated.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final selector = DropdownButton<String>(
                value: selected.code,
                underline: const SizedBox.shrink(),
                items: currencies
                    .where((item) => item.rateMicros > 0)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.code,
                        child: Text(item.code),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => selectedCode = value),
              );
              final metrics = Row(
                children: [
                  metric('الموجودات', widget.report.assetsMinor),
                  const SizedBox(width: 8),
                  metric(
                    'المطلوبات وحقوق الملكية',
                    widget.report.liabilitiesAndEquityMinor,
                  ),
                  const SizedBox(width: 8),
                  metric('نتيجة السنة', widget.report.netProfitMinor),
                ],
              );
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'عرض مرجعي فقط — القيود والتوازن بعملة المؤسسة',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        selector,
                      ],
                    ),
                    const SizedBox(height: 7),
                    metrics,
                  ],
                );
              }
              return Row(
                children: [
                  const Text(
                    'عرض مرجعي',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  selector,
                  const SizedBox(width: 16),
                  Expanded(child: metrics),
                  const SizedBox(width: 12),
                  Text(
                    'التوازن الرسمي بـ ${widget.report.currencyCode}',
                    style: TextStyle(color: colors.textDim, fontSize: 9.5),
                  ),
                ],
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report});
  final ClosingAccountsReport report;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy/MM/dd', 'ar');
    final color = report.isReliable ? Colors.teal : Colors.amber;
    final message =
        report.unbalancedEntries > 0
            ? 'يوجد ${report.unbalancedEntries} قيد غير متوازن؛ النتائج غير معتمدة.'
            : report.missingJournalOperations > 0
            ? 'يوجد ${report.missingJournalOperations} عملية مرحّلة بلا قيد محاسبي؛ النتائج غير مكتملة.'
            : !report.balanceSheetIsBalanced
            ? 'الميزانية غير متوازنة بفارق ${_money(context, report, report.balanceDifferenceMinor)}.'
            : 'جميع القيود متوازنة والتغطية المحاسبية مكتملة.';
    return PremiumPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(
            '${report.financialYearName}  •  ${date.format(report.startsOn)} — ${date.format(report.endsOn)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: .38)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  report.isReliable
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    message,
                    softWrap: true,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
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

class _TradingStatement extends StatelessWidget {
  const _TradingStatement({required this.report});
  final ClosingAccountsReport report;

  @override
  Widget build(BuildContext context) => _StatementLayout(
    leading: _StatementSection(
      title: 'تكلفة المبيعات',
      rows: [_AmountRow('تكلفة البضاعة المباعة', report.costOfGoodsSoldMinor)],
      totalLabel: 'إجمالي تكلفة المبيعات',
      totalMinor: report.costOfGoodsSoldMinor,
      report: report,
    ),
    trailing: _StatementSection(
      title: 'صافي الإيراد التجاري',
      rows: [
        ...report.revenueLines
            .where((line) => line.code == '410' || line.code == '420')
            .map((line) => _AmountRow(line.name, line.creditBalanceMinor)),
      ],
      totalLabel: 'صافي المبيعات',
      totalMinor: report.netSalesMinor,
      report: report,
    ),
    footer: _ResultCard(
      label: report.grossProfitMinor >= 0 ? 'مجمل الربح' : 'مجمل الخسارة',
      amountMinor: report.grossProfitMinor.abs(),
      positive: report.grossProfitMinor >= 0,
      report: report,
      caption: 'وفق الجرد المستمر: صافي المبيعات − تكلفة البضاعة المباعة',
    ),
  );
}

class _ProfitAndLossStatement extends StatelessWidget {
  const _ProfitAndLossStatement({required this.report});
  final ClosingAccountsReport report;

  @override
  Widget build(BuildContext context) => _StatementLayout(
    leading: _StatementSection(
      title: 'المصروفات والخسائر',
      rows: report.expenseLines
          .where((line) => line.code != '510')
          .map((line) => _AmountRow(line.name, line.debitBalanceMinor))
          .toList(growable: false),
      totalLabel: 'إجمالي المصروفات',
      totalMinor: report.operatingExpensesMinor,
      report: report,
    ),
    trailing: _StatementSection(
      title: 'الأرباح والإيرادات',
      rows: [
        _AmountRow('مجمل الربح من المتاجرة', report.grossProfitMinor),
        ...report.revenueLines
            .where((line) => line.code != '410' && line.code != '420')
            .map((line) => _AmountRow(line.name, line.creditBalanceMinor)),
      ],
      totalLabel: 'الإيرادات قبل المصروفات',
      totalMinor: report.grossProfitMinor + report.otherRevenueMinor,
      report: report,
    ),
    footer: _ResultCard(
      label: report.netProfitMinor >= 0 ? 'صافي ربح السنة' : 'صافي خسارة السنة',
      amountMinor: report.netProfitMinor.abs(),
      positive: report.netProfitMinor >= 0,
      report: report,
      caption: 'نتيجة السنة معروضة ضمن حقوق الملكية في الميزانية دون قيد إقفال',
    ),
  );
}

class _BalanceSheet extends StatelessWidget {
  const _BalanceSheet({required this.report});
  final ClosingAccountsReport report;

  @override
  Widget build(BuildContext context) {
    final assets = report.linesOfType('asset');
    final liabilities = report.linesOfType('liability');
    final equity = report.linesOfType('equity');
    return _StatementLayout(
      leading: _StatementSection(
        title: 'الموجودات',
        rows:
            assets
                .map((line) => _AmountRow(line.name, line.debitBalanceMinor))
                .toList(),
        totalLabel: 'إجمالي الموجودات',
        totalMinor: report.assetsMinor,
        report: report,
      ),
      trailing: _StatementSection(
        title: 'المطلوبات وحقوق الملكية',
        rows: [
          ...liabilities.map(
            (line) => _AmountRow(line.name, line.creditBalanceMinor),
          ),
          ...equity.map(
            (line) => _AmountRow(line.name, line.creditBalanceMinor),
          ),
          _AmountRow(
            report.netProfitMinor >= 0
                ? 'صافي ربح السنة الحالية'
                : 'صافي خسارة السنة الحالية',
            report.netProfitMinor,
          ),
        ],
        totalLabel: 'إجمالي المطلوبات وحقوق الملكية',
        totalMinor: report.liabilitiesAndEquityMinor,
        report: report,
      ),
      footer: _ResultCard(
        label:
            report.balanceSheetIsBalanced
                ? 'الميزانية متوازنة'
                : 'فرق الميزانية',
        amountMinor: report.balanceDifferenceMinor.abs(),
        positive: report.balanceSheetIsBalanced,
        report: report,
        caption:
            report.balanceSheetIsBalanced
                ? 'إجمالي الموجودات يساوي المطلوبات وحقوق الملكية'
                : 'راجع العمليات غير المقيدة أو الحسابات ذات الطبيعة غير الصحيحة',
      ),
    );
  }
}

class _StatementLayout extends StatelessWidget {
  const _StatementLayout({
    required this.leading,
    required this.trailing,
    required this.footer,
  });
  final Widget leading;
  final Widget trailing;
  final Widget footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 820;
      final sections =
          wide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leading),
                  const SizedBox(width: 12),
                  Expanded(child: trailing),
                ],
              )
              : Column(
                children: [leading, const SizedBox(height: 12), trailing],
              );
      return ListView(children: [sections, const SizedBox(height: 12), footer]);
    },
  );
}

class _AmountRow {
  const _AmountRow(this.label, this.amountMinor);
  final String label;
  final int amountMinor;
}

class _StatementSection extends StatelessWidget {
  const _StatementSection({
    required this.title,
    required this.rows,
    required this.totalLabel,
    required this.totalMinor,
    required this.report,
  });
  final String title;
  final List<_AmountRow> rows;
  final String totalLabel;
  final int totalMinor;
  final ClosingAccountsReport report;

  @override
  Widget build(BuildContext context) => PremiumPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'لا توجد أرصدة',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          )
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(child: Text(row.label)),
                  Text(
                    _money(context, report, row.amountMinor),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                totalLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              _money(context, report, totalMinor),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.label,
    required this.amountMinor,
    required this.positive,
    required this.report,
    required this.caption,
  });
  final String label;
  final int amountMinor;
  final bool positive;
  final ClosingAccountsReport report;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.teal : Colors.redAccent;
    return PremiumPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(context, report, amountMinor),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(BuildContext context, ClosingAccountsReport report, int minor) =>
    Money(minor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: report.currencyCode,
    );
