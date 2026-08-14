import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/features/master_data/ui/party_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key, this.filterType});
  final String? filterType;

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load() => ref.read(masterDataRepositoryProvider).listParties(type: widget.filterType, search: search.text);

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    return Scaffold(
      appBar: AppBar(title: Text(widget.filterType == 'customer' ? 'العملاء' : widget.filterType == 'supplier' ? 'الموردون' : 'الأطراف')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالاسم أو الهاتف'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: _load(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
                  final rows = snapshot.data ?? const <Map<String, Object?>>[];
                  if (rows.isEmpty) return const Center(child: Text('لا توجد بيانات'));
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final balance = (row['current_balance_minor'] as num).toInt();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.colors.secondary.withValues(alpha: .35),
                          child: const Icon(Icons.person_outline),
                        ),
                        title: Text('${row['name']}'),
                        subtitle: Text('${row['phone'] ?? ''} • ${row['type']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Money(balance).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') await _edit(row: row);
                                if (value == 'archive') await _archive(row);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => showDialog(context: context, builder: (_) => PartyDetailsDialog(party: row)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit({Map<String, Object?>? row}) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final phone = TextEditingController(text: row?['phone']?.toString() ?? '');
    var type = row?['type']?.toString() ?? widget.filterType ?? 'customer';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text(row == null ? 'إضافة طرف' : 'تعديل طرف'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 10),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('عميل')),
                    DropdownMenuItem(value: 'supplier', child: Text('مورد')),
                    DropdownMenuItem(value: 'both', child: Text('عميل ومورد')),
                  ],
                  onChanged: (value) {
                    if (value != null) setLocal(() => type = value);
                  },
                  decoration: const InputDecoration(labelText: 'النوع'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(masterDataRepositoryProvider).saveParty(id: row?['id'] as String?, name: name.text, phone: phone.text, type: type);
      ref.read(dataRevisionProvider.notifier).state++;
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _archive(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('أرشفة الطرف'),
        content: Text('هل تريد أرشفة ${row['name']}؟ لن يتم حذف الحركات التاريخية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(masterDataRepositoryProvider).archiveParty(row['id'] as String);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
