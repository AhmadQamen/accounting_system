import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/domain/party_balance.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PartyDetailsDialog extends ConsumerStatefulWidget {
  const PartyDetailsDialog({super.key, required this.party});
  final Party party;

  @override
  ConsumerState<PartyDetailsDialog> createState() => _PartyDetailsDialogState();
}

class _PartyDetailsDialogState extends ConsumerState<PartyDetailsDialog> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final partyId = widget.party.id!;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.party.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${widget.party.phone ?? ''} • ${widget.party.type}'),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<PartyAccountSnapshot>(
                  key: ValueKey(revision),
                  future: _summary(partyId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(child: Text('${snapshot.error}'));
                    final data = snapshot.data!;
                    final balance = data.balanceMinor;
                    final ledger = data.ledger;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              runSpacing: 8,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('الرصيد الحالي'),
                                    Text(
                                      Money(balance.partyDisplayAmountMinor).format(
                                        locale:
                                            Localizations.localeOf(
                                              context,
                                            ).toString(),
                                        currencyCode: currency,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      balance.partyBalanceLabel,
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => _payment(receive: true),
                                      icon: const Icon(Icons.south_west),
                                      label: const Text('قبض من الطرف'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _payment(receive: false),
                                      icon: const Icon(Icons.north_east),
                                      label: const Text('دفع للطرف'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _showStatement,
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      label: const Text('كشف الحساب والفواتير'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'كشف الحساب',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child:
                              ledger.isEmpty
                                  ? const Center(
                                    child: Text('لا توجد حركات على هذا الطرف'),
                                  )
                                  : ListView.separated(
                                    itemCount: ledger.length,
                                    separatorBuilder:
                                        (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final row = ledger[index];
                                      final delta = row.balanceDeltaMinor;
                                      final amountText = Money(delta.abs()).format(
                                        locale: Localizations.localeOf(context).toString(),
                                        currencyCode: currency,
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final info = Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  partyLedgerEntryLabel(
                                                    row.entryType,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${row.occurredAt?.toLocal().toString() ?? ''} • ${row.referenceType ?? ''}',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        context.colors.textDim,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            );
                                            final amount = Text(
                                              amountText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    delta > 0
                                                        ? context.colors.success
                                                        : delta < 0
                                                        ? context.colors.warning
                                                        : context.colors.textSecondary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            );
                                            if (constraints.maxWidth < 440)
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  info,
                                                  const SizedBox(height: 5),
                                                  amount,
                                                ],
                                              );
                                            return Row(
                                              children: [
                                                Expanded(child: info),
                                                const SizedBox(width: 10),
                                                Flexible(child: amount),
                                              ],
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<PartyAccountSnapshot> _summary(String partyId) =>
      ref.read(cashRepositoryProvider).partyAccountSummary(partyId);

  Future<void> _showStatement() async {
    final cash = ref.read(cashRepositoryProvider);
    final statement = await cash.partyStatement(widget.party.id!);
    final documents = await cash.partyOpenDocuments(widget.party.id!);
    if (!mounted) return;
    final currency =
        ref.read(localContextProvider).asData?.value.currencyCode ?? 'IQD';
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('كشف الحساب والفواتير غير المسددة'),
            content: SizedBox(
              width: responsiveDialogWidth(context, 760),
              height: responsiveDialogHeight(context, 560),
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('رصيد البداية'),
                    trailing: Text(
                      Money(statement.openingMinor).format(
                        locale: Localizations.localeOf(context).toString(),
                        currencyCode: currency,
                      ),
                    ),
                  ),
                  ...statement.entries.map(
                    (row) => ListTile(
                      title: Text(partyLedgerEntryLabel(row.entryType)),
                      subtitle: Text(
                        '${row.referenceType ?? ''} • ${row.referenceId ?? ''} • ${row.occurredAt?.toLocal() ?? ''}',
                      ),
                      trailing: Text(
                        Money(row.balanceDeltaMinor.abs()).format(
                          locale: Localizations.localeOf(context).toString(),
                          currencyCode: currency,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('رصيد النهاية'),
                    trailing: Text(
                      Money(statement.closingMinor.partyDisplayAmountMinor).format(
                        locale: Localizations.localeOf(context).toString(),
                        currencyCode: currency,
                      ),
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'المتبقي المسجل داخل المستند',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'لا يشمل الدفعات اللاحقة غير المخصصة لفاتورة محددة.',
                  ),
                  ...documents.map(
                    (doc) => ListTile(
                      title: Text('${doc.type} • ${doc.number}'),
                      subtitle: Text(doc.status),
                      trailing: Text(
                        Money(doc.recordedRemainingMinor).format(
                          locale: Localizations.localeOf(context).toString(),
                          currencyCode: currency,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  Future<void> _payment({required bool receive}) async {
    final cashboxes = await ref.read(cashRepositoryProvider).listCashboxes();
    final currencies =
        await ref.read(currencyRepositoryProvider).listCurrencies();
    if (!mounted) return;
    if (cashboxes.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أضف صندوقاً أولاً');
      return;
    }
    var cashboxId = cashboxes.first.id!;
    var selectedCurrency = currencies.first;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: Text(receive ? 'قبض من الطرف' : 'دفع للطرف'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: cashboxId,
                          items:
                              cashboxes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id!,
                                      child: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null)
                              setLocal(() => cashboxId = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'الصندوق',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedCurrency.code,
                          items: currencies
                              .where((item) => item.rateMicros > 0)
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.code,
                                  child: Text(
                                    item.isBase
                                        ? '${item.code} • الأساسية'
                                        : '${item.code} • 1 = ${CurrencyMath.formatRateMicros(item.rateMicros)}',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocal(
                              () =>
                                  selectedCurrency = currencies.firstWhere(
                                    (item) => item.code == value,
                                  ),
                            );
                          },
                          decoration: const InputDecoration(
                            labelText: 'عملة الدفعة',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setLocal(() {}),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                        if (!selectedCurrency.isBase &&
                            amount.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              try {
                                final foreign = Money.fromMajor(
                                  amount.text,
                                  decimals: selectedCurrency.decimalDigits,
                                );
                                final base = CurrencyMath.toBaseMinor(
                                  foreign,
                                  selectedCurrency.rateMicros,
                                );
                                final baseCode =
                                    ref
                                        .read(localContextProvider)
                                        .asData
                                        ?.value
                                        .currencyCode ??
                                    '';
                                return Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    'المقابل: ${Money(base).format(locale: Localizations.localeOf(context).toString(), currencyCode: baseCode)}',
                                    style: TextStyle(
                                      color: context.colors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: note,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('اعتماد'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true) {
      try {
        final foreignAmount = Money.fromMajor(
          amount.text,
          decimals: selectedCurrency.decimalDigits,
        );
        final baseAmount = CurrencyMath.toBaseMinor(
          foreignAmount,
          selectedCurrency.rateMicros,
        );
        await ref
            .read(cashRepositoryProvider)
            .partyPayment(
              partyId: widget.party.id!,
              cashboxId: cashboxId,
              amountMinor: baseAmount,
              receiveFromParty: receive,
              note: note.text,
              currencyCode: selectedCurrency.code,
              exchangeRateMicros: selectedCurrency.rateMicros,
              foreignAmountMinor: foreignAmount,
            );
        ref.read(dataRevisionProvider.notifier).state++;
        setState(() => revision++);
      } catch (e) {
        if (mounted) CustomSnackBar.showErrorSnackbar('$e');
      }
    }
    amount.dispose();
    note.dispose();
  }
}
