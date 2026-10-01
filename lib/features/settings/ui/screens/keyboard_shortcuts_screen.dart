import 'package:accounting_system/core/shortcuts/shortcut_model.dart';
import 'package:accounting_system/core/shortcuts/shortcut_provider.dart';
import 'package:accounting_system/core/shortcuts/invoice_shortcut_macro.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class KeyboardShortcutsScreen extends ConsumerStatefulWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  ConsumerState<KeyboardShortcutsScreen> createState() =>
      _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState
    extends ConsumerState<KeyboardShortcutsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shortcutNotifierProvider).load());
  }

  Future<void> _edit(ShortcutModel shortcut) async {
    final updated = await showDialog<ShortcutModel>(
      context: context,
      builder: (_) => _ShortcutCaptureDialog(shortcut: shortcut),
    );
    if (updated == null || !mounted) return;
    final notifier = ref.read(shortcutNotifierProvider);
    final duplicate = notifier.shortcuts.where(
      (item) =>
          item.action != updated.action &&
          item.key == updated.key &&
          item.ctrl == updated.ctrl &&
          item.shift == updated.shift &&
          item.alt == updated.alt,
    );
    if (duplicate.isNotEmpty) {
      CustomSnackBar.showErrorSnackbar(
        'هذا الاختصار مستخدم بالفعل لعملية: ${duplicate.first.label}',
      );
      return;
    }
    await notifier.update(updated);
    if (mounted) {
      CustomSnackBar.showSuccessSnackbar('تم حفظ اختصار ${updated.label}');
    }
  }

  Future<void> _newInvoiceMacro() async {
    final products =
        await ref.read(masterDataRepositoryProvider).listProducts();
    if (!mounted) return;
    if (products.isEmpty) {
      CustomSnackBar.showWarningSnackbar('أضف منتجات أولاً لإنشاء اختصار بنود');
      return;
    }
    final macro = await showDialog<InvoiceShortcutMacro>(
      context: context,
      builder: (_) => _InvoiceMacroDialog(products: products),
    );
    if (macro == null) return;
    await ref.read(invoiceShortcutMacroProvider).save(macro);
    if (mounted)
      CustomSnackBar.showSuccessSnackbar(
        'تم حفظ اختصار الفاتورة ${macro.name}',
      );
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(shortcutNotifierProvider);
    return MyScaffold(
      appBar:
          showCompactPageAppBar(context)
              ? const BlurAppBar(title: Text('اختصارات لوحة المفاتيح'))
              : null,
      body: PremiumPage(
        maxWidth: 1120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageIntro(
              eyebrow: 'KEYBOARD',
              title: 'اختصارات لوحة المفاتيح',
              subtitle: 'خصص المفاتيح التي تفتح العمليات الشائعة بسرعة.',
              icon: Iconsax.keyboard,
            ),
            const SizedBox(height: 16),
            PremiumPanel(
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اضغط على أي عملية ثم اضغط التركيبة المطلوبة. الاختصارات لا تعمل أثناء الكتابة داخل الحقول.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PremiumPanel(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.colors.secondary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.playlist_add_rounded,
                      color: context.colors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اختصارات بنود الفاتورة',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'مثل Ctrl + E لإضافة 3 اندومي و6 مخلل فوراً',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _newInvoiceMacro,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إنشاء'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final macros = ref.watch(invoiceShortcutMacroProvider);
                if (!macros.loaded) {
                  Future.microtask(macros.load);
                  return const SizedBox.shrink();
                }
                if (macros.macros.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      macros.macros
                          .map(
                            (m) => Chip(
                              label: Text('${m.name}  •  ${m.displayLabel}'),
                              avatar: const Icon(Icons.playlist_add, size: 17),
                            ),
                          )
                          .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            if (!shortcuts.loaded)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 850 ? 2 : 1;
                  final items = shortcuts.shortcuts;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 104,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder:
                        (context, index) => _ShortcutCard(
                          shortcut: items[index],
                          onEdit: () => _edit(items[index]),
                        ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceMacroDialog extends StatefulWidget {
  const _InvoiceMacroDialog({required this.products});
  final List<Product> products;
  @override
  State<_InvoiceMacroDialog> createState() => _InvoiceMacroDialogState();
}

class _InvoiceMacroDialogState extends State<_InvoiceMacroDialog> {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final lines = <InvoiceShortcutLine>[];
  final keyFocus = FocusNode();
  String? productId;
  bool ctrl = true, shift = false, alt = false;
  LogicalKeyboardKey key = LogicalKeyboardKey.keyE;
  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('اختصار بنود فاتورة'),
    content: KeyboardListener(
      focusNode: keyFocus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent ||
            event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight ||
            event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight ||
            event.logicalKey == LogicalKeyboardKey.altLeft ||
            event.logicalKey == LogicalKeyboardKey.altRight)
          return;
        final keyboard = HardwareKeyboard.instance;
        setState(() {
          key = event.logicalKey;
          ctrl = keyboard.isControlPressed;
          shift = keyboard.isShiftPressed;
          alt = keyboard.isAltPressed;
        });
      },
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'اسم الاختصار، مثال: طلب الاندومي',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: productId,
                    hint: const Text('اختر منتجاً'),
                    isExpanded: true,
                    items:
                        widget.products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id!,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => productId = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 85,
                  child: TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية'),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final q = double.tryParse(quantity.text) ?? 0;
                    if (productId != null && q > 0)
                      setState(() {
                        lines.add(
                          InvoiceShortcutLine(
                            productId: productId!,
                            quantity: q,
                          ),
                        );
                        productId = null;
                        quantity.text = '1';
                      });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children:
                  lines.map((l) {
                    final p = widget.products.firstWhere(
                      (p) => p.id == l.productId,
                    );
                    return InputChip(
                      label: Text('${p.name} × ${l.quantity}'),
                      onDeleted: () => setState(() => lines.remove(l)),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'اضغط أي مفتاح الآن لالتقاطه، أو عدل الخيارات أدناه',
              style: TextStyle(fontSize: 11, color: context.colors.textDim),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: const Text('Ctrl'),
                  selected: ctrl,
                  onSelected: (v) => setState(() => ctrl = v),
                ),
                FilterChip(
                  label: const Text('Shift'),
                  selected: shift,
                  onSelected: (v) => setState(() => shift = v),
                ),
                FilterChip(
                  label: const Text('Alt'),
                  selected: alt,
                  onSelected: (v) => setState(() => alt = v),
                ),
                Chip(label: Text(key.keyLabel ?? key.debugName ?? 'مفتاح')),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed:
            name.text.trim().isEmpty || lines.isEmpty
                ? null
                : () => Navigator.pop(
                  context,
                  InvoiceShortcutMacro(
                    id: uuid.v4(),
                    name: name.text.trim(),
                    key: key,
                    keyLabel: key.keyLabel ?? 'مفتاح',
                    ctrl: ctrl,
                    shift: shift,
                    alt: alt,
                    lines: lines,
                  ),
                ),
        child: const Text('حفظ'),
      ),
    ],
  );
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.shortcut, required this.onEdit});
  final ShortcutModel shortcut;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => PremiumPanel(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Iconsax.keyboard, color: context.colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shortcut.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                shortcut.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.colors.textDim),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: Text(shortcut.displayLabel)),
      ],
    ),
  );
}

class _ShortcutCaptureDialog extends StatefulWidget {
  const _ShortcutCaptureDialog({required this.shortcut});
  final ShortcutModel shortcut;
  @override
  State<_ShortcutCaptureDialog> createState() => _ShortcutCaptureDialogState();
}

class _ShortcutCaptureDialogState extends State<_ShortcutCaptureDialog> {
  final _focus = FocusNode();
  late LogicalKeyboardKey _key;
  late bool _ctrl;
  late bool _shift;
  late bool _alt;

  @override
  void initState() {
    super.initState();
    _key = widget.shortcut.key;
    _ctrl = widget.shortcut.ctrl;
    _shift = widget.shortcut.shift;
    _alt = widget.shortcut.alt;
  }

  String get _label {
    final parts = <String>[];
    if (_ctrl) parts.add('Ctrl');
    if (_shift) parts.add('Shift');
    if (_alt) parts.add('Alt');
    parts.add(_key.keyLabel ?? _key.debugName ?? 'مفتاح');
    return parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('تعديل اختصار ${widget.shortcut.label}'),
    content: KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent ||
            event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight ||
            event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight ||
            event.logicalKey == LogicalKeyboardKey.altLeft ||
            event.logicalKey == LogicalKeyboardKey.altRight)
          return;
        final keyboard = HardwareKeyboard.instance;
        setState(() {
          _key = event.logicalKey;
          _ctrl = keyboard.isControlPressed;
          _shift = keyboard.isShiftPressed;
          _alt = keyboard.isAltPressed;
        });
      },
      child: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اضغط المفتاح أو التركيبة المطلوبة',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _label,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: const Text('Ctrl'),
                  selected: _ctrl,
                  onSelected: (v) => setState(() => _ctrl = v),
                ),
                FilterChip(
                  label: const Text('Shift'),
                  selected: _shift,
                  onSelected: (v) => setState(() => _shift = v),
                ),
                FilterChip(
                  label: const Text('Alt'),
                  selected: _alt,
                  onSelected: (v) => setState(() => _alt = v),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed:
            () => Navigator.pop(
              context,
              widget.shortcut.copyWith(
                key: _key,
                keyLabel: _key.keyLabel ?? _key.debugName ?? 'مفتاح',
                ctrl: _ctrl,
                shift: _shift,
                alt: _alt,
              ),
            ),
        child: const Text('حفظ'),
      ),
    ],
  );
}
