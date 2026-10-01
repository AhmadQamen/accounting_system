import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
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
                        final columns = constraints.maxWidth < 720 ? 2 : 3;
                        final width =
                            (constraints.maxWidth - ((columns - 1) * 12)) /
                            columns;
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

    // Opening a modal directly while desktop Flutter is finalising the pointer
    // update can re-enter MouseTracker. Present it on the next frame instead.
    await WidgetsBinding.instance.endOfFrame;
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
            titlePadding: const EdgeInsetsDirectional.fromSTEB(22, 20, 14, 8),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 8),
            actionsPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.kind.label} • ${header.displayNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'تفاصيل البيع والكلفة والبنود',
                        style: TextStyle(
                          color: context.colors.textDim,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: _statusLabel(header.status),
                  color:
                      header.isPosted
                          ? context.colors.success
                          : header.isVoid
                          ? context.colors.error
                          : context.colors.warning,
                  compact: true,
                ),
              ],
            ),
            content: SizedBox(
              width: responsiveDialogWidth(context, 1040),
              child: _InvoiceDetailsPanel(
                details: details,
                currency: currency,
                documentKind: widget.kind,
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
    final repository = ref.read(documentRepositoryProvider);
    var shortages = const <SaleStockShortage>[];
    if (widget.kind == DocumentKind.sale) {
      try {
        shortages = await repository.saleDraftStockShortages(documentId);
      } catch (error) {
        if (context.mounted) {
          CustomSnackBar.showErrorSnackbar(
            'تعذر التحقق من رصيد المخزون: $error',
          );
        }
        return;
      }
      if (!context.mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              shortages.isEmpty ? 'تأكيد الاعتماد' : 'تنبيه: مخزون غير كافٍ',
            ),
            content: SizedBox(
              width: shortages.isEmpty ? 360 : 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    shortages.isEmpty
                        ? 'سيتم إنشاء حركات المخزون والصندوق والذمم محلياً. هل تريد المتابعة؟'
                        : 'اعتماد هذه الفاتورة سيجعل رصيد المواد التالية سالبًا:',
                  ),
                  if (shortages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final shortage in shortages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${shortage.productName}: المتاح '
                          '${shortage.availableBaseQuantity.toStringAsFixed(2)}، '
                          'المطلوب ${shortage.requestedBaseQuantity.toStringAsFixed(2)}، '
                          'الرصيد الجديد ${shortage.resultingBaseQuantity.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: context.colors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(shortages.isEmpty ? 'اعتماد' : 'بيع رغم النقص'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      if (widget.kind == DocumentKind.sale) {
        await repository.postSale(
          documentId,
          allowNegativeStock: shortages.isNotEmpty,
        );
      } else if (widget.kind == DocumentKind.purchase) {
        await repository.postPurchase(documentId);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) {
        CustomSnackBar.showSuccessSnackbar('تم الاعتماد محلياً');
      }
    } catch (error) {
      if (context.mounted) {
        CustomSnackBar.showErrorSnackbar('$error');
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
        CustomSnackBar.showSuccessSnackbar(
          'تم إلغاء المستند وإنشاء الحركات العكسية محلياً',
        );
      }
    } catch (error) {
      if (context.mounted) {
        CustomSnackBar.showErrorSnackbar('$error');
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
      CustomSnackBar.showWarningSnackbar('لا توجد فواتير معتمدة للإرجاع');
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
          CustomSnackBar.showWarningSnackbar(
            'أدخل كمية إرجاع لبند واحد على الأقل',
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
            CustomSnackBar.showSuccessSnackbar('تم اعتماد المرتجع محلياً');
          }
        } catch (error) {
          if (context.mounted) {
            CustomSnackBar.showErrorSnackbar('$error');
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

class _InvoiceDetailsPanel extends StatelessWidget {
  const _InvoiceDetailsPanel({
    required this.details,
    required this.currency,
    required this.documentKind,
  });

  final DocumentDetails details;
  final String currency;
  final DocumentKind documentKind;

  String _date(DateTime? value) {
    if (value == null) return 'غير محدد';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} • ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final header = details.header;
    final colors = context.colors;
    final saleLabel = switch (documentKind) {
      DocumentKind.purchase => 'إجمالي الشراء',
      DocumentKind.saleReturn => 'قيمة المرتجع',
      DocumentKind.purchaseReturn => 'قيمة المرتجع',
      DocumentKind.waste => 'قيمة التالف',
      _ => 'إجمالي البيع',
    };
    final margin = header.finalMinor - header.totalCostMinor;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        primary: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: compact ? 2 : 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: compact ? 2.35 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DocumentInfoChip(
                      icon: Icons.warehouse_outlined,
                      label: 'المستودع',
                      value: details.warehouseName ?? 'غير محدد',
                    ),
                    _DocumentInfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'التاريخ',
                      value: _date(header.postedAt ?? header.occurredAt),
                    ),
                    _DocumentInfoChip(
                      icon: Icons.person_outline_rounded,
                      label: 'الطرف',
                      value: header.partyName ?? 'بيع نقدي',
                    ),
                    _DocumentInfoChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'الصندوق',
                      value: details.cashboxName ?? 'غير محدد',
                    ),
                  ],
                ),
                if (header.currencyCode != null &&
                    header.currencyCode != currency &&
                    header.foreignFinalMinor != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .18),
                      ),
                    ),
                    child: Text(
                      'عملة الفاتورة: ${Money(header.foreignFinalMinor!).format(locale: Localizations.localeOf(context).toString(), currencyCode: header.currencyCode!)}'
                      ' • المقابل المثبت: ${_money(context, header.finalMinor)}'
                      ' • السعر ${CurrencyMath.formatRateMicros(header.exchangeRateMicros)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'ملخص الفاتورة',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 9),
                GridView.count(
                  crossAxisCount: compact ? 2 : 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: compact ? 2.25 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DocumentSummaryCard(
                      label: saleLabel,
                      value: header.displayTotalMinor,
                      currency: currency,
                      color: colors.primary,
                      icon: Icons.receipt_long_outlined,
                    ),
                    _DocumentSummaryCard(
                      label: 'إجمالي الكلفة',
                      value: header.totalCostMinor,
                      currency: currency,
                      color: colors.warning,
                      icon: Icons.inventory_2_outlined,
                    ),
                    _DocumentSummaryCard(
                      label: 'الهامش',
                      value: margin,
                      currency: currency,
                      color: margin >= 0 ? colors.success : colors.error,
                      icon: Icons.insights_outlined,
                    ),
                    _DocumentSummaryCard(
                      label: 'المدفوع / المقبوض',
                      value: header.paidMinor,
                      currency: currency,
                      color: colors.info,
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                if (header.discountMinor > 0 || header.refundedMinor > 0) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (header.discountMinor > 0)
                        StatusPill(
                          label: 'خصم ${_money(context, header.discountMinor)}',
                          color: colors.warning,
                          compact: true,
                        ),
                      if (header.refundedMinor > 0)
                        StatusPill(
                          label:
                              'مرتجع نقدي ${_money(context, header.refundedMinor)}',
                          color: colors.error,
                          compact: true,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'بنود الفاتورة',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${details.items.length} بند',
                      style: TextStyle(color: colors.textDim, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (details.items.isEmpty)
                  _EmptyInvoiceItems()
                else if (compact)
                  ...details.items.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InvoiceItemCard(line: line, currency: currency),
                    ),
                  )
                else
                  _InvoiceItemsTable(items: details.items, currency: currency),
                if (header.note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  _InvoiceNote(note: header.note!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _money(BuildContext context, int value) => Money(value).format(
    locale: Localizations.localeOf(context).toString(),
    currencyCode: currency,
  );
}

class _DocumentInfoChip extends StatelessWidget {
  const _DocumentInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.primary.withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: colors.primary),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textDim, fontSize: 9),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSummaryCard extends StatelessWidget {
  const _DocumentSummaryCard({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    required this.icon,
  });
  final String label;
  final int value;
  final String currency;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .075),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: .20)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.textDim, fontSize: 9),
              ),
              const SizedBox(height: 2),
              Text(
                Money(value).format(
                  locale: Localizations.localeOf(context).toString(),
                  currencyCode: currency,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InvoiceItemsTable extends StatelessWidget {
  const _InvoiceItemsTable({required this.items, required this.currency});
  final List<DocumentLine> items;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colors.surface.withValues(alpha: .46),
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const _InvoiceTableHeader(),
        for (var index = 0; index < items.length; index++) ...[
          _InvoiceTableLine(line: items[index], currency: currency),
          if (index != items.length - 1)
            Divider(height: 1, color: context.colors.border),
        ],
      ],
    ),
  );
}

class _InvoiceTableHeader extends StatelessWidget {
  const _InvoiceTableHeader();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.colors.primary.withValues(alpha: .09),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
    ),
    child: const Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'البند',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            'الكمية',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            'سعر البيع',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            'الكلفة',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            'الإجمالي',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _InvoiceTableLine extends StatelessWidget {
  const _InvoiceTableLine({required this.line, required this.currency});
  final DocumentLine line;
  final String currency;

  String _quantity(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
  String _money(BuildContext context, int value) => Money(value).format(
    locale: Localizations.localeOf(context).toString(),
    currencyCode: currency,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.productName ?? 'منتج',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                line.unitName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: context.colors.textDim),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            '${_quantity(line.quantity)} ${line.unitName ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            _money(context, line.unitPriceMinor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _money(context, line.unitCostMinor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _money(
              context,
              line.lineTotalMinor != 0
                  ? line.lineTotalMinor
                  : line.costAmountMinor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _InvoiceItemCard extends StatelessWidget {
  const _InvoiceItemCard({required this.line, required this.currency});
  final DocumentLine line;
  final String currency;

  String _money(BuildContext context, int value) => Money(value).format(
    locale: Localizations.localeOf(context).toString(),
    currencyCode: currency,
  );
  String _quantity(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: context.colors.surface.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.productName ?? 'منتج',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          '${_quantity(line.quantity)} ${line.unitName ?? ''}',
          style: TextStyle(color: context.colors.textDim, fontSize: 11),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ItemMetric(
                label: 'سعر البيع',
                value: _money(context, line.unitPriceMinor),
                color: context.colors.primary,
              ),
            ),
            Expanded(
              child: _ItemMetric(
                label: 'الكلفة',
                value: _money(context, line.unitCostMinor),
                color: context.colors.warning,
              ),
            ),
            Expanded(
              child: _ItemMetric(
                label: 'الإجمالي',
                value: _money(
                  context,
                  line.lineTotalMinor != 0
                      ? line.lineTotalMinor
                      : line.costAmountMinor,
                ),
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ItemMetric extends StatelessWidget {
  const _ItemMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: context.colors.textDim, fontSize: 9)),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _EmptyInvoiceItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 34),
    decoration: BoxDecoration(
      color: context.colors.surface.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      children: [
        Icon(Icons.inventory_2_outlined, color: context.colors.textDim),
        const SizedBox(height: 8),
        Text(
          'لا توجد بنود في هذه الفاتورة',
          style: TextStyle(color: context.colors.textDim, fontSize: 12),
        ),
      ],
    ),
  );
}

class _InvoiceNote extends StatelessWidget {
  const _InvoiceNote({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.info.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.info.withValues(alpha: .22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.notes_rounded, size: 18, color: context.colors.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            note,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 12),
          ),
        ),
      ],
    ),
  );
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
