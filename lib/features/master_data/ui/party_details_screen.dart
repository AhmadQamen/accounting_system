import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/domain/party_balance.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/services/excel_export_service.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class PartyDetailsScreen extends ConsumerWidget {
  const PartyDetailsScreen({super.key, required this.party});

  final Party party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'IQD';
    final compact = showCompactPageAppBar(context);
    return MyScaffold(
      appBar: compact ? BlurAppBar(title: Text(party.name)) : null,
      body: PremiumBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 28,
              16,
              compact ? 12 : 28,
              20,
            ),
            child: FutureBuilder<List<PartyInvoiceReportRow>>(
              future: ref
                  .read(reportsRepositoryProvider)
                  .partyInvoices(party.id!),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر تحميل فواتير الطرف',
                    subtitle: '${snapshot.error}',
                  );
                }
                final rows = snapshot.data ?? const <PartyInvoiceReportRow>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PremiumPanel(
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        spacing: 16,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                backgroundColor: context.colors.primary
                                    .withValues(alpha: .12),
                                child: Icon(
                                  Iconsax.user,
                                  color: context.colors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    party.name,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${_partyType(party.type)}${party.phone == null ? '' : ' • ${party.phone}'}',
                                    style: TextStyle(
                                      color: context.colors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusPill(
                                label:
                                    '${party.currentBalanceMinor.partyBalanceLabel} • ${_money(context, party.currentBalanceMinor.partyDisplayAmountMinor, currency)}',
                                color:
                                    switch (party.currentBalanceMinor.partyBalanceStatus) {
                                      PartyBalanceStatus.receivable => context.colors.success,
                                      PartyBalanceStatus.payable => context.colors.warning,
                                      PartyBalanceStatus.settled => context.colors.textSecondary,
                                    },
                                icon: Iconsax.wallet_2,
                              ),
                              FilledButton.icon(
                                onPressed:
                                    rows.isEmpty
                                        ? null
                                        : () =>
                                            _export(context, rows, currency),
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
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              title: 'فواتير الطرف',
                              subtitle: '${rows.length} مستند',
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child:
                                  rows.isEmpty
                                      ? const EmptyState(
                                        icon: Iconsax.receipt,
                                        title: 'لا توجد فواتير لهذا الطرف',
                                      )
                                      : ListView.separated(
                                        itemCount: rows.length,
                                        separatorBuilder:
                                            (_, __) => Divider(
                                              height: 1,
                                              color: context.colors.border,
                                            ),
                                        itemBuilder: (context, index) {
                                          final row = rows[index];
                                          return ListTile(
                                            leading: Icon(
                                              _typeIcon(row.type),
                                              color: context.colors.primary,
                                            ),
                                            title: Text(
                                              '${_documentType(row.type)} • ${row.number}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${_date(row.occurredAt)} • ${_status(row.status)}',
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _money(
                                                    context,
                                                    row.totalMinor,
                                                    currency,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  'المتبقي المسجل: ${_money(context, row.recordedRemainingMinor, currency)}',
                                                  style: TextStyle(
                                                    color:
                                                        context.colors.textDim,
                                                    fontSize: 10,
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
    BuildContext context,
    List<PartyInvoiceReportRow> rows,
    String currency,
  ) async {
    try {
      final path = await ExcelExportService.export(
        fileName: 'فواتير_${party.name}',
        sheetName: 'فواتير الطرف',
        title: 'فواتير ${party.name}',
        contextLines: [
          'نوع الطرف: ${_partyType(party.type)}',
          'العملة: $currency',
          'ملاحظة: المتبقي هو المسجل داخل الفاتورة ولا يوزع الدفعات اللاحقة غير المخصصة.',
        ],
        columns: const [
          ExcelColumn('نوع المستند', width: 18),
          ExcelColumn('رقم المستند', width: 28),
          ExcelColumn('التاريخ', width: 22),
          ExcelColumn('الحالة', width: 14),
          ExcelColumn('الإجمالي', width: 18),
          ExcelColumn('المدفوع/المسترد', width: 18),
          ExcelColumn('المتبقي المسجل', width: 18),
        ],
        rows: [
          for (final row in rows)
            [
              _documentType(row.type),
              row.number,
              row.occurredAt?.toLocal(),
              _status(row.status),
              row.totalMinor / 100,
              row.paidMinor / 100,
              row.recordedRemainingMinor / 100,
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
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  static String _partyType(String value) => switch (value) {
    'supplier' => 'مورد',
    'both' => 'عميل ومورد',
    _ => 'عميل',
  };

  static String _documentType(String value) => switch (value) {
    'purchase' => 'فاتورة شراء',
    'sale_return' => 'مرتجع بيع',
    'purchase_return' => 'مرتجع شراء',
    _ => 'فاتورة بيع',
  };

  static IconData _typeIcon(String value) => switch (value) {
    'purchase' => Iconsax.shopping_cart,
    'sale_return' || 'purchase_return' => Iconsax.rotate_left,
    _ => Iconsax.receipt_1,
  };

  static String _status(String value) => switch (value) {
    'posted' => 'معتمدة',
    'void' => 'ملغاة',
    _ => 'مسودة',
  };
}
