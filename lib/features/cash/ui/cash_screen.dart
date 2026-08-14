import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CashScreenMode { cashboxes, expenses, transfers, sessions }

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key, required this.mode});
  final CashScreenMode mode;

  String get title => switch (mode) {
        CashScreenMode.cashboxes => 'الصناديق',
        CashScreenMode.expenses => 'المصروفات',
        CashScreenMode.transfers => 'تحويلات الصندوق',
        CashScreenMode.sessions => 'جلسات الصندوق',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(onPressed: () => _action(context, ref), child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _load(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, Object?>>[];
          if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            itemBuilder: (context, index) => _row(context, ref, rows[index], currency),
          );
        },
      ),
    );
  }

  Future<List<Map<String, Object?>>> _load(WidgetRef ref) => switch (mode) {
        CashScreenMode.cashboxes => ref.read(cashRepositoryProvider).listCashboxes(),
        CashScreenMode.expenses => ref.read(cashRepositoryProvider).listExpenses(),
        CashScreenMode.transfers => ref.read(cashRepositoryProvider).listTransfers(),
        CashScreenMode.sessions => ref.read(cashRepositoryProvider).listSessions(),
      };

  Widget _row(BuildContext context, WidgetRef ref, Map<String, Object?> row, String currency) {
    if (mode == CashScreenMode.cashboxes) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text('${row['name']}'),
          subtitle: const Text('الرصيد الحالي من دفتر حركات الصندوق'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Money((row['current_balance_minor'] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'opening') await _openingBalance(context, ref, row['id'] as String);
                  if (value == 'adjust') await _adjustment(context, ref, row['id'] as String);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'opening', child: Text('رصيد افتتاحي')),
                  PopupMenuItem(value: 'adjust', child: Text('تسوية الصندوق')),
                ],
              ),
            ],
          ),
          onTap: () => _history(context, ref, row['id'] as String, currency),
        ),
      );
    }
    if (mode == CashScreenMode.expenses) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text('${row['expense_number']}'),
          subtitle: Text('${row['cashbox_name']} • ${row['occurred_at']}'),
          trailing: Text(Money((row['amount_minor'] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
        ),
      );
    }
    if (mode == CashScreenMode.transfers) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: Text('${row['transfer_number']}'),
          subtitle: Text('${row['from_cashbox_name']} ← ${row['to_cashbox_name']} • ${row['occurred_at']}'),
          trailing: Text(Money((row['amount_minor'] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
        ),
      );
    }
    final open = row['status'] == 'open';
    return Card(
      child: ListTile(
        leading: Icon(open ? Icons.lock_open : Icons.lock_outline),
        title: Text('${row['cashbox_name']}'),
        subtitle: Text('${row['status']} • ${row['opened_at']}'),
        trailing: open ? const Chip(label: Text('مفتوحة')) : Text('فرق: ${row['difference_minor'] ?? 0}'),
        onTap: open ? () => _closeSession(context, ref, row['id'] as String, currency) : null,
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref) async {
    final boxes = await ref.read(cashRepositoryProvider).listCashboxes();
    if (!context.mounted) return;
    try {
      if (mode == CashScreenMode.cashboxes) {
        final controller = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('صندوق جديد'),
            content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'الاسم')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
            ],
          ),
        );
        if (ok == true && controller.text.trim().isNotEmpty) await ref.read(masterDataRepositoryProvider).saveCashbox(name: controller.text);
        controller.dispose();
      } else if (boxes.isEmpty) {
        throw StateError('أضف صندوقاً أولاً');
      } else if (mode == CashScreenMode.expenses) {
        var box = boxes.first['id'] as String;
        final amount = TextEditingController();
        final note = TextEditingController();
        final ok = await _moneyDialog(context, 'مصروف جديد', boxes, (value) => box = value, amount, note);
        if (ok) await ref.read(cashRepositoryProvider).postExpense(cashboxId: box, amountMinor: Money.fromMajor(amount.text), note: note.text);
        amount.dispose();
        note.dispose();
      } else if (mode == CashScreenMode.transfers) {
        if (boxes.length < 2) throw StateError('تحتاج صندوقين على الأقل');
        await _transfer(context, ref, boxes);
      } else {
        var box = boxes.first['id'] as String;
        final amount = TextEditingController(text: '0');
        final ok = await _moneyDialog(context, 'فتح جلسة صندوق', boxes, (value) => box = value, amount, null);
        if (ok) await ref.read(cashRepositoryProvider).openSession(cashboxId: box, openingAmountMinor: Money.fromMajor(amount.text));
        amount.dispose();
      }
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openingBalance(BuildContext context, WidgetRef ref, String cashboxId) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الرصيد الافتتاحي'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ؛ استخدم قيمة سالبة إن لزم')),
              const SizedBox(height: 8),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(cashRepositoryProvider).postOpeningBalance(cashboxId: cashboxId, amountMinor: Money.fromMajor(amount.text), note: note.text);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> _adjustment(BuildContext context, WidgetRef ref, String cashboxId) async {
    var direction = 'in';
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('تسوية الصندوق'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: direction,
                  items: const [DropdownMenuItem(value: 'in', child: Text('زيادة')), DropdownMenuItem(value: 'out', child: Text('نقص'))],
                  onChanged: (value) {
                    if (value != null) setLocal(() => direction = value);
                  },
                  decoration: const InputDecoration(labelText: 'الاتجاه'),
                ),
                const SizedBox(height: 8),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
                const SizedBox(height: 8),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'سبب التسوية')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد')),
          ],
        ),
      ),
    );
    if (ok == true && note.text.trim().isNotEmpty) {
      try {
        await ref.read(cashRepositoryProvider).postAdjustment(cashboxId: cashboxId, direction: direction, amountMinor: Money.fromMajor(amount.text), note: note.text);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> _history(BuildContext context, WidgetRef ref, String cashboxId, String currency) async {
    final rows = await ref.read(cashRepositoryProvider).transactionHistory(cashboxId: cashboxId);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
          child: Column(
            children: [
              AppBar(title: const Text('حركات الصندوق'), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))]),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final amount = (row['amount_minor'] as num).toInt();
                    return ListTile(
                      leading: Icon(row['direction'] == 'in' ? Icons.south_west : Icons.north_east),
                      title: Text('${row['kind']}'),
                      subtitle: Text('${row['occurred_at']} • ${row['party_name'] ?? ''}'),
                      trailing: Text('${row['direction'] == 'in' ? '+' : '-'}${Money(amount).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}'),
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

  Future<void> _transfer(BuildContext context, WidgetRef ref, List<Map<String, Object?>> boxes) async {
    var from = boxes.first['id'] as String;
    var to = boxes[1]['id'] as String;
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('تحويل بين الصناديق'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: from,
                  items: boxes.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['name']}'))).toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => from = value);
                  },
                  decoration: const InputDecoration(labelText: 'من صندوق'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: to,
                  items: boxes.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['name']}'))).toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => to = value);
                  },
                  decoration: const InputDecoration(labelText: 'إلى صندوق'),
                ),
                const SizedBox(height: 8),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تحويل')),
          ],
        ),
      ),
    );
    if (ok == true) await ref.read(cashRepositoryProvider).postTransfer(fromCashboxId: from, toCashboxId: to, amountMinor: Money.fromMajor(amount.text));
    amount.dispose();
  }

  Future<void> _closeSession(BuildContext context, WidgetRef ref, String sessionId, String currency) async {
    final counted = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إغلاق جلسة الصندوق'),
        content: TextField(controller: counted, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المعدود فعلياً')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إغلاق')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final result = await ref.read(cashRepositoryProvider).closeSession(sessionId: sessionId, countedAmountMinor: Money.fromMajor(counted.text));
        ref.read(dataRevisionProvider.notifier).state++;
        if (context.mounted) {
          final expected = Money(result['expected']!).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency);
          final difference = Money(result['difference']!).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('المتوقع: $expected • الفرق: $difference')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    counted.dispose();
  }

  Future<bool> _moneyDialog(
    BuildContext context,
    String title,
    List<Map<String, Object?>> boxes,
    ValueChanged<String> onBox,
    TextEditingController amount,
    TextEditingController? note,
  ) async {
    var box = boxes.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: box,
                  items: boxes.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text('${e['name']}'))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setLocal(() => box = value);
                      onBox(value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'الصندوق'),
                ),
                const SizedBox(height: 8),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
                if (note != null) ...[
                  const SizedBox(height: 8),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                onBox(box);
                Navigator.pop(dialogContext, true);
              },
              child: const Text('اعتماد'),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }
}
