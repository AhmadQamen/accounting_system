import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

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
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final compact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: const Text('المخزون')) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'INVENTORY',
                title: 'المخزون',
                subtitle: 'قراءة سريعة للكميات والقيمة والتنبيهات عبر جميع المستودعات.',
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
            FutureBuilder<List<Map<String, Object?>>>(
              future: ref.read(inventoryRepositoryProvider).listInventory(search: search.text),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 360, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل المخزون', subtitle: '${snapshot.error}');
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                final totalValue = rows.fold<int>(0, (sum, row) => sum + (((row['inventory_value_minor'] as num?) ?? 0).toInt()));
                final low = rows.where((row) {
                  final qty = ((row['current_quantity'] as num?) ?? 0).toDouble();
                  final min = ((row['min_quantity'] as num?) ?? 0).toDouble();
                  return min > 0 && qty <= min;
                }).length;
                final warehouses = rows.map((e) => '${e['warehouse_name']}').toSet().length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 700;
                        final width = narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
                        final stats = [
                          ('قيمة المخزون', _money(context, totalValue, currency), Icons.payments_outlined, context.colors.primary, 'بسعر التكلفة'),
                          ('تنبيهات الحد الأدنى', '$low', Iconsax.warning_2, context.colors.error, low == 0 ? 'المخزون بحالة جيدة' : 'تحتاج متابعة'),
                          ('المستودعات النشطة', '$warehouses', Iconsax.buildings_2, context.colors.info, '${rows.length} رصيد صنف'),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < stats.length; i++)
                              SizedBox(
                                width: width,
                                height: 132,
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
                            Row(
                              children: [
                                Expanded(
                                  child: PremiumSearchField(
                                    controller: search,
                                    hintText: 'ابحث باسم المنتج…',
                                    onChanged: (_) => setState(() {}),
                                    trailing: search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              search.clear();
                                              setState(() {});
                                            },
                                            icon: const Icon(Iconsax.close_circle, size: 18),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusPill(label: '${rows.length} رصيد', color: context.colors.primary, icon: Iconsax.box),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (rows.isEmpty)
                              EmptyState(
                                title: search.text.trim().isEmpty ? 'لا توجد أرصدة مخزون بعد' : 'لا توجد نتائج مطابقة',
                                subtitle: search.text.trim().isEmpty
                                    ? 'أنشئ منتجاً ثم أضف له رصيداً افتتاحياً لتظهر بيانات المخزون هنا.'
                                    : 'جرّب البحث باسم مختلف.',
                                icon: Iconsax.box,
                              )
                            else
                              ...rows.indexed.map((entry) => _InventoryRow(
                                    row: entry.$2,
                                    currency: currency,
                                    showDivider: entry.$1 != rows.length - 1,
                                  )),
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

  String _money(BuildContext context, int value, String currency) => Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  Future<void> _opening() async {
    final products = await ref.read(masterDataRepositoryProvider).listProducts();
    final warehouses = await ref.read(masterDataRepositoryProvider).listWarehouses();
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنشئ منتجاً أولاً')));
      return;
    }
    if (warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنشئ مستودعاً أولاً')));
      return;
    }

    String productId = products.first['id'] as String;
    String warehouseId = warehouses.first['id'] as String;
    final qty = TextEditingController();
    final value = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_box_outlined, color: context.colors.primary),
              const SizedBox(width: 10),
              const Text('رصيد افتتاحي'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: productId,
                  items: products.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['name']}'))).toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => productId = v);
                  },
                  decoration: const InputDecoration(labelText: 'المنتج', prefixIcon: Icon(Iconsax.box)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: warehouseId,
                  items: warehouses.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['name']}'))).toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => warehouseId = v);
                  },
                  decoration: const InputDecoration(labelText: 'المستودع', prefixIcon: Icon(Iconsax.buildings_2)),
                ),
                const SizedBox(height: 10),
                TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية', prefixIcon: Icon(Icons.straighten_outlined))),
                const SizedBox(height: 10),
                TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'إجمالي قيمة المخزون', prefixIcon: Icon(Icons.payments_outlined))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Iconsax.tick_circle, size: 17), label: const Text('اعتماد')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final parsedQty = double.tryParse(qty.text.trim());
      if (parsedQty == null || parsedQty <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية صحيحة أكبر من صفر')));
      } else {
        await ref.read(inventoryRepositoryProvider).addOpeningBalance(
              productId: productId,
              warehouseId: warehouseId,
              quantity: parsedQty,
              totalValueMinor: Money.fromMajor(value.text),
            );
        ref.read(dataRevisionProvider.notifier).state++;
      }
    }
    qty.dispose();
    value.dispose();
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.row, required this.currency, required this.showDivider});
  final Map<String, Object?> row;
  final String currency;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final qty = ((row['current_quantity'] as num?) ?? 0).toDouble();
    final min = ((row['min_quantity'] as num?) ?? 0).toDouble();
    final low = min > 0 && qty <= min;
    final value = ((row['inventory_value_minor'] as num?) ?? 0).toInt();
    final avg = qty > 0 ? (value / qty).round() : 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (low ? colors.error : colors.primary).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(low ? Iconsax.warning_2 : Iconsax.box, color: low ? colors.error : colors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['product_name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('${row['warehouse_name']} • ${row['primary_unit_name'] ?? 'وحدة'}', style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_qty(qty), style: TextStyle(color: low ? colors.error : colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                    Text(low ? 'عند الحد الأدنى' : 'الكمية الحالية', style: TextStyle(color: low ? colors.error : colors.textDim, fontSize: 9.5)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Money(value).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.5)),
                    Text('متوسط ${Money(avg).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }

  String _qty(double value) => value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
