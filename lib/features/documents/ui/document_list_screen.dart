import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key, required this.kind});
  final DocumentKind kind;

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  (IconData, Color) _kindVisual(BuildContext context) => switch (widget.kind) {
        DocumentKind.sale => (Iconsax.receipt_1, context.colors.success),
        DocumentKind.purchase => (Iconsax.shopping_cart, context.colors.secondary),
        DocumentKind.saleReturn => (Iconsax.rotate_left, context.colors.info),
        DocumentKind.purchaseReturn => (Iconsax.undo, context.colors.warning),
        DocumentKind.waste => (Iconsax.warning_2, context.colors.error),
      };

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final compact = MediaQuery.sizeOf(context).width < 900;
    final canDirectCreate = widget.kind == DocumentKind.sale ||
        widget.kind == DocumentKind.purchase ||
        widget.kind == DocumentKind.waste;
    final visual = _kindVisual(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: Text(widget.kind.label)) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'DOCUMENTS',
                title: widget.kind.label,
                subtitle: 'سجل مرتب وواضح للمستندات، مع حالة كل مستند وقيمته وتاريخه.',
                icon: visual.$1,
                actions: [
                  FilledButton.icon(
                    onPressed: () async {
                      if (canDirectCreate) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => NewDocumentScreen(kind: widget.kind)),
                        );
                      } else {
                        await _newReturn(context);
                      }
                      ref.read(dataRevisionProvider.notifier).state++;
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(widget.kind == DocumentKind.saleReturn || widget.kind == DocumentKind.purchaseReturn
                        ? 'مرتجع جديد'
                        : 'مستند جديد'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, Object?>>>(
              future: ref.read(documentRepositoryProvider).listDocuments(widget.kind.dbType),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 360, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل المستندات', subtitle: '${snapshot.error}');
                }
                final query = _search.text.trim().toLowerCase();
                final allRows = snapshot.data ?? const <Map<String, Object?>>[];
                final rows = allRows.where((row) => query.isEmpty ||
                    '${row['display_number']}'.toLowerCase().contains(query) ||
                    '${row['party_name'] ?? ''}'.toLowerCase().contains(query) ||
                    '${row['id']}'.toLowerCase().contains(query)).toList();
                final posted = allRows.where((e) => e['status'] == 'posted').length;
                final drafts = allRows.where((e) => e['status'] == 'draft').length;
                final total = allRows.fold<int>(0, (sum, row) => sum + (((row['final_minor'] ?? row['total_cost_minor'] ?? 0) as num).toInt()));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 720;
                        final width = narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
                        final stats = [
                          ('إجمالي السجل', '${allRows.length}', Icons.description_outlined, visual.$2, 'كل الحالات'),
                          ('المعتمدة', '$posted', Iconsax.tick_circle, context.colors.success, drafts > 0 ? '$drafts مسودة' : 'لا توجد مسودات'),
                          ('القيمة الإجمالية', Money(total).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency), Icons.payments_outlined, context.colors.primary, 'حسب السجل الحالي'),
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
                                  child: MetricCard(label: stats[i].$1, value: stats[i].$2, icon: stats[i].$3, accent: stats[i].$4, caption: stats[i].$5),
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
                                    controller: _search,
                                    hintText: 'بحث برقم المستند أو الطرف…',
                                    onChanged: (_) => setState(() {}),
                                    trailing: _search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () { _search.clear(); setState(() {}); },
                                            icon: const Icon(Iconsax.close_circle, size: 18),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusPill(label: '${rows.length} نتيجة', color: visual.$2, icon: visual.$1),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (rows.isEmpty)
                              EmptyState(
                                title: query.isEmpty ? 'لا توجد مستندات بعد' : 'لا توجد نتائج مطابقة',
                                subtitle: query.isEmpty ? 'أنشئ أول مستند لتبدأ الحركة المحاسبية.' : 'جرّب رقم مستند أو اسم طرف مختلف.',
                                icon: visual.$1,
                              )
                            else
                              ...rows.indexed.map((entry) => _DocumentRow(
                                    row: entry.$2,
                                    kindColor: visual.$2,
                                    kindIcon: visual.$1,
                                    currency: currency,
                                    onTap: () => _showDetails(context, entry.$2['id'] as String, currency),
                                    onVoid: entry.$2['status'] == 'posted'
                                        ? () => _confirmVoid(context, entry.$2['id'] as String)
                                        : null,
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
  Widget _statusIcon(String status) {
    final icon = switch (status) {
      'posted' => Icons.check_circle_outline,
      'void' => Icons.block,
      _ => Icons.edit_note,
    };
    return CircleAvatar(child: Icon(icon));
  }

  String _statusLabel(String status) => switch (status) {
        'posted' => 'معتمد',
        'void' => 'ملغى',
        _ => 'مسودة',
      };

  String _shortDate(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDetails(BuildContext context, String documentId, String currency) async {
    final details = await ref.read(documentRepositoryProvider).documentDetails(widget.kind.dbType, documentId);
    if (!context.mounted) return;
    final header = details['header'] as Map<String, Object?>;
    final items = details['items'] as List<Map<String, Object?>>;
    final shouldPost = header['status'] == 'draft' &&
        (widget.kind == DocumentKind.sale || widget.kind == DocumentKind.purchase);
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${header['invoice_number'] ?? header['return_number'] ?? header['waste_number'] ?? documentId}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(_statusLabel('${header['status']}'))),
                    if (header['final_minor'] != null)
                      Chip(
                        label: Text(
                          Money((header['final_minor'] as num).toInt()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                        ),
                      ),
                    if (header['total_cost_minor'] != null)
                      Chip(
                        label: Text(
                          Money((header['total_cost_minor'] as num).toInt()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((item) {
                  final lineAmount = (item['line_total_minor'] ?? item['cost_amount_minor'] ?? 0) as num;
                  return ListTile(
                    dense: true,
                    title: Text('${item['product_name'] ?? 'منتج'}'),
                    subtitle: Text('${item['quantity']} ${item['unit_name'] ?? ''}'),
                    trailing: Text(
                      Money(lineAmount.toInt()).format(
                        locale: Localizations.localeOf(context).toString(),
                        currencyCode: currency,
                      ),
                    ),
                  );
                }),
                if (header['note'] != null && '${header['note']}'.trim().isNotEmpty) ...[
                  const Divider(),
                  Text('ملاحظات: ${header['note']}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          if (shouldPost)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'post'),
              child: const Text('اعتماد المسودة'),
            ),
        ],
      ),
    );
    if (action != 'post' || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الاعتماد'),
        content: const Text('سيتم إنشاء حركات المخزون والصندوق والذمم محلياً. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (widget.kind == DocumentKind.sale) {
        await ref.read(documentRepositoryProvider).postSale(documentId);
      } else if (widget.kind == DocumentKind.purchase) {
        await ref.read(documentRepositoryProvider).postPurchase(documentId);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد محلياً')));
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmVoid(BuildContext context, String documentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء المستند المعتمد'),
        content: const Text(
          'لن يتم حذف المستند. سيتم إنشاء حركات عكسية للمخزون والصندوق والذمم للحفاظ على سجل التدقيق. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إلغاء وعكس الحركات')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(documentRepositoryProvider).voidDocument(widget.kind.dbType, documentId);
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء المستند وإنشاء الحركات العكسية محلياً')),
        );
      }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _newReturn(BuildContext context) async {
    final originalKind = widget.kind == DocumentKind.saleReturn ? DocumentKind.sale : DocumentKind.purchase;
    final originals = (await ref.read(documentRepositoryProvider).listDocuments(originalKind.dbType))
        .where((row) => row['status'] == 'posted')
        .toList();
    if (!context.mounted) return;
    if (originals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد فواتير معتمدة للإرجاع')));
      return;
    }

    var docId = originals.first['id'] as String;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('اختيار فاتورة ${originalKind.label}'),
          content: SizedBox(
            width: 520,
            child: DropdownButtonFormField<String>(
              value: docId,
              items: originals
                  .map((row) => DropdownMenuItem(
                        value: row['id'] as String,
                        child: Text('${row['display_number']} • ${row['party_name'] ?? ''}'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setLocal(() => docId = value);
              },
              decoration: const InputDecoration(labelText: 'الفاتورة الأصلية'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, docId), child: const Text('التالي')),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final details = await ref.read(documentRepositoryProvider).documentDetails(originalKind.dbType, selected);
    if (!context.mounted) return;
    final items = details['items'] as List<Map<String, Object?>>;
    if (items.isEmpty) return;
    final controllers = {for (final item in items) item['id'] as String: TextEditingController(text: '0')};
    final cashAmount = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إنشاء ${widget.kind.label}'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['product_name'] ?? 'منتج'} • مباع/مشتَرى ${item['quantity']} ${item['unit_name'] ?? ''}',
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: controllers[item['id'] as String],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'كمية الإرجاع'),
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(),
                TextField(
                  controller: cashAmount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.kind == DocumentKind.saleReturn ? 'المبلغ المعاد نقداً' : 'المبلغ المستلم من المورد',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('اعتماد المرتجع')),
        ],
      ),
    );

    if (confirmed == true) {
      final returnLines = <ReturnLineInput>[];
      for (final item in items) {
        final quantity = double.tryParse(controllers[item['id'] as String]!.text.trim()) ?? 0;
        if (quantity <= 0) continue;
        final factor = (item[originalKind == DocumentKind.sale ? 'unit_factor_at_sale' : 'unit_factor_at_purchase'] as num)
            .toDouble();
        returnLines.add(ReturnLineInput(
          originalItemId: item['id'] as String,
          quantity: quantity,
          unitFactor: factor,
        ));
      }
      if (returnLines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية إرجاع لبند واحد على الأقل')));
        }
      } else {
        try {
          final money = Money.fromMajor(cashAmount.text);
          if (widget.kind == DocumentKind.saleReturn) {
            await ref.read(documentRepositoryProvider).postSaleReturn(
                  saleId: selected,
                  items: returnLines,
                  refundedMinor: money,
                );
          } else {
            await ref.read(documentRepositoryProvider).postPurchaseReturn(
                  purchaseId: selected,
                  items: returnLines,
                  receivedMinor: money,
                );
          }
          ref.read(dataRevisionProvider.notifier).state++;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد المرتجع محلياً')));
          }
        } catch (error) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
    cashAmount.dispose();
  }
}


class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.row,
    required this.kindColor,
    required this.kindIcon,
    required this.currency,
    required this.onTap,
    required this.showDivider,
    this.onVoid,
  });

  final Map<String, Object?> row;
  final Color kindColor;
  final IconData kindIcon;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onVoid;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = '${row['status']}';
    final statusColor = status == 'posted' ? colors.success : status == 'void' ? colors.error : colors.warning;
    final statusLabel = status == 'posted' ? 'معتمد' : status == 'void' ? 'ملغى' : 'مسودة';
    final amount = ((row['final_minor'] ?? row['total_cost_minor'] ?? 0) as num).toInt();
    final parsed = DateTime.tryParse('${row['occurred_at']}')?.toLocal();
    final date = parsed == null ? '${row['occurred_at']}' : '${parsed.day}/${parsed.month}/${parsed.year} • ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            onLongPress: onVoid,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: kindColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                    child: Icon(kindIcon, color: kindColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text('${row['display_number']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13))),
                          const SizedBox(width: 8),
                          StatusPill(label: statusLabel, color: statusColor, compact: true),
                        ]),
                        const SizedBox(height: 3),
                        Text('${row['party_name'] ?? 'بدون طرف'} • $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(Money(amount).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_left_rounded, color: colors.textDim, size: 17),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}

