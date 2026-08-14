import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductDetailsDialog extends ConsumerStatefulWidget {
  const ProductDetailsDialog({super.key, required this.product});
  final Map<String, Object?> product;

  @override
  ConsumerState<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends ConsumerState<ProductDetailsDialog> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final productId = widget.product['id'] as String;
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
                      '${widget.product['name']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<List<Map<String, Object?>>>>(
                  key: ValueKey(revision),
                  future: _load(productId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
                    final data = snapshot.data!;
                    final units = data[0];
                    final barcodes = data[1];
                    final specs = data[2];
                    return ListView(
                      children: [
                        _sectionHeader('الوحدات', () => _addUnit(productId)),
                        ...units.map(
                          (u) => ListTile(
                            leading: Icon((u['is_primary'] as num).toInt() == 1 ? Icons.star : Icons.straighten),
                            title: Text('${u['name']}'),
                            subtitle: Text('عامل التحويل: ${u['factor']}'),
                            trailing: (u['is_primary'] as num).toInt() == 1 ? const Chip(label: Text('رئيسية')) : null,
                          ),
                        ),
                        const Divider(),
                        _sectionHeader('الباركود', units.isEmpty ? null : () => _addBarcode(units)),
                        if (barcodes.isEmpty) const ListTile(title: Text('لا توجد باركودات')),
                        ...barcodes.map((b) => ListTile(leading: const Icon(Icons.qr_code), title: Text('${b['code']}'), subtitle: Text('${b['unit_name']}'))),
                        const Divider(),
                        _sectionHeader('المواصفات', () => _addSpecification(productId)),
                        if (specs.isEmpty) const ListTile(title: Text('لا توجد مواصفات')),
                        ...specs.map((s) => ListTile(title: Text('${s['title']}'), trailing: Text('${s['value']}'))),
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
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
            if (onAdd != null) IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
      );

  Future<List<List<Map<String, Object?>>>> _load(String productId) async {
    final repo = ref.read(masterDataRepositoryProvider);
    return Future.wait([
      repo.listProductUnits(productId),
      repo.listBarcodes(productId),
      repo.listProductSpecifications(productId),
    ]);
  }

  Future<void> _addUnit(String productId) async {
    final name = TextEditingController();
    final factor = TextEditingController(text: '1');
    var primary = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('إضافة وحدة'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الوحدة')),
                const SizedBox(height: 8),
                TextField(controller: factor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عامل التحويل للوحدة الرئيسية')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: primary,
                  onChanged: (v) => setLocal(() => primary = v ?? false),
                  title: const Text('اجعلها الوحدة الرئيسية'),
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
    if (ok == true) {
      try {
        await ref.read(masterDataRepositoryProvider).saveProductUnit(
              productId: productId,
              name: name.text,
              factor: double.parse(factor.text),
              isPrimary: primary,
            );
        setState(() => revision++);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    name.dispose();
    factor.dispose();
  }

  Future<void> _addBarcode(List<Map<String, Object?>> units) async {
    var unitId = units.first['id'] as String;
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('إضافة باركود'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: unitId,
                  items: units.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text('${u['name']}'))).toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => unitId = v);
                  },
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                ),
                const SizedBox(height: 8),
                TextField(controller: code, decoration: const InputDecoration(labelText: 'الباركود')),
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
    if (ok == true) {
      try {
        await ref.read(masterDataRepositoryProvider).addBarcode(productUnitId: unitId, code: code.text);
        setState(() => revision++);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    code.dispose();
  }

  Future<void> _addSpecification(String productId) async {
    final title = TextEditingController();
    final value = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مواصفة'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 8),
              TextField(controller: value, decoration: const InputDecoration(labelText: 'القيمة')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(masterDataRepositoryProvider).addProductSpecification(productId: productId, title: title.text, value: value.text);
        setState(() => revision++);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    title.dispose();
    value.dispose();
  }
}
