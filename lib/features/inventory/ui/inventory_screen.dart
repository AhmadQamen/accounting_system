import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/inventory/models/inventory_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);

    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('المخزون')) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'INVENTORY',
                title: 'المخزون',
                subtitle:
                    'قراءة سريعة للكميات والقيمة والتنبيهات عبر جميع المستودعات.',
                icon: Iconsax.box_1,
                actions: [
                  FilledButton.icon(
                    onPressed: _opening,
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('رصيد افتتاحي'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<InventoryItem>>(
              future: ref
                  .read(inventoryRepositoryProvider)
                  .listInventory(search: search.text),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 360,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر تحميل المخزون',
                    subtitle: '${snapshot.error}',
                  );
                }
                final rows = snapshot.data ?? const <InventoryItem>[];
                final totalValue = rows.fold<int>(
                  0,
                  (sum, row) => sum + row.inventoryValueMinor,
                );
                final low = rows.where((row) => row.isLowStock).length;
                final warehouses =
                    rows
                        .map((e) => e.warehouseName ?? '')
                        .where((e) => e.isNotEmpty)
                        .toSet()
                        .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 700 ? 2 : 3;
                        final width =
                            (constraints.maxWidth - ((columns - 1) * 12)) /
                            columns;
                        final stats = [
                          (
                            'قيمة المخزون',
                            _money(context, totalValue, currency),
                            Icons.payments_outlined,
                            context.colors.primary,
                            'بسعر التكلفة',
                          ),
                          (
                            'تنبيهات الحد الأدنى',
                            '$low',
                            Iconsax.warning_2,
                            context.colors.error,
                            low == 0 ? 'المخزون بحالة جيدة' : 'تحتاج متابعة',
                          ),
                          (
                            'المستودعات النشطة',
                            '$warehouses',
                            Iconsax.buildings_2,
                            context.colors.info,
                            '${rows.length} رصيد صنف',
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < stats.length; i++)
                              SizedBox(
                                width: width,
                                child: AnimatedEntrance(
                                  delay: Duration(milliseconds: 60 + i * 35),
                                  child: MetricCard(
                                    label: stats[i].$1,
                                    value: stats[i].$2,
                                    icon: stats[i].$3,
                                    accent: stats[i].$4,
                                    caption: stats[i].$5,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 150),
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final field = PremiumSearchField(
                                  controller: search,
                                  hintText: 'ابحث باسم المنتج…',
                                  onChanged: (_) => setState(() {}),
                                  trailing:
                                      search.text.isEmpty
                                          ? null
                                          : IconButton(
                                            onPressed: () {
                                              search.clear();
                                              setState(() {});
                                            },
                                            icon: const Icon(
                                              Iconsax.close_circle,
                                              size: 18,
                                            ),
                                          ),
                                );
                                final count = StatusPill(
                                  label: '${rows.length} رصيد',
                                  color: context.colors.primary,
                                  icon: Iconsax.box,
                                );
                                if (constraints.maxWidth < 500) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      field,
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: count,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: field),
                                    const SizedBox(width: 10),
                                    count,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            if (rows.isEmpty)
                              EmptyState(
                                title:
                                    search.text.trim().isEmpty
                                        ? 'لا توجد أرصدة مخزون بعد'
                                        : 'لا توجد نتائج مطابقة',
                                subtitle:
                                    search.text.trim().isEmpty
                                        ? 'أنشئ منتجاً ثم أضف له رصيداً افتتاحياً لتظهر بيانات المخزون هنا.'
                                        : 'جرّب البحث باسم مختلف.',
                                icon: Iconsax.box,
                              )
                            else
                              ...rows.indexed.map(
                                (entry) => _InventoryRow(
                                  row: entry.$2,
                                  currency: currency,
                                  showDivider: entry.$1 != rows.length - 1,
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
          ],
        ),
      ),
    );
  }

  String _money(BuildContext context, int value, String currency) =>
      Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  String _quantity(double value) =>
      value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

  Future<void> _opening() async {
    final inventoryRepository = ref.read(inventoryRepositoryProvider);
    final products = await ref.read(masterDataRepositoryProvider).listProducts();
    final warehouses =
        await ref.read(masterDataRepositoryProvider).listWarehouses();
    final currentInventory = await inventoryRepository.listInventory();
    if (!mounted) return;
    if (products.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أنشئ منتجاً أولاً');
      return;
    }
    if (warehouses.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أنشئ مستودعاً أولاً');
      return;
    }

    String productId = products.first.id!;
    String warehouseId = warehouses.first.id!;
    final qty = TextEditingController();
    final unitCost = TextEditingController(
      text: _moneyInput(products.first.costPriceMinor),
    );
    final currency =
        ref.read(localContextProvider).asData?.value.currencyCode ?? 'IQD';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              final selectedProduct = products.firstWhere(
                (product) => product.id == productId,
              );
              final enteredQty = double.tryParse(qty.text.trim()) ?? 0;
              final enteredUnitCost = _tryMoney(unitCost.text);
              final calculatedTotal = Money.multiplyByQuantity(
                enteredUnitCost,
                enteredQty,
              );
              final matchingInventory =
                  currentInventory
                      .where(
                        (item) =>
                            item.productId == productId &&
                            item.warehouseId == warehouseId,
                      )
                      .firstOrNull;
              final currentQuantity =
                  matchingInventory?.currentQuantity ?? 0;
              final currentValue =
                  matchingInventory?.inventoryValueMinor ?? 0;
              final currentAverage =
                  currentQuantity > 0
                      ? Money.divideByQuantity(currentValue, currentQuantity)
                      : 0;
              final projectedQuantity = currentQuantity + enteredQty;
              final projectedAverage =
                  projectedQuantity > 0
                      ? Money.divideByQuantity(
                        currentValue + calculatedTotal,
                        projectedQuantity,
                      )
                      : 0;
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.add_box_outlined, color: context.colors.primary),
                    const SizedBox(width: 10),
                    const Text('رصيد افتتاحي'),
                  ],
                ),
                content: SizedBox(
                  width: responsiveDialogWidth(context, 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: productId,
                        items:
                            products
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id!,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setLocal(() {
                              productId = v;
                              final product = products.firstWhere(
                                (item) => item.id == v,
                              );
                              unitCost.text = _moneyInput(
                                product.costPriceMinor,
                              );
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'المنتج',
                          prefixIcon: Icon(Iconsax.box),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: warehouseId,
                        items:
                            warehouses
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id!,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => warehouseId = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'المستودع',
                          prefixIcon: Icon(Iconsax.buildings_2),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: qty,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setLocal(() {}),
                        decoration: const InputDecoration(
                          labelText: 'الكمية',
                          prefixIcon: Icon(Icons.straighten_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: unitCost,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setLocal(() {}),
                        decoration: const InputDecoration(
                          labelText: 'كلفة الوحدة الافتتاحية',
                          prefixIcon: Icon(Icons.price_check_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سعر الكلفة المرجعي: ${_money(context, selectedProduct.costPriceMinor, currency)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إجمالي قيمة الرصيد: ${_money(context, calculatedTotal, currency)}',
                              style: TextStyle(
                                color: context.colors.textSecondary,
                              ),
                            ),
                            if (currentQuantity > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'المتوسط المرجّح الحالي: ${_money(context, currentAverage, currency)} • الكمية: ${_quantity(currentQuantity)}',
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                            if (enteredQty > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'المتوسط المرجّح بعد الإضافة: ${_money(context, projectedAverage, currency)}',
                                style: TextStyle(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              'يمكنك تغيير كلفة الوحدة لهذا الرصيد فقط دون تعديل السعر المرجعي للمنتج.',
                              style: TextStyle(
                                color: context.colors.textDim,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Iconsax.tick_circle, size: 17),
                    label: const Text('اعتماد'),
                  ),
                ],
              );
            },
          ),
    );
    if (ok == true) {
      final parsedQty = double.tryParse(qty.text.trim());
      if (parsedQty == null || parsedQty <= 0) {
        if (mounted) {
          CustomSnackBar.showWarningSnackbar('أدخل كمية صحيحة أكبر من صفر');
        }
      } else {
        final unitCostMinor = _tryParseMoney(unitCost.text);
        if (unitCostMinor == null) {
          if (mounted) {
            CustomSnackBar.showWarningSnackbar('أدخل كلفة وحدة صحيحة');
          }
        } else if (unitCostMinor < 0) {
          if (mounted) {
            CustomSnackBar.showWarningSnackbar(
              'كلفة الوحدة لا يمكن أن تكون سالبة',
            );
          }
        } else {
          try {
            await inventoryRepository.addOpeningBalance(
                  productId: productId,
                  warehouseId: warehouseId,
                  quantity: parsedQty,
                  totalValueMinor: Money.multiplyByQuantity(
                    unitCostMinor,
                    parsedQty,
                  ),
                );
            ref.read(dataRevisionProvider.notifier).state++;
          } catch (error) {
            if (mounted) {
              CustomSnackBar.showErrorSnackbar(
                'تعذر إضافة الرصيد: $error',
                copyText: '$error',
              );
            }
          }
        }
      }
    }
    qty.dispose();
    unitCost.dispose();
  }

  String _moneyInput(int minor) {
    final major = Money(minor).major;
    return major == major.truncateToDouble()
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
  }

  int _tryMoney(String value) {
    return _tryParseMoney(value) ?? 0;
  }

  int? _tryParseMoney(String value) {
    try {
      return Money.fromMajor(value);
    } catch (_) {
      return null;
    }
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.row,
    required this.currency,
    required this.showDivider,
  });
  final InventoryItem row;
  final String currency;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qty = row.currentQuantity;
    final min = row.minQuantity;
    final low = min > 0 && qty <= min;
    final value = row.inventoryValueMinor;
    final avg = qty > 0 ? (value / qty).round() : 0;
    final valueText = Money(value).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final avgText = Money(avg).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );

    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: (low ? colors.error : colors.primary).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        low ? Iconsax.warning_2 : Iconsax.box,
        color: low ? colors.error : colors.primary,
        size: 20,
      ),
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.productName ?? 'منتج',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${row.warehouseName ?? 'مستودع'} • ${row.primaryUnitName ?? 'وحدة'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textDim, fontSize: 10.5),
        ),
      ],
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: identity),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 54),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _InventoryValue(
                            label: low ? 'عند الحد الأدنى' : 'الكمية الحالية',
                            value: _qty(qty),
                            color: low ? colors.error : colors.textPrimary,
                          ),
                          _InventoryValue(
                            label: 'قيمة المخزون',
                            value: valueText,
                            color: colors.textPrimary,
                          ),
                          _InventoryValue(
                            label: 'متوسط التكلفة',
                            value: avgText,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: identity),
                  Expanded(
                    child: _InventoryValue(
                      label: low ? 'عند الحد الأدنى' : 'الكمية الحالية',
                      value: _qty(qty),
                      color: low ? colors.error : colors.textPrimary,
                      alignEnd: true,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 2,
                    child: _InventoryValue(
                      label: 'متوسط $avgText',
                      value: valueText,
                      color: colors.textPrimary,
                      alignEnd: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }

  String _qty(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
}

class _InventoryValue extends StatelessWidget {
  const _InventoryValue({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.textDim, fontSize: 9.5),
        ),
      ],
    );
  }
}
