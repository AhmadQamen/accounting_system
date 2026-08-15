import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: const Text('المستودعات')) : null,
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
            FutureBuilder<List<Map<String, Object?>>>(
              future: ref.read(masterDataRepositoryProvider).listWarehouses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل المستودعات', subtitle: '${snapshot.error}');
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
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

  Future<void> _edit(BuildContext context, WidgetRef ref, {Map<String, Object?>? row}) async {
    final controller = TextEditingController(text: row?['name']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [Icon(Iconsax.buildings_2, color: context.colors.primary), const SizedBox(width: 10), Text(row == null ? 'مستودع جديد' : 'تعديل المستودع')]),
        content: SizedBox(width: 430, child: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المستودع', prefixIcon: Icon(Iconsax.buildings_2)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Iconsax.tick_circle, size: 17), label: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref.read(masterDataRepositoryProvider).saveWarehouse(id: row?['id'] as String?, name: controller.text);
      ref.read(dataRevisionProvider.notifier).state++;
    }
    controller.dispose();
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, Map<String, Object?> row) async {
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
        await ref.read(masterDataRepositoryProvider).archiveWarehouse(row['id'] as String);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({required this.row, required this.showDivider, required this.onEdit, required this.onArchive});
  final Map<String, Object?> row;
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
          child: Row(
            children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: colors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(Iconsax.buildings_2, color: colors.primary, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text('${row['name']}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13))),
              StatusPill(label: 'نشط', color: colors.success, compact: true),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'archive') onArchive(); },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('تعديل'), dense: true)),
                  PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('أرشفة'), dense: true)),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
