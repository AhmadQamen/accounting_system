import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key, required this.kind});

  final DocumentKind kind;

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final canDirectCreate = widget.kind == DocumentKind.sale ||
        widget.kind == DocumentKind.purchase ||
        widget.kind == DocumentKind.waste;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.label)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (canDirectCreate) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewDocumentScreen(kind: widget.kind)),
            );
          } else {
            await _newReturn(context);
          }
          ref.read(dataRevisionProvider.notifier).state++;
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'بحث برقم المستند أو الطرف',
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: ref.read(documentRepositoryProvider).listDocuments(widget.kind.dbType),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
                final query = _search.text.trim().toLowerCase();
                final rows = (snapshot.data ?? const <Map<String, Object?>>[])
                    .where((row) => query.isEmpty ||
                        '${row['display_number']}'.toLowerCase().contains(query) ||
                        '${row['party_name'] ?? ''}'.toLowerCase().contains(query) ||
                        '${row['id']}'.toLowerCase().contains(query))
                    .toList();
                if (rows.isEmpty) return const Center(child: Text('لا توجد مستندات'));
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final amount = (row['final_minor'] ?? row['total_cost_minor'] ?? 0) as num;
                    return Card(
                      child: ListTile(
                        leading: _statusIcon('${row['status']}'),
                        title: Text('${row['display_number']}'),
                        subtitle: Text(
                          '${row['party_name'] ?? ''}${row['party_name'] == null ? '' : ' • '}${_statusLabel('${row['status']}')} • ${_shortDate('${row['occurred_at']}')}',
                        ),
                        trailing: Text(
                          Money(amount.toInt()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => _showDetails(context, row['id'] as String, currency),
                        onLongPress: row['status'] == 'posted'
                            ? () => _confirmVoid(context, row['id'] as String)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(String status) {
    final icon = switch (status) {
      'posted' => Icons.check_circle_outline,
      'void' => Icons.block,
      _ => Icons.edit_note,
    };
    return CircleAvatar(child: Icon(icon));
  }

  String _statusLabel(String status) => switch (status) {
        'posted' => 'معتمد',
        'void' => 'ملغى',
        _ => 'مسودة',
      };

  String _shortDate(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetails(BuildContext context, String documentId, String currency) async {
    final details = await ref.read(documentRepositoryProvider).documentDetails(widget.kind.dbType, documentId);
    if (!context.mounted) return;
    final header = details['header'] as Map<String, Object?>;
    final items = details['items'] as List<Map<String, Object?>>;
    final shouldPost = header['status'] == 'draft' &&
        (widget.kind == DocumentKind.sale || widget.kind == DocumentKind.purchase);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${header['invoice_number'] ?? header['return_number'] ?? header['waste_number'] ?? documentId}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(_statusLabel('${header['status']}'))),
                    if (header['final_minor'] != null)
                      Chip(
                        label: Text(
                          Money((header['final_minor'] as num).toInt()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                        ),
                      ),
                    if (header['total_cost_minor'] != null)
                      Chip(
                        label: Text(
                          Money((header['total_cost_minor'] as num).toInt()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final lineAmount = (item['line_total_minor'] ?? item['cost_amount_minor'] ?? 0) as num;
                  return ListTile(
                    dense: true,
                    title: Text('${item['product_name'] ?? 'منتج'}'),
                    subtitle: Text('${item['quantity']} ${item['unit_name'] ?? ''}'),
                    trailing: Text(
                      Money(lineAmount.toInt()).format(
                        locale: Localizations.localeOf(context).toString(),
                        currencyCode: currency,
                      ),
                    ),
                  );
                }),
                if (header['note'] != null && '${header['note']}'.trim().isNotEmpty) ...[
                  const Divider(),
                  Text('ملاحظات: ${header['note']}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          if (shouldPost)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'post'),
              child: const Text('اعتماد المسودة'),
            ),
        ],
      ),
    );
    if (action != 'post' || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الاعتماد'),
        content: const Text('سيتم إنشاء حركات المخزون والصندوق والذمم محلياً. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (widget.kind == DocumentKind.sale) {
        await ref.read(documentRepositoryProvider).postSale(documentId);
      } else if (widget.kind == DocumentKind.purchase) {
        await ref.read(documentRepositoryProvider).postPurchase(documentId);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد محلياً')));
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmVoid(BuildContext context, String documentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء المستند المعتمد'),
        content: const Text(
          'لن يتم حذف المستند. سيتم إنشاء حركات عكسية للمخزون والصندوق والذمم للحفاظ على سجل التدقيق. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إلغاء وعكس الحركات')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(documentRepositoryProvider).voidDocument(widget.kind.dbType, documentId);
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء المستند وإنشاء الحركات العكسية محلياً')),
        );
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _newReturn(BuildContext context) async {
    final originalKind = widget.kind == DocumentKind.saleReturn ? DocumentKind.sale : DocumentKind.purchase;
    final originals = (await ref.read(documentRepositoryProvider).listDocuments(originalKind.dbType))
        .where((row) => row['status'] == 'posted')
        .toList();
    if (!context.mounted) return;
    if (originals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد فواتير معتمدة للإرجاع')));
      return;
    }

    var docId = originals.first['id'] as String;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('اختيار فاتورة ${originalKind.label}'),
          content: SizedBox(
            width: 520,
            child: DropdownButtonFormField<String>(
              value: docId,
              items: originals
                  .map((row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['display_number']} • ${row['party_name'] ?? ''}'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setLocal(() => docId = value);
              },
              decoration: const InputDecoration(labelText: 'الفاتورة الأصلية'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, docId), child: const Text('التالي')),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final details = await ref.read(documentRepositoryProvider).documentDetails(originalKind.dbType, selected);
    if (!context.mounted) return;
    final items = details['items'] as List<Map<String, Object?>>;
    if (items.isEmpty) return;
    final controllers = {for (final item in items) item['id'] as String: TextEditingController(text: '0')};
    final cashAmount = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إنشاء ${widget.kind.label}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['product_name'] ?? 'منتج'} • مباع/مشتَرى ${item['quantity']} ${item['unit_name'] ?? ''}',
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: controllers[item['id'] as String],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'كمية الإرجاع'),
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                TextField(
                  controller: cashAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.kind == DocumentKind.saleReturn ? 'المبلغ المعاد نقداً' : 'المبلغ المستلم من المورد',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد المرتجع')),
        ],
      ),
    );

    if (confirmed == true) {
      final returnLines = <ReturnLineInput>[];
      for (final item in items) {
        final quantity = double.tryParse(controllers[item['id'] as String]!.text.trim()) ?? 0;
        if (quantity <= 0) continue;
        final factor = (item[originalKind == DocumentKind.sale ? 'unit_factor_at_sale' : 'unit_factor_at_purchase'] as num)
            .toDouble();
        returnLines.add(ReturnLineInput(
          originalItemId: item['id'] as String,
          quantity: quantity,
          unitFactor: factor,
        ));
      }
      if (returnLines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية إرجاع لبند واحد على الأقل')));
        }
      } else {
        try {
          final money = Money.fromMajor(cashAmount.text);
          if (widget.kind == DocumentKind.saleReturn) {
            await ref.read(documentRepositoryProvider).postSaleReturn(
                  saleId: selected,
                  items: returnLines,
                  refundedMinor: money,
                );
          } else {
            await ref.read(documentRepositoryProvider).postPurchaseReturn(
                  purchaseId: selected,
                  items: returnLines,
                  receivedMinor: money,
                );
          }
          ref.read(dataRevisionProvider.notifier).state++;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد المرتجع محلياً')));
          }
        } catch (error) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
    cashAmount.dispose();
  }
}
