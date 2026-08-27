import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:accounting_system/features/documents/models/document_models.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

enum DocumentKind { sale, purchase, saleReturn, purchaseReturn, waste }

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
  const NewDocumentScreen({super.key, required this.kind});

  final DocumentKind kind;

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

  _InvoiceWorkspaceTab _createTab() {
    final id = _nextId++;
    return _InvoiceWorkspaceTab(id: id, serial: id, kind: widget.kind);
  }

  void _addInvoice() {
    setState(() {
      _tabs.add(_createTab());
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MyScaffold(
      body: PremiumBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 850;
            final radius = desktop ? 28.0 : 0.0;
            return Padding(
              padding:
                  desktop
                      ? const EdgeInsets.fromLTRB(18, 14, 18, 18)
                      : EdgeInsets.zero,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(radius),
                      border:
                          desktop
                              ? Border.all(
                                color: colors.border.withValues(alpha: .82),
                              )
                              : null,
                      boxShadow:
                          desktop
                              ? [
                                BoxShadow(
                                  color: colors.bgDeep.withValues(alpha: .16),
                                  blurRadius: 34,
                                  offset: const Offset(0, 14),
                                ),
                              ]
                              : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Column(
                        children: [
                          _InvoiceWorkspaceHeader(
                            kind: widget.kind,
                            openCount: _tabs.length,
                            compact: !desktop,
                            onAdd: _addInvoice,
                          ),
                          _InvoiceTabsBar(
                            tabs: _tabs,
                            activeIndex: _activeIndex,
                            onSelected:
                                (index) => setState(() => _activeIndex = index),
                            onClose: _requestClose,
                            onAdd: _addInvoice,
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
                                    onDirtyChanged:
                                        (dirty) => _setDirty(tab.id, dirty),
                                    onSaved: () => _completeTab(tab.id),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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

class _InvoiceWorkspaceHeader extends StatelessWidget {
  const _InvoiceWorkspaceHeader({
    required this.kind,
    required this.openCount,
    required this.compact,
    required this.onAdd,
  });

  final DocumentKind kind;
  final int openCount;
  final bool compact;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 22,
        14,
        compact ? 14 : 22,
        13,
      ),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [colors.primary, colors.blue],
              ),
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Iconsax.receipt_item,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kind == DocumentKind.waste
                      ? 'مساحة مستندات الهالك'
                      : 'مساحة عمل فواتير ${kind.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    'افتح وحرّر أكثر من فاتورة بالتوازي مع حفظ حالة كل مسودة.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textDim, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (!compact) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .16),
                ),
              ),
              child: Text(
                '$openCount مفتوحة',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(compact ? 'جديدة' : 'فاتورة جديدة'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTabsBar extends StatelessWidget {
  const _InvoiceTabsBar({
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
    required this.onClose,
    required this.onAdd,
  });

  final List<_InvoiceWorkspaceTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onClose;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: colors.bgPage.withValues(alpha: .72),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final active = index == activeIndex;
                return InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    constraints: const BoxConstraints(
                      minWidth: 150,
                      maxWidth: 230,
                    ),
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          active
                              ? colors.bgElevated
                              : colors.bgElevated.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color:
                            active
                                ? colors.primary.withValues(alpha: .30)
                                : colors.border,
                      ),
                      boxShadow:
                          active
                              ? [
                                BoxShadow(
                                  color: colors.bgDeep.withValues(alpha: .08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.fast,
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                tab.dirty
                                    ? colors.secondary
                                    : active
                                    ? colors.primary
                                    : colors.textDim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  active
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                              fontSize: 11.5,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إغلاق الفاتورة',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onClose(index),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: colors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'فتح فاتورة جديدة',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
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

  String? _warehouseId;
  String? _partyId;
  String? _cashboxId;
  bool _saving = false;
  bool _dirty = false;

  bool get _isPurchase => widget.kind == DocumentKind.purchase;
  bool get _isWaste => widget.kind == DocumentKind.waste;

  @override
  void initState() {
    super.initState();
    _editorData = _loadEditorData();
  }

  @override
  void dispose() {
    _documentDiscount.dispose();
    _paid.dispose();
    _note.dispose();
    super.dispose();
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
        color: context.colors.bgPage.withValues(alpha: .74),
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
    if (_dirty) return;
    _dirty = true;
    widget.onDirtyChanged?.call(true);
  }

  void _markClean() {
    if (!_dirty) return;
    _dirty = false;
    widget.onDirtyChanged?.call(false);
  }

  Widget _body(BuildContext context, _EditorData data) {
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final subtotal = _lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotalMinor,
    );
    final discount = _safeMoney(_documentDiscount.text);
    final finalMinor = (subtotal - discount).clamp(0, subtotal).toInt();
    final colors = context.colors;
    final icon = switch (widget.kind) {
      DocumentKind.sale => Iconsax.receipt_add,
      DocumentKind.purchase => Iconsax.shopping_cart,
      DocumentKind.waste => Iconsax.warning_2,
      _ => Icons.description_outlined,
    };

    if (MediaQuery.sizeOf(context).width >= 720) {
      return _professionalInvoiceBody(
        context,
        data: data,
        currency: currency,
        subtotal: subtotal,
        finalMinor: finalMinor,
        icon: icon,
      );
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedEntrance(
                child: PageIntro(
                  eyebrow: 'NEW DOCUMENT',
                  title: 'مستند ${widget.kind.label} جديد',
                  subtitle:
                      _isWaste
                          ? 'سجّل الهالك بدقة ليُخصم من المخزون مع حفظ أثر الحركة.'
                          : _isPurchase
                          ? 'أدخل المورد والبنود والدفع، ثم احفظ كمسودة أو اعتمد المستند.'
                          : 'واجهة سريعة للبيع؛ أضف البنود وحدد المقبوض ثم اعتمد الفاتورة.',
                  icon: icon,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 60),
                child: PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'بيانات المستند',
                        subtitle: 'المستودع والطرف والصندوق المرتبط بالحركة',
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final full = constraints.maxWidth < 620;
                          final wideField = full ? constraints.maxWidth : 270.0;
                          final smallField =
                              full ? constraints.maxWidth : 230.0;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: wideField,
                                child: DropdownButtonFormField<String>(
                                  value: _warehouseId,
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
                                            setState(
                                              () => _warehouseId = value,
                                            );
                                            _markDirty();
                                          },
                                  decoration: const InputDecoration(
                                    labelText: 'المستودع',
                                    prefixIcon: Icon(Iconsax.buildings_2),
                                  ),
                                ),
                              ),
                              if (!_isWaste)
                                SizedBox(
                                  width: wideField,
                                  child: DropdownButtonFormField<String?>(
                                    value: _partyId,
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
                                      labelText:
                                          _isPurchase ? 'المورد' : 'العميل',
                                      prefixIcon: Icon(
                                        _isPurchase
                                            ? Iconsax.truck_fast
                                            : Icons.person_outline_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!_isWaste)
                                SizedBox(
                                  width: smallField,
                                  child: DropdownButtonFormField<String>(
                                    value: _cashboxId,
                                    items:
                                        data.cashboxes
                                            .where((row) => row.id != null)
                                            .map(
                                              (row) => DropdownMenuItem(
                                                value: row.id!,
                                                child: Text(
                                                  row.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      setState(() => _cashboxId = value);
                                      _markDirty();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'الصندوق',
                                      prefixIcon: Icon(Iconsax.wallet_3),
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
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 110),
                child: PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: 'البنود',
                        subtitle:
                            _lines.isEmpty
                                ? 'أضف أول بند للمستند'
                                : '${_lines.length} بند مضاف',
                        trailing: FilledButton.icon(
                          onPressed: () => _addLine(context),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('إضافة بند'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration: AppMotion.normal,
                        curve: AppMotion.curve,
                        alignment: Alignment.topCenter,
                        child:
                            _lines.isEmpty
                                ? const EmptyState(
                                  title: 'لا توجد بنود بعد',
                                  subtitle:
                                      'اضغط “إضافة بند” لاختيار المنتج والكمية والسعر.',
                                  icon: Icons.inventory_2_outlined,
                                )
                                : Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _lines.length;
                                      index++
                                    ) ...[
                                      _InvoiceLineRow(
                                        index: index,
                                        line: _lines[index],
                                        currency: currency,
                                        onDelete: () {
                                          setState(
                                            () => _lines.removeAt(index),
                                          );
                                          _markDirty();
                                        },
                                      ),
                                      if (index != _lines.length - 1)
                                        Divider(
                                          height: 1,
                                          color: colors.border,
                                        ),
                                    ],
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!_isWaste)
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 160),
                  child: PremiumPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          title: 'التسوية المالية',
                          subtitle: 'الخصم والدفع والقيمة النهائية للمستند',
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final full = constraints.maxWidth < 500;
                            final fieldWidth =
                                full ? constraints.maxWidth : 220.0;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: TextField(
                                    controller: _documentDiscount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) {
                                      setState(() {});
                                      _markDirty();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'خصم الفاتورة',
                                      prefixIcon: Icon(Icons.discount_outlined),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: TextField(
                                    controller: _paid,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (_) => _markDirty(),
                                    decoration: InputDecoration(
                                      labelText:
                                          _isPurchase
                                              ? 'المدفوع للمورد'
                                              : 'المقبوض',
                                      prefixIcon: const Icon(
                                        Icons.payments_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: full ? constraints.maxWidth : 210,
                                  child: _totalChip(
                                    context,
                                    'المجموع',
                                    subtotal,
                                    currency,
                                  ),
                                ),
                                SizedBox(
                                  width: full ? constraints.maxWidth : 210,
                                  child: _totalChip(
                                    context,
                                    'الصافي',
                                    finalMinor,
                                    currency,
                                    emphasized: true,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_isWaste) const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 200),
                child: PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                        title: 'ملاحظات',
                        subtitle: 'اختياري — تحفظ مع المستند',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: 'أضف أي ملاحظة مهمة هنا…',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 240),
                child: PremiumPanel(
                  accent: colors.primary,
                  child:
                      _isWaste
                          ? FilledButton.icon(
                            onPressed: _saving ? null : () => _save(post: true),
                            icon:
                                _saving
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Iconsax.tick_circle),
                            label: const Text('اعتماد الهالك'),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final draft = OutlinedButton.icon(
                                onPressed:
                                    _saving ? null : () => _save(post: false),
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('حفظ مسودة'),
                              );
                              final post = FilledButton.icon(
                                onPressed:
                                    _saving ? null : () => _save(post: true),
                                icon:
                                    _saving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Iconsax.tick_circle),
                                label: const Text('حفظ واعتماد'),
                              );
                              if (constraints.maxWidth < 440) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    draft,
                                    const SizedBox(height: 10),
                                    post,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: draft),
                                  const SizedBox(width: 12),
                                  Expanded(child: post),
                                ],
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _editorFrame(context, content, backdrop: true);
  }

  Widget _professionalInvoiceBody(
    BuildContext context, {
    required _EditorData data,
    required String currency,
    required int subtotal,
    required int finalMinor,
    required IconData icon,
  }) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1040;
        final main = _invoiceMainColumn(
          context,
          data: data,
          currency: currency,
          icon: icon,
        );
        final summary = _invoiceSummarySidebar(
          context,
          currency: currency,
          subtotal: subtotal,
          finalMinor: finalMinor,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            split ? 18 : 16,
            16,
            split ? 18 : 16,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child:
                  split
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: TextDirection.ltr,
                        children: [
                          SizedBox(width: 310, child: summary),
                          const SizedBox(width: 16),
                          Expanded(child: main),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [main, const SizedBox(height: 16), summary],
                      ),
            ),
          ),
        );
      },
    );
    return _editorFrame(context, content, backdrop: true);
  }

  Widget _invoiceMainColumn(
    BuildContext context, {
    required _EditorData data,
    required String currency,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _invoiceTitleBand(context, icon),
        const SizedBox(height: 14),
        _invoiceInformationPanel(context, data),
        const SizedBox(height: 14),
        _invoiceItemsPanel(context, currency),
        const SizedBox(height: 14),
        _invoiceNotesPanel(context),
      ],
    );
  }

  Widget _invoiceTitleBand(BuildContext context, IconData icon) {
    final colors = context.colors;
    final now = DateTime.now();
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            colors.primary.withValues(alpha: .15),
            colors.blue.withValues(alpha: .08),
            colors.bgElevated.withValues(alpha: .96),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .24),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: colors.onPrimary, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _isWaste
                            ? 'مستند هالك جديد'
                            : 'فاتورة ${widget.kind.label} جديدة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: colors.secondary.withValues(alpha: .20),
                        ),
                      ),
                      child: Text(
                        'مسودة',
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _isWaste
                      ? 'سجّل البنود ثم راجعها قبل الاعتماد.'
                      : 'أضف بيانات الطرف والبنود، وسيتم حساب الإجمالي فوراً.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: colors.bgElevated.withValues(alpha: .76),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  date,
                  style: TextStyle(
                    color: colors.textSecondary,
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

  Widget _invoiceInformationPanel(BuildContext context, _EditorData data) {
    final colors = context.colors;
    return PremiumPanel(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.blue.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Iconsax.information, color: colors.blue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات الفاتورة',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'حدد الطرف والمستودع وحساب التسوية',
                      style: TextStyle(color: colors.textDim, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.bgPage.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'رقم الفاتورة: تلقائي',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 760 ? 3 : 2;
              final fieldWidth =
                  (constraints.maxWidth - ((count - 1) * 12)) / count;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      value: _warehouseId,
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
                        labelText: 'المستودع',
                        prefixIcon: Icon(Iconsax.buildings_2),
                      ),
                    ),
                  ),
                  if (!_isWaste)
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String?>(
                        value: _partyId,
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
                          labelText: _isPurchase ? 'المورد' : 'العميل',
                          prefixIcon: Icon(
                            _isPurchase
                                ? Iconsax.truck_fast
                                : Icons.person_outline_rounded,
                          ),
                        ),
                      ),
                    ),
                  if (!_isWaste)
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        value: _cashboxId,
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
                          labelText: 'الصندوق / الحساب',
                          prefixIcon: Icon(Iconsax.wallet_3),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _invoiceItemsPanel(BuildContext context, String currency) {
    final colors = context.colors;
    return PremiumPanel(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Iconsax.box_1, color: colors.primary, size: 18),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lines.isEmpty
                            ? 'ابحث عن منتج لبدء الفاتورة'
                            : '${_lines.length} بند مضاف للفاتورة',
                        style: TextStyle(color: colors.textDim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _addLine(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة بند'),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _addLine(context),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.bgPage.withValues(alpha: .70),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .18),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ابح عن منتج أو اضغط لإضافة بند…',
                      style: TextStyle(color: colors.textDim, fontSize: 11.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'F2',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_lines.isEmpty)
            const EmptyState(
              title: 'لا توجد بنود بعد',
              subtitle:
                  'اختر المنتج والوحدة والكمية، وسيظهر الحساب هنا مباشرة.',
              icon: Iconsax.box_add,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: OutlinedButton.icon(
                onPressed: () => _addLine(context),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('إضافة سطر جديد'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceTableHeader(BuildContext context) {
    final colors = context.colors;
    Widget label(String value, int flex, {TextAlign align = TextAlign.start}) {
      return Expanded(
        flex: flex,
        child: Text(
          value,
          textAlign: align,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .075),
        border: Border.symmetric(horizontal: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 34, child: Text('#')),
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
  }

  Widget _invoiceNotesPanel(BuildContext context) {
    final colors = context.colors;
    return PremiumPanel(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Iconsax.note_text, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'ملاحظات وشروط الفاتورة',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                'اختياري',
                style: TextStyle(color: colors.textDim, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => _markDirty(),
            decoration: const InputDecoration(
              hintText: 'أضف ملاحظة للعميل أو تعليمات داخلية…',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceSummarySidebar(
    BuildContext context, {
    required String currency,
    required int subtotal,
    required int finalMinor,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumPanel(
          borderRadius: 20,
          padding: const EdgeInsets.all(12),
          child:
              _isWaste
                  ? FilledButton.icon(
                    onPressed: _saving ? null : () => _save(post: true),
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Iconsax.tick_circle),
                    label: const Text('اعتماد مستند الهالك'),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _save(post: true),
                        icon:
                            _saving
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Iconsax.tick_circle),
                        label: const Text('حفظ واعتماد الفاتورة'),
                      ),
                      const SizedBox(height: 9),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () => _save(post: false),
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('حفظ كمسودة'),
                      ),
                    ],
                  ),
        ),
        const SizedBox(height: 12),
        PremiumPanel(
          borderRadius: 20,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        _isWaste ? Iconsax.chart_2 : Iconsax.receipt_text,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isWaste ? 'ملخص الكميات' : 'ملخص الفاتورة',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _isWaste
                                ? 'يحدّث مع كل بند'
                                : 'القيمة المالية النهائية',
                            style: TextStyle(
                              color: colors.textDim,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              if (_isWaste) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _invoiceSummaryRow(
                        context,
                        'عدد البنود',
                        '${_lines.length}',
                      ),
                      const SizedBox(height: 12),
                      _invoiceSummaryRow(context, 'إجمالي الكمية', '$quantity'),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          'سيتم خصم هذه الكميات من المخزون عند الاعتماد.',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 10.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _invoiceSummaryRow(
                        context,
                        'المجموع الفرعي',
                        _formatMoney(context, gross, currency),
                      ),
                      const SizedBox(height: 11),
                      _invoiceSummaryRow(
                        context,
                        'خصم البنود',
                        lineDiscount == 0
                            ? '—'
                            : '- ${_formatMoney(context, lineDiscount, currency)}',
                        valueColor: colors.error,
                      ),
                      const SizedBox(height: 11),
                      _invoiceSummaryRow(
                        context,
                        'بعد خصم البنود',
                        _formatMoney(context, subtotal, currency),
                      ),
                      const SizedBox(height: 14),
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
                          labelText: 'خصم إضافي على الفاتورة',
                          prefixIcon: Icon(Icons.discount_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: [colors.primary, colors.blueDark],
                          ),
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .24),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الإجمالي النهائي',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _formatMoney(context, finalMinor, currency),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (documentDiscount > 0) ...[
                              const SizedBox(height: 5),
                              Text(
                                'يتضمن خصماً إضافياً بقيمة ${_formatMoney(context, documentDiscount, currency)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .72),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_isWaste) ...[
          const SizedBox(height: 12),
          PremiumPanel(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.wallet_check, color: colors.success, size: 19),
                    const SizedBox(width: 8),
                    Text(
                      'الدفعة المقدمة',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
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
                        _isPurchase ? 'المدفوع للمورد' : 'المقبوض من العميل',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color:
                        remaining == 0
                            ? colors.success.withValues(alpha: .09)
                            : colors.secondary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color:
                          remaining == 0
                              ? colors.success.withValues(alpha: .18)
                              : colors.secondary.withValues(alpha: .18),
                    ),
                  ),
                  child: _invoiceSummaryRow(
                    context,
                    remaining == 0 ? 'الفاتورة مسددة' : 'المتبقي للدفع',
                    _formatMoney(context, remaining, currency),
                    valueColor:
                        remaining == 0 ? colors.success : colors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _invoiceSummaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 10.5),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? colors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMoney(BuildContext context, int minor, String currency) {
    return Money(minor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );
  }

  Widget _totalChip(
    BuildContext context,
    String label,
    int value,
    String currency, {
    bool emphasized = false,
  }) {
    final colors = context.colors;
    final accent = emphasized ? colors.primary : colors.secondary;
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasized ? .12 : .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Money(value).format(
              locale: Localizations.localeOf(context).toString(),
              currencyCode: currency,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasized ? colors.primary : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<_EditorData> _loadEditorData() async {
    final master = ref.read(masterDataRepositoryProvider);
    final parties = await master.listParties(
      type: _isPurchase ? 'supplier' : 'customer',
    );
    return _EditorData(
      warehouses: await master.listWarehouses(),
      parties: parties,
      cashboxes: await master.listCashboxes(),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أضف منتجاً أولاً')));
      return;
    }

    var product = products.first;
    var units = await masterRepo.listProductUnits(product.productId);
    if (!context.mounted || units.isEmpty) return;
    var unit = units.first;
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final lineDiscount = TextEditingController(text: '0');

    final result = await showDialog<_DraftLine>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  backgroundColor: dialogContext.colors.bgElevated,
                  surfaceTintColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: dialogContext.colors.border),
                  ),
                  title: const Text('إضافة بند'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: product.productId,
                          items:
                              products
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.productId,
                                      child: Text(row.productName),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) async {
                            if (value == null) return;
                            final nextProduct = products.firstWhere(
                              (row) => row.productId == value,
                            );
                            final nextUnits = await masterRepo.listProductUnits(
                              value,
                            );
                            if (!dialogContext.mounted || nextUnits.isEmpty)
                              return;
                            setLocal(() {
                              product = nextProduct;
                              units = nextUnits;
                              unit = nextUnits.first;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'المنتج',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: unit.id!,
                          items:
                              units
                                  .map(
                                    (row) => DropdownMenuItem(
                                      value: row.id!,
                                      child: Text(
                                        '${row.name} × ${row.factor}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setLocal(
                              () =>
                                  unit = units.firstWhere(
                                    (row) => row.id == value,
                                  ),
                            );
                          },
                          decoration: const InputDecoration(
                            labelText: 'الوحدة',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: qty,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                          ),
                        ),
                        if (!_isWaste) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  _isPurchase ? 'تكلفة الوحدة' : 'سعر الوحدة',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: lineDiscount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'خصم السطر',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final quantity = double.parse(qty.text.trim());
                          if (quantity <= 0)
                            throw const FormatException(
                              'الكمية يجب أن تكون أكبر من صفر',
                            );
                          final factor = unit.factor;
                          final unitPriceMinor =
                              _isWaste ? 0 : Money.fromMajor(price.text);
                          final discountMinor =
                              _isWaste ? 0 : Money.fromMajor(lineDiscount.text);
                          final gross = Money.multiplyByQuantity(
                            unitPriceMinor,
                            quantity,
                          );
                          if (discountMinor < 0 || discountMinor > gross) {
                            throw const FormatException('خصم السطر غير صالح');
                          }
                          var inventoryItemId = product.inventoryItemId;
                          inventoryItemId ??= await inventoryRepo
                              .ensureInventoryItemForProduct(
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
                            ScaffoldMessenger.of(
                              dialogContext,
                            ).showSnackBar(SnackBar(content: Text('$error')));
                          }
                        }
                      },
                      child: const Text('إضافة'),
                    ),
                  ],
                ),
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

  Future<void> _save({required bool post}) async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }
    if (_isPurchase && _partyId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر مورداً')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(documentRepositoryProvider);
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
        final id = await repo.createPurchaseDraft(
          supplierId: _partyId!,
          cashboxId: _cashboxId,
          discountMinor: Money.fromMajor(_documentDiscount.text),
          paidMinor: Money.fromMajor(_paid.text),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items:
              _lines
                  .map(
                    (line) => PurchaseLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                      unitCostMinor: line.unitPriceMinor,
                      lineDiscountMinor: line.lineDiscountMinor,
                    ),
                  )
                  .toList(),
        );
        if (post) await repo.postPurchase(id);
      } else {
        final subtotal = _lines.fold<int>(
          0,
          (sum, line) => sum + line.lineTotalMinor,
        );
        final discount = Money.fromMajor(_documentDiscount.text);
        final finalMinor = subtotal - discount;
        var paidMinor = Money.fromMajor(_paid.text);
        if (_partyId == null) paidMinor = finalMinor;
        final id = await repo.createSaleDraft(
          partyId: _partyId,
          cashboxId: _cashboxId,
          discountMinor: discount,
          paidMinor: paidMinor,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          items:
              _lines
                  .map(
                    (line) => SaleLineInput(
                      inventoryItemId: line.inventoryItemId,
                      productUnitId: line.productUnitId,
                      quantity: line.quantity,
                      unitFactor: line.unitFactor,
                      unitPriceMinor: line.unitPriceMinor,
                      lineDiscountMinor: line.lineDiscountMinor,
                    ),
                  )
                  .toList(),
        );
        if (post) await repo.postSale(id);
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (mounted) {
        _markClean();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              post ? 'تم الاعتماد محلياً بنجاح' : 'تم حفظ المسودة محلياً',
            ),
          ),
        );
        if (widget.embedded) {
          widget.onSaved?.call();
        } else {
          Navigator.maybePop(context);
        }
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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

    final number = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900),
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
            fontWeight: FontWeight.w900,
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
                        color: colors.error,
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
                        color: colors.error,
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
  });

  final List<Warehouse> warehouses;
  final List<Party> parties;
  final List<Cashbox> cashboxes;
}
