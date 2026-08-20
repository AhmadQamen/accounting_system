import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
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
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);
    final canDirectCreate =
        widget.kind == DocumentKind.sale ||
        widget.kind == DocumentKind.purchase ||
        widget.kind == DocumentKind.waste;
    final visual = _kindVisual(context);

    return MyScaffold(
      appBar: compact ? BlurAppBar(title: Text(widget.kind.label)) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'DOCUMENTS',
                title: widget.kind.label,
                subtitle:
                    'سجل مرتب وواضح للمستندات، مع حالة كل مستند وقيمته وتاريخه.',
                icon: visual.$1,
                actions: [
                  FilledButton.icon(
                    onPressed: () async {
                      if (canDirectCreate) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => NewDocumentScreen(kind: widget.kind),
                          ),
                        );
                      } else {
                        await _newReturn(context);
                      }
                      ref.read(dataRevisionProvider.notifier).state++;
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      widget.kind == DocumentKind.saleReturn ||
                              widget.kind == DocumentKind.purchaseReturn
                          ? 'مرتجع جديد'
                          : 'مستند جديد',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<AccountingDocument>>(
              future: ref
                  .read(documentRepositoryProvider)
                  .listDocuments(widget.kind.dbType),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 360,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر تحميل المستندات',
                    subtitle: '${snapshot.error}',
                  );
                }

                final query = _search.text.trim().toLowerCase();
                final allDocuments =
                    snapshot.data ?? const <AccountingDocument>[];
                final documents = allDocuments
                    .where((document) {
                      if (query.isEmpty) return true;
                      return document.displayNumber.toLowerCase().contains(
                            query,
                          ) ||
                          (document.partyName ?? '').toLowerCase().contains(
                            query,
                          ) ||
                          (document.id ?? '').toLowerCase().contains(query);
                    })
                    .toList(growable: false);
                final posted = allDocuments.where((e) => e.isPosted).length;
                final drafts = allDocuments.where((e) => e.isDraft).length;
                final total = allDocuments.fold<int>(
                  0,
                  (sum, document) => sum + document.displayTotalMinor,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 720;
                        final width =
                            narrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 3;
                        final stats = [
                          (
                            'إجمالي السجل',
                            '${allDocuments.length}',
                            Icons.description_outlined,
                            visual.$2,
                            'كل الحالات',
                          ),
                          (
                            'المعتمدة',
                            '$posted',
                            Iconsax.tick_circle,
                            context.colors.success,
                            drafts > 0 ? '$drafts مسودة' : 'لا توجد مسودات',
                          ),
                          (
                            'القيمة الإجمالية',
                            Money(total).format(
                              locale:
                                  Localizations.localeOf(context).toString(),
                              currencyCode: currency,
                            ),
                            Icons.payments_outlined,
                            context.colors.primary,
                            'حسب السجل الحالي',
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < stats.length; i++)
                              SizedBox(
                                width: width,
                                child: AnimatedEntrance(
                                  delay: Duration(milliseconds: 60 + i * 35),
                                  child: MetricCard(
                                    label: stats[i].$1,
                                    value: stats[i].$2,
                                    icon: stats[i].$3,
                                    accent: stats[i].$4,
                                    caption: stats[i].$5,
                                  ),
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final field = PremiumSearchField(
                                  controller: _search,
                                  hintText: 'بحث برقم المستند أو الطرف…',
                                  onChanged: (_) => setState(() {}),
                                  trailing:
                                      _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                            onPressed: () {
                                              _search.clear();
                                              setState(() {});
                                            },
                                            icon: const Icon(
                                              Iconsax.close_circle,
                                              size: 18,
                                            ),
                                          ),
                                );
                                final count = StatusPill(
                                  label: '${documents.length} نتيجة',
                                  color: visual.$2,
                                  icon: visual.$1,
                                );
                                if (constraints.maxWidth < 500) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      field,
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: count,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(child: field),
                                    const SizedBox(width: 10),
                                    count,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            if (documents.isEmpty)
                              EmptyState(
                                title:
                                    query.isEmpty
                                        ? 'لا توجد مستندات بعد'
                                        : 'لا توجد نتائج مطابقة',
                                subtitle:
                                    query.isEmpty
                                        ? 'أنشئ أول مستند لتبدأ الحركة المحاسبية.'
                                        : 'جرّب رقم مستند أو اسم طرف مختلف.',
                                icon: visual.$1,
                              )
                            else
                              ...documents.indexed.map(
                                (entry) => _DocumentRow(
                                  document: entry.$2,
                                  kindColor: visual.$2,
                                  kindIcon: visual.$1,
                                  currency: currency,
                                  onTap: () {
                                    final id = entry.$2.id;
                                    if (id != null) {
                                      _showDetails(context, id, currency);
                                    }
                                  },
                                  onVoid:
                                      entry.$2.isPosted && entry.$2.id != null
                                          ? () => _confirmVoid(
                                            context,
                                            entry.$2.id!,
                                          )
                                          : null,
                                  showDivider: entry.$1 != documents.length - 1,
                                ),
                              ),
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

  String _statusLabel(String status) => switch (status) {
    'posted' => 'معتمد',
    'void' => 'ملغى',
    _ => 'مسودة',
  };

  Future<void> _showDetails(
    BuildContext context,
    String documentId,
    String currency,
  ) async {
    final details = await ref
        .read(documentRepositoryProvider)
        .documentDetails(widget.kind.dbType, documentId);
    if (!context.mounted) return;

    final header = details.header;
    final shouldPost =
        header.isDraft &&
        (widget.kind == DocumentKind.sale ||
            widget.kind == DocumentKind.purchase);
    final action = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${widget.kind.label} • ${header.displayNumber}'),
            content: SizedBox(
              width: responsiveDialogWidth(context, 720),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label: _statusLabel(header.status),
                          color:
                              header.isPosted
                                  ? context.colors.success
                                  : header.isVoid
                                  ? context.colors.error
                                  : context.colors.warning,
                        ),
                        if (header.partyName != null)
                          StatusPill(
                            label: header.partyName!,
                            color: context.colors.info,
                            icon: Icons.person_outline_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < details.items.length; i++) ...[
                      _DetailLine(line: details.items[i], currency: currency),
                      if (i != details.items.length - 1)
                        const Divider(height: 1),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    _DetailAmount(
                      label: 'الإجمالي',
                      value: header.displayTotalMinor,
                      currency: currency,
                      emphasized: true,
                    ),
                    if (header.discountMinor > 0)
                      _DetailAmount(
                        label: 'الخصم',
                        value: header.discountMinor,
                        currency: currency,
                      ),
                    if (header.paidMinor > 0)
                      _DetailAmount(
                        label: 'المدفوع/المقبوض',
                        value: header.paidMinor,
                        currency: currency,
                      ),
                    if (header.refundedMinor > 0)
                      _DetailAmount(
                        label: 'المبلغ النقدي المرتجع',
                        value: header.refundedMinor,
                        currency: currency,
                      ),
                    if (header.note?.trim().isNotEmpty == true) ...[
                      const Divider(),
                      Text('ملاحظات: ${header.note}'),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
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
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('تأكيد الاعتماد'),
            content: const Text(
              'سيتم إنشاء حركات المخزون والصندوق والذمم محلياً. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('اعتماد'),
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الاعتماد محلياً')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _confirmVoid(BuildContext context, String documentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('إلغاء المستند المعتمد'),
            content: const Text(
              'لن يتم حذف المستند. سيتم إنشاء حركات عكسية للمخزون والصندوق والذمم للحفاظ على سجل التدقيق. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إلغاء وعكس الحركات'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(documentRepositoryProvider)
          .voidDocument(widget.kind.dbType, documentId);
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء المستند وإنشاء الحركات العكسية محلياً'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _newReturn(BuildContext context) async {
    final originalKind =
        widget.kind == DocumentKind.saleReturn
            ? DocumentKind.sale
            : DocumentKind.purchase;
    final originals = (await ref
            .read(documentRepositoryProvider)
            .listDocuments(originalKind.dbType))
        .where((document) => document.isPosted && document.id != null)
        .toList(growable: false);
    if (!context.mounted) return;

    if (originals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فواتير معتمدة للإرجاع')),
      );
      return;
    }

    var documentId = originals.first.id!;
    final selected = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: Text('اختيار فاتورة ${originalKind.label}'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 520),
                    child: DropdownButtonFormField<String>(
                      value: documentId,
                      items:
                          originals
                              .map(
                                (document) => DropdownMenuItem(
                                  value: document.id!,
                                  child: Text(
                                    '${document.displayNumber} • ${document.partyName ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) setLocal(() => documentId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'الفاتورة الأصلية',
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, documentId),
                      child: const Text('التالي'),
                    ),
                  ],
                ),
          ),
    );
    if (selected == null || !context.mounted) return;

    final details = await ref
        .read(documentRepositoryProvider)
        .documentDetails(originalKind.dbType, selected);
    if (!context.mounted || details.items.isEmpty) return;

    final controllers = <String, TextEditingController>{};
    for (final item in details.items) {
      if (item.id != null) {
        controllers[item.id!] = TextEditingController(text: '0');
      }
    }
    if (controllers.isEmpty) return;

    final cashAmount = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('إنشاء ${widget.kind.label}'),
            content: SizedBox(
              width: responsiveDialogWidth(context, 680),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in details.items)
                      if (item.id != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final product = Text(
                                '${item.productName ?? 'منتج'} • مباع/مشتَرى ${_quantity(item.quantity)} ${item.unitName ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                              final quantity = TextField(
                                controller: controllers[item.id!],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'كمية الإرجاع',
                                ),
                              );
                              if (constraints.maxWidth < 430) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    product,
                                    const SizedBox(height: 8),
                                    quantity,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: product),
                                  const SizedBox(width: 12),
                                  SizedBox(width: 150, child: quantity),
                                ],
                              );
                            },
                          ),
                        ),
                    const Divider(),
                    TextField(
                      controller: cashAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            widget.kind == DocumentKind.saleReturn
                                ? 'المبلغ المعاد نقداً'
                                : 'المبلغ المستلم من المورد',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('اعتماد المرتجع'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final returnLines = <ReturnLineInput>[];
      for (final item in details.items) {
        final id = item.id;
        if (id == null) continue;
        final controller = controllers[id];
        if (controller == null) continue;
        final quantity = double.tryParse(controller.text.trim()) ?? 0;
        if (quantity <= 0) continue;
        returnLines.add(
          ReturnLineInput(
            originalItemId: id,
            quantity: quantity,
            unitFactor: item.unitFactor,
          ),
        );
      }

      if (returnLines.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('أدخل كمية إرجاع لبند واحد على الأقل'),
            ),
          );
        }
      } else {
        try {
          final cashMinor = Money.fromMajor(cashAmount.text);
          if (widget.kind == DocumentKind.saleReturn) {
            await ref
                .read(documentRepositoryProvider)
                .postSaleReturn(
                  saleId: selected,
                  items: returnLines,
                  refundedMinor: cashMinor,
                );
          } else {
            await ref
                .read(documentRepositoryProvider)
                .postPurchaseReturn(
                  purchaseId: selected,
                  items: returnLines,
                  receivedMinor: cashMinor,
                );
          }
          ref.read(dataRevisionProvider.notifier).state++;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم اعتماد المرتجع محلياً')),
            );
          }
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$error')));
          }
        }
      }
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }
    cashAmount.dispose();
  }

  String _quantity(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.line, required this.currency});

  final DocumentLine line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final amount =
        line.lineTotalMinor != 0 ? line.lineTotalMinor : line.costAmountMinor;
    final amountText = Money(amount).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final quantity =
        line.quantity.truncateToDouble() == line.quantity
            ? line.quantity.toStringAsFixed(0)
            : line.quantity.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.productName ?? 'منتج',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '$quantity ${line.unitName ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.textDim, fontSize: 11),
              ),
            ],
          );
          final amountWidget = Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          );
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 5), amountWidget],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 10),
              Flexible(child: amountWidget),
            ],
          );
        },
      ),
    );
  }
}

class _DetailAmount extends StatelessWidget {
  const _DetailAmount({
    required this.label,
    required this.value,
    required this.currency,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              Money(value).format(
                locale: Localizations.localeOf(context).toString(),
                currencyCode: currency,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
                color: emphasized ? context.colors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.kindColor,
    required this.kindIcon,
    required this.currency,
    required this.onTap,
    required this.showDivider,
    this.onVoid,
  });

  final AccountingDocument document;
  final Color kindColor;
  final IconData kindIcon;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onVoid;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor =
        document.isPosted
            ? colors.success
            : document.isVoid
            ? colors.error
            : colors.warning;
    final statusLabel =
        document.isPosted
            ? 'معتمد'
            : document.isVoid
            ? 'ملغى'
            : 'مسودة';
    final parsed = document.occurredAt?.toLocal();
    final date =
        parsed == null
            ? '-'
            : '${parsed.day}/${parsed.month}/${parsed.year} • ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    final amountText = Money(document.displayTotalMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );

    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: kindColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(kindIcon, color: kindColor, size: 20),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              document.displayNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            StatusPill(label: statusLabel, color: statusColor, compact: true),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${document.partyName ?? 'بدون طرف'} • $date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textDim, fontSize: 10.5),
        ),
      ],
    );

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            icon,
                            const SizedBox(width: 12),
                            Expanded(child: identity),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: colors.textDim,
                              size: 17,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 54),
                          child: Text(
                            amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: identity),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          amountText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_left_rounded,
                        color: colors.textDim,
                        size: 17,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}
