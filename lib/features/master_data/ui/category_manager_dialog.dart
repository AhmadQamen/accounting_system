import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Small catalog manager reused by the product create/edit flows.
class CategoryManagerDialog extends ConsumerStatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  ConsumerState<CategoryManagerDialog> createState() =>
      _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends ConsumerState<CategoryManagerDialog> {
  int _revision = 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إدارة التصنيفات'),
    content: SizedBox(
      width: 420,
      height: 360,
      child: FutureBuilder<List<Category>>(
        key: ValueKey(_revision),
        future: ref.read(masterDataRepositoryProvider).listCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final categories = snapshot.data!;
          return Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('تصنيف جديد'),
                ),
              ),
              Expanded(
                child:
                    categories.isEmpty
                        ? const Center(child: Text('لا توجد تصنيفات بعد'))
                        : ListView.separated(
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final category = categories[index];
                            return ListTile(
                              title: Text(category.name),
                              trailing: IconButton(
                                tooltip: 'تعديل',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(category),
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );

  Future<void> _edit([Category? category]) async {
    final name = TextEditingController(text: category?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(category == null ? 'تصنيف جديد' : 'تعديل التصنيف'),
            content: TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم التصنيف'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(masterDataRepositoryProvider)
            .saveCategory(id: category?.id, name: name.text);
        ref.read(dataRevisionProvider.notifier).state++;
        setState(() => _revision++);
      } catch (error) {
        if (mounted) CustomSnackBar.showErrorSnackbar('$error');
      }
    }
    name.dispose();
  }
}
