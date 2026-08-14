import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('المستودعات')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, ref), child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: ref.read(masterDataRepositoryProvider).listWarehouses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, Object?>>[];
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: Text('${row['name']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await _edit(context, ref, row: row);
                      if (value == 'archive') await _archive(context, ref, row);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {Map<String, Object?>? row}) async {
    final controller = TextEditingController(text: row?['name']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(row == null ? 'مستودع جديد' : 'تعديل المستودع'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'الاسم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
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
        content: const Text('يمكن أرشفة المستودع فقط إذا لم يكن المستودع الافتراضي ولا يحتوي على مخزون.'),
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
