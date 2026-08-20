import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
import 'package:accounting_system/features/inventory/models/inventory_models.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

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
          return MyScaffold(
            appBar:
                showCompactPageAppBar(context)
                    ? BlurAppBar(title: Text('مستند ${widget.kind.label} جديد'))
                    : null,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return MyScaffold(
            appBar:
                showCompactPageAppBar(context)
                    ? BlurAppBar(title: Text('مستند ${widget.kind.label} جديد'))
                    : null,
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        final data = snapshot.data!;
        _warehouseId ??=
            data.warehouses.isEmpty ? null : data.warehouses.first.id;
        _cashboxId ??= data.cashboxes.isEmpty ? null : data.cashboxes.first.id;
        if (_warehouseId == null) {
          return MyScaffold(
            appBar:
                showCompactPageAppBar(context)
                    ? BlurAppBar(title: Text('مستند ${widget.kind.label} جديد'))
                    : null,
            body: const Center(child: Text('أضف مستودعاً أولاً.')),
          );
        }
        return _body(context, data);
      },
    );
  }

  Widget _body(BuildContext context, _EditorData data) {
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final subtotal = _lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotalMinor,
    );
    final discount = _safeMoney(_documentDiscount.text);
    final finalMinor = (subtotal - discount).clamp(0, subtotal).toInt();
    final colors = context.colors;
    final icon = switch (widget.kind) {
      DocumentKind.sale => Iconsax.receipt_add,
      DocumentKind.purchase => Iconsax.shopping_cart,
      DocumentKind.waste => Iconsax.warning_2,
      _ => Icons.description_outlined,
    };

    return MyScaffold(
      appBar:
          showCompactPageAppBar(context)
              ? BlurAppBar(title: Text('مستند ${widget.kind.label} جديد'))
              : null,
      body: PremiumBackdrop(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedEntrance(
                    child: PageIntro(
                      eyebrow: 'NEW DOCUMENT',
                      title: 'مستند ${widget.kind.label} جديد',
                      subtitle:
                          _isWaste
                              ? 'سجّل الهالك بدقة ليُخصم من المخزون مع حفظ أثر الحركة.'
                              : _isPurchase
                              ? 'أدخل المورد والبنود والدفع، ثم احفظ كمسودة أو اعتمد المستند.'
                              : 'واجهة سريعة للبيع؛ أضف البنود وحدد المقبوض ثم اعتمد الفاتورة.',
                      icon: icon,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 60),
                    child: PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'بيانات المستند',
                            subtitle:
                                'المستودع والطرف والصندوق المرتبط بالحركة',
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final full = constraints.maxWidth < 620;
                              final wideField =
                                  full ? constraints.maxWidth : 270.0;
                              final smallField =
                                  full ? constraints.maxWidth : 230.0;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: wideField,
                                    child: DropdownButtonFormField<String>(
                                      value: _warehouseId,
                                      items:
                                          data.warehouses
                                              .where((row) => row.id != null)
                                              .map(
                                                (row) => DropdownMenuItem(
                                                  value: row.id!,
                                                  child: Text(
                                                    row.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged:
                                          _lines.isNotEmpty
                                              ? null
                                              : (value) => setState(
                                                () => _warehouseId = value,
                                              ),
                                      decoration: const InputDecoration(
                                        labelText: 'المستودع',
                                        prefixIcon: Icon(Iconsax.buildings_2),
                                      ),
                                    ),
                                  ),
                                  if (!_isWaste)
                                    SizedBox(
                                      width: wideField,
                                      child: DropdownButtonFormField<String?>(
                                        value: _partyId,
                                        items: [
                                          if (!_isPurchase)
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text(
                                                'بدون عميل (بيع نقدي)',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ...data.parties
                                              .where((row) => row.id != null)
                                              .map(
                                                (row) =>
                                                    DropdownMenuItem<String?>(
                                                      value: row.id!,
                                                      child: Text(
                                                        row.name,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                              ),
                                        ],
                                        onChanged:
                                            (value) => setState(
                                              () => _partyId = value,
                                            ),
                                        decoration: InputDecoration(
                                          labelText:
                                              _isPurchase ? 'المورد' : 'العميل',
                                          prefixIcon: Icon(
                                            _isPurchase
                                                ? Iconsax.truck_fast
                                                : Icons.person_outline_rounded,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!_isWaste)
                                    SizedBox(
                                      width: smallField,
                                      child: DropdownButtonFormField<String>(
                                        value: _cashboxId,
                                        items:
                                            data.cashboxes
                                                .where((row) => row.id != null)
                                                .map(
                                                  (row) => DropdownMenuItem(
                                                    value: row.id!,
                                                    child: Text(
                                                      row.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged:
                                            (value) => setState(
                                              () => _cashboxId = value,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'الصندوق',
                                          prefixIcon: Icon(Iconsax.wallet_3),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 110),
                    child: PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(
                            title: 'البنود',
                            subtitle:
                                _lines.isEmpty
                                    ? 'أضف أول بند للمستند'
                                    : '${_lines.length} بند مضاف',
                            trailing: FilledButton.icon(
                              onPressed: () => _addLine(context),
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('إضافة بند'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSize(
                            duration: AppMotion.normal,
                            curve: AppMotion.curve,
                            alignment: Alignment.topCenter,
                            child:
                                _lines.isEmpty
                                    ? const EmptyState(
                                      title: 'لا توجد بنود بعد',
                                      subtitle:
                                          'اضغط “إضافة بند” لاختيار المنتج والكمية والسعر.',
                                      icon: Icons.inventory_2_outlined,
                                    )
                                    : Column(
                                      children: [
                                        for (
                                          var index = 0;
                                          index < _lines.length;
                                          index++
                                        ) ...[
                                          _InvoiceLineRow(
                                            index: index,
                                            line: _lines[index],
                                            currency: currency,
                                            onDelete:
                                                () => setState(
                                                  () => _lines.removeAt(index),
                                                ),
                                          ),
                                          if (index != _lines.length - 1)
                                            Divider(
                                              height: 1,
                                              color: colors.border,
                                            ),
                                        ],
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_isWaste)
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 160),
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(
                              title: 'التسوية المالية',
                              subtitle: 'الخصم والدفع والقيمة النهائية للمستند',
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final full = constraints.maxWidth < 500;
                                final fieldWidth =
                                    full ? constraints.maxWidth : 220.0;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth,
                                      child: TextField(
                                        controller: _documentDiscount,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                        decoration: const InputDecoration(
                                          labelText: 'خصم الفاتورة',
                                          prefixIcon: Icon(
                                            Icons.discount_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth,
                                      child: TextField(
                                        controller: _paid,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText:
                                              _isPurchase
                                                  ? 'المدفوع للمورد'
                                                  : 'المقبوض',
                                          prefixIcon: const Icon(
                                            Icons.payments_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: full ? constraints.maxWidth : 210,
                                      child: _totalChip(
                                        context,
                                        'المجموع',
                                        subtotal,
                                        currency,
                                      ),
                                    ),
                                    SizedBox(
                                      width: full ? constraints.maxWidth : 210,
                                      child: _totalChip(
                                        context,
                                        'الصافي',
                                        finalMinor,
                                        currency,
                                        emphasized: true,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_isWaste) const SizedBox(height: 14),
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 200),
                    child: PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(
                            title: 'ملاحظات',
                            subtitle: 'اختياري — تحفظ مع المستند',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _note,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'أضف أي ملاحظة مهمة هنا…',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 240),
                    child: PremiumPanel(
                      accent: colors.primary,
                      child:
                          _isWaste
                              ? FilledButton.icon(
                                onPressed:
                                    _saving ? null : () => _save(post: true),
                                icon:
                                    _saving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Iconsax.tick_circle),
                                label: const Text('اعتماد الهالك'),
                              )
                              : LayoutBuilder(
                                builder: (context, constraints) {
                                  final draft = OutlinedButton.icon(
                                    onPressed:
                                        _saving
                                            ? null
                                            : () => _save(post: false),
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('حفظ مسودة'),
                                  );
                                  final post = FilledButton.icon(
                                    onPressed:
                                        _saving
                                            ? null
                                            : () => _save(post: true),
                                    icon:
                                        _saving
                                            ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Icon(Iconsax.tick_circle),
                                    label: const Text('حفظ واعتماد'),
                                  );
                                  if (constraints.maxWidth < 440) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        draft,
                                        const SizedBox(height: 10),
                                        post,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: draft),
                                      const SizedBox(width: 12),
                                      Expanded(child: post),
                                    ],
                                  );
                                },
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalChip(
    BuildContext context,
    String label,
    int value,
    String currency, {
    bool emphasized = false,
  }) {
    final colors = context.colors;
    final accent = emphasized ? colors.primary : colors.secondary;
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? .12 : .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Money(value).format(
              locale: Localizations.localeOf(context).toString(),
              currencyCode: currency,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasized ? colors.primary : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<_EditorData> _loadEditorData() async {
    final master = ref.read(masterDataRepositoryProvider);
    final parties = await master.listParties(
      type: _isPurchase ? 'supplier' : 'customer',
    );
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
    final products = await inventoryRepo.listSellableProducts(
      warehouseId: warehouseId,
    );
    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أضف منتجاً أولاً')));
      return;
    }

    var product = products.first;
    var units = await masterRepo.listProductUnits(product.productId);
    if (!context.mounted || units.isEmpty) return;
    var unit = units.first;
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final lineDiscount = TextEditingController(text: '0');

    final result = await showDialog<_DraftLine>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('إضافة بند'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: product.productId,
                          items:
                              products
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.productId,
                                      child: Text(row.productName),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            final nextProduct = products.firstWhere(
                              (row) => row.productId == value,
                            );
                            final nextUnits = await masterRepo.listProductUnits(
                              value,
                            );
                            if (!dialogContext.mounted || nextUnits.isEmpty)
                              return;
                            setLocal(() {
                              product = nextProduct;
                              units = nextUnits;
                              unit = nextUnits.first;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'المنتج',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: unit.id!,
                          items:
                              units
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.id!,
                                      child: Text(
                                        '${row.name} × ${row.factor}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocal(
                              () =>
                                  unit = units.firstWhere(
                                    (row) => row.id == value,
                                  ),
                            );
                          },
                          decoration: const InputDecoration(
                            labelText: 'الوحدة',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: qty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                          ),
                        ),
                        if (!_isWaste) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  _isPurchase ? 'تكلفة الوحدة' : 'سعر الوحدة',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: lineDiscount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'خصم السطر',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final quantity = double.parse(qty.text.trim());
                          if (quantity <= 0)
                            throw const FormatException(
                              'الكمية يجب أن تكون أكبر من صفر',
                            );
                          final factor = unit.factor;
                          final unitPriceMinor =
                              _isWaste ? 0 : Money.fromMajor(price.text);
                          final discountMinor =
                              _isWaste ? 0 : Money.fromMajor(lineDiscount.text);
                          final gross = Money.multiplyByQuantity(
                            unitPriceMinor,
                            quantity,
                          );
                          if (discountMinor < 0 || discountMinor > gross) {
                            throw const FormatException('خصم السطر غير صالح');
                          }
                          var inventoryItemId = product.inventoryItemId;
                          inventoryItemId ??= await inventoryRepo
                              .ensureInventoryItemForProduct(
                                productId: product.productId,
                                warehouseId: warehouseId,
                              );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(
                            dialogContext,
                            _DraftLine(
                              inventoryItemId: inventoryItemId,
                              productId: product.productId,
                              productUnitId: unit.id!,
                              productName: product.productName,
                              unitName: unit.name,
                              quantity: quantity,
                              unitFactor: factor,
                              unitPriceMinor: unitPriceMinor,
                              lineDiscountMinor: discountMinor,
                            ),
                          );
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(
                              dialogContext,
                            ).showSnackBar(SnackBar(content: Text('$error')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }
    if (_isPurchase && _partyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر مورداً')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
      if (_isWaste) {
        await repo.postWaste(
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items:
              _lines
                  .map(
                    (line) => WasteLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                    ),
                  )
                  .toList(),
        );
      } else if (_isPurchase) {
        final id = await repo.createPurchaseDraft(
          supplierId: _partyId!,
          cashboxId: _cashboxId,
          discountMinor: Money.fromMajor(_documentDiscount.text),
          paidMinor: Money.fromMajor(_paid.text),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items:
              _lines
                  .map(
                    (line) => PurchaseLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                      unitCostMinor: line.unitPriceMinor,
                      lineDiscountMinor: line.lineDiscountMinor,
                    ),
                  )
                  .toList(),
        );
        if (post) await repo.postPurchase(id);
      } else {
        final subtotal = _lines.fold<int>(
          0,
          (sum, line) => sum + line.lineTotalMinor,
        );
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
          items:
              _lines
                  .map(
                    (line) => SaleLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                      unitPriceMinor: line.unitPriceMinor,
                      lineDiscountMinor: line.lineDiscountMinor,
                    ),
                  )
                  .toList(),
        );
        if (post) await repo.postSale(id);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              post ? 'تم الاعتماد محلياً بنجاح' : 'تم حفظ المسودة محلياً',
            ),
          ),
        );
        Navigator.maybePop(context);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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

  int get lineTotalMinor =>
      Money.multiplyByQuantity(unitPriceMinor, quantity) - lineDiscountMinor;
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({
    required this.index,
    required this.line,
    required this.currency,
    required this.onDelete,
  });

  final int index;
  final _DraftLine line;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = Money(line.lineTotalMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final details =
        '${line.quantity} ${line.unitName} × ${Money(line.unitPriceMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}'
        '${line.lineDiscountMinor > 0 ? ' • خصم ${Money(line.lineDiscountMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}' : ''}';

    final number = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textDim, fontSize: 10.5),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    number,
                    const SizedBox(width: 11),
                    Expanded(child: identity),
                    IconButton(
                      tooltip: 'حذف البند',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.error,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 45),
                  child: Text(
                    total,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              number,
              const SizedBox(width: 11),
              Expanded(child: identity),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  total,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'حذف البند',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 18,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorData {
  const _EditorData({
    required this.warehouses,
    required this.parties,
    required this.cashboxes,
  });

  final List<Warehouse> warehouses;
  final List<Party> parties;
  final List<Cashbox> cashboxes;
}
