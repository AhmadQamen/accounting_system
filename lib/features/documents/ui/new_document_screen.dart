import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DocumentKind { sale, purchase, saleReturn, purchaseReturn, waste }

extension DocumentKindX on DocumentKind {
  String get dbType => switch (this) {
        DocumentKind.sale => 'sale',
        DocumentKind.purchase => 'purchase',
        DocumentKind.saleReturn => 'sale_return',
        DocumentKind.purchaseReturn => 'purchase_return',
        DocumentKind.waste => 'waste',
      };

  String get label => switch (this) {
        DocumentKind.sale => 'بيع',
        DocumentKind.purchase => 'شراء',
        DocumentKind.saleReturn => 'مرتجع بيع',
        DocumentKind.purchaseReturn => 'مرتجع شراء',
        DocumentKind.waste => 'هالك',
      };
}

class NewDocumentScreen extends ConsumerStatefulWidget {
  const NewDocumentScreen({super.key, required this.kind});

  final DocumentKind kind;

  @override
  ConsumerState<NewDocumentScreen> createState() => _NewDocumentScreenState();
}

class _NewDocumentScreenState extends ConsumerState<NewDocumentScreen> {
  final _documentDiscount = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _note = TextEditingController();
  final List<_DraftLine> _lines = [];

  String? _warehouseId;
  String? _partyId;
  String? _cashboxId;
  bool _saving = false;

  bool get _isPurchase => widget.kind == DocumentKind.purchase;
  bool get _isWaste => widget.kind == DocumentKind.waste;

  @override
  void dispose() {
    _documentDiscount.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    return FutureBuilder<_EditorData>(
      future: _loadEditorData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text('مستند ${widget.kind.label} جديد')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('مستند ${widget.kind.label} جديد')),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        final data = snapshot.data!;
        _warehouseId ??= data.warehouses.isEmpty ? null : data.warehouses.first['id'] as String;
        _cashboxId ??= data.cashboxes.isEmpty ? null : data.cashboxes.first['id'] as String;
        if (_warehouseId == null) {
          return Scaffold(
            appBar: AppBar(title: Text('مستند ${widget.kind.label} جديد')),
            body: const Center(child: Text('أضف مستودعاً أولاً.')),
          );
        }
        return _body(context, data);
      },
    );
  }

  Widget _body(BuildContext context, _EditorData data) {
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final subtotal = _lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinor);
    final discount = _safeMoney(_documentDiscount.text);
    final finalMinor = (subtotal - discount).clamp(0, subtotal).toInt();

    return Scaffold(
      appBar: AppBar(title: Text('مستند ${widget.kind.label} جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            value: _warehouseId,
                            items: data.warehouses
                                .map((row) => DropdownMenuItem(
                                      value: row['id'] as String,
                                      child: Text('${row['name']}'),
                                    ))
                                .toList(),
                            onChanged: _lines.isNotEmpty
                                ? null
                                : (value) => setState(() => _warehouseId = value),
                            decoration: const InputDecoration(labelText: 'المستودع'),
                          ),
                        ),
                        if (!_isWaste)
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String?>(
                              value: _partyId,
                              items: [
                                if (!_isPurchase)
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('بدون عميل (بيع نقدي)'),
                                  ),
                                ...data.parties.map((row) => DropdownMenuItem<String?>(
                                      value: row['id'] as String,
                                      child: Text('${row['name']}'),
                                    )),
                              ],
                              onChanged: (value) => setState(() => _partyId = value),
                              decoration: InputDecoration(labelText: _isPurchase ? 'المورد' : 'العميل'),
                            ),
                          ),
                        if (!_isWaste)
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              value: _cashboxId,
                              items: data.cashboxes
                                  .map((row) => DropdownMenuItem(
                                        value: row['id'] as String,
                                        child: Text('${row['name']}'),
                                      ))
                                  .toList(),
                              onChanged: (value) => setState(() => _cashboxId = value),
                              decoration: const InputDecoration(labelText: 'الصندوق'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('البنود', style: Theme.of(context).textTheme.titleLarge),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: () => _addLine(context),
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة بند'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_lines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: Text('لا توجد بنود بعد')),
                          )
                        else
                          ..._lines.indexed.map((entry) {
                            final index = entry.$1;
                            final line = entry.$2;
                            return ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(line.productName),
                              subtitle: Text(
                                '${line.quantity} ${line.unitName} × ${Money(line.unitPriceMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}'
                                '${line.lineDiscountMinor > 0 ? ' • خصم سطر ${Money(line.lineDiscountMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    Money(line.lineTotalMinor).format(
                                      locale: Localizations.localeOf(context).toString(),
                                      currencyCode: currency,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف البند',
                                    onPressed: () => setState(() => _lines.removeAt(index)),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isWaste)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _documentDiscount,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'خصم الفاتورة'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _paid,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: _isPurchase ? 'المدفوع للمورد' : 'المقبوض'),
                            ),
                          ),
                          _totalChip(context, 'المجموع', subtotal, currency),
                          _totalChip(context, 'الصافي', finalMinor, currency),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                const SizedBox(height: 18),
                if (_isWaste)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(post: true),
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('اعتماد الهالك'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _save(post: false),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('حفظ مسودة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(post: true),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: const Text('حفظ واعتماد'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalChip(BuildContext context, String label, int value, String currency) {
    return Chip(
      label: Text(
        '$label: ${Money(value).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<_EditorData> _loadEditorData() async {
    final master = ref.read(masterDataRepositoryProvider);
    final parties = await master.listParties(type: _isPurchase ? 'supplier' : 'customer');
    return _EditorData(
      warehouses: await master.listWarehouses(),
      parties: parties,
      cashboxes: await master.listCashboxes(),
    );
  }

  Future<void> _addLine(BuildContext context) async {
    final warehouseId = _warehouseId;
    if (warehouseId == null) return;
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final masterRepo = ref.read(masterDataRepositoryProvider);
    final products = await inventoryRepo.listSellableProducts(warehouseId: warehouseId);
    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف منتجاً أولاً')));
      return;
    }

    var product = products.first;
    var units = await masterRepo.listProductUnits(product['product_id'] as String);
    if (!context.mounted || units.isEmpty) return;
    var unit = units.first;
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final lineDiscount = TextEditingController(text: '0');

    final result = await showDialog<_DraftLine>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('إضافة بند'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: product['product_id'] as String,
                  items: products
                      .map((row) => DropdownMenuItem(
                            value: row['product_id'] as String,
                            child: Text('${row['product_name']}'),
                          ))
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    final nextProduct = products.firstWhere((row) => row['product_id'] == value);
                    final nextUnits = await masterRepo.listProductUnits(value);
                    if (!dialogContext.mounted || nextUnits.isEmpty) return;
                    setLocal(() {
                      product = nextProduct;
                      units = nextUnits;
                      unit = nextUnits.first;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'المنتج'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: unit['id'] as String,
                  items: units
                      .map((row) => DropdownMenuItem(
                            value: row['id'] as String,
                            child: Text('${row['name']} × ${row['factor']}'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() => unit = units.firstWhere((row) => row['id'] == value));
                  },
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                if (!_isWaste) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _isPurchase ? 'تكلفة الوحدة' : 'سعر الوحدة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lineDiscount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'خصم السطر'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  final quantity = double.parse(qty.text.trim());
                  if (quantity <= 0) throw const FormatException('الكمية يجب أن تكون أكبر من صفر');
                  final factor = (unit['factor'] as num).toDouble();
                  final unitPriceMinor = _isWaste ? 0 : Money.fromMajor(price.text);
                  final discountMinor = _isWaste ? 0 : Money.fromMajor(lineDiscount.text);
                  final gross = Money.multiplyByQuantity(unitPriceMinor, quantity);
                  if (discountMinor < 0 || discountMinor > gross) {
                    throw const FormatException('خصم السطر غير صالح');
                  }
                  var inventoryItemId = product['inventory_item_id'] as String?;
                  inventoryItemId ??= await inventoryRepo.ensureInventoryItemForProduct(
                    productId: product['product_id'] as String,
                    warehouseId: warehouseId,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(
                    dialogContext,
                    _DraftLine(
                      inventoryItemId: inventoryItemId,
                      productId: product['product_id'] as String,
                      productUnitId: unit['id'] as String,
                      productName: product['product_name'] as String,
                      unitName: unit['name'] as String,
                      quantity: quantity,
                      unitFactor: factor,
                      unitPriceMinor: unitPriceMinor,
                      lineDiscountMinor: discountMinor,
                    ),
                  );
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    qty.dispose();
    price.dispose();
    lineDiscount.dispose();
    if (result != null && mounted) setState(() => _lines.add(result));
  }

  Future<void> _save({required bool post}) async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف بنداً واحداً على الأقل')));
      return;
    }
    if (_isPurchase && _partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر مورداً')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      if (_isWaste) {
        await repo.postWaste(
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items: _lines
              .map((line) => WasteLineInput(
                    inventoryItemId: line.inventoryItemId,
                    productUnitId: line.productUnitId,
                    quantity: line.quantity,
                    unitFactor: line.unitFactor,
                  ))
              .toList(),
        );
      } else if (_isPurchase) {
        final id = await repo.createPurchaseDraft(
          supplierId: _partyId!,
          cashboxId: _cashboxId,
          discountMinor: Money.fromMajor(_documentDiscount.text),
          paidMinor: Money.fromMajor(_paid.text),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items: _lines
              .map((line) => PurchaseLineInput(
                    inventoryItemId: line.inventoryItemId,
                    productUnitId: line.productUnitId,
                    quantity: line.quantity,
                    unitFactor: line.unitFactor,
                    unitCostMinor: line.unitPriceMinor,
                    lineDiscountMinor: line.lineDiscountMinor,
                  ))
              .toList(),
        );
        if (post) await repo.postPurchase(id);
      } else {
        final subtotal = _lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinor);
        final discount = Money.fromMajor(_documentDiscount.text);
        final finalMinor = subtotal - discount;
        var paidMinor = Money.fromMajor(_paid.text);
        if (_partyId == null) paidMinor = finalMinor;
        final id = await repo.createSaleDraft(
          partyId: _partyId,
          cashboxId: _cashboxId,
          discountMinor: discount,
          paidMinor: paidMinor,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items: _lines
              .map((line) => SaleLineInput(
                    inventoryItemId: line.inventoryItemId,
                    productUnitId: line.productUnitId,
                    quantity: line.quantity,
                    unitFactor: line.unitFactor,
                    unitPriceMinor: line.unitPriceMinor,
                    lineDiscountMinor: line.lineDiscountMinor,
                  ))
              .toList(),
        );
        if (post) await repo.postSale(id);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(post ? 'تم الاعتماد محلياً بنجاح' : 'تم حفظ المسودة محلياً')),
        );
        Navigator.maybePop(context);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _safeMoney(String value) {
    try {
      return Money.fromMajor(value);
    } catch (_) {
      return 0;
    }
  }
}

class _DraftLine {
  const _DraftLine({
    required this.inventoryItemId,
    required this.productId,
    required this.productUnitId,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.unitFactor,
    required this.unitPriceMinor,
    required this.lineDiscountMinor,
  });

  final String inventoryItemId;
  final String productId;
  final String productUnitId;
  final String productName;
  final String unitName;
  final double quantity;
  final double unitFactor;
  final int unitPriceMinor;
  final int lineDiscountMinor;

  int get lineTotalMinor => Money.multiplyByQuantity(unitPriceMinor, quantity) - lineDiscountMinor;
}

class _EditorData {
  const _EditorData({
    required this.warehouses,
    required this.parties,
    required this.cashboxes,
  });

  final List<Map<String, Object?>> warehouses;
  final List<Map<String, Object?>> parties;
  final List<Map<String, Object?>> cashboxes;
}
