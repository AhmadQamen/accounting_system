import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/master_data/models/product_unit_hierarchy.dart';
import 'package:accounting_system/features/master_data/ui/product_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'IQD';
    return MyScaffold(
      appBar: BlurAppBar(title: const Text('تفاصيل المنتج')),
      body: PremiumPage(
        child: FutureBuilder<ProductInsights>(
          future: ref
              .read(masterDataRepositoryProvider)
              .productInsights(product.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError)
              return EmptyState(
                title: 'تعذر تحميل تفاصيل المنتج',
                subtitle: '${snapshot.error}',
                icon: Icons.error_outline,
              );
            final data = snapshot.data!;
            return Column(
              children: [
                PageIntro(
                  eyebrow: 'PRODUCT',
                  title: product.name,
                  subtitle:
                      '${product.itemType == 'stocked' ? 'مادة مخزنية' : 'مادة غير مخزنية'} • ${product.categoryName ?? 'بدون تصنيف'} • وحدة الأساس: ${product.primaryUnitName ?? '—'} • الحد الأدنى: ${_qty(product.minQuantity)}${product.location?.isNotEmpty == true ? ' • المكان: ${product.location}' : ''}',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'بيانات المادة',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('سعر الكلفة المرجعي: ${Money(product.costPriceMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}'),
                      const Text('هذا السعر محلي فقط ولا يحل محل متوسط تكلفة المخزون.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'الوحدات والباركود',
                  action: TextButton.icon(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (_) => ProductDetailsDialog(product: product),
                        ),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('إدارة الطبقات'),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children:
                        data.units.map((unit) {
                          final unitBarcodes = data.barcodes
                              .where(
                                (barcode) => barcode.productUnitId == unit.id,
                              )
                              .map((barcode) => barcode.code)
                              .join(' • ');
                          return SizedBox(
                            width: 270,
                            child: _UnitCard(
                              unit: unit,
                              units: data.units,
                              barcodeText: unitBarcodes,
                              currency: currency,
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'المخزون حسب المستودع',
                  subtitle:
                      'الكمية بوحدة الأساس. متوسط التكلفة ليس سعر البيع.',
                  child: _Stocks(
                    rows: data.stockByWarehouse,
                    currency: currency,
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'آخر الحركات',
                  subtitle:
                      'آخر ${data.movements.length} حركة فقط لتبقى الصفحة سريعة.',
                  child: _Movements(rows: data.movements),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'المستندات المرتبطة',
                  subtitle:
                      'آخر ${data.documents.length} مستندات تحتوي هذا المنتج.',
                  child: Column(
                    children:
                        data.documents
                            .map(
                              (doc) => ListTile(
                                leading: const Icon(Icons.description_outlined),
                                title: Text(
                                  '${_docType(doc.type)} • ${doc.number}',
                                ),
                                subtitle: Text(
                                  '${_date(doc.occurredAt)} • ${_status(doc.status)}',
                                ),
                                trailing: const Icon(Icons.chevron_left),
                                onTap:
                                    () => _openDocument(
                                      context,
                                      ref,
                                      doc,
                                      currency,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'المواصفات المحلية غير معروضة هنا لأنها لا تُزامَن بين الأجهزة. يلزم إضافة أحداث ProductSpecificationCreated/Updated/Deleted إلى عقد الباك قبل عرضها كمعلومة مشتركة.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    WidgetRef ref,
    ProductDocumentLink link,
    String currency,
  ) async {
    final details = await ref
        .read(documentRepositoryProvider)
        .documentDetails(link.type, link.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              '${_docType(link.type)} • ${details.header.displayNumber}',
            ),
            content: SizedBox(
              width: 620,
              child: ListView(
                shrinkWrap: true,
                children:
                    details.items
                        .map(
                          (line) => ListTile(
                            title: Text(line.productName ?? '—'),
                            subtitle: Text(
                              '${_qty(line.baseQuantity)} من الوحدة الأساسية',
                            ),
                            trailing: Text(
                              Money(line.lineTotalMinor).format(
                                locale:
                                    Localizations.localeOf(context).toString(),
                                currencyCode: currency,
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => PremiumPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (action != null) action!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.units,
    required this.barcodeText,
    required this.currency,
  });
  final ProductUnit unit;
  final List<ProductUnit> units;
  final String barcodeText;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final parent = ProductUnitHierarchy.parentOf(unit, units);
    final base = ProductUnitHierarchy.baseUnit(units);
    final relation =
        parent == null
            ? 'وحدة الأساس للمخزون'
            : '1 ${unit.name} = ${_qty(ProductUnitHierarchy.unitsPerParent(unit, units))} ${parent.name} = ${_qty(unit.factor)} ${base?.name ?? 'وحدة أساس'}';
    return PremiumPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(unit.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          relation,
        ),
        Text(
          'سعر البيع المحدد: ${Money(unit.salePriceMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
        ),
        if (barcodeText.isNotEmpty)
          Text(
            'الباركود: $barcodeText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
    );
  }
}

class _Stocks extends StatelessWidget {
  const _Stocks({required this.rows, required this.currency});
  final List<ProductWarehouseStock> rows;
  final String currency;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('لا يوجد مخزون مسجل في المستودعات.');
    return Column(
      children:
          rows
              .map(
                (row) => ListTile(
                  leading: Icon(
                    row.isLowStock
                        ? Icons.warning_amber_rounded
                        : Icons.warehouse_outlined,
                    color: row.isLowStock ? Colors.amber : null,
                  ),
                  title: Text(row.warehouseName),
                  subtitle: Text(
                    'الكمية: ${_qty(row.baseQuantity)} • القيمة: ${Money(row.inventoryValueMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('متوسط تكلفة الوحدة الأساسية'),
                      Text(
                        Money(row.averageCostMinor).format(
                          locale: Localizations.localeOf(context).toString(),
                          currencyCode: currency,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({required this.rows});
  final List<ProductMovementSummary> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('لا توجد حركات لهذا المنتج بعد.');
    return Column(
      children:
          rows
              .map(
                (row) => ListTile(
                  leading: Icon(
                    row.quantityDelta >= 0
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                  ),
                  title: Text(_movementType(row.type)),
                  subtitle: Text(
                    '${row.warehouseName} • ${_date(row.occurredAt)} • ${row.referenceType}',
                  ),
                  trailing: Text(
                    '${row.quantityDelta >= 0 ? '+' : ''}${_qty(row.quantityDelta)}',
                  ),
                ),
              )
              .toList(),
    );
  }
}

String _qty(double value) =>
    value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3);
String _date(DateTime? date) =>
    date == null
        ? '—'
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
String _status(String value) => switch (value) {
  'posted' => 'معتمد',
  'void' => 'ملغى',
  _ => 'مسودة',
};
String _docType(String value) => switch (value) {
  'sale' => 'فاتورة بيع',
  'purchase' => 'فاتورة شراء',
  'sale_return' => 'مرتجع بيع',
  'purchase_return' => 'مرتجع شراء',
  'waste' => 'هالك',
  _ => value,
};
String _movementType(String value) => switch (value) {
  'purchase' => 'شراء',
  'sale' => 'بيع',
  'sale_return' => 'مرتجع بيع',
  'purchase_return' => 'مرتجع شراء',
  'adjustment' => 'تسوية',
  'transfer_in' => 'تحويل وارد',
  'transfer_out' => 'تحويل صادر',
  'waste' => 'تالف',
  'reversal' => 'قيد عكسي',
  'opening_balance' => 'رصيد افتتاحي',
  _ => value,
};
