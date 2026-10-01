import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/master_data/models/product_unit_hierarchy.dart';
import 'package:accounting_system/features/master_data/ui/category_manager_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductDetailsDialog extends ConsumerStatefulWidget {
  const ProductDetailsDialog({super.key, required this.product});
  final Product product;

  @override
  ConsumerState<ProductDetailsDialog> createState() =>
      _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends ConsumerState<ProductDetailsDialog> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final productId = widget.product.id!;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل بيانات المنتج',
                    onPressed: _editProduct,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<ProductDetailsData>(
                  key: ValueKey(revision),
                  future: _load(productId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError)
                      return Center(child: Text('${snapshot.error}'));
                    final data = snapshot.data!;
                    final units = data.units;
                    final barcodes = data.barcodes;
                    return ListView(
                      children: [
                        _sectionHeader('الوحدات', () => _addUnit(productId)),
                        ...units.map((u) {
                          final parent = ProductUnitHierarchy.parentOf(
                            u,
                            units,
                          );
                          final relation =
                              parent == null
                                  ? 'وحدة الأساس للمخزون'
                                  : '1 ${u.name} = ${_numberInput(ProductUnitHierarchy.unitsPerParent(u, units))} ${parent.name} = ${_numberInput(u.factor)} ${ProductUnitHierarchy.baseUnit(units)?.name ?? 'وحة أساس'}';
                          return ListTile(
                            leading: Icon(
                              u.isPrimary ? Icons.star : Icons.straighten,
                            ),
                            title: Text(u.name),
                            subtitle: Text(
                              '$relation • سعر البيع: ${_moneyInput(u.salePriceMinor)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (u.isPrimary)
                                  const Chip(label: Text('وحدة الأساس')),
                                IconButton(
                                  tooltip: 'تعديل الوحدة والسعر',
                                  onPressed: () => _editUnit(u),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                        _sectionHeader(
                          'الباركود',
                          units.isEmpty ? null : () => _addBarcode(units),
                        ),
                        if (barcodes.isEmpty)
                          const ListTile(title: Text('لا توجد باركودات')),
                        ...barcodes.map(
                          (b) => ListTile(
                            leading: const Icon(Icons.qr_code),
                            title: Text(b.code),
                            subtitle: Text(b.unitName ?? ''),
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

  Widget _sectionHeader(String title, VoidCallback? onAdd) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        if (onAdd != null)
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
          ),
      ],
    ),
  );

  Future<ProductDetailsData> _load(String productId) async {
    final repo = ref.read(masterDataRepositoryProvider);
    final unitsFuture = repo.listProductUnits(productId);
    final barcodesFuture = repo.listBarcodes(productId);
    return ProductDetailsData(
      units: ProductUnitHierarchy.ordered(await unitsFuture),
      barcodes: await barcodesFuture,
      specifications: const [],
    );
  }

  Future<void> _editProduct() async {
    final categories =
        await ref.read(masterDataRepositoryProvider).listCategories();
    if (!mounted) return;
    final name = TextEditingController(text: widget.product.name);
    final min = TextEditingController(
      text: _numberInput(widget.product.minQuantity),
    );
    var categoryId =
        categories.any(
              (category) => category.id == widget.product.categoryId,
            )
            ? widget.product.categoryId
            : null;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('تعديل المنتج'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'اسم المنتج',
                          ),
                        ),
                        const SizedBox(height: 9),
                        DropdownButtonFormField<String?>(
                          initialValue: categoryId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('بدون تصنيف'),
                            ),
                            ...categories.map(
                              (category) => DropdownMenuItem<String?>(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) => setLocal(() => categoryId = value),
                          decoration: const InputDecoration(
                            labelText: 'التصنيف',
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: min,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الحد الأدنى للمخزون',
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed:
                                () => showDialog<void>(
                                  context: dialogContext,
                                  builder: (_) => const CategoryManagerDialog(),
                                ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('إدارة التصنيفات'),
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
                      child: const Text('حفظ التعديل'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(masterDataRepositoryProvider)
            .updateProduct(
              id: widget.product.id!,
              name: name.text,
              categoryId: categoryId,
              minQuantity: double.tryParse(min.text.trim()) ?? -1,
            );
        ref.read(dataRevisionProvider.notifier).state++;
        setState(() => revision++);
      } catch (error) {
        if (mounted) CustomSnackBar.showErrorSnackbar('$error');
      }
    }
    name.dispose();
    min.dispose();
  }

  Future<void> _addUnit(String productId) async {
    final units = await ref
        .read(masterDataRepositoryProvider)
        .listProductUnits(productId);
    if (!mounted) return;
    await _showUnitEditor(productId: productId, units: units);
  }

  Future<void> _editUnit(ProductUnit unit) async {
    final units = await ref
        .read(masterDataRepositoryProvider)
        .listProductUnits(unit.productId);
    if (!mounted) return;
    await _showUnitEditor(
      productId: unit.productId,
      units: units,
      existing: unit,
    );
  }

  Future<void> _showUnitEditor({
    required String productId,
    required List<ProductUnit> units,
    ProductUnit? existing,
  }) async {
    final orderedUnits = ProductUnitHierarchy.ordered(units);
    final isBase = existing?.isPrimary ?? false;
    final inferredParent =
        existing == null
            ? ProductUnitHierarchy.baseUnit(orderedUnits)
            : ProductUnitHierarchy.parentOf(existing, orderedUnits);
    final rawParentCandidates = <ProductUnit>[
      if (existing == null && orderedUnits.isNotEmpty)
        orderedUnits.last
      else if (inferredParent != null)
        inferredParent,
    ];
    final parentCandidates = <ProductUnit>[
      ...{
        for (final unit in rawParentCandidates)
          if (unit.id != null) unit.id!: unit,
      }.values,
    ];
    String? parentUnitId =
        parentCandidates
                .where((unit) => unit.id == inferredParent?.id)
                .firstOrNull
                ?.id ??
            parentCandidates.firstOrNull?.id;
    final name = TextEditingController(text: existing?.name ?? '');
    final unitsPerParent = TextEditingController(
      text:
          existing == null
              ? '2'
              : _numberInput(
                ProductUnitHierarchy.unitsPerParent(existing, orderedUnits),
              ),
    );
    final salePrice = TextEditingController(
      text: _moneyInput(existing?.salePriceMinor ?? 0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: Text(existing == null ? 'إضافة وحدة' : 'تعديل الوحدة'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          onChanged: (_) => setLocal(() {}),
                          decoration: const InputDecoration(
                            labelText: 'اسم الوحدة',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isBase) ...[
                          DropdownButtonFormField<String>(
                            key: ValueKey('unit-parent-$parentUnitId'),
                            initialValue:
                                parentCandidates.any(
                                      (unit) => unit.id == parentUnitId,
                                    )
                                    ? parentUnitId
                                    : null,
                            items:
                                parentCandidates
                                    .map(
                                      (unit) => DropdownMenuItem(
                                        value: unit.id,
                                        child: Text(unit.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setLocal(
                                  () => parentUnitId = value,
                                ),
                            decoration: const InputDecoration(
                              labelText: 'الوحدة الأصغر داخلها',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: unitsPerParent,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setLocal(() {}),
                            decoration: InputDecoration(
                              labelText:
                                  'عدد ${parentCandidates.where((unit) => unit.id == parentUnitId).firstOrNull?.name ?? 'الوحدات'} داخل ${name.text.trim().isEmpty ? 'العبوة' : name.text.trim()}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _UnitConversionPreview(
                            unitName:
                                name.text.trim().isEmpty
                                    ? 'العبوة الجديدة'
                                    : name.text.trim(),
                            parent:
                                parentCandidates
                                    .where(
                                      (unit) => unit.id == parentUnitId,
                                    )
                                    .firstOrNull,
                            unitsPerParent:
                                double.tryParse(unitsPerParent.text.trim()) ?? 0,
                            baseUnit:
                                ProductUnitHierarchy.baseUnit(orderedUnits),
                          ),
                        ] else
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.lock_outline),
                            title: Text('وحدة الأساس للمخزون'),
                            subtitle: Text(
                              'معاملها 1 ولا يمكن تحويلها إلى عبوة بعد إنشاء المنتج.',
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: salePrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'سعر البيع',
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
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(masterDataRepositoryProvider)
            .saveProductUnit(
              productId: productId,
              id: existing?.id,
              name: name.text,
              parentUnitId: isBase ? null : parentUnitId,
              unitsPerParent:
                  isBase
                      ? 1
                      : double.parse(unitsPerParent.text.trim()),
              salePriceMinor: Money.fromMajor(salePrice.text),
            );
        setState(() => revision++);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) CustomSnackBar.showErrorSnackbar('$e');
      }
    }
    name.dispose();
    unitsPerParent.dispose();
    salePrice.dispose();
  }

  String _moneyInput(int minor) {
    final value = Money(minor).major.toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _numberInput(double value) =>
      value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();

  Future<void> _addBarcode(List<ProductUnit> units) async {
    final selectableUnits = <ProductUnit>[
      ...{
        for (final unit in units)
          if (unit.id != null) unit.id!: unit,
      }.values,
    ];
    if (selectableUnits.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أضف وحدة للمنتج أولاً');
      return;
    }
    var unitId = selectableUnits.first.id!;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('إضافة باركود'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: unitId,
                          items:
                              selectableUnits
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.id!,
                                      child: Text(u.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) setLocal(() => unitId = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'الوحدة',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: code,
                          decoration: const InputDecoration(
                            labelText: 'الباركود',
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
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(masterDataRepositoryProvider)
            .addBarcode(productUnitId: unitId, code: code.text);
        setState(() => revision++);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) CustomSnackBar.showErrorSnackbar('$e');
      }
    }
    code.dispose();
  }
}

class _UnitConversionPreview extends StatelessWidget {
  const _UnitConversionPreview({
    required this.unitName,
    required this.parent,
    required this.unitsPerParent,
    required this.baseUnit,
  });

  final String unitName;
  final ProductUnit? parent;
  final double unitsPerParent;
  final ProductUnit? baseUnit;

  @override
  Widget build(BuildContext context) {
    final selectedParent = parent;
    if (selectedParent == null || unitsPerParent <= 1) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text('اختر الوحدة الأصغر وأدخل عدداً أكبر من 1.'),
      );
    }
    final factor = selectedParent.factor * unitsPerParent;
    final count = _formatUnitNumber(unitsPerParent);
    final baseCount = _formatUnitNumber(factor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .25),
        ),
      ),
      child: Text(
        '1 $unitName = $count ${selectedParent.name} = $baseCount ${baseUnit?.name ?? 'وحدة الأساس'}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _formatUnitNumber(double value) =>
    value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
