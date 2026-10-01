import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:accounting_system/features/cash/ui/cashbox_details_screen.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:accounting_system/features/master_data/ui/parties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

enum CashScreenMode { cashDesk, cashboxes, expenses, transfers, sessions }

/// A focused expense form for the common "create document" flow. It is not a
/// separate page, so closing it always returns the user to the screen that
/// started the action.
Future<void> showExpenseDocumentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ExpenseDocumentDialog(),
  );
}

class _ExpenseDocumentDialog extends ConsumerStatefulWidget {
  const _ExpenseDocumentDialog();

  @override
  ConsumerState<_ExpenseDocumentDialog> createState() =>
      _ExpenseDocumentDialogState();
}

class _ExpenseDocumentDialogState extends ConsumerState<_ExpenseDocumentDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _cashboxId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<Cashbox> cashboxes) async {
    final cashboxId = _cashboxId;
    if (cashboxId == null) return;
    try {
      setState(() => _saving = true);
      await ref.read(cashRepositoryProvider).postExpense(
        cashboxId: cashboxId,
        amountMinor: Money.fromMajor(_amount.text),
        note: _note.text,
      );
      ref.read(dataRevisionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.pop(context);
      CustomSnackBar.showSuccessSnackbar('تم تسجيل المصروف');
    } catch (error) {
      if (mounted) CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Cashbox>>(
      future: ref.read(cashRepositoryProvider).listCashboxes(),
      builder: (context, snapshot) {
        final boxes = snapshot.data ?? const <Cashbox>[];
        if (boxes.isNotEmpty && !_cashboxIdSet(boxes)) {
          _cashboxId = boxes.first.id;
        }
        return AlertDialog(
          title: const Text('مصروف جديد'),
          content: SizedBox(
            width: responsiveDialogWidth(context, 440),
            child: snapshot.connectionState != ConnectionState.done
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : boxes.isEmpty
                ? const Text('أضف صندوقاً أولاً لتسجيل المصروف.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _cashboxId,
                        decoration: const InputDecoration(labelText: 'الصندوق'),
                        items: boxes
                            .map(
                              (box) => DropdownMenuItem(
                                value: box.id,
                                child: Text(box.name),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _cashboxId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amount,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المبلغ'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _note,
                        enabled: !_saving,
                        decoration: const InputDecoration(labelText: 'البيان'),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: boxes.isEmpty || _saving ? null : () => _save(boxes),
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'جارٍ الحفظ…' : 'اعتماد المصروف'),
            ),
          ],
        );
      },
    );
  }

  bool _cashboxIdSet(List<Cashbox> boxes) =>
      boxes.any((box) => box.id == _cashboxId);
}

class _CashOperationsPanel extends StatelessWidget {
  const _CashOperationsPanel();

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String, IconData, _CashWorkspace)>[
      (
        'فاتورة بيع',
        'تسجيل قبض ومبيعات جديدة',
        Iconsax.receipt_add,
        _CashWorkspace.sale,
      ),
      (
        'فاتورة شراء',
        'تسجيل دفع ومشتريات',
        Iconsax.shopping_cart,
        _CashWorkspace.purchase,
      ),
      (
        'مصروف',
        'تسجيل مصروف من الصندوق',
        Iconsax.money_send,
        _CashWorkspace.expense,
      ),
      (
        'دفعة أو سلفة',
        'إدارة حسابات العملاء والموردين',
        Iconsax.wallet_money,
        _CashWorkspace.payment,
      ),
    ];
    return PremiumPanel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'إضافة حركة للصندوق',
            subtitle: 'اختر العملية التي تريد تسجيلها',
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 920
                      ? 4
                      : constraints.maxWidth >= 580
                      ? 2
                      : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    actions
                        .map(
                          (action) => SizedBox(
                            width: width,
                            child: _CashOperationButton(
                              title: action.$1,
                              subtitle: action.$2,
                              icon: action.$3,
                              onTap:
                                  () => _openCashWorkspace(context, action.$4),
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _CashWorkspace { sale, purchase, expense, payment }

Future<void> _openCashWorkspace(BuildContext context, _CashWorkspace action) {
  if (action == _CashWorkspace.sale) {
    return showNewDocumentDialog(
      context,
      kind: DocumentKind.sale,
      onExpenseRequested: showExpenseDocumentDialog,
    );
  }
  if (action == _CashWorkspace.purchase) {
    return showNewDocumentDialog(
      context,
      kind: DocumentKind.purchase,
      onExpenseRequested: showExpenseDocumentDialog,
    );
  }
  if (action == _CashWorkspace.expense) {
    return showExpenseDocumentDialog(context);
  }
  final title = switch (action) {
    _CashWorkspace.sale => 'فاتورة بيع جديدة',
    _CashWorkspace.purchase => 'فاتورة شراء جديدة',
    _CashWorkspace.expense => 'مصروف جديد',
    _CashWorkspace.payment => 'دفعة أو سلفة',
  };
  final child = switch (action) {
    _CashWorkspace.sale => const NewDocumentScreen(
      kind: DocumentKind.sale,
      embedded: true,
    ),
    _CashWorkspace.purchase => const NewDocumentScreen(
      kind: DocumentKind.purchase,
      embedded: true,
    ),
    _CashWorkspace.expense => const SizedBox.shrink(),
    _CashWorkspace.payment => const PartiesScreen(),
  };
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final width = size.width < 700 ? size.width : 1180.0;
      final height = size.height < 720 ? size.height : size.height * .88;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 700 ? 0 : 24,
          vertical: size.height < 720 ? 0 : 24,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (action != _CashWorkspace.sale &&
                  action != _CashWorkspace.purchase)
                PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'إغلاق $title',
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
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

class _CashOperationButton extends StatelessWidget {
  const _CashOperationButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.bgPage.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: colors.primary, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (MediaQuery.sizeOf(context).width < 760) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textDim, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_rounded, color: colors.textDim, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashDeskHeader extends StatelessWidget {
  const _CashDeskHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Iconsax.wallet_money, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الصندوق',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'الحركة النقدية والسجل اليومي',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key, required this.mode});
  final CashScreenMode mode;

  String get title => switch (mode) {
    CashScreenMode.cashDesk => 'الصندوق',
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
      CashScreenMode.cashDesk => (
        Iconsax.wallet_money,
        context.colors.primary,
        'مركز الحركة النقدية: البيع والشراء والمصروفات والدفعات.',
      ),
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
            if (mode == CashScreenMode.cashDesk)
              const _CashDeskHeader()
            else
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
                        CashScreenMode.cashDesk => '',
                        CashScreenMode.cashboxes => 'صندوق جديد',
                        CashScreenMode.expenses => 'مصروف جديد',
                        CashScreenMode.transfers => 'تحويل جديد',
                        CashScreenMode.sessions => 'فتح جلسة',
                      }),
                    ),
                  ],
                ),
              ),
            SizedBox(height: mode == CashScreenMode.cashDesk ? 10 : 20),
            if (mode == CashScreenMode.cashDesk) ...[
              const _CashOperationsPanel(),
              const SizedBox(height: 16),
            ],
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
                  CashScreenMode.cashDesk => rows
                      .whereType<CashTransaction>()
                      .fold<int>(
                        0,
                        (sum, row) =>
                            sum +
                            (row.direction == 'in'
                                ? row.amountMinor
                                : -row.amountMinor),
                      ),
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

                if (mode == CashScreenMode.cashDesk) {
                  return _cashDeskLedger(
                    context,
                    ref,
                    rows,
                    currency,
                    totalLabel,
                    accent,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 12) / 2;
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
                                    CashScreenMode.cashDesk =>
                                      'السيولة المتاحة',
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
                                    CashScreenMode.cashDesk =>
                                      'إجمالي أرصدة الصناديق',
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

  Widget _cashDeskLedger(
    BuildContext context,
    WidgetRef ref,
    List<CashListItem> rows,
    String currency,
    String totalLabel,
    Color accent,
  ) {
    final transactions = rows.whereType<CashTransaction>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Iconsax.wallet_money, color: accent, size: 19),
              const SizedBox(width: 9),
              const Text(
                'السيولة الحالية',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                totalLabel,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 14),
              StatusPill(
                label: '${transactions.length} حركة',
                color: accent,
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumPanel(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.sizeOf(context).height - 330).clamp(
                340,
                620,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'سجل الحركات',
                  subtitle:
                      transactions.isEmpty
                          ? 'لا توجد حركة نقدية مسجلة بعد'
                          : 'آخر الحركات النقدية أولاً',
                ),
                const SizedBox(height: 8),
                if (transactions.isEmpty)
                  const SizedBox(
                    height: 270,
                    child: EmptyState(
                      title: 'السجل فارغ',
                      subtitle:
                          'ستظهر هنا عمليات البيع والشراء والمصروفات والدفعات.',
                      icon: Iconsax.receipt_text,
                    ),
                  )
                else
                  ...transactions.indexed.map(
                    (entry) => _cashRow(
                      context,
                      ref,
                      entry.$2,
                      currency,
                      showDivider: entry.$1 != transactions.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<List<CashListItem>> _load(WidgetRef ref) async {
    final repo = ref.read(cashRepositoryProvider);
    return switch (mode) {
      CashScreenMode.cashDesk => List<CashListItem>.from(
        await repo.transactionHistory(),
      ),
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
      case CashScreenMode.cashDesk:
        final transaction = row as CashTransaction;
        icon =
            transaction.direction == 'in'
                ? Icons.south_west_rounded
                : Icons.north_east_rounded;
        accent =
            transaction.direction == 'in' ? colors.success : colors.warning;
        titleText = _transactionLabel(transaction.kind);
        subtitleText =
            '${_prettyDate(transaction.occurredAt)}${transaction.partyName == null ? '' : ' • ${transaction.partyName}'}';
        trailing = Text(
          '${transaction.direction == 'in' ? '+' : '−'}${Money(transaction.amountMinor).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)}',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        );
        break;
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
                if (value == 'adjust') {
                  await _adjustment(context, ref, id);
                }
              },
              itemBuilder:
                  (_) => const [
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
          onTap =
              () => AppNavigation.open(
                AppRoute(
                  type: RouteType.cashboxDetails,
                  args: CashboxDetailsArgs(id: cashbox.id!, name: cashbox.name),
                ),
              );
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

  String _transactionLabel(String kind) => switch (kind) {
    'opening_balance' => 'رصيد افتتاحي',
    'sale_payment' => 'قبض فاتورة بيع',
    'purchase_payment' => 'دفع فاتورة شراء',
    'sale_refund' => 'رد مبيعات',
    'purchase_refund' => 'رد مشتريات',
    'expense' => 'مصروف',
    'transfer' => 'تحويل صندوق',
    'adjustment' => 'تسوية صندوق',
    'party_payment' => 'دفعة / سلفة',
    'reversal' => 'قيد عكسي',
    _ => 'حركة صندوق',
  };

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
        final start = await ref
            .read(cashRepositoryProvider)
            .sessionStartInfo(box);
        if (!context.mounted) return;
        final amount = TextEditingController();
        final ok = await _moneyDialog(
          context,
          start.needsInitialDeposit
              ? 'بدء أول جرد للصندوق'
              : 'بدء جرد صندوق جديد',
          boxes,
          (value) => box = value,
          amount,
          null,
          amountLabel:
              start.needsInitialDeposit
                  ? 'الرصيد الافتتاحي (لا يتجاوز رأس المال غير المخصص)'
                  : 'يُرحّل الرصيد تلقائياً من الدورة السابقة',
          amountEnabled: start.needsInitialDeposit,
        );
        if (ok) {
          final selectedStart = await ref
              .read(cashRepositoryProvider)
              .sessionStartInfo(box);
          if (selectedStart.needsInitialDeposit) {
            await ref.read(cashRepositoryProvider).postOpeningBalance(
              cashboxId: box,
              amountMinor: Money.fromMajor(amount.text),
            );
          }
          await ref
              .read(cashRepositoryProvider)
              .openSession(cashboxId: box, initialDepositMinor: null);
        }
        amount.dispose();
      }
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (e) {
      if (context.mounted) CustomSnackBar.showErrorSnackbar('$e');
    }
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
        if (context.mounted) CustomSnackBar.showErrorSnackbar('$e');
      }
    }
    amount.dispose();
    note.dispose();
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
        final countedMinor = Money.fromMajor(counted.text);
        final preview = await ref
            .read(cashRepositoryProvider)
            .previewCloseSession(
              sessionId: sessionId,
              countedAmountMinor: countedMinor,
            );
        if (!context.mounted) return;
        if (preview.differenceMinor != 0) {
          final expected = Money(preview.expectedMinor).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          final difference = Money(preview.differenceMinor.abs()).format(
            locale: Localizations.localeOf(context).toString(),
            currencyCode: currency,
          );
          final continueClosing = await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AlertDialog(
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color: context.colors.warning,
                  ),
                  title: const Text('الرصيد غير مطابق'),
                  content: Text(
                    'المتوقع $expected، والفرق $difference. '
                    'لن يُنشأ تعديل تلقائي. هل تريد إغلاق الجرد مع تسجيل الفرق؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('العودة للمراجعة'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('إغلاق مع تسجيل الفرق'),
                    ),
                  ],
                ),
          );
          if (continueClosing != true) return;
        }
        final result = await ref
            .read(cashRepositoryProvider)
            .closeSession(
              sessionId: sessionId,
              countedAmountMinor: countedMinor,
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
          CustomSnackBar.showInfoSnackbar(
            'المتوقع: $expected • الفرق: $difference',
          );
        }
      } catch (e) {
        if (context.mounted) CustomSnackBar.showErrorSnackbar('$e');
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
    TextEditingController? note, {
    String amountLabel = 'المبلغ',
    bool amountEnabled = true,
  }) async {
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
                          enabled: amountEnabled,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: amountLabel),
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
