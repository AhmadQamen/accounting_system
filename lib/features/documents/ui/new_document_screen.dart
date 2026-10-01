import 'dart:async';

import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/keyboard/keyboard_context.dart';
import 'package:accounting_system/core/keyboard/keyboard_action.dart';
import 'package:accounting_system/core/keyboard/keyboard_manager.dart';
import 'package:accounting_system/core/keyboard/keyboard_provider.dart';
import 'package:accounting_system/core/shortcuts/invoice_shortcut_macro_notifier.dart';
import 'package:accounting_system/core/shortcuts/shortcut_provider.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

enum DocumentKind { sale, purchase, saleReturn, purchaseReturn, waste }

/// Opens the document workspace over the current page. Keeping creation in a
/// dialog preserves the caller's navigation stack (especially on mobile).
Future<void> showNewDocumentDialog(
  BuildContext context, {
  required DocumentKind kind,
  Future<void> Function(BuildContext context)? onExpenseRequested,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final fullScreen = size.width < 700 || size.height < 620;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: fullScreen ? 0 : 24,
          vertical: fullScreen ? 0 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: fullScreen ? size.width : 1180,
          height: fullScreen ? size.height : size.height * .88,
          child: Stack(
            children: [
              Positioned.fill(
                child: NewDocumentScreen(
                  kind: kind,
                  embedded: true,
                  onExpenseRequested: onExpenseRequested,
                ),
              ),
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton.filledTonal(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

extension DocumentKindX on DocumentKind {
  String get dbType => switch (this) {
    DocumentKind.sale => 'sale',
    DocumentKind.purchase => 'purchase',
    DocumentKind.saleReturn => 'sale_return',
    DocumentKind.purchaseReturn => 'purchase_return',
    DocumentKind.waste => 'waste',
  };

  String get label => switch (this) {
    DocumentKind.sale => 'بيع',
    DocumentKind.purchase => 'شراء',
    DocumentKind.saleReturn => 'مرتجع بيع',
    DocumentKind.purchaseReturn => 'مرتجع شراء',
    DocumentKind.waste => 'هالك',
  };
}

class NewDocumentScreen extends StatefulWidget {
  const NewDocumentScreen({
    super.key,
    required this.kind,
    this.embedded = false,
    this.onExpenseRequested,
  });

  final DocumentKind kind;
  final bool embedded;
  final Future<void> Function(BuildContext context)? onExpenseRequested;

  @override
  State<NewDocumentScreen> createState() => _NewDocumentScreenState();
}

class _NewDocumentScreenState extends State<NewDocumentScreen> {
  final List<_InvoiceWorkspaceTab> _tabs = [];
  int _activeIndex = 0;
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _tabs.add(_createTab());
  }

  _InvoiceWorkspaceTab _createTab([DocumentKind? kind]) {
    final id = _nextId++;
    return _InvoiceWorkspaceTab(id: id, serial: id, kind: kind ?? widget.kind);
  }

  void _selectDocumentKind(DocumentKind kind) {
    if (kind == DocumentKind.saleReturn ||
        kind == DocumentKind.purchaseReturn) {
      AppNavigation.open(
        AppRoute(
          type:
              kind == DocumentKind.saleReturn
                  ? RouteType.saleReturns
                  : RouteType.purchaseReturns,
        ),
      );
      return;
    }
    setState(() {
      _tabs.add(_createTab(kind));
      _activeIndex = _tabs.length - 1;
    });
  }

  void _setDirty(int id, bool dirty) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0 || _tabs[index].dirty == dirty) return;
    setState(() => _tabs[index].dirty = dirty);
  }

  Future<void> _requestClose(int index) async {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (tab.dirty) {
      final discard = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .34),
        builder: (context) => const _DiscardInvoiceDialog(),
      );
      if (discard != true || !mounted) return;
    }
    _removeAt(index);
  }

  void _completeTab(int id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index >= 0) _removeAt(index);
  }

  void _removeAt(int index) {
    setState(() {
      if (_tabs.length == 1) {
        _tabs[0] = _createTab();
        _activeIndex = 0;
        return;
      }
      _tabs.removeAt(index);
      if (_activeIndex > index) {
        _activeIndex--;
      } else if (_activeIndex >= _tabs.length) {
        _activeIndex = _tabs.length - 1;
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_tabs.length > 1) {
      await _requestClose(_activeIndex);
      return false;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('مغادرة الفاتورة؟'),
            content: const Text('سيتم إغلاق شاشة الفاتورة الحالية.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('البقاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('مغادرة'),
              ),
            ],
          ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final workspace = PremiumBackdrop(
      child: ColoredBox(
        // Keep invoice surfaces readable while preserving the same shared
        // ledger canvas visible behind every feature page.
        color: colors.bgPage.withValues(alpha: .14),
        child: Column(
          children: [
            _InvoiceTabsBar(
              tabs: _tabs,
              activeIndex: _activeIndex,
              onSelected: (index) => setState(() => _activeIndex = index),
              onClose: _requestClose,
              onKindSelected: _selectDocumentKind,
              onExpenseRequested: widget.onExpenseRequested,
            ),
            Expanded(
              child: IndexedStack(
                index: _activeIndex,
                children: [
                  for (final tab in _tabs)
                    _InvoiceEditor(
                      key: ValueKey('invoice-editor-${tab.id}'),
                      kind: tab.kind,
                      embedded: true,
                      onDirtyChanged: (dirty) => _setDirty(tab.id, dirty),
                      onSaved: () => _completeTab(tab.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.embedded) {
      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(body: workspace),
      );
    }
    return WillPopScope(
      onWillPop: _onWillPop,
      child: MyScaffold(body: workspace),
    );
  }
}

class _InvoiceWorkspaceTab {
  _InvoiceWorkspaceTab({
    required this.id,
    required this.serial,
    required this.kind,
  });

  final int id;
  final int serial;
  final DocumentKind kind;
  bool dirty = false;

  String get title =>
      kind == DocumentKind.waste
          ? 'مستند هالك $serial'
          : 'فاتورة ${kind.label} $serial';
}

class _InvoiceTabsBar extends StatelessWidget {
  const _InvoiceTabsBar({
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
    required this.onClose,
    required this.onKindSelected,
    this.onExpenseRequested,
  });

  final List<_InvoiceWorkspaceTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onClose;
  final ValueChanged<DocumentKind> onKindSelected;
  final Future<void> Function(BuildContext context)? onExpenseRequested;

  Future<void> _showDocumentKindPicker(BuildContext context) async {
    final selected = await showDialog<DocumentKind>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Iconsax.document_text_1,
                        color: colors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إنشاء مستند جديد',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'اختر نوع العملية التي تريد تسجيلها',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth =
                        constraints.maxWidth < 440
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final kind in DocumentKind.values)
                          _DocumentKindChoice(
                            kind: kind,
                            width: cardWidth,
                            onTap: () => Navigator.pop(dialogContext, kind),
                          ),
                        if (onExpenseRequested != null)
                          SizedBox(
                            width: cardWidth,
                            height: 82,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onExpenseRequested!(context);
                              },
                              icon: Icon(
                                Iconsax.money_send,
                                color: colors.error,
                              ),
                              label: const Text('مصروف'),
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
      },
    );
    if (selected != null) onKindSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      height: compact ? 58 : 70,
      padding: EdgeInsetsDirectional.fromSTEB(
        compact ? 10 : 16,
        7,
        compact ? 8 : 14,
        7,
      ),
      decoration: BoxDecoration(
        color: colors.bgPage.withValues(alpha: .58),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Material(
            color: colors.primary.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showDocumentKindPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: compact ? 42 : 48,
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: colors.primary, size: 20),
                    if (!compact) ...[
                      const SizedBox(width: 7),
                      Text(
                        'مستند جديد',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final active = index == activeIndex;
                return Material(
                  color: colors.bgElevated.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelected(index),
                    child: Container(
                      width: compact ? 142 : 205,
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        end: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              active
                                  ? colors.primary.withValues(alpha: .35)
                                  : colors.border,
                        ),
                        boxShadow:
                            active
                                ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: .08,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                                : null,
                      ),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      tab.dirty
                                          ? colors.secondary
                                          : active
                                          ? colors.success
                                          : colors.textDim,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${1000 + tab.serial}',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (!compact)
                                      Text(
                                        tab.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'إغلاق',
                                visualDensity: VisualDensity.compact,
                                splashRadius: 15,
                                onPressed: () => onClose(index),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textDim,
                                ),
                              ),
                            ],
                          ),
                          if (active)
                            PositionedDirectional(
                              start: 0,
                              end: 0,
                              bottom: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentKindChoice extends StatelessWidget {
  const _DocumentKindChoice({
    required this.kind,
    required this.width,
    required this.onTap,
  });

  final DocumentKind kind;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, accent, description) = switch (kind) {
      DocumentKind.sale => (
        Iconsax.receipt_add,
        colors.primary,
        'تسجيل مبيعات وقبض',
      ),
      DocumentKind.purchase => (
        Iconsax.shopping_cart,
        colors.success,
        'تسجيل مشتريات ودفع',
      ),
      DocumentKind.saleReturn => (
        Iconsax.undo,
        colors.secondary,
        'إرجاع فاتورة بيع',
      ),
      DocumentKind.purchaseReturn => (
        Iconsax.redo,
        colors.secondary,
        'إرجاع فاتورة شراء',
      ),
      DocumentKind.waste => (Iconsax.trash, colors.error, 'تسجيل مواد تالفة'),
    };
    final title =
        kind == DocumentKind.waste ? 'مستند هالك' : 'فاتورة ${kind.label}';
    return SizedBox(
      width: width,
      child: Material(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: .20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(color: colors.textDim, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: accent.withValues(alpha: .75),
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscardInvoiceDialog extends StatelessWidget {
  const _DiscardInvoiceDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.bgElevated,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Iconsax.warning_2, color: colors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'إغلاق مسودة الفاتورة؟',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'تحتوي هذه الفاتورة على تعديلات غير محفوظة. سيتم فقدها عند الإغلاق.',
                style: TextStyle(color: colors.textSecondary, height: 1.55),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('متابعة التحرير'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('إغلاق وتجاهل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceEditor extends ConsumerStatefulWidget {
  const _InvoiceEditor({
    super.key,
    required this.kind,
    this.embedded = false,
    this.onDirtyChanged,
    this.onSaved,
  });

  final DocumentKind kind;
  final bool embedded;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onSaved;

  @override
  ConsumerState<_InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends ConsumerState<_InvoiceEditor> {
  final _documentDiscount = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _note = TextEditingController();
  final List<_DraftLine> _lines = [];
  late final Future<_EditorData> _editorData;
  late final KeyboardManager _keyboardManager;
  late final InvoiceShortcutMacroNotifier _invoiceMacros;

  String? _warehouseId;
  String? _partyId;
  String? _cashboxId;
  String? _currencyCode;
  int _exchangeRateMicros = CurrencyMath.rateScale;
  String? _equivalentCurrencyCode;
  int _equivalentRateMicros = CurrencyMath.rateScale;
  bool _selectedCurrencyIsBase = true;
  bool _saving = false;
  bool _dirty = false;
  String? _draftId;
  Timer? _autoSaveTimer;
  Future<void>? _activeAutoSave;
  bool _autoSaveInProgress = false;
  bool _autoSaveQueued = false;
  String _autoSaveLabel = 'يحفظ تلقائياً';

  bool get _isPurchase => widget.kind == DocumentKind.purchase;
  bool get _isWaste => widget.kind == DocumentKind.waste;

  @override
  void initState() {
    super.initState();
    _editorData = _loadEditorData();
    _keyboardManager = ref.read(keyboardManagerProvider);
    _invoiceMacros = ref.read(invoiceShortcutMacroProvider);
    _keyboardManager.register(this, KeyboardContext.invoice);
    _keyboardManager.on(KeyboardAction.invoiceAddLine, () => _addLine(context));
    _invoiceMacros.addListener(_applyPendingMacro);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _keyboardManager.unregister(this);
    _keyboardManager.off(KeyboardAction.invoiceAddLine);
    _invoiceMacros.removeListener(_applyPendingMacro);
    _documentDiscount.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _applyPendingMacro() async {
    final macro = _invoiceMacros.takePending();
    if (macro == null || !mounted || _warehouseId == null) return;
    final inventory = ref.read(inventoryRepositoryProvider);
    final master = ref.read(masterDataRepositoryProvider);
    final products = await inventory.listSellableProducts(
      warehouseId: _warehouseId,
    );
    final added = <_DraftLine>[];
    for (final entry in macro.lines) {
      final matches = products.where((p) => p.productId == entry.productId);
      final product = matches.isEmpty ? null : matches.first;
      if (product == null) continue;
      final units = await master.listProductUnits(entry.productId);
      if (units.isEmpty) continue;
      final unit = units.firstWhere(
        (u) => u.isPrimary,
        orElse: () => units.first,
      );
      final itemId =
          product.inventoryItemId ??
          await inventory.ensureInventoryItemForProduct(
            productId: entry.productId,
            warehouseId: _warehouseId!,
          );
      added.add(
        _DraftLine(
          inventoryItemId: itemId,
          productId: entry.productId,
          productUnitId: unit.id!,
          productName: product.productName,
          unitName: unit.name,
          quantity: entry.quantity,
          unitFactor: unit.factor,
          unitPriceMinor:
              _isPurchase
                  ? 0
                  : CurrencyMath.fromBaseMinor(
                    unit.salePriceMinor,
                    _exchangeRateMicros,
                  ),
          lineDiscountMinor: 0,
        ),
      );
    }
    if (!mounted) return;
    if (added.isEmpty) {
      CustomSnackBar.showWarningSnackbar(
        'لم تتوفر منتجات هذا الاختصار في المستودع المحدد',
      );
      return;
    }
    setState(() => _lines.addAll(added));
    _markDirty();
    CustomSnackBar.showSuccessSnackbar(
      'تمت إضافة ${added.length} بند من اختصار ${macro.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    return FutureBuilder<_EditorData>(
      future: _editorData,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _editorFrame(
            context,
            const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _editorFrame(
            context,
            Center(child: Text('${snapshot.error}')),
          );
        }
        final data = snapshot.data!;
        _warehouseId ??=
            data.warehouses.isEmpty ? null : data.warehouses.first.id;
        _cashboxId ??= data.cashboxes.isEmpty ? null : data.cashboxes.first.id;
        if (_warehouseId == null) {
          return _editorFrame(
            context,
            const Center(child: Text('أضف مستودعاً أولاً.')),
          );
        }
        return _body(context, data);
      },
    );
  }

  Widget _editorFrame(
    BuildContext context,
    Widget child, {
    bool backdrop = false,
  }) {
    if (widget.embedded) {
      return ColoredBox(
        color: context.colors.bgPage.withValues(alpha: .16),
        child: child,
      );
    }
    return MyScaffold(
      appBar:
          showCompactPageAppBar(context)
              ? BlurAppBar(title: Text('مستند ${widget.kind.label} جديد'))
              : null,
      body: backdrop ? PremiumBackdrop(child: child) : child,
    );
  }

  void _markDirty() {
    _scheduleAutoSave();
    if (_dirty) return;
    _dirty = true;
    widget.onDirtyChanged?.call(true);
  }

  void _scheduleAutoSave() {
    if (_isWaste) return;
    _autoSaveTimer?.cancel();
    if (mounted) setState(() => _autoSaveLabel = 'بانتظار الحفظ…');
    _autoSaveTimer = Timer(
      const Duration(milliseconds: 450),
      () => _activeAutoSave = _persistDraft(),
    );
  }

  List<SaleLineInput> _saleInputs() => _lines
      .map(
        (line) => SaleLineInput(
          inventoryItemId: line.inventoryItemId,
          productUnitId: line.productUnitId,
          quantity: line.quantity,
          unitFactor: line.unitFactor,
          unitPriceMinor: _toBaseMinor(line.unitPriceMinor),
          lineDiscountMinor: _toBaseMinor(line.lineDiscountMinor),
        ),
      )
      .toList(growable: false);

  List<PurchaseLineInput> _purchaseInputs() => _lines
      .map(
        (line) => PurchaseLineInput(
          inventoryItemId: line.inventoryItemId,
          productUnitId: line.productUnitId,
          quantity: line.quantity,
          unitFactor: line.unitFactor,
          unitCostMinor: _toBaseMinor(line.unitPriceMinor),
          lineDiscountMinor: _toBaseMinor(line.lineDiscountMinor),
        ),
      )
      .toList(growable: false);

  Future<void> _persistDraft() async {
    if (!mounted || _isWaste) return;
    if (_lines.isEmpty) {
      try {
        if (_draftId != null) {
          final repo = ref.read(documentRepositoryProvider);
          await repo.deleteDraft(
            documentId: _draftId!,
            type: _isPurchase ? 'purchase' : 'sale',
          );
          _draftId = null;
        }
        if (mounted) {
          _dirty = false;
          widget.onDirtyChanged?.call(false);
          setState(() => _autoSaveLabel = 'لا توجد بنود للحفظ');
        }
      } catch (_) {
        if (mounted) {
          setState(() => _autoSaveLabel = 'تعذر تحديث المسودة تلقائياً');
        }
      }
      return;
    }
    if (_isPurchase && _partyId == null) {
      setState(() => _autoSaveLabel = 'اختر المورد للحفظ التلقائي');
      return;
    }
    if (_autoSaveInProgress) {
      _autoSaveQueued = true;
      return;
    }
    _autoSaveInProgress = true;
    setState(() => _autoSaveLabel = 'جارٍ الحفظ…');
    try {
      final repo = ref.read(documentRepositoryProvider);
      final foreignDiscount = Money.fromMajor(_documentDiscount.text);
      final foreignSubtotal = _lines.fold<int>(
        0,
        (sum, line) => sum + line.lineTotalMinor,
      );
      if (foreignDiscount < 0 || foreignDiscount > foreignSubtotal) {
        throw const FormatException('خصم الفاتورة غير صالح');
      }
      var discount = _toBaseMinor(foreignDiscount);
      final saleInputs = _isPurchase ? const <SaleLineInput>[] : _saleInputs();
      final purchaseInputs =
          _isPurchase ? _purchaseInputs() : const <PurchaseLineInput>[];
      final baseSubtotal =
          _isPurchase
              ? purchaseInputs.fold<int>(
                0,
                (sum, item) => sum + item.lineTotalMinor,
              )
              : saleInputs.fold<int>(
                0,
                (sum, item) => sum + item.lineTotalMinor,
              );
      discount = discount.clamp(0, baseSubtotal).toInt();
      final baseFinal =
          (baseSubtotal - discount).clamp(0, baseSubtotal).toInt();
      final foreignFinal = foreignSubtotal - foreignDiscount;
      var foreignPaid = Money.fromMajor(_paid.text);
      if (!_isPurchase && _partyId == null) {
        foreignPaid = foreignFinal;
      }
      if (foreignPaid < 0 || foreignPaid > foreignFinal) {
        throw const FormatException('قيمة الدفعة أكبر من إجمالي الفاتورة');
      }
      final paid =
          foreignPaid == foreignFinal
              ? baseFinal
              : _toBaseMinor(foreignPaid).clamp(0, baseFinal).toInt();
      if (_isPurchase) {
        if (_draftId == null) {
          _draftId = await repo.createPurchaseDraft(
            supplierId: _partyId!,
            cashboxId: _cashboxId,
            discountMinor: discount,
            paidMinor: paid,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: foreignSubtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaid,
            items: purchaseInputs,
          );
        } else {
          await repo.updatePurchaseDraft(
            purchaseId: _draftId!,
            supplierId: _partyId!,
            cashboxId: _cashboxId,
            discountMinor: discount,
            paidMinor: paid,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: foreignSubtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaid,
            items: purchaseInputs,
          );
        }
      } else if (_draftId == null) {
        _draftId = await repo.createSaleDraft(
          partyId: _partyId,
          cashboxId: _cashboxId,
          discountMinor: discount,
          paidMinor: paid,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          currencyCode: _currencyCode,
          exchangeRateMicros: _exchangeRateMicros,
          foreignSubtotalMinor: foreignSubtotal,
          foreignDiscountMinor: foreignDiscount,
          foreignPaidMinor: foreignPaid,
          items: saleInputs,
        );
      } else {
        await repo.updateSaleDraft(
          saleId: _draftId!,
          partyId: _partyId,
          cashboxId: _cashboxId,
          discountMinor: discount,
          paidMinor: paid,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          currencyCode: _currencyCode,
          exchangeRateMicros: _exchangeRateMicros,
          foreignSubtotalMinor: foreignSubtotal,
          foreignDiscountMinor: foreignDiscount,
          foreignPaidMinor: foreignPaid,
          items: saleInputs,
        );
      }
      if (mounted) {
        _dirty = false;
        widget.onDirtyChanged?.call(false);
        setState(() => _autoSaveLabel = 'تم الحفظ تلقائياً');
      }
    } catch (_) {
      if (mounted) setState(() => _autoSaveLabel = 'تعذر الحفظ التلقائي');
    } finally {
      _autoSaveInProgress = false;
      if (_autoSaveQueued) {
        _autoSaveQueued = false;
        _scheduleAutoSave();
      }
    }
  }

  void _markClean() {
    if (!_dirty) return;
    _dirty = false;
    widget.onDirtyChanged?.call(false);
  }

  Widget _body(BuildContext context, _EditorData data) {
    final baseCurrency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final configuredCurrencies = ref.watch(currenciesProvider).asData?.value;
    final editorData =
        configuredCurrencies == null || configuredCurrencies.isEmpty
            ? data
            : _EditorData(
              warehouses: data.warehouses,
              parties: data.parties,
              cashboxes: data.cashboxes,
              currencies: configuredCurrencies,
            );
    _currencyCode ??= baseCurrency;
    final selectedCurrency = editorData.currencies.where(
      (currency) => currency.code == _currencyCode,
    );
    if (selectedCurrency.isNotEmpty) {
      _exchangeRateMicros = selectedCurrency.first.rateMicros;
    }
    final currency = _currencyCode ?? baseCurrency;
    _selectedCurrencyIsBase = currency == baseCurrency;
    if (_selectedCurrencyIsBase) {
      final dollars = editorData.currencies.where(
        (item) => item.code == 'USD' && !item.isBase && item.rateMicros > 0,
      );
      _equivalentCurrencyCode = dollars.isEmpty ? null : 'USD';
      _equivalentRateMicros =
          dollars.isEmpty ? CurrencyMath.rateScale : dollars.first.rateMicros;
    } else {
      _equivalentCurrencyCode = baseCurrency;
      _equivalentRateMicros = _exchangeRateMicros;
    }
    final subtotal = _lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotalMinor,
    );
    final discount = _safeMoney(_documentDiscount.text);
    final finalMinor = (subtotal - discount).clamp(0, subtotal).toInt();
    return _professionalInvoiceBody(
      context,
      data: editorData,
      currency: currency,
      subtotal: subtotal,
      finalMinor: finalMinor,
    );
  }

  int _toBaseMinor(int foreignMinor) =>
      CurrencyMath.toBaseMinor(foreignMinor, _exchangeRateMicros);

  Widget _professionalInvoiceBody(
    BuildContext context, {
    required _EditorData data,
    required String currency,
    required int subtotal,
    required int finalMinor,
  }) {
    final colors = context.colors;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final desktop = constraints.maxWidth >= 1080;
        final horizontal = compact ? 12.0 : 20.0;
        final desktopSummaryHeight =
            constraints.maxHeight > 562 ? constraints.maxHeight - 42 : 520.0;
        final desktopItemsHeight =
            constraints.maxHeight > 680 ? constraints.maxHeight - 160 : 520.0;

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                // Panels still provide the reading surface; the page canvas stays
                // subtly visible through the free areas of the invoice workspace.
                color: colors.bgPage.withValues(alpha: .42),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          16,
                          horizontal,
                          26,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _invoiceInformationPanel(
                                          context,
                                          data,
                                          horizontal: true,
                                        ),
                                        const SizedBox(height: 14),
                                        _invoiceItemsPanel(
                                          context,
                                          currency,
                                          minHeight: desktopItemsHeight,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 306,
                                    child: _invoiceBottomSection(
                                      context,
                                      currency: currency,
                                      subtotal: subtotal,
                                      finalMinor: finalMinor,
                                      sidebar: true,
                                      minHeight: desktopSummaryHeight,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _invoiceInformationPanel(
                                context,
                                data,
                                horizontal: !compact,
                              ),
                              const SizedBox(height: 14),
                              _invoiceItemsPanel(context, currency),
                              const SizedBox(height: 14),
                              _invoiceBottomSection(
                                context,
                                currency: currency,
                                subtotal: subtotal,
                                finalMinor: finalMinor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (compact)
              PositionedDirectional(
                end: 16,
                bottom: 18,
                child: FloatingActionButton.extended(
                  heroTag: 'invoice-add-line-${widget.kind.name}',
                  onPressed: () => _addLine(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة بند'),
                ),
              ),
          ],
        );
      },
    );
    return _editorFrame(context, content);
  }

  Widget _invoiceInformationPanel(
    BuildContext context,
    _EditorData data, {
    bool sidebar = false,
    bool horizontal = false,
  }) {
    final colors = context.colors;
    final baseCurrency =
        ref.read(localContextProvider).asData?.value.currencyCode ??
        CurrencyDefaults.baseCode;
    return Container(
      padding:
          horizontal
              ? const EdgeInsets.symmetric(horizontal: 11, vertical: 8)
              : EdgeInsets.all(sidebar ? 11 : 15),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!horizontal) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Iconsax.document_text,
                    color: colors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isWaste ? 'معلومات المستند' : 'معلومات الفاتورة',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: sidebar ? 10 : 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  sidebar
                      ? 1
                      : horizontal
                      ? (constraints.maxWidth >= 1000 ? 4 : 2)
                      : constraints.maxWidth >= 900
                      ? 3
                      : 2;
              final fieldWidth =
                  columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - ((columns - 1) * 12)) / columns;

              Widget field(String label, Widget child, {bool full = false}) {
                return SizedBox(
                  width: full ? constraints.maxWidth : fieldWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: 2,
                          bottom: horizontal ? 3 : (sidebar ? 4 : 6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: horizontal ? 9.5 : 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (horizontal)
                        SizedBox(height: 50, child: child)
                      else
                        child,
                    ],
                  ),
                );
              }

              final fields = <Widget>[
                field(
                  'المستودع',
                  DropdownButtonFormField<String>(
                    value: _warehouseId,
                    isExpanded: true,
                    items:
                        data.warehouses
                            .where((row) => row.id != null)
                            .map(
                              (row) => DropdownMenuItem(
                                value: row.id!,
                                child: Text(
                                  row.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _lines.isNotEmpty
                            ? null
                            : (value) {
                              setState(() => _warehouseId = value);
                              _markDirty();
                            },
                    decoration: const InputDecoration(
                      hintText: 'اختر المستودع',
                      prefixIcon: Icon(Iconsax.buildings_2, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                if (!_isWaste)
                  field(
                    _isPurchase ? 'المورد *' : 'العميل',
                    DropdownButtonFormField<String?>(
                      value: _partyId,
                      isExpanded: true,
                      items: [
                        if (!_isPurchase)
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'بدون عميل (بيع نقدي)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ...data.parties
                            .where((row) => row.id != null)
                            .map(
                              (row) => DropdownMenuItem<String?>(
                                value: row.id!,
                                child: Text(
                                  row.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                      onChanged: (value) {
                        setState(() => _partyId = value);
                        _markDirty();
                      },
                      decoration: InputDecoration(
                        hintText: _isPurchase ? 'اختر المورد' : 'اختر العميل',
                        prefixIcon: const Icon(Iconsax.user, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                if (!_isWaste)
                  field(
                    'الصندوق / الحساب',
                    DropdownButtonFormField<String>(
                      value: _cashboxId,
                      isExpanded: true,
                      items:
                          data.cashboxes
                              .where((row) => row.id != null)
                              .map(
                                (row) => DropdownMenuItem(
                                  value: row.id!,
                                  child: Text(
                                    row.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() => _cashboxId = value);
                        _markDirty();
                      },
                      decoration: const InputDecoration(
                        hintText: 'اختر الحساب',
                        prefixIcon: Icon(Iconsax.wallet_2, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                if (!_isWaste)
                  field(
                    'عملة الفاتورة',
                    DropdownButtonFormField<String>(
                      value: _currencyCode,
                      isExpanded: true,
                      items: data.currencies
                          .where((currency) => currency.rateMicros > 0)
                          .map(
                            (currency) => DropdownMenuItem(
                              value: currency.code,
                              child: Text(
                                currency.isBase
                                    ? '${currency.code} • الأساسية'
                                    : '${currency.code} • 1 = ${CurrencyMath.formatRateMicros(currency.rateMicros)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          _lines.isNotEmpty
                              ? null
                              : (value) {
                                if (value == null) return;
                                final selected = data.currencies.firstWhere(
                                  (currency) => currency.code == value,
                                );
                                setState(() {
                                  _currencyCode = selected.code;
                                  _exchangeRateMicros = selected.rateMicros;
                                });
                                _markDirty();
                              },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.currency_exchange_rounded,
                          size: 18,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                if (_isPurchase && !_selectedCurrencyIsBase)
                  field(
                    'سعر الصرف (1 ${_currencyCode ?? baseCurrency} = $baseCurrency)',
                    TextFormField(
                      key: ValueKey('purchase-rate-$_currencyCode'),
                      initialValue: CurrencyMath.formatRateMicros(
                        _exchangeRateMicros,
                      ),
                      enabled: _lines.isEmpty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        try {
                          final rate = CurrencyMath.parseRateMicros(value);
                          if (rate == _exchangeRateMicros) return;
                          setState(() => _exchangeRateMicros = rate);
                          _markDirty();
                        } on FormatException {
                          // Keep the entered value visible while it is edited;
                          // saving validates it again before posting.
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: 1400',
                        helperText:
                            _lines.isEmpty
                                ? 'تُحوّل كلفة المخزون تلقائياً إلى $baseCurrency.'
                                : 'لا يغيّر سعر الصرف بعد إضافة البنود.',
                        prefixIcon: const Icon(
                          Icons.currency_exchange_rounded,
                          size: 18,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                field(
                  _isWaste
                      ? 'ملاحظة المستند'
                      : _isPurchase
                      ? 'ملاحظة المورد'
                      : 'ملاحظة العميل',
                  TextField(
                    controller: _note,
                    minLines: 1,
                    maxLines: horizontal ? 1 : (sidebar ? 2 : 3),
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(
                      hintText: 'أضف ملاحظة اختيارية...',
                      prefixIcon: Icon(Iconsax.note_1, size: 18),
                      alignLabelWithHint: true,
                    ),
                  ),
                  full: sidebar,
                ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: sidebar ? 8 : 12,
                children: fields,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _shortcutBadge(BuildContext context, String label) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: .56),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textDim,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _invoiceItemsPanel(
    BuildContext context,
    String currency, {
    double? minHeight,
  }) {
    final colors = context.colors;
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? (compact ? 280 : 420),
      ),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Iconsax.box, color: colors.primary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بنود الفاتورة',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _lines.isEmpty
                            ? 'أضف المنتجات التي تريد تسجيلها'
                            : '${_lines.length} ${_lines.length == 1 ? 'بند' : 'بنود'}',
                        style: TextStyle(color: colors.textDim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  FilledButton.icon(
                    onPressed: () => _addLine(context),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('إضافة بند'),
                  ),
              ],
            ),
          ),
          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                children: [
                  Icon(Iconsax.box_add, size: 28, color: colors.textDim),
                  const SizedBox(height: 9),
                  Text(
                    'لا توجد منتجات في الفاتورة',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اضغط على “إضافة بند” لاختيار منتج',
                    style: TextStyle(color: colors.textDim, fontSize: 10.5),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _addLine(context),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('إضافة أول بند'),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            _invoiceTableHeader(context),
            for (var index = 0; index < _lines.length; index++) ...[
              _InvoiceLineRow(
                index: index,
                line: _lines[index],
                currency: currency,
                tableMode: true,
                onDelete: () {
                  setState(() => _lines.removeAt(index));
                  _markDirty();
                },
              ),
              if (index != _lines.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colors.border,
                ),
            ],
            if (!compact)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: colors.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _addLine(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: colors.primary,
                            size: 19,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'إضافة بند جديد',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _shortcutBadge(context, 'Ctrl + Enter'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceTableHeader(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) return const SizedBox.shrink();

        Widget label(
          String value,
          int flex, {
          TextAlign align = TextAlign.start,
        }) {
          return Expanded(
            flex: flex,
            child: Text(
              value,
              textAlign: align,
              style: TextStyle(
                color: colors.textDim,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.bgPage.withValues(alpha: .65),
            border: Border.symmetric(
              horizontal: BorderSide(color: colors.border),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 34),
              const SizedBox(width: 10),
              label('المنتج', 4),
              label('الوحدة', 2, align: TextAlign.center),
              label('الكمية', 2, align: TextAlign.center),
              label('السعر', 2, align: TextAlign.center),
              label('الخصم', 2, align: TextAlign.center),
              label('الإجمالي', 3, align: TextAlign.center),
              const SizedBox(width: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _invoiceBottomSection(
    BuildContext context, {
    required String currency,
    required int subtotal,
    required int finalMinor,
    bool sidebar = false,
    double? minHeight,
  }) {
    return _invoiceSummaryCard(
      context,
      currency: currency,
      subtotal: subtotal,
      finalMinor: finalMinor,
      sidebar: sidebar,
      minHeight: minHeight,
    );
  }

  Widget _invoiceSummaryCard(
    BuildContext context, {
    required String currency,
    required int subtotal,
    required int finalMinor,
    bool sidebar = false,
    double? minHeight,
  }) {
    final colors = context.colors;
    final gross = _lines.fold<int>(
      0,
      (sum, line) =>
          sum + Money.multiplyByQuantity(line.unitPriceMinor, line.quantity),
    );
    final lineDiscount = _lines.fold<int>(
      0,
      (sum, line) => sum + line.lineDiscountMinor,
    );
    final documentDiscount = _safeMoney(_documentDiscount.text);
    final paid = _safeMoney(_paid.text);
    final remaining = (finalMinor - paid).clamp(0, finalMinor).toInt();
    final quantity = _lines.fold<double>(0, (sum, line) => sum + line.quantity);
    final equivalentCurrency = _equivalentCurrencyCode;
    final showEquivalent = equivalentCurrency != null;
    final equivalentFinalMinor =
        _selectedCurrencyIsBase
            ? CurrencyMath.fromBaseMinor(finalMinor, _equivalentRateMicros)
            : CurrencyMath.toBaseMinor(finalMinor, _equivalentRateMicros);

    if (sidebar) {
      Widget summaryRow(
        String label,
        String value, {
        Color? valueColor,
        bool strong = false,
      }) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: sidebar ? 4 : 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: strong ? colors.textPrimary : colors.textSecondary,
                    fontSize: strong ? 12 : 10.5,
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? colors.textPrimary,
                  fontSize: strong ? 15 : 11,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        height: minHeight ?? 520,
        padding: EdgeInsets.all(sidebar ? 11 : 15),
        decoration: BoxDecoration(
          color: colors.bgElevated.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Iconsax.receipt_text,
                            color: colors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _isWaste ? 'ملخص المستند' : 'ملخص الفاتورة',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.visibility_outlined,
                          color: colors.textDim,
                          size: 17,
                        ),
                      ],
                    ),
                    SizedBox(height: sidebar ? 8 : 11),
                    if (_isWaste) ...[
                      summaryRow('عدد البنود', '${_lines.length}'),
                      summaryRow('إجمالي الكمية', '$quantity', strong: true),
                    ] else ...[
                      summaryRow(
                        'المجموع الفرعي',
                        _formatMoney(context, gross, currency),
                      ),
                      summaryRow(
                        'خصم البنود',
                        lineDiscount == 0
                            ? '—'
                            : _formatMoney(context, lineDiscount, currency),
                        valueColor:
                            lineDiscount == 0 ? colors.textDim : colors.error,
                      ),
                      SizedBox(height: sidebar ? 4 : 6),
                      TextField(
                        controller: _documentDiscount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _markDirty();
                        },
                        decoration: const InputDecoration(
                          labelText: 'خصم على الفاتورة',
                          prefixIcon: Icon(Iconsax.discount_shape, size: 17),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: sidebar ? 8 : 11),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'الإجمالي',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              _formatMoney(context, finalMinor, currency),
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showEquivalent) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${_selectedCurrencyIsBase ? 'المقابل المرجعي' : 'المقابل المثبت في الدفاتر'}: '
                          '${_formatMoney(context, equivalentFinalMinor, equivalentCurrency)}'
                          ' • 1 ${_selectedCurrencyIsBase ? equivalentCurrency : currency} = '
                          '${CurrencyMath.formatRateMicros(_equivalentRateMicros)} '
                          '${_selectedCurrencyIsBase ? currency : equivalentCurrency}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      SizedBox(height: sidebar ? 8 : 11),
                      TextField(
                        controller: _paid,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _markDirty();
                        },
                        decoration: InputDecoration(
                          labelText:
                              _isPurchase
                                  ? 'المدفوع للمورد'
                                  : 'المقبوض من العميل',
                          prefixIcon: const Icon(
                            Iconsax.wallet_money,
                            size: 17,
                          ),
                          isDense: true,
                        ),
                      ),
                      SizedBox(height: sidebar ? 3 : 5),
                      summaryRow(
                        remaining == 0 ? 'حالة الدفع' : 'المتبقي',
                        remaining == 0
                            ? 'مسددة'
                            : _formatMoney(context, remaining, currency),
                        valueColor:
                            remaining == 0 ? colors.success : colors.secondary,
                        strong: remaining != 0,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: 10),
            if (!_isWaste)
              Text(
                _autoSaveLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      _autoSaveLabel.startsWith('تعذر')
                          ? colors.error
                          : colors.textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (!_isWaste) const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(post: true),
              icon:
                  _saving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Iconsax.tick_circle, size: 17),
              label: Text(_isWaste ? 'اعتماد المستند' : 'حفظ واعتماد'),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Iconsax.calculator,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isWaste ? 'ملخص المستند' : 'إجمالي الفاتورة',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (!_isWaste)
                Text(
                  '${_lines.length} ${_lines.length == 1 ? 'بند' : 'بنود'}',
                  style: TextStyle(color: colors.textDim, fontSize: 10.5),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              final width =
                  columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - ((columns - 1) * 10)) / columns;

              Widget metric({
                required String label,
                required String value,
                required IconData icon,
                Color? accent,
                bool emphasized = false,
              }) {
                final tint = accent ?? colors.primary;
                return Container(
                  width: width,
                  constraints: const BoxConstraints(minHeight: 82),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        emphasized
                            ? tint.withValues(alpha: .11)
                            : colors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          emphasized
                              ? tint.withValues(alpha: .20)
                              : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: tint, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: emphasized ? tint : colors.textPrimary,
                                fontSize: emphasized ? 15 : 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget moneyField({
                required String label,
                required TextEditingController controller,
                required IconData icon,
              }) {
                return Container(
                  width: width,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _markDirty();
                    },
                    decoration: InputDecoration(
                      labelText: label,
                      prefixIcon: Icon(icon, size: 18),
                      isDense: true,
                    ),
                  ),
                );
              }

              final children =
                  _isWaste
                      ? <Widget>[
                        metric(
                          label: 'عدد البنود',
                          value: '${_lines.length}',
                          icon: Iconsax.box,
                        ),
                        metric(
                          label: 'إجمالي الكمية',
                          value: '$quantity',
                          icon: Iconsax.chart_1,
                          accent: colors.success,
                          emphasized: true,
                        ),
                      ]
                      : <Widget>[
                        metric(
                          label: 'المجموع الفرعي',
                          value: _formatMoney(context, gross, currency),
                          icon: Iconsax.document_text,
                        ),
                        metric(
                          label: 'خصم البنود',
                          value:
                              lineDiscount == 0
                                  ? '—'
                                  : _formatMoney(
                                    context,
                                    lineDiscount,
                                    currency,
                                  ),
                          icon: Iconsax.tag,
                          accent: colors.secondary,
                        ),
                        moneyField(
                          label: 'خصم إضافي',
                          controller: _documentDiscount,
                          icon: Iconsax.discount_shape,
                        ),
                        moneyField(
                          label:
                              _isPurchase
                                  ? 'المدفوع للمورد'
                                  : 'المقبوض من العميل',
                          controller: _paid,
                          icon: Iconsax.wallet_money,
                        ),
                        metric(
                          label: 'الإجمالي النهائي',
                          value: _formatMoney(context, finalMinor, currency),
                          icon: Iconsax.money_4,
                          accent: colors.success,
                          emphasized: true,
                        ),
                        metric(
                          label: remaining == 0 ? 'حالة الدفع' : 'المتبقي',
                          value:
                              remaining == 0
                                  ? 'مسددة'
                                  : _formatMoney(context, remaining, currency),
                          icon:
                              remaining == 0
                                  ? Iconsax.tick_circle
                                  : Iconsax.timer_1,
                          accent:
                              remaining == 0
                                  ? colors.success
                                  : colors.secondary,
                        ),
                      ];

              return Wrap(spacing: 10, runSpacing: 10, children: children);
            },
          ),
          if (!_isWaste && showEquivalent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .16),
                ),
              ),
              child: Text(
                '${_selectedCurrencyIsBase ? 'المقابل المرجعي' : 'المقابل بعملة الدفاتر'}: '
                '${_formatMoney(context, equivalentFinalMinor, equivalentCurrency)}'
                '  •  1 ${_selectedCurrencyIsBase ? equivalentCurrency : currency} = '
                '${CurrencyMath.formatRateMicros(_equivalentRateMicros)} '
                '${_selectedCurrencyIsBase ? currency : equivalentCurrency}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (!_isWaste && documentDiscount > subtotal && subtotal > 0) ...[
            const SizedBox(height: 10),
            Text(
              'قيمة الخصم الإضافي أكبر من إجمالي البنود.',
              style: TextStyle(
                color: colors.error,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(post: true),
                icon:
                    _saving
                        ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Iconsax.tick_circle, size: 18),
                label: Text(_isWaste ? 'اعتماد المستند' : 'حفظ واعتماد'),
              ),
              const SizedBox(width: 12),
              if (!_isWaste)
                Expanded(
                  child: Text(
                    _autoSaveLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          _autoSaveLabel.startsWith('تعذر')
                              ? colors.error
                              : colors.textDim,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMoney(BuildContext context, int minor, String currency) {
    return Money(minor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
  }

  Future<_EditorData> _loadEditorData() async {
    final master = ref.read(masterDataRepositoryProvider);
    final local = await ref.read(localContextProvider.future);
    final currencies = [
      EntityCurrency(
        code: local.currencyCode,
        name: local.currencyCode,
        symbol: local.currencyCode,
        decimalDigits: 2,
        isBase: true,
        isActive: true,
        rateMicros: CurrencyMath.rateScale,
      ),
    ];
    final parties = await master.listParties(
      type: _isPurchase ? 'supplier' : 'customer',
    );
    return _EditorData(
      warehouses: await master.listWarehouses(),
      parties: parties,
      cashboxes: await master.listCashboxes(),
      currencies: currencies,
    );
  }

  Future<void> _addLine(BuildContext context) async {
    final warehouseId = _warehouseId;
    if (warehouseId == null) return;
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final masterRepo = ref.read(masterDataRepositoryProvider);
    final products = await inventoryRepo.listSellableProducts(
      warehouseId: warehouseId,
    );
    if (!context.mounted) return;
    if (products.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أضف منتجاً أولاً');
      return;
    }

    var product = products.first;
    var units = await masterRepo.listProductUnits(product.productId);
    if (!context.mounted || units.isEmpty) return;
    var unit = units.first;
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(
      text:
          _isPurchase
              ? '0'
              : _moneyInput(
                CurrencyMath.fromBaseMinor(
                  unit.salePriceMinor,
                  _exchangeRateMicros,
                ),
              ),
    );
    final lineDiscount = TextEditingController(text: '0');
    final currency =
        _currencyCode ??
        ref.read(localContextProvider).asData?.value.currencyCode ??
        'USD';

    int currentLineTotal() {
      if (_isWaste) return 0;
      final quantity =
          double.tryParse(qty.text.trim().replaceAll(',', '.')) ?? 0;
      final gross = Money.multiplyByQuantity(_safeMoney(price.text), quantity);
      final total = gross - _safeMoney(lineDiscount.text);
      return total < 0 ? 0 : total;
    }

    Future<void> submit(BuildContext dialogContext) async {
      try {
        final quantity = double.parse(qty.text.trim().replaceAll(',', '.'));
        if (quantity <= 0) {
          throw const FormatException('الكمية يجب أن تكون أكبر من صفر');
        }
        final factor = unit.factor;
        final unitPriceMinor = _isWaste ? 0 : Money.fromMajor(price.text);
        final discountMinor = _isWaste ? 0 : Money.fromMajor(lineDiscount.text);
        final gross = Money.multiplyByQuantity(unitPriceMinor, quantity);
        if (discountMinor < 0 || discountMinor > gross) {
          throw const FormatException('خصم السطر غير صالح');
        }
        var inventoryItemId = product.inventoryItemId;
        inventoryItemId ??= await inventoryRepo.ensureInventoryItemForProduct(
          productId: product.productId,
          warehouseId: warehouseId,
        );
        if (!dialogContext.mounted) return;
        Navigator.pop(
          dialogContext,
          _DraftLine(
            inventoryItemId: inventoryItemId,
            productId: product.productId,
            productUnitId: unit.id!,
            productName: product.productName,
            unitName: unit.name,
            quantity: quantity,
            unitFactor: factor,
            unitPriceMinor: unitPriceMinor,
            lineDiscountMinor: discountMinor,
          ),
        );
      } catch (error) {
        if (dialogContext.mounted) {
          CustomSnackBar.showErrorSnackbar('$error');
        }
      }
    }

    final result = await showDialog<_DraftLine>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .42),
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setLocal) {
              final colors = dialogContext.colors;

              void changeQuantity(double delta) {
                final current =
                    double.tryParse(qty.text.trim().replaceAll(',', '.')) ?? 1;
                final next = current + delta;
                if (next <= 0) return;
                qty.text =
                    next == next.roundToDouble()
                        ? '${next.toInt()}'
                        : next.toStringAsFixed(2);
                setLocal(() {});
              }

              Widget labeled(String label, Widget child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 2,
                        bottom: 7,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    child,
                  ],
                );
              }

              return Dialog(
                backgroundColor: colors.bgElevated,
                surfaceTintColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: MediaQuery.sizeOf(dialogContext).height - 36,
                  ),
                  child: Material(
                    color: colors.bgElevated,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 17, 14, 17),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .055),
                            border: Border(
                              bottom: BorderSide(color: colors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .11),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Iconsax.box_add,
                                  color: colors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'إضافة بند',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'اختر المنتج وحدد الكمية، وسيُحسب الإجمالي تلقائياً',
                                      style: TextStyle(
                                        color: colors.textDim,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final twoColumns =
                                          constraints.maxWidth >= 560;
                                      final productField = labeled(
                                        'المنتج',
                                        DropdownButtonFormField<String>(
                                          value: product.productId,
                                          isExpanded: true,
                                          items:
                                              products
                                                  .map(
                                                    (row) => DropdownMenuItem(
                                                      value: row.productId,
                                                      child: Text(
                                                        row.productName,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) async {
                                            if (value == null) return;
                                            final nextProduct = products
                                                .firstWhere(
                                                  (row) =>
                                                      row.productId == value,
                                                );
                                            final nextUnits = await masterRepo
                                                .listProductUnits(value);
                                            if (!dialogContext.mounted ||
                                                nextUnits.isEmpty) {
                                              return;
                                            }
                                            setLocal(() {
                                              product = nextProduct;
                                              units = nextUnits;
                                              unit = nextUnits.first;
                                              if (!_isPurchase) {
                                                price.text = _moneyInput(
                                                  CurrencyMath.fromBaseMinor(
                                                    unit.salePriceMinor,
                                                    _exchangeRateMicros,
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                          decoration: const InputDecoration(
                                            labelText: 'المنتج',
                                            prefixIcon: Icon(
                                              Iconsax.box,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      );
                                      final unitField = labeled(
                                        'الوحدة',
                                        DropdownButtonFormField<String>(
                                          value: unit.id!,
                                          isExpanded: true,
                                          items:
                                              units
                                                  .map(
                                                    (row) => DropdownMenuItem(
                                                      value: row.id!,
                                                      child: Text(
                                                        '${row.name} × ${row.factor}',
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setLocal(() {
                                              unit = units.firstWhere(
                                                (row) => row.id == value,
                                              );
                                              if (!_isPurchase) {
                                                price.text = _moneyInput(
                                                  CurrencyMath.fromBaseMinor(
                                                    unit.salePriceMinor,
                                                    _exchangeRateMicros,
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                          decoration: const InputDecoration(
                                            labelText: 'الوحدة',
                                            prefixIcon: Icon(
                                              Icons.straighten_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      );
                                      if (!twoColumns) {
                                        return Column(
                                          children: [
                                            productField,
                                            const SizedBox(height: 14),
                                            unitField,
                                          ],
                                        );
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: productField),
                                          const SizedBox(width: 14),
                                          Expanded(child: unitField),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: colors.bgPage,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'الكمية',
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colors.success
                                                    .withValues(alpha: .09),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: Text(
                                                'متوفر: ${product.currentQuantity}',
                                                style: TextStyle(
                                                  color: colors.success,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _QuantityButton(
                                              icon: Icons.remove_rounded,
                                              onTap: () => changeQuantity(-1),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: TextField(
                                                controller: qty,
                                                textAlign: TextAlign.center,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                onChanged:
                                                    (_) => setLocal(() {}),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'الكمية',
                                                      isDense: true,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            _QuantityButton(
                                              icon: Icons.add_rounded,
                                              filled: true,
                                              onTap: () => changeQuantity(1),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isWaste) ...[
                                    const SizedBox(height: 16),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final twoColumns =
                                            constraints.maxWidth >= 520;
                                        final priceField = TextField(
                                          controller: price,
                                          readOnly: !_isPurchase,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged: (_) => setLocal(() {}),
                                          decoration: InputDecoration(
                                            labelText:
                                                _isPurchase
                                                    ? 'تكلفة الوحدة'
                                                    : 'سعر الوحدة',
                                            helperText:
                                                _isPurchase
                                                    ? null
                                                    : 'يُعبّأ تلقائياً من المنتج',
                                            prefixIcon: const Icon(
                                              Iconsax.money_3,
                                              size: 18,
                                            ),
                                            suffixIcon:
                                                _isPurchase
                                                    ? null
                                                    : const Icon(
                                                      Icons
                                                          .lock_outline_rounded,
                                                      size: 18,
                                                    ),
                                          ),
                                        );
                                        final discountField = TextField(
                                          controller: lineDiscount,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          onChanged: (_) => setLocal(() {}),
                                          decoration: const InputDecoration(
                                            labelText: 'خصم السطر',
                                            prefixIcon: Icon(
                                              Iconsax.discount_shape,
                                              size: 18,
                                            ),
                                          ),
                                        );
                                        if (!twoColumns) {
                                          return Column(
                                            children: [
                                              priceField,
                                              const SizedBox(height: 14),
                                              discountField,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: priceField),
                                            const SizedBox(width: 14),
                                            Expanded(child: discountField),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: colors.success.withValues(
                                        alpha: .075,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: colors.success.withValues(
                                          alpha: .16,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: colors.success.withValues(
                                              alpha: .12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                          ),
                                          child: Icon(
                                            Iconsax.receipt_1,
                                            color: colors.success,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.productName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${qty.text} ${unit.name}',
                                                style: TextStyle(
                                                  color: colors.textDim,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isWaste)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'إجمالي البند',
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _formatMoney(
                                                  dialogContext,
                                                  currentLineTotal(),
                                                  currency,
                                                ),
                                                style: TextStyle(
                                                  color: colors.success,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.bgPage.withValues(alpha: .7),
                            border: Border(
                              top: BorderSide(color: colors.border),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                child: const Text('إلغاء'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: () => submit(dialogContext),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('إضافة'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    qty.dispose();
    price.dispose();
    lineDiscount.dispose();
    if (result != null && mounted) {
      setState(() => _lines.add(result));
      _markDirty();
    }
  }

  String _moneyInput(int minor) {
    final value = Money(minor).major.toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _save({required bool post}) async {
    if (_lines.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أضف بنداً واحداً على الأقل');
      return;
    }
    if (_isPurchase && _partyId == null) {
      CustomSnackBar.showWarningSnackbar('اختر مورداً');
      return;
    }
    final repo = ref.read(documentRepositoryProvider);
    final saleItems =
        !_isPurchase && !_isWaste ? _saleInputs() : const <SaleLineInput>[];
    var shortages = const <SaleStockShortage>[];
    if (post && saleItems.isNotEmpty) {
      try {
        shortages = await repo.saleStockShortages(saleItems);
      } catch (error) {
        if (mounted) {
          CustomSnackBar.showErrorSnackbar(
            'تعذر التحقق من رصيد المخزون: $error',
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (post) {
      final subtotal = _lines.fold<int>(
        0,
        (sum, line) => sum + line.lineTotalMinor,
      );
      final discount = Money.fromMajor(_documentDiscount.text);
      final total = (subtotal - discount).clamp(0, subtotal).toInt();
      final currency =
          _currencyCode ??
          ref.read(localContextProvider).asData?.value.currencyCode ??
          'USD';
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('تأكيد اعتماد الفاتورة'),
              content: Container(
                width: shortages.isEmpty ? 320 : 440,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إجمالي الفاتورة',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatMoney(context, total, currency),
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${_lines.length} بند جاهز للاعتماد'),
                    if (shortages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.warning.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.colors.warning.withValues(
                              alpha: .35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: context.colors.warning,
                                  size: 19,
                                ),
                                const SizedBox(width: 7),
                                const Expanded(
                                  child: Text(
                                    'هذه الفاتورة ستجعل المخزون سالبًا',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final shortage in shortages)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  '${shortage.productName}: المتاح '
                                  '${shortage.availableBaseQuantity.toStringAsFixed(2)}، '
                                  'بعد البيع '
                                  '${shortage.resultingBaseQuantity.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
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
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    shortages.isEmpty ? 'حفظ واعتماد' : 'بيع رغم النقص',
                  ),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) return;
    }
    _autoSaveTimer?.cancel();
    final activeAutoSave = _activeAutoSave;
    if (activeAutoSave != null) await activeAutoSave;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      if (_isWaste) {
        await repo.postWaste(
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items:
              _lines
                  .map(
                    (line) => WasteLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                    ),
                  )
                  .toList(),
        );
      } else if (_isPurchase) {
        final purchaseItems = _purchaseInputs();
        final foreignSubtotal = _lines.fold<int>(
          0,
          (sum, line) => sum + line.lineTotalMinor,
        );
        final foreignDiscount = Money.fromMajor(_documentDiscount.text);
        final foreignPaid = Money.fromMajor(_paid.text);
        if (foreignDiscount < 0 || foreignDiscount > foreignSubtotal) {
          throw const FormatException('خصم الفاتورة غير صالح');
        }
        final baseSubtotal = purchaseItems.fold<int>(
          0,
          (sum, item) => sum + item.lineTotalMinor,
        );
        var baseDiscount = _toBaseMinor(foreignDiscount);
        baseDiscount = baseDiscount.clamp(0, baseSubtotal).toInt();
        final foreignFinal = foreignSubtotal - foreignDiscount;
        if (foreignPaid < 0 || foreignPaid > foreignFinal) {
          throw const FormatException('قيمة الدفعة أكبر من إجمالي الفاتورة');
        }
        final baseFinal =
            (baseSubtotal - baseDiscount).clamp(0, baseSubtotal).toInt();
        final basePaid =
            foreignPaid == foreignFinal
                ? baseFinal
                : _toBaseMinor(foreignPaid).clamp(0, baseFinal).toInt();
        if (_draftId == null) {
          _draftId = await repo.createPurchaseDraft(
            supplierId: _partyId!,
            cashboxId: _cashboxId,
            discountMinor: baseDiscount,
            paidMinor: basePaid,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            items: purchaseItems,
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: foreignSubtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaid,
          );
        } else {
          await repo.updatePurchaseDraft(
            purchaseId: _draftId!,
            supplierId: _partyId!,
            cashboxId: _cashboxId,
            discountMinor: baseDiscount,
            paidMinor: basePaid,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            items: purchaseItems,
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: foreignSubtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaid,
          );
        }
        final id = _draftId!;
        if (post) await repo.postPurchase(id);
      } else {
        final subtotal = _lines.fold<int>(
          0,
          (sum, line) => sum + line.lineTotalMinor,
        );
        final foreignDiscount = Money.fromMajor(_documentDiscount.text);
        if (foreignDiscount < 0 || foreignDiscount > subtotal) {
          throw const FormatException('خصم الفاتورة غير صالح');
        }
        final foreignFinalMinor = subtotal - foreignDiscount;
        var foreignPaidMinor = Money.fromMajor(_paid.text);
        if (_partyId == null) foreignPaidMinor = foreignFinalMinor;
        if (foreignPaidMinor < 0 || foreignPaidMinor > foreignFinalMinor) {
          throw const FormatException('قيمة الدفعة أكبر من إجمالي الفاتورة');
        }
        var discount = _toBaseMinor(foreignDiscount);
        final baseSubtotal = saleItems.fold<int>(
          0,
          (sum, item) => sum + item.lineTotalMinor,
        );
        discount = discount.clamp(0, baseSubtotal).toInt();
        final baseFinal =
            (baseSubtotal - discount).clamp(0, baseSubtotal).toInt();
        final paidMinor =
            foreignPaidMinor == foreignFinalMinor
                ? baseFinal
                : _toBaseMinor(foreignPaidMinor).clamp(0, baseFinal).toInt();
        if (_draftId == null) {
          _draftId = await repo.createSaleDraft(
            partyId: _partyId,
            cashboxId: _cashboxId,
            discountMinor: discount,
            paidMinor: paidMinor,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            items: saleItems,
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: subtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaidMinor,
          );
        } else {
          await repo.updateSaleDraft(
            saleId: _draftId!,
            partyId: _partyId,
            cashboxId: _cashboxId,
            discountMinor: discount,
            paidMinor: paidMinor,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            items: saleItems,
            currencyCode: _currencyCode,
            exchangeRateMicros: _exchangeRateMicros,
            foreignSubtotalMinor: subtotal,
            foreignDiscountMinor: foreignDiscount,
            foreignPaidMinor: foreignPaidMinor,
          );
        }
        final id = _draftId!;
        if (post) {
          await repo.postSale(id, allowNegativeStock: shortages.isNotEmpty);
        }
      }
      if (post) _draftId = null;
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        _markClean();
        CustomSnackBar.showSuccessSnackbar(
          post ? 'تم الاعتماد محلياً بنجاح' : 'تم حفظ المسودة محلياً',
        );
        if (widget.embedded) {
          widget.onSaved?.call();
        } else {
          Navigator.maybePop(context);
        }
      }
    } catch (error) {
      if (mounted) CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _safeMoney(String value) {
    try {
      return Money.fromMajor(value);
    } catch (_) {
      return 0;
    }
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: filled ? colors.primary : colors.bgElevated,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: filled ? null : Border.all(color: colors.border),
          ),
          child: Icon(
            icon,
            color: filled ? colors.onPrimary : colors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DraftLine {
  const _DraftLine({
    required this.inventoryItemId,
    required this.productId,
    required this.productUnitId,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.unitFactor,
    required this.unitPriceMinor,
    required this.lineDiscountMinor,
  });

  final String inventoryItemId;
  final String productId;
  final String productUnitId;
  final String productName;
  final String unitName;
  final double quantity;
  final double unitFactor;
  final int unitPriceMinor;
  final int lineDiscountMinor;

  int get lineTotalMinor =>
      Money.multiplyByQuantity(unitPriceMinor, quantity) - lineDiscountMinor;
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({
    required this.index,
    required this.line,
    required this.currency,
    required this.onDelete,
    this.tableMode = false,
  });

  final int index;
  final _DraftLine line;
  final String currency;
  final VoidCallback onDelete;
  final bool tableMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = Money(line.lineTotalMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final details =
        '${line.quantity} ${line.unitName} × ${Money(line.unitPriceMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}'
        '${line.lineDiscountMinor > 0 ? ' • خصم ${Money(line.lineDiscountMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}' : ''}';
    final unitPrice = Money(line.unitPriceMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final discount = Money(line.lineDiscountMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
    final quantity =
        line.quantity == line.quantity.roundToDouble()
            ? '${line.quantity.toInt()}'
            : '${line.quantity}';

    final number = SizedBox(
      width: 34,
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textDim,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textDim, fontSize: 10.5),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (tableMode && constraints.maxWidth >= 650) {
            Widget cell(
              Widget child,
              int flex, {
              AlignmentGeometry alignment = AlignmentDirectional.center,
            }) {
              return Expanded(
                flex: flex,
                child: Align(alignment: alignment, child: child),
              );
            }

            final cellStyle = TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color:
                  index.isOdd
                      ? colors.bgPage.withValues(alpha: .28)
                      : Colors.transparent,
              child: Row(
                children: [
                  number,
                  const SizedBox(width: 10),
                  cell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'معرف: ${line.productId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textDim,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                    4,
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  cell(Text(line.unitName, style: cellStyle), 2),
                  cell(Text(quantity, style: cellStyle), 2),
                  cell(Text(unitPrice, style: cellStyle), 2),
                  cell(
                    Text(
                      line.lineDiscountMinor == 0 ? '—' : discount,
                      style: cellStyle.copyWith(
                        color:
                            line.lineDiscountMinor == 0
                                ? colors.textDim
                                : colors.error,
                      ),
                    ),
                    2,
                  ),
                  cell(
                    Text(
                      total,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    3,
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      tooltip: 'حذف البند',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.textDim,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    number,
                    const SizedBox(width: 11),
                    Expanded(child: identity),
                    IconButton(
                      tooltip: 'حذف البند',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colors.textDim,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 45),
                  child: Text(
                    total,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              number,
              const SizedBox(width: 11),
              Expanded(child: identity),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  total,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'حذف البند',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error,
                  size: 18,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditorData {
  const _EditorData({
    required this.warehouses,
    required this.parties,
    required this.cashboxes,
    required this.currencies,
  });

  final List<Warehouse> warehouses;
  final List<Party> parties;
  final List<Cashbox> cashboxes;
  final List<EntityCurrency> currencies;
}
