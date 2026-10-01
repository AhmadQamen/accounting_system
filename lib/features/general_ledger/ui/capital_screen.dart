import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/general_ledger/data/capital_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CapitalScreen extends ConsumerStatefulWidget {
  const CapitalScreen({super.key});

  @override
  ConsumerState<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends ConsumerState<CapitalScreen> {
  var _revision = 0;

  bool _allowed(String role) => const {
    'owner',
    'admin',
    'accountant',
    'manager',
  }.contains(role.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(localContextProvider).asData?.value;
    if (local == null) {
      return const MyScaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_allowed(local.role)) {
      return const MyScaffold(
        body: PremiumPage(
          child: EmptyState(
            title: 'هذه الصفحة للمحاسب أو المدير فقط',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    return MyScaffold(
      appBar: const BlurAppBar(title: Text('رأس المال والشركاء')),
      body: PremiumBackdrop(
        child: FutureBuilder<CapitalOverview>(
          key: ValueKey(_revision),
          future: ref.read(capitalRepositoryProvider).overview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('تعذر قراءة رأس المال: ${snapshot.error}'),
              );
            }
            return _body(context, local.currencyCode, snapshot.requireData);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String currency, CapitalOverview data) {
    final money =
        (int value) => Money(value).format(
          locale: Localizations.localeOf(context).toString(),
          currencyCode: currency,
        );
    return PremiumPage(
      maxWidth: 1180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Text(
                'يموّل رأس المال رصيد الصناديق الافتتاحي ويُرحّل بقيد متوازن.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _addPartner,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('إضافة شريك'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addContribution(data.partners),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('إيداع رأس مال'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          PremiumPanel(
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('إجمالي رأس المال المودع')),
                Text(
                  money(data.totalMinor),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // PremiumPage is vertically scrollable, therefore its child has an
          // unbounded height. Do not use Expanded or a nested ListView here.
          // Both caused the Capital page to fail layout on desktop and mobile.
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final partners = _partnersPanel(context, data, money);
              final movements = _contributionsPanel(context, data, money);
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [partners, const SizedBox(height: 12), movements],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: partners),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: movements),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _partnersPanel(
    BuildContext context,
    CapitalOverview data,
    String Function(int) money,
  ) => PremiumPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الشركاء',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 8),
        if (data.partners.isEmpty)
          const EmptyState(
            icon: Icons.people_outline,
            title: 'لا يوجد شركاء مسجلون',
            subtitle: 'يمكن الإيداع مباشرة في رأس مال المنشأة أو إضافة شركاء.',
          )
        else
          ...data.partners.map(
            (partner) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(partner.name.substring(0, 1))),
              title: Text(partner.name),
              subtitle: Text(
                partner.ownershipBps == null
                    ? 'نسبة الملكية غير محددة'
                    : 'نسبة الملكية ${(partner.ownershipBps! / 100).toStringAsFixed(2)}%',
              ),
              trailing: Text(
                money(partner.contributedMinor),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _contributionsPanel(
    BuildContext context,
    CapitalOverview data,
    String Function(int) money,
  ) => PremiumPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'إيداعات رأس المال',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 8),
        if (data.contributions.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'لا يوجد رأس مال مودع',
            subtitle: 'سجّل رأس المال أولاً، ثم خصص منه رصيداً افتتاحياً للصندوق.',
          )
        else
          ...data.contributions.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.south_west_rounded,
                color: context.colors.success,
              ),
              title: Text(item.partnerName ?? 'رأس مال المنشأة'),
              subtitle: Text(
                item.note ?? 'رأس مال غير مخصص لصندوق بعد',
              ),
              trailing: Text(
                money(item.amountMinor),
                style: TextStyle(
                  color: context.colors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _addPartner() async {
    final name = TextEditingController();
    final share = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('إضافة شريك'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الشريك'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: share,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'نسبة الملكية % (اختياري)',
                  ),
                ),
              ],
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
    try {
      if (ok == true) {
        final parsed = double.tryParse(share.text.trim().replaceAll(',', '.'));
        await ref
            .read(capitalRepositoryProvider)
            .addPartner(
              name: name.text,
              ownershipBps: parsed == null ? null : (parsed * 100).round(),
            );
        setState(() => _revision++);
      }
    } catch (error) {
      if (mounted) CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      name.dispose();
      share.dispose();
    }
  }

  Future<void> _addContribution(List<CapitalPartner> partners) async {
    String? partnerId;
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: const Text('تسجيل رأس المال'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: partnerId,
                          decoration: const InputDecoration(
                            labelText: 'الشريك',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('رأس مال المنشأة'),
                            ),
                            ...partners.map(
                              (partner) => DropdownMenuItem(
                                value: partner.id,
                                child: Text(partner.name),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) => setLocal(() => partnerId = value),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: note,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظة (اختياري)',
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
                      child: const Text('تسجيل الإيداع'),
                    ),
                  ],
                ),
          ),
    );
    try {
      if (ok == true) {
        await ref
            .read(capitalRepositoryProvider)
            .contribute(
              partnerId: partnerId,
              amountMinor: Money.fromMajor(amount.text),
              note: note.text,
            );
        ref.read(dataRevisionProvider.notifier).state++;
        setState(() => _revision++);
        if (mounted)
          CustomSnackBar.showSuccessSnackbar(
            'تم تسجيل رأس المال. خصص منه رصيد الصندوق الافتتاحي عند بدء الجرد.',
          );
      }
    } catch (error) {
      if (mounted) CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      amount.dispose();
      note.dispose();
    }
  }
}
