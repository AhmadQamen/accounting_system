import 'dart:ui';

import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

enum CashScreenMode { cashboxes, expenses, transfers, sessions }

class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key, required this.mode});
  final CashScreenMode mode;

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late Future<List<Map<String, Object?>>> _future;

  CashScreenMode get mode => widget.mode;

  String get title => switch (mode) {
    CashScreenMode.cashboxes => 'الصناديق',
    CashScreenMode.expenses => 'المصروفات',
    CashScreenMode.transfers => 'تحويلات الصندوق',
    CashScreenMode.sessions => 'جلسات الصندوق',
  };

  IconData get modeIcon => switch (mode) {
    CashScreenMode.cashboxes => Iconsax.wallet_money,
    CashScreenMode.expenses => Iconsax.money_send,
    CashScreenMode.transfers => Iconsax.arrow_swap_horizontal,
    CashScreenMode.sessions => Iconsax.timer_1,
  };

  String get fabLabel => switch (mode) {
    CashScreenMode.cashboxes => 'صندوق جديد',
    CashScreenMode.expenses => 'مصروف جديد',
    CashScreenMode.transfers => 'تحويل جديد',
    CashScreenMode.sessions => 'فتح جلسة',
  };

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _future = _load(ref);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load(WidgetRef ref) => switch (mode) {
    CashScreenMode.cashboxes =>
      ref.read(cashRepositoryProvider).listCashboxes(),
    CashScreenMode.expenses => ref.read(cashRepositoryProvider).listExpenses(),
    CashScreenMode.transfers =>
      ref.read(cashRepositoryProvider).listTransfers(),
    CashScreenMode.sessions => ref.read(cashRepositoryProvider).listSessions(),
  };

  void _reload() {
    setState(() => _future = _load(ref));
    _entrance
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final compact = MediaQuery.sizeOf(context).width < 900;
    final (icon, accent, subtitle) = switch (mode) {
      CashScreenMode.cashboxes => (
        Iconsax.wallet_money,
        context.colors.primary,
        'أرصدة الصناديق وسجل الحركة والتسويات.',
      ),
      CashScreenMode.expenses => (
        Iconsax.money_send,
        context.colors.error,
        'مصروفات معتمدة مرتبطة بالصندوق مباشرة.',
      ),
      CashScreenMode.transfers => (
        Iconsax.convert_card,
        context.colors.info,
        'تحويلات داخلية موثقة بين الصناديق.',
      ),
      CashScreenMode.sessions => (
        Iconsax.clock,
        context.colors.secondary,
        'فتح وإغلاق جلسات الصندوق ومطابقة النقد.',
      ),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: Text(title)) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'CASH MANAGEMENT',
                title: title,
                subtitle: subtitle,
                icon: icon,
                actions: [
                  FilledButton.icon(
                    onPressed: () => _action(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(switch (mode) {
                      CashScreenMode.cashboxes => 'صندوق جديد',
                      CashScreenMode.expenses => 'مصروف جديد',
                      CashScreenMode.transfers => 'تحويل جديد',
                      CashScreenMode.sessions => 'فتح جلسة',
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, Object?>>>(
              future: _load(ref),
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
                    title: 'تعذر تحميل البيانات',
                    subtitle: '${snapshot.error}',
                  );
                }
                final rows = snapshot.data ?? const <Map<String, Object?>>[];
                final total = switch (mode) {
                  CashScreenMode.cashboxes => rows.fold<int>(
                    0,
                    (sum, row) =>
                        sum +
                        (((row['current_balance_minor'] as num?) ?? 0).toInt()),
                  ),
                  CashScreenMode.expenses => rows.fold<int>(
                    0,
                    (sum, row) =>
                        sum + (((row['amount_minor'] as num?) ?? 0).toInt()),
                  ),
                  CashScreenMode.transfers => rows.fold<int>(
                    0,
                    (sum, row) =>
                        sum + (((row['amount_minor'] as num?) ?? 0).toInt()),
                  ),
                  CashScreenMode.sessions =>
                    rows.where((row) => row['status'] == 'open').length,
                };
                final totalLabel =
                    mode == CashScreenMode.sessions
                        ? '$total'
                        : Money(total).format(
                          locale: Localizations.localeOf(context).toString(),
                          currencyCode: currency,
                        );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 700;
                        final width =
                            narrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              height: 132,
                              child: AnimatedEntrance(
                                delay: const Duration(milliseconds: 60),
                                child: MetricCard(
                                  label: switch (mode) {
                                    CashScreenMode.cashboxes =>
                                      'إجمالي السيولة',
                                    CashScreenMode.expenses =>
                                      'إجمالي المصروفات',
                                    CashScreenMode.transfers =>
                                      'قيمة التحويلات',
                                    CashScreenMode.sessions =>
                                      'الجلسات المفتوحة',
                                  },
                                  value: totalLabel,
                                  icon: icon,
                                  accent: accent,
                                  caption: switch (mode) {
                                    CashScreenMode.cashboxes =>
                                      'من دفتر حركات الصندوق',
                                    CashScreenMode.expenses =>
                                      '${rows.length} مستند مصروف',
                                    CashScreenMode.transfers =>
                                      '${rows.length} تحويل',
                                    CashScreenMode.sessions =>
                                      '${rows.length} جلسة في السجل',
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              height: 132,
                              child: AnimatedEntrance(
                                delay: const Duration(milliseconds: 95),
                                child: MetricCard(
                                  label: 'عدد السجلات',
                                  value: '${rows.length}',
                                  icon: Icons.description_outlined,
                                  accent: context.colors.secondary,
                                  caption: 'بيانات محفوظة محلياً',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 140),
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              title: 'السجل',
                              subtitle:
                                  rows.isEmpty
                                      ? 'لا توجد حركات مسجلة بعد'
                                      : 'آخر البيانات أولاً',
                              trailing:
                                  rows.isEmpty
                                      ? null
                                      : StatusPill(
                                        label: '${rows.length} سجل',
                                        color: accent,
                                        icon: icon,
                                      ),
                            ),
                            const SizedBox(height: 12),
                            if (rows.isEmpty)
                              EmptyState(
                                title: 'لا توجد بيانات بعد',
                                subtitle:
                                    'استخدم زر الإضافة في الأعلى لإنشاء أول سجل.',
                                icon: icon,
                              )
                            else
                              ...rows.indexed.map(
                                (entry) => _cashRow(
                                  context,
                                  ref,
                                  entry.$2,
                                  currency,
                                  showDivider: entry.$1 != rows.length - 1,
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

  Future<List<Map<String, Object?>>> _load(WidgetRef ref) => switch (mode) {
    CashScreenMode.cashboxes =>
      ref.read(cashRepositoryProvider).listCashboxes(),
    CashScreenMode.expenses => ref.read(cashRepositoryProvider).listExpenses(),
    CashScreenMode.transfers =>
      ref.read(cashRepositoryProvider).listTransfers(),
    CashScreenMode.sessions => ref.read(cashRepositoryProvider).listSessions(),
  };

  Widget _cashRow(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> row,
    String currency, {
    required bool showDivider,
  }) {
    final colors = context.colors;
    late final IconData icon;
    late final Color accent;
    late final String titleText;
    late final String subtitleText;
    late final Widget trailing;
    VoidCallback? onTap;

    if (mode == CashScreenMode.cashboxes) {
      icon = Iconsax.wallet_3;
      accent = colors.primary;
      titleText = '${row['name']}';
      subtitleText = 'الرصيد الحالي من دفتر الحركات';
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Money((row['current_balance_minor'] as num).toInt()).format(
              locale: Localizations.localeOf(context).toString(),
              currencyCode: currency,
            ),
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'opening')
                await _openingBalance(context, ref, row['id'] as String);
              if (value == 'adjust')
                await _adjustment(context, ref, row['id'] as String);
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'opening',
                    child: ListTile(
                      leading: Icon(Icons.add_box_outlined),
                      title: Text('رصيد افتتاحي'),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'adjust',
                    child: ListTile(
                      leading: Icon(Icons.tune_rounded),
                      title: Text('تسوية الصندوق'),
                      dense: true,
                    ),
                  ),
                ],
          ),
        ],
      );
      onTap = () => _history(context, ref, row['id'] as String, currency);
    } else if (mode == CashScreenMode.expenses) {
      icon = Iconsax.money_send;
      accent = colors.error;
      titleText = '${row['expense_number']}';
      subtitleText =
          '${row['cashbox_name']} • ${_prettyDate('${row['occurred_at']}')}';
      trailing = Text(
        Money((row['amount_minor'] as num).toInt()).format(
          locale: Localizations.localeOf(context).toString(),
          currencyCode: currency,
        ),
        style: TextStyle(
          color: colors.error,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      );
    } else if (mode == CashScreenMode.transfers) {
      icon = Iconsax.convert_card;
      accent = colors.info;
      titleText = '${row['transfer_number']}';
      subtitleText =
          '${row['from_cashbox_name']} ← ${row['to_cashbox_name']} • ${_prettyDate('${row['occurred_at']}')}';
      trailing = Text(
        Money((row['amount_minor'] as num).toInt()).format(
          locale: Localizations.localeOf(context).toString(),
          currencyCode: currency,
        ),
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      );
    } else {
      final open = row['status'] == 'open';
      icon = open ? Icons.lock_open_rounded : Icons.lock_outline_rounded;
      accent = open ? colors.success : colors.textSecondary;
      titleText = '${row['cashbox_name']}';
      subtitleText =
          '${open ? 'جلسة مفتوحة' : 'جلسة مغلقة'} • ${_prettyDate('${row['opened_at']}')}';
      trailing =
          open
              ? StatusPill(
                label: 'مفتوحة',
                color: colors.success,
                icon: Icons.lock_open_rounded,
                compact: true,
              )
              : Text(
                'فرق ${Money(((row['difference_minor'] as num?) ?? 0).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              );
      onTap =
          open
              ? () => _closeSession(context, ref, row['id'] as String, currency)
              : null;
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textDim,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }

  String _prettyDate(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _action(BuildContext context, WidgetRef ref) async {
    final boxes = await ref.read(cashRepositoryProvider).listCashboxes();
    if (!context.mounted) return;
    try {
      if (mode == CashScreenMode.cashboxes) {
        final controller = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => _ThemedDialog(
                title: 'صندوق جديد',
                content: _ThemedField(controller: controller, label: 'الاسم'),
                confirmLabel: 'حفظ',
                onCancel: () => Navigator.pop(dialogContext, false),
                onConfirm: () => Navigator.pop(dialogContext, true),
              ),
        );
        if (ok == true && controller.text.trim().isNotEmpty) {
          await ref
              .read(masterDataRepositoryProvider)
              .saveCashbox(name: controller.text);
        }
        controller.dispose();
      } else if (boxes.isEmpty) {
        throw StateError('أضف صندوقاً أولاً');
      } else if (mode == CashScreenMode.expenses) {
        var box = boxes.first['id'] as String;
        final amount = TextEditingController();
        final note = TextEditingController();
        final ok = await _moneyDialog(
          context,
          'مصروف جديد',
          boxes,
          (value) => box = value,
          amount,
          note,
        );
        if (ok) {
          await ref
              .read(cashRepositoryProvider)
              .postExpense(
                cashboxId: box,
                amountMinor: Money.fromMajor(amount.text),
                note: note.text,
              );
        }
        amount.dispose();
        note.dispose();
      } else if (mode == CashScreenMode.transfers) {
        if (boxes.length < 2) throw StateError('تحتاج صندوقين على الأقل');
        await _transfer(context, ref, boxes);
      } else {
        var box = boxes.first['id'] as String;
        final amount = TextEditingController(text: '0');
        final ok = await _moneyDialog(
          context,
          'فتح جلسة صندوق',
          boxes,
          (value) => box = value,
          amount,
          null,
        );
        if (ok) {
          await ref
              .read(cashRepositoryProvider)
              .openSession(
                cashboxId: box,
                openingAmountMinor: Money.fromMajor(amount.text),
              );
        }
        amount.dispose();
      }
      ref.read(dataRevisionProvider.notifier).state++;
      if (context.mounted) _reload();
    } catch (e) {
      if (context.mounted) _showError(context, '$e');
    }
  }

  Future<void> _openingBalance(
    BuildContext context,
    WidgetRef ref,
    String cashboxId,
  ) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => _ThemedDialog(
            title: 'الرصيد الافتتاحي',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemedField(
                  controller: amount,
                  label: 'المبلغ؛ استخدم قيمة سالبة إن لزم',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _ThemedField(controller: note, label: 'ملاحظة'),
              ],
            ),
            confirmLabel: 'اعتماد',
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(cashRepositoryProvider)
            .postOpeningBalance(
              cashboxId: cashboxId,
              amountMinor: Money.fromMajor(amount.text),
              note: note.text,
            );
        ref.read(dataRevisionProvider.notifier).state++;
        if (context.mounted) _reload();
      } catch (e) {
        if (context.mounted) _showError(context, '$e');
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> _adjustment(
    BuildContext context,
    WidgetRef ref,
    String cashboxId,
  ) async {
    var direction = 'in';
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => _ThemedDialog(
                  title: 'تسوية الصندوق',
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemedDropdown<String>(
                        value: direction,
                        label: 'الاتجاه',
                        items: const {'in': 'زيادة', 'out': 'نقص'},
                        onChanged: (value) {
                          if (value != null) setLocal(() => direction = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ThemedField(
                        controller: amount,
                        label: 'المبلغ',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _ThemedField(controller: note, label: 'سبب التسوية'),
                    ],
                  ),
                  confirmLabel: 'اعتماد',
                  onCancel: () => Navigator.pop(dialogContext, false),
                  onConfirm: () => Navigator.pop(dialogContext, true),
                ),
          ),
    );
    if (ok == true && note.text.trim().isNotEmpty) {
      try {
        await ref
            .read(cashRepositoryProvider)
            .postAdjustment(
              cashboxId: cashboxId,
              direction: direction,
              amountMinor: Money.fromMajor(amount.text),
              note: note.text,
            );
        ref.read(dataRevisionProvider.notifier).state++;
        if (context.mounted) _reload();
      } catch (e) {
        if (context.mounted) _showError(context, '$e');
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<void> _history(
    BuildContext context,
    WidgetRef ref,
    String cashboxId,
    String currency,
  ) async {
    final rows = await ref
        .read(cashRepositoryProvider)
        .transactionHistory(cashboxId: cashboxId);
    if (!context.mounted) return;
    final colors = context.colors;
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: colors.bgElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.border, width: .5),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.receipt_text,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'حركات الصندوق',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(
                            Iconsax.close_circle,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  Expanded(
                    child:
                        rows.isEmpty
                            ? _EmptyState(
                              icon: Iconsax.document,
                              label: 'لا توجد حركات',
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: rows.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final amount =
                                    (row['amount_minor'] as num).toInt();
                                final isIn = row['direction'] == 'in';
                                return _CashTile(
                                  dense: true,
                                  icon:
                                      isIn
                                          ? Iconsax.import_1
                                          : Iconsax.export_1,
                                  iconColor:
                                      isIn ? colors.success : colors.error,
                                  title: '${row['kind']}',
                                  subtitle:
                                      '${row['occurred_at']} • ${row['party_name'] ?? ''}',
                                  trailingValue:
                                      '${isIn ? '+' : '-'}${Money(amount).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
                                  trailingValueColor:
                                      isIn ? colors.success : colors.error,
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

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, Object?>> boxes,
  ) async {
    var from = boxes.first['id'] as String;
    var to = boxes[1]['id'] as String;
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => _ThemedDialog(
                  title: 'تحويل بين الصناديق',
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemedDropdown<String>(
                        value: from,
                        label: 'من صندوق',
                        items: {
                          for (final e in boxes)
                            e['id'] as String: '${e['name']}',
                        },
                        onChanged: (value) {
                          if (value != null) setLocal(() => from = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ThemedDropdown<String>(
                        value: to,
                        label: 'إلى صندوق',
                        items: {
                          for (final e in boxes)
                            e['id'] as String: '${e['name']}',
                        },
                        onChanged: (value) {
                          if (value != null) setLocal(() => to = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _ThemedField(
                        controller: amount,
                        label: 'المبلغ',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  confirmLabel: 'تحويل',
                  onCancel: () => Navigator.pop(dialogContext, false),
                  onConfirm: () => Navigator.pop(dialogContext, true),
                ),
          ),
    );
    if (ok == true) {
      try {
        await ref
            .read(cashRepositoryProvider)
            .postTransfer(
              fromCashboxId: from,
              toCashboxId: to,
              amountMinor: Money.fromMajor(amount.text),
            );
        ref.read(dataRevisionProvider.notifier).state++;
        if (context.mounted) _reload();
      } catch (e) {
        if (context.mounted) _showError(context, '$e');
      }
    }
    amount.dispose();
  }

  Future<void> _closeSession(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String currency,
  ) async {
    final counted = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => _ThemedDialog(
            title: 'إغلاق جلسة الصندوق',
            content: _ThemedField(
              controller: counted,
              label: 'المبلغ المعدود فعلياً',
              keyboardType: TextInputType.number,
            ),
            confirmLabel: 'إغلاق',
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () => Navigator.pop(dialogContext, true),
          ),
    );
    if (ok == true) {
      try {
        final result = await ref
            .read(cashRepositoryProvider)
            .closeSession(
              sessionId: sessionId,
              countedAmountMinor: Money.fromMajor(counted.text),
            );
        ref.read(dataRevisionProvider.notifier).state++;
        if (context.mounted) {
          _reload();
          final expected = Money(result['expected']!).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          final difference = Money(result['difference']!).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          _showInfo(context, 'المتوقع: $expected • الفرق: $difference');
        }
      } catch (e) {
        if (context.mounted) _showError(context, '$e');
      }
    }
    counted.dispose();
  }

  Future<bool> _moneyDialog(
    BuildContext context,
    String title,
    List<Map<String, Object?>> boxes,
    ValueChanged<String> onBox,
    TextEditingController amount,
    TextEditingController? note,
  ) async {
    var box = boxes.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => _ThemedDialog(
                  title: title,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ThemedDropdown<String>(
                        value: box,
                        label: 'الصندوق',
                        items: {
                          for (final e in boxes)
                            e['id'] as String: '${e['name']}',
                        },
                        onChanged: (value) {
                          if (value != null) {
                            setLocal(() => box = value);
                            onBox(value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _ThemedField(
                        controller: amount,
                        label: 'المبلغ',
                        keyboardType: TextInputType.number,
                      ),
                      if (note != null) ...[
                        const SizedBox(height: 12),
                        _ThemedField(controller: note, label: 'ملاحظة'),
                      ],
                    ],
                  ),
                  confirmLabel: 'اعتماد',
                  onCancel: () => Navigator.pop(dialogContext, false),
                  onConfirm: () {
                    onBox(box);
                    Navigator.pop(dialogContext, true);
                  },
                ),
          ),
    );
    return ok == true;
  }

  void _showError(BuildContext context, String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message),
      ),
    );
  }

  void _showInfo(BuildContext context, String message) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: .5),
        ),
        content: Text(message, style: TextStyle(color: colors.textPrimary)),
      ),
    );
  }
}

// =====================================================================
// 🧩 UI Components — كل شي هون واجهة بس، ما في منطق أعمال
// =====================================================================

class _GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GlassAppBar({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AppBar(
          backgroundColor: colors.bgPage.withValues(alpha: .82),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: colors.border, width: .5)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .16),
                ),
                child: Icon(icon, size: 18, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowFab extends StatefulWidget {
  const _GlowFab({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_GlowFab> createState() => _GlowFabState();
}

class _GlowFabState extends State<_GlowFab> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : (_hover ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  colors.primary.withValues(alpha: _hover ? 1 : .92),
                  colors.secondary.withValues(alpha: _hover ? .9 : .8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: _hover ? .35 : .22),
                  blurRadius: _hover ? 22 : 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.add, size: 18, color: Colors.black87),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedRow extends StatelessWidget {
  const _AnimatedRow({
    required this.controller,
    required this.index,
    required this.total,
    required this.child,
  });
  final AnimationController controller;
  final int index;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clampedTotal = total.clamp(1, 12);
    final start = (index / clampedTotal) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

class _CashTile extends StatefulWidget {
  const _CashTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingValue,
    this.trailingValueColor,
    this.trailingWidget,
    this.menu,
    this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailingValue;
  final Color? trailingValueColor;
  final Widget? trailingWidget;
  final Widget? menu;
  final VoidCallback? onTap;
  final bool dense;

  @override
  State<_CashTile> createState() => _CashTileState();
}

class _CashTileState extends State<_CashTile> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tappable = widget.onTap != null;

    return MouseRegion(
      onEnter: tappable ? (_) => setState(() => _hover = true) : null,
      onExit: tappable ? (_) => setState(() => _hover = false) : null,
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
        onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.99 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.dense ? 10 : 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colors.bgElevated,
              border: Border.all(
                color:
                    _hover
                        ? widget.iconColor.withValues(alpha: .4)
                        : colors.border,
                width: .5,
              ),
              boxShadow:
                  _hover
                      ? [
                        BoxShadow(
                          color: widget.iconColor.withValues(alpha: .12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(widget.dense ? 8 : 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.iconColor.withValues(
                      alpha: _hover ? .22 : .14,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: widget.dense ? 16 : 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          fontSize: widget.dense ? 14 : 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.trailingWidget != null)
                  widget.trailingWidget!
                else if (widget.trailingValue != null)
                  Text(
                    widget.trailingValue!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: widget.trailingValueColor ?? colors.textPrimary,
                    ),
                  ),
                if (widget.menu != null) widget.menu!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4), width: .5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: colors.textSecondary.withValues(alpha: .5),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

class _ThemedDialog extends StatelessWidget {
  const _ThemedDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });
  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border, width: .5),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: colors.textPrimary,
        ),
      ),
      content: SizedBox(width: 420, child: content),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text('إلغاء', style: TextStyle(color: colors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onConfirm,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _ThemedField extends StatelessWidget {
  const _ThemedField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.bgPage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border, width: .5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border, width: .5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1),
        ),
      ),
    );
  }
}

class _ThemedDropdown<T> extends StatelessWidget {
  const _ThemedDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final String label;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: colors.bgElevated,
      style: TextStyle(color: colors.textPrimary),
      items:
          items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.bgPage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border, width: .5),
        ),
      ),
    );
  }
}
