import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/ui/product_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: const Text('المنتجات')) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'CATALOG',
                title: 'دليل المنتجات',
                subtitle: 'إدارة الأصناف والوحدات والباركود من مكان واحد.',
                icon: Iconsax.box,
                actions: [
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('منتج جديد'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 70),
              child: PremiumPanel(
                padding: const EdgeInsets.all(14),
                child: PremiumSearchField(
                  controller: search,
                  hintText: 'ابحث باسم المنتج أو الباركود…',
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
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, Object?>>>(
              future: ref.read(masterDataRepositoryProvider).listProducts(search: search.text),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل المنتجات', subtitle: '${snapshot.error}');
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                if (rows.isEmpty) {
                  return EmptyState(
                    title: search.text.trim().isEmpty ? 'لا توجد منتجات بعد' : 'لا توجد نتائج مطابقة',
                    subtitle: search.text.trim().isEmpty
                        ? 'ابدأ بإضافة أول منتج، ثم أضف وحداته وباركوداته.'
                        : 'جرّب البحث بكلمة مختلفة أو امسح حقل البحث.',
                    icon: Iconsax.box,
                    action: search.text.trim().isEmpty
                        ? FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('إضافة منتج'))
                        : null,
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1180 ? 4 : width >= 820 ? 3 : width >= 560 ? 2 : 1;
                    final cardWidth = (width - ((columns - 1) * 12)) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          SizedBox(
                            width: cardWidth,
                            height: 154,
                            child: AnimatedEntrance(
                              delay: Duration(milliseconds: 100 + ((i % 8) * 30)),
                              child: _ProductCard(
                                product: rows[i],
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => ProductDetailsDialog(product: rows[i]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'قطعة');
    final barcode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: context.colors.primary),
            const SizedBox(width: 10),
            const Text('منتج جديد'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المنتج', prefixIcon: Icon(Iconsax.box))),
              const SizedBox(height: 10),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة الرئيسية', prefixIcon: Icon(Icons.straighten_outlined))),
              const SizedBox(height: 10),
              TextField(controller: barcode, decoration: const InputDecoration(labelText: 'الباركود (اختياري)', prefixIcon: Icon(Icons.qr_code_scanner_outlined))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Iconsax.tick_circle, size: 17), label: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(masterDataRepositoryProvider).createProduct(
            name: name.text,
            primaryUnitName: unit.text,
            barcode: barcode.text,
          );
      ref.read(dataRevisionProvider.notifier).state++;
    }
    name.dispose();
    unit.dispose();
    barcode.dispose();
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});
  final Map<String, Object?> product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final minQty = ((product['min_quantity'] as num?) ?? 0).toDouble();
    final name = '${product['name']}';
    final initials = name.trim().isEmpty ? '؟' : name.trim().substring(0, 1);
    return PremiumPanel(
      onTap: onTap,
      hoverLift: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colors.primary.withValues(alpha: .18), colors.secondary.withValues(alpha: .18)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary.withValues(alpha: .16)),
                ),
                child: Text(initials, style: TextStyle(color: colors.primary, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Icon(Icons.chevron_left_rounded, size: 17, color: colors.textDim),
            ],
          ),
          const Spacer(),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${product['category_name'] ?? 'بدون تصنيف'} • ${product['primary_unit_name'] ?? 'وحدة'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Iconsax.warning_2, size: 13, color: minQty > 0 ? colors.warning : colors.textDim),
              const SizedBox(width: 5),
              Text(
                minQty > 0 ? 'حد أدنى ${_qty(minQty)}' : 'بدون حد أدنى',
                style: TextStyle(color: minQty > 0 ? colors.warning : colors.textDim, fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _qty(double value) => value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}
