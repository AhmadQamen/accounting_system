import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final compact = showCompactPageAppBar(context);
    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('المستودعات')) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'WAREHOUSES',
                title: 'المستودعات',
                subtitle: 'نقاط تخزين واضحة ومستقلة، مع حماية الأرصدة من الحذف غير المقصود.',
                icon: Iconsax.buildings_2,
                actions: [
                  FilledButton.icon(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add_rounded), label: const Text('مستودع جديد')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Warehouse>>(
              future: ref.read(masterDataRepositoryProvider).listWarehouses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل المستودعات', subtitle: '${snapshot.error}');
                final rows = snapshot.data ?? const <Warehouse>[];
                return AnimatedEntrance(
                  delay: const Duration(milliseconds: 90),
                  child: PremiumPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'قائمة المستودعات',
                          subtitle: 'يمكن تعديل الاسم أو أرشفة المستودع الفارغ فقط',
                          trailing: StatusPill(label: '${rows.length} مستودع', color: context.colors.primary, icon: Iconsax.buildings_2),
                        ),
                        const SizedBox(height: 14),
                        if (rows.isEmpty)
                          const EmptyState(title: 'لا توجد مستودعات', subtitle: 'أنشئ مستودعاً لتبدأ إدارة المخزون.', icon: Iconsax.buildings_2)
                        else
                          ...rows.indexed.map((entry) => _WarehouseRow(
                                row: entry.$2,
                                showDivider: entry.$1 != rows.length - 1,
                                onEdit: () => _edit(context, ref, row: entry.$2),
                                onArchive: () => _archive(context, ref, entry.$2),
                              )),
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

  Future<void> _edit(BuildContext context, WidgetRef ref, {Warehouse? row}) async {
    final controller = TextEditingController(text: row?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [Icon(Iconsax.buildings_2, color: context.colors.primary), const SizedBox(width: 10), Text(row == null ? 'مستودع جديد' : 'تعديل المستودع')]),
        content: SizedBox(width: responsiveDialogWidth(context, 430), child: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المستودع', prefixIcon: Icon(Iconsax.buildings_2)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Iconsax.tick_circle, size: 17), label: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref.read(masterDataRepositoryProvider).saveWarehouse(id: row?.id, name: controller.text);
      ref.read(dataRevisionProvider.notifier).state++;
    }
    controller.dispose();
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, Warehouse row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أرشفة المستودع'),
        content: const Text('يمكن أرشفة المستودع فقط إذا لم يكن الافتراضي ولا يحتوي على رصيد مخزون.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(masterDataRepositoryProvider).archiveWarehouse(row.id!);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({required this.row, required this.showDivider, required this.onEdit, required this.onArchive});
  final Warehouse row;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final identity = Row(
                children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(Iconsax.buildings_2, color: colors.primary, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(row.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13))),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(label: 'نشط', color: colors.success, compact: true),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'archive') onArchive(); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('تعديل'), dense: true)),
                      PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('أرشفة'), dense: true)),
                    ],
                  ),
                ],
              );
              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 6), Align(alignment: AlignmentDirectional.centerEnd, child: actions)]);
              }
              return Row(children: [Expanded(child: identity), const SizedBox(width: 8), actions]);
            },
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
