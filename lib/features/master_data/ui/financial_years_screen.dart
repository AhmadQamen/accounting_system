import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinancialYearsScreen extends ConsumerWidget {
  const FinancialYearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currentId = ref.watch(localContextProvider).asData?.value?.financialYearId;
    return Scaffold(
      appBar: AppBar(title: const Text('السنوات المالية')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createYear(context, ref),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: ref.read(masterDataRepositoryProvider).listFinancialYears(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, Object?>>[];
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final id = row['id'] as String;
              final isOpen = (row['is_open'] as num).toInt() == 1;
              final isCurrent = id == currentId;
              return Card(
                child: ListTile(
                  leading: Icon(isOpen ? Icons.lock_open : Icons.lock),
                  title: Row(
                    children: [
                      Text('${row['name']}'),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        const Chip(label: Text('الحالية')),
                      ],
                    ],
                  ),
                  subtitle: Text('${row['starts_on']} — ${row['ends_on']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(context, ref, id, value),
                    itemBuilder: (context) => [
                      if (isOpen && !isCurrent)
                        const PopupMenuItem(value: 'activate', child: Text('تعيين كسنة حالية')),
                      if (isOpen && !isCurrent)
                        const PopupMenuItem(value: 'close', child: Text('إغلاق السنة')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(isOpen ? 'مفتوحة' : 'مغلقة'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String id, String action) async {
    try {
      if (action == 'activate') {
        await ref.read(masterDataRepositoryProvider).activateFinancialYear(id);
        ref.invalidate(localContextProvider);
      } else if (action == 'close') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('إغلاق السنة المالية'),
            content: const Text('بعد الإغلاق لن يمكن إنشاء مستندات جديدة على هذه السنة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إغلاق')),
            ],
          ),
        );
        if (confirmed == true) await ref.read(masterDataRepositoryProvider).closeFinancialYear(id);
      }
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _createYear(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final nextYear = now.year + 1;
    final name = TextEditingController(text: '$nextYear');
    var start = DateTime(nextYear, 1, 1);
    var end = DateTime(nextYear, 12, 31, 23, 59, 59);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('سنة مالية جديدة'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم السنة')),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('تاريخ البداية'),
                  subtitle: Text('${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2200));
                    if (picked != null) setLocal(() => start = picked);
                  },
                ),
                ListTile(
                  title: const Text('تاريخ النهاية'),
                  subtitle: Text('${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2200));
                    if (picked != null) setLocal(() => end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ref.read(masterDataRepositoryProvider).createFinancialYear(name: name.text, startsOn: start, endsOn: end);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    name.dispose();
  }
}
