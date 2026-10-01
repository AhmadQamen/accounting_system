import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/services/excel_export_service.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class CashboxDetailsArgs {
  const CashboxDetailsArgs({required this.id, required this.name});
  final String id;
  final String name;
}

class CashboxDetailsScreen extends ConsumerWidget {
  const CashboxDetailsScreen({super.key, required this.args});
  final CashboxDetailsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'IQD';
    final compact = showCompactPageAppBar(context);
    return MyScaffold(
      appBar: compact ? BlurAppBar(title: Text(args.name)) : null,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 28,
              16,
              compact ? 12 : 28,
              20,
            ),
            child: FutureBuilder<CashboxDetails>(
              future: ref.read(cashRepositoryProvider).cashboxDetails(args.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر تحميل تفاصيل الصندوق',
                    subtitle: '${snapshot.error}',
                  );
                }
                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumPanel(
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 10,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.cashbox.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'الرصيد الحالي ${_money(context, data.cashbox.currentBalanceMinor, currency)}',
                                style: TextStyle(color: context.colors.textDim),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed:
                                data.transactions.isEmpty
                                    ? null
                                    : () => _export(ref, data, currency),
                            icon: const Icon(
                              Iconsax.document_download,
                              size: 18,
                            ),
                            label: const Text('تصدير Excel'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 92,
                      child: Row(
                        children: [
                          _Summary(
                            label: 'مبيعات',
                            value: _money(context, data.salesInMinor, currency),
                            color: context.colors.success,
                          ),
                          const SizedBox(width: 8),
                          _Summary(
                            label: 'مشتريات',
                            value: _money(
                              context,
                              data.purchasesOutMinor,
                              currency,
                            ),
                            color: context.colors.warning,
                          ),
                          const SizedBox(width: 8),
                          _Summary(
                            label: 'مصاريف',
                            value: _money(
                              context,
                              data.expensesOutMinor,
                              currency,
                            ),
                            color: context.colors.error,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              title: 'حركات الصندوق',
                              subtitle: '${data.transactions.length} حركة',
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child:
                                  data.transactions.isEmpty
                                      ? const EmptyState(
                                        icon: Iconsax.wallet_3,
                                        title: 'لا توجد حركات',
                                      )
                                      : ListView.separated(
                                        itemCount: data.transactions.length,
                                        separatorBuilder:
                                            (_, __) => Divider(
                                              height: 1,
                                              color: context.colors.border,
                                            ),
                                        itemBuilder: (context, index) {
                                          final row = data.transactions[index];
                                          final incoming =
                                              row.direction == 'in';
                                          return ListTile(
                                            leading: Icon(
                                              incoming
                                                  ? Icons.south_west_rounded
                                                  : Icons.north_east_rounded,
                                              color:
                                                  incoming
                                                      ? context.colors.success
                                                      : context.colors.error,
                                            ),
                                            title: Text(
                                              _kind(row.kind),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${_date(row.occurredAt)}${row.partyName == null ? '' : ' • ${row.partyName}'}${row.note == null ? '' : ' • ${row.note}'}',
                                            ),
                                            trailing: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${incoming ? '+' : '−'}${_money(context, row.amountMinor, currency)}',
                                                  style: TextStyle(
                                                    color:
                                                        incoming
                                                            ? context
                                                                .colors
                                                                .success
                                                            : context
                                                                .colors
                                                                .error,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                if (row.foreignAmountMinor !=
                                                        null &&
                                                    row.currencyCode != null &&
                                                    row.currencyCode !=
                                                        currency)
                                                  Text(
                                                    Money(
                                                      row.foreignAmountMinor!,
                                                    ).format(
                                                      locale:
                                                          Localizations.localeOf(
                                                            context,
                                                          ).toString(),
                                                      currencyCode:
                                                          row.currencyCode!,
                                                    ),
                                                    style: TextStyle(
                                                      color:
                                                          context
                                                              .colors
                                                              .textDim,
                                                      fontSize: 9.5,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    WidgetRef ref,
    CashboxDetails data,
    String currency,
  ) async {
    try {
      final allTransactions = await ref
          .read(cashRepositoryProvider)
          .transactionHistory(cashboxId: args.id, limit: null);
      final path = await ExcelExportService.export(
        fileName: 'حركات_${data.cashbox.name}',
        sheetName: 'حركات الصندوق',
        title: 'تقرير صندوق ${data.cashbox.name}',
        contextLines: [
          'الرصيد الحالي: ${data.cashbox.currentBalanceMinor / 100} $currency',
        ],
        columns: const [
          ExcelColumn('التاريخ', width: 22),
          ExcelColumn('نوع الحركة', width: 20),
          ExcelColumn('الاتجاه', width: 12),
          ExcelColumn('المبلغ', width: 18),
          ExcelColumn('الطرف', width: 22),
          ExcelColumn('نوع المرجع', width: 18),
          ExcelColumn('معرف المرجع', width: 28),
          ExcelColumn('ملاحظة', width: 30),
        ],
        rows: [
          for (final row in allTransactions)
            [
              row.occurredAt?.toLocal(),
              _kind(row.kind),
              row.direction == 'in' ? 'داخل' : 'خارج',
              row.amountMinor / 100,
              row.partyName ?? '',
              row.referenceType ?? '',
              row.referenceId ?? '',
              row.note ?? '',
            ],
        ],
      );
      CustomSnackBar.showSuccessSnackbar('تم حفظ ملف Excel في: $path');
    } catch (error) {
      CustomSnackBar.showErrorSnackbar(
        'تعذر تصدير ملف Excel',
        copyText: '$error',
      );
    }
  }

  static String _money(BuildContext context, int value, String currency) =>
      Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  static String _date(DateTime? value) {
    final date = value?.toLocal();
    if (date == null) return '—';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String _kind(String value) => switch (value) {
    'sale_payment' => 'قبض فاتورة بيع',
    'purchase_payment' => 'دفع فاتورة شراء',
    'expense' => 'مصروف',
    'party_payment' => 'دفعة طرف',
    'cash_transfer' => 'تحويل صندوق',
    'opening' => 'رصيد افتتاحي',
    _ => value,
  };
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: PremiumPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: context.colors.textDim)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}
