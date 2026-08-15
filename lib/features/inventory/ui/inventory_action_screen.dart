import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/inventory/models/inventory_models.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';

enum InventoryActionMode { adjustment, transfer }

class InventoryActionScreen extends ConsumerWidget {
  const InventoryActionScreen({super.key, required this.mode});

  final InventoryActionMode mode;

  bool get _isAdjustment => mode == InventoryActionMode.adjustment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final compact = showCompactPageAppBar(context);
    final title = _isAdjustment ? 'الجرد والتسويات' : 'تحويلات المستودعات';
    final subtitle = _isAdjustment
        ? 'راجع الرصيد الفعلي وسجّل الفرق بحركة موثقة في سجل المخزون.'
        : 'انقل الكميات بين المستودعات مع تسجيل حركة خروج ودخول مترابطة.';

    return MyScaffold(
      appBar: compact ? BlurAppBar(title: Text(title)) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: _isAdjustment ? 'STOCK COUNT' : 'WAREHOUSE TRANSFER',
                title: title,
                subtitle: subtitle,
                icon: _isAdjustment ? Iconsax.clipboard_tick : Icons.swap_horiz_rounded,
                actions: [
                  FilledButton.icon(
                    onPressed: () => _isAdjustment ? _adjust(context, ref) : _transfer(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_isAdjustment ? 'تسوية جديدة' : 'تحويل جديد'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<InventoryMovement>>(
              future: ref.read(inventoryRepositoryProvider).movementHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل الحركات', subtitle: '${snapshot.error}');
                }
                final rows = snapshot.data ?? const <InventoryMovement>[];
                final filtered = rows.where((row) {
                  final type = row.movementType;
                  return _isAdjustment ? type == 'adjustment' : type == 'transfer_in' || type == 'transfer_out';
                }).toList();

                return AnimatedEntrance(
                  delay: const Duration(milliseconds: 80),
                  child: PremiumPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'سجل الحركات',
                          subtitle: _isAdjustment ? 'آخر فروقات الجرد المسجلة' : 'آخر حركات النقل بين المستودعات',
                          trailing: StatusPill(label: '${filtered.length} حركة', color: context.colors.primary, icon: Icons.history_rounded),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          EmptyState(
                            icon: _isAdjustment ? Iconsax.clipboard_tick : Icons.swap_horiz_rounded,
                            title: _isAdjustment ? 'لا توجد تسويات بعد' : 'لا توجد تحويلات بعد',
                            subtitle: 'ابدأ بأول عملية من الزر في أعلى الصفحة.',
                          )
                        else
                          ...filtered.indexed.map((entry) => _MovementRow(row: entry.$2, divider: entry.$1 != filtered.length - 1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    final inventory = await ref.read(inventoryRepositoryProvider).listInventory();
    if (!context.mounted) return;
    if (inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مخزون متاح للتسوية.')));
      return;
    }

    var id = inventory.first.id!;
    final quantity = TextEditingController(text: '${inventory.first.currentQuantity}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('تسوية مخزون'),
          content: SizedBox(
            width: responsiveDialogWidth(context, 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: id,
                  isExpanded: true,
                  items: inventory
                      .map((item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text('${item.productName ?? 'منتج'} — ${item.warehouseName ?? 'مستودع'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() => id = value);
                    final row = inventory.firstWhere((item) => item.id == value);
                    quantity.text = '${row.currentQuantity}';
                  },
                  decoration: const InputDecoration(labelText: 'الصنف والمستودع'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية المعدودة', prefixIcon: Icon(Icons.scale_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد التسوية')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final counted = double.tryParse(quantity.text.trim());
      if (counted == null || counted < 0) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية صحيحة.')));
      } else {
        final row = inventory.firstWhere((item) => item.id == id);
        try {
          await ref.read(inventoryRepositoryProvider).postAdjustment(
            warehouseId: row.warehouseId,
            items: [
              InventoryAdjustmentInput(
                inventoryItemId: id,
                productUnitId: row.primaryUnitId!,
                countedQuantity: counted,
              ),
            ],
          );
          ref.read(dataRevisionProvider.notifier).state++;
        } catch (error) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    quantity.dispose();
  }

  Future<void> _transfer(BuildContext context, WidgetRef ref) async {
    final inventory = await ref.read(inventoryRepositoryProvider).listInventory();
    final warehouses = await ref.read(masterDataRepositoryProvider).listWarehouses();
    if (!context.mounted) return;
    if (inventory.isEmpty || warehouses.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التحويل يحتاج مخزوناً ومستودعين على الأقل.')));
      return;
    }

    var itemId = inventory.first.id!;
    var from = inventory.first.warehouseId;
    var to = warehouses.firstWhere((warehouse) => warehouse.id != from).id!;
    final quantity = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('تحويل مخزون'),
          content: SizedBox(
            width: responsiveDialogWidth(context, 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: itemId,
                  isExpanded: true,
                  items: inventory
                      .map((item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text('${item.productName ?? 'منتج'} — ${item.warehouseName ?? 'مستودع'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final row = inventory.firstWhere((item) => item.id == value);
                    setLocal(() {
                      itemId = value;
                      from = row.warehouseId;
                      to = warehouses.firstWhere((warehouse) => warehouse.id != from).id!;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'الصنف من المستودع'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: to,
                  isExpanded: true,
                  items: warehouses
                      .where((warehouse) => warehouse.id != from)
                      .map((warehouse) => DropdownMenuItem(value: warehouse.id!, child: Text(warehouse.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => to = value);
                  },
                  decoration: const InputDecoration(labelText: 'إلى مستودع'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية', prefixIcon: Icon(Icons.scale_outlined)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تنفيذ التحويل')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final parsed = double.tryParse(quantity.text.trim());
      if (parsed == null || parsed <= 0) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية أكبر من صفر.')));
      } else {
        final row = inventory.firstWhere((item) => item.id == itemId);
        try {
          await ref.read(inventoryRepositoryProvider).postTransfer(
            fromWarehouseId: from,
            toWarehouseId: to,
            items: [
              InventoryTransferInput(
                productId: row.productId,
                productUnitId: row.primaryUnitId!,
                quantity: parsed,
                unitFactor: row.primaryUnitFactor,
              ),
            ],
          );
          ref.read(dataRevisionProvider.notifier).state++;
        } catch (error) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    quantity.dispose();
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.row, required this.divider});

  final InventoryMovement row;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final delta = row.quantityDelta;
    final positive = delta >= 0;
    final accent = positive ? colors.success : colors.error;
    final movement = row.movementType;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final identity = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)),
                    child: Icon(positive ? Icons.south_west_rounded : Icons.north_east_rounded, color: accent, size: 18),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.productName ?? 'منتج', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text('$movement • ${row.warehouseName ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              );
              final amount = Text('${positive ? '+' : ''}${_qty(delta)}', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13));
              if (constraints.maxWidth < 430) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 7), Padding(padding: const EdgeInsetsDirectional.only(start: 51), child: amount)]);
              }
              return Row(children: [Expanded(child: identity), const SizedBox(width: 12), amount]);
            },
          ),
        ),
        if (divider) Divider(height: 1, color: colors.border),
      ],
    );
  }

  String _qty(double value) => value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
