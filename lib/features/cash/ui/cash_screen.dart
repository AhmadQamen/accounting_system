import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

enum CashScreenMode { cashboxes, expenses, transfers, sessions }

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key, required this.mode});
  final CashScreenMode mode;

  String get title => switch (mode) {
    CashScreenMode.cashboxes => 'الصناديق',
    CashScreenMode.expenses => 'المصروفات',
    CashScreenMode.transfers => 'تحويلات الصندوق',
    CashScreenMode.sessions => 'جلسات الصندوق',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);
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

    return MyScaffold(
      appBar: compact ? BlurAppBar(title: Text(title)) : null,
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
            FutureBuilder<List<CashListItem>>(
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
                final rows = snapshot.data ?? const <CashListItem>[];
                final total = switch (mode) {
                  CashScreenMode.cashboxes => rows
                      .whereType<Cashbox>()
                      .fold<int>(
                        0,
                        (sum, row) => sum + row.currentBalanceMinor,
                      ),
                  CashScreenMode.expenses => rows
                      .whereType<Expense>()
                      .fold<int>(0, (sum, row) => sum + row.amountMinor),
                  CashScreenMode.transfers => rows
                      .whereType<CashTransfer>()
                      .fold<int>(0, (sum, row) => sum + row.amountMinor),
                  CashScreenMode.sessions =>
                    rows
                        .whereType<CashSession>()
                        .where((row) => row.status == 'open')
                        .length,
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

  Future<List<CashListItem>> _load(WidgetRef ref) async {
    final repo = ref.read(cashRepositoryProvider);
    return switch (mode) {
      CashScreenMode.cashboxes => List<CashListItem>.from(
        await repo.listCashboxes(),
      ),
      CashScreenMode.expenses => List<CashListItem>.from(
        await repo.listExpenses(),
      ),
      CashScreenMode.transfers => List<CashListItem>.from(
        await repo.listTransfers(),
      ),
      CashScreenMode.sessions => List<CashListItem>.from(
        await repo.listSessions(),
      ),
    };
  }

  Widget _cashRow(
    BuildContext context,
    WidgetRef ref,
    CashListItem row,
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

    switch (mode) {
      case CashScreenMode.cashboxes:
        final cashbox = row as Cashbox;
        icon = Iconsax.wallet_3;
        accent = colors.primary;
        titleText = cashbox.name;
        subtitleText = 'الرصيد الحالي من دفتر الحركات';
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                Money(cashbox.currentBalanceMinor).format(
                  locale: Localizations.localeOf(context).toString(),
                  currencyCode: currency,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                final id = cashbox.id;
                if (id == null) return;
                if (value == 'opening') {
                  await _openingBalance(context, ref, id);
                } else if (value == 'adjust') {
                  await _adjustment(context, ref, id);
                }
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
        if (cashbox.id != null) {
          onTap = () => _history(context, ref, cashbox.id!, currency);
        }
        break;
      case CashScreenMode.expenses:
        final expense = row as Expense;
        icon = Iconsax.money_send;
        accent = colors.error;
        titleText = expense.expenseNumber;
        subtitleText =
            '${expense.cashboxName ?? 'صندوق'} • ${_prettyDate(expense.occurredAt)}';
        trailing = Text(
          Money(expense.amountMinor).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          ),
          style: TextStyle(
            color: colors.error,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        );
        break;
      case CashScreenMode.transfers:
        final transfer = row as CashTransfer;
        icon = Iconsax.convert_card;
        accent = colors.info;
        titleText = transfer.transferNumber;
        subtitleText =
            '${transfer.fromCashboxName ?? 'صندوق'} ← ${transfer.toCashboxName ?? 'صندوق'} • ${_prettyDate(transfer.occurredAt)}';
        trailing = Text(
          Money(transfer.amountMinor).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          ),
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        );
        break;
      case CashScreenMode.sessions:
        final session = row as CashSession;
        final open = session.status == 'open';
        icon = open ? Icons.lock_open_rounded : Icons.lock_outline_rounded;
        accent = open ? colors.success : colors.textSecondary;
        titleText = session.cashboxName ?? 'صندوق';
        subtitleText =
            '${open ? 'جلسة مفتوحة' : 'جلسة مغلقة'} • ${_prettyDate(session.openedAt)}';
        trailing =
            open
                ? StatusPill(
                  label: 'مفتوحة',
                  color: colors.success,
                  icon: Icons.lock_open_rounded,
                  compact: true,
                )
                : Text(
                  'فرق ${Money(session.differenceMinor ?? 0).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                );
        if (open && session.id != null) {
          onTap = () => _closeSession(context, ref, session.id!, currency);
        }
        break;
    }

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                            leading,
                            const SizedBox(width: 12),
                            Expanded(child: identity),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 54),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: trailing,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: identity),
                      const SizedBox(width: 10),
                      Flexible(child: trailing),
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

  String _prettyDate(DateTime? value) {
    final d = value?.toLocal();
    if (d == null) return '-';
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
              (dialogContext) => AlertDialog(
                title: const Text('صندوق جديد'),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'الاسم'),
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
        if (ok == true && controller.text.trim().isNotEmpty)
          await ref
              .read(masterDataRepositoryProvider)
              .saveCashbox(name: controller.text);
        controller.dispose();
      } else if (boxes.isEmpty) {
        throw StateError('أضف صندوقاً أولاً');
      } else if (mode == CashScreenMode.expenses) {
        var box = boxes.first.id!;
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
        if (ok)
          await ref
              .read(cashRepositoryProvider)
              .postExpense(
                cashboxId: box,
                amountMinor: Money.fromMajor(amount.text),
                note: note.text,
              );
        amount.dispose();
        note.dispose();
      } else if (mode == CashScreenMode.transfers) {
        if (boxes.length < 2) throw StateError('تحتاج صندوقين على الأقل');
        await _transfer(context, ref, boxes);
      } else {
        var box = boxes.first.id!;
        final amount = TextEditingController(text: '0');
        final ok = await _moneyDialog(
          context,
          'فتح جلسة صندوق',
          boxes,
          (value) => box = value,
          amount,
          null,
        );
        if (ok)
          await ref
              .read(cashRepositoryProvider)
              .openSession(
                cashboxId: box,
                openingAmountMinor: Money.fromMajor(amount.text),
              );
        amount.dispose();
      }
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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
          (dialogContext) => AlertDialog(
            title: const Text('الرصيد الافتتاحي'),
            content: SizedBox(
              width: responsiveDialogWidth(context, 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ؛ استخدم قيمة سالبة إن لزم',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'ملاحظة'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('اعتماد'),
              ),
            ],
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
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
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
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('تسوية الصندوق'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: direction,
                          items: const [
                            DropdownMenuItem(value: 'in', child: Text('زيادة')),
                            DropdownMenuItem(value: 'out', child: Text('نقص')),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              setLocal(() => direction = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'الاتجاه',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: note,
                          decoration: const InputDecoration(
                            labelText: 'سبب التسوية',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('اعتماد'),
                    ),
                  ],
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
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
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
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 650),
              child: MyScaffold(
                appBar: BlurAppBar(
                  title: const Text('حركات الصندوق'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final amount = row.amountMinor;
                          final amountText =
                              '${row.direction == 'in' ? '+' : '-'}${Money(amount).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final identity = Row(
                                  children: [
                                    Icon(
                                      row.direction == 'in'
                                          ? Icons.south_west
                                          : Icons.north_east,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.kind,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_prettyDate(row.occurredAt)} • ${row.partyName ?? ''}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: context.colors.textDim,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                                final amountWidget = Text(
                                  amountText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                                if (constraints.maxWidth < 440)
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      identity,
                                      const SizedBox(height: 7),
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              start: 34,
                                            ),
                                        child: amountWidget,
                                      ),
                                    ],
                                  );
                                return Row(
                                  children: [
                                    Expanded(child: identity),
                                    const SizedBox(width: 12),
                                    Flexible(child: amountWidget),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    List<Cashbox> boxes,
  ) async {
    var from = boxes.first.id!;
    var to = boxes[1].id!;
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('تحويل بين الصناديق'),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: from,
                          items:
                              boxes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id!,
                                      child: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) setLocal(() => from = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'من صندوق',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: to,
                          items:
                              boxes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id!,
                                      child: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) setLocal(() => to = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'إلى صندوق',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('تحويل'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true)
      await ref
          .read(cashRepositoryProvider)
          .postTransfer(
            fromCashboxId: from,
            toCashboxId: to,
            amountMinor: Money.fromMajor(amount.text),
          );
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
          (dialogContext) => AlertDialog(
            title: const Text('إغلاق جلسة الصندوق'),
            content: TextField(
              controller: counted,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المعدود فعلياً',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إغلاق'),
              ),
            ],
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
          final expected = Money(result.expectedMinor).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          final difference = Money(result.differenceMinor).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('المتوقع: $expected • الفرق: $difference')),
          );
        }
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    counted.dispose();
  }

  Future<bool> _moneyDialog(
    BuildContext context,
    String title,
    List<Cashbox> boxes,
    ValueChanged<String> onBox,
    TextEditingController amount,
    TextEditingController? note,
  ) async {
    var box = boxes.first.id!;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: Text(title),
                  content: SizedBox(
                    width: responsiveDialogWidth(context, 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: box,
                          items:
                              boxes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id!,
                                      child: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setLocal(() => box = value);
                              onBox(value);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'الصندوق',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                        if (note != null) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: note,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () {
                        onBox(box);
                        Navigator.pop(dialogContext, true);
                      },
                      child: const Text('اعتماد'),
                    ),
                  ],
                ),
          ),
    );
    return ok == true;
  }
}
