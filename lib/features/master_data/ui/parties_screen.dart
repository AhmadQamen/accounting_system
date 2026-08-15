import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/ui/party_details_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key, this.filterType});
  final String? filterType;

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> _load() => ref
      .read(masterDataRepositoryProvider)
      .listParties(type: widget.filterType, search: search.text);

  String get _title =>
      widget.filterType == 'customer'
          ? 'العملاء'
          : widget.filterType == 'supplier'
          ? 'الموردون'
          : 'الأطراف';

  String get _subtitle =>
      widget.filterType == 'customer'
          ? 'متابعة العملاء وأرصدة الذمم وحركة الحساب.'
          : widget.filterType == 'supplier'
          ? 'إدارة الموردين والمبالغ المستحقة وحركة الحساب.'
          : 'العملاء والموردون وحساباتهم في مكان واحد.';

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final compact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: compact ? AppBar(title: Text(_title)) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow:
                    widget.filterType == 'supplier' ? 'SUPPLIERS' : 'PARTIES',
                title: _title,
                subtitle: _subtitle,
                icon:
                    widget.filterType == 'supplier'
                        ? Iconsax.truck_fast
                        : Iconsax.people,
                actions: [
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: Text(
                      widget.filterType == 'supplier'
                          ? 'مورد جديد'
                          : 'إضافة طرف',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Map<String, Object?>>>(
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 340,
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
                final receivable = rows.fold<int>(0, (sum, row) {
                  final value =
                      ((row['current_balance_minor'] as num?) ?? 0).toInt();
                  return sum + (value > 0 ? value : 0);
                });
                final payable = rows.fold<int>(0, (sum, row) {
                  final value =
                      ((row['current_balance_minor'] as num?) ?? 0).toInt();
                  return sum + (value < 0 ? -value : 0);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 680;
                        final width =
                            narrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 3;
                        final stats = [
                          (
                            'عدد السجلات',
                            '${rows.length}',
                            Iconsax.people,
                            context.colors.primary,
                            'نشط حالياً',
                          ),
                          (
                            'مستحق لنا',
                            _money(context, receivable, currency),
                            Iconsax.arrow_down_2,
                            context.colors.success,
                            'أرصدة مدينة',
                          ),
                          (
                            'مستحق علينا',
                            _money(context, payable, currency),
                            Iconsax.arrow_up_2,
                            context.colors.warning,
                            'أرصدة دائنة',
                          ),
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
                            Row(
                              children: [
                                Expanded(
                                  child: PremiumSearchField(
                                    controller: search,
                                    hintText: 'بحث بالاسم أو رقم الهاتف…',
                                    onChanged: (_) => setState(() {}),
                                    trailing:
                                        search.text.isEmpty
                                            ? null
                                            : IconButton(
                                              onPressed: () {
                                                search.clear();
                                                setState(() {});
                                              },
                                              icon: const Icon(
                                                Iconsax.close_circle,
                                                size: 18,
                                              ),
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusPill(
                                  label: '${rows.length} سجل',
                                  color: context.colors.primary,
                                  icon: Iconsax.people,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (rows.isEmpty)
                              EmptyState(
                                title:
                                    search.text.trim().isEmpty
                                        ? 'لا توجد بيانات بعد'
                                        : 'لا توجد نتائج مطابقة',
                                subtitle:
                                    search.text.trim().isEmpty
                                        ? 'أضف أول طرف لتبدأ متابعة الذمم والحركات.'
                                        : 'جرّب عبارة بحث مختلفة.',
                                icon: Iconsax.people,
                              )
                            else
                              ...rows.indexed.map(
                                (entry) => _PartyRow(
                                  row: entry.$2,
                                  currency: currency,
                                  onTap:
                                      () => showDialog(
                                        context: context,
                                        builder:
                                            (_) => PartyDetailsDialog(
                                              party: entry.$2,
                                            ),
                                      ),
                                  onEdit: () => _edit(row: entry.$2),
                                  onArchive: () => _archive(entry.$2),
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

  String _money(BuildContext context, int value, String currency) =>
      Money(value).format(
        locale: Localizations.localeOf(context).toString(),
        currencyCode: currency,
      );

  Future<void> _edit({Map<String, Object?>? row}) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final phone = TextEditingController(text: row?['phone']?.toString() ?? '');
    var type = row?['type']?.toString() ?? widget.filterType ?? 'customer';
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setLocal) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        row == null
                            ? Icons.person_add_alt_1_outlined
                            : Icons.manage_accounts_outlined,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(row == null ? 'إضافة طرف' : 'تعديل الطرف'),
                    ],
                  ),
                  content: SizedBox(
                    width: 430,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'الاسم',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phone,
                          decoration: const InputDecoration(
                            labelText: 'الهاتف',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: type,
                          items: const [
                            DropdownMenuItem(
                              value: 'customer',
                              child: Text('عميل'),
                            ),
                            DropdownMenuItem(
                              value: 'supplier',
                              child: Text('مورد'),
                            ),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('عميل ومورد'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setLocal(() => type = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'النوع',
                            prefixIcon: Icon(Icons.category_outlined),
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
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Iconsax.tick_circle, size: 17),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
          ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref
          .read(masterDataRepositoryProvider)
          .saveParty(
            id: row?['id'] as String?,
            name: name.text,
            phone: phone.text,
            type: type,
          );
      ref.read(dataRevisionProvider.notifier).state++;
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _archive(Map<String, Object?> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('أرشفة الطرف'),
            content: Text(
              'هل تريد أرشفة ${row['name']}؟ ستبقى كل الحركات التاريخية محفوظة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('أرشفة'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(masterDataRepositoryProvider)
            .archiveParty(row['id'] as String);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.row,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.showDivider,
  });

  final Map<String, Object?> row;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final balance = ((row['current_balance_minor'] as num?) ?? 0).toInt();
    final balanceColor =
        balance > 0
            ? colors.success
            : balance < 0
            ? colors.warning
            : colors.textSecondary;
    final type = '${row['type']}';
    final typeLabel =
        type == 'customer'
            ? 'عميل'
            : type == 'supplier'
            ? 'مورد'
            : 'عميل ومورد';
    final name = '${row['name']}';
    final initial = name.trim().isEmpty ? '؟' : name.trim().substring(0, 1);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${row['phone'] ?? 'بدون هاتف'}',
                          style: TextStyle(
                            color: colors.textDim,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 720)
                    Expanded(
                      child: StatusPill(
                        label: typeLabel,
                        color: colors.info,
                        compact: true,
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Money(balance.abs()).format(
                            locale: Localizations.localeOf(context).toString(),
                            currencyCode: currency,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: balanceColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          balance > 0
                              ? 'مدين لنا'
                              : balance < 0
                              ? 'مستحق له'
                              : 'متوازن',
                          style: TextStyle(
                            color: colors.textDim,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'خيارات',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'archive') onArchive();
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('تعديل'),
                              dense: true,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: ListTile(
                              leading: Icon(Icons.archive_outlined),
                              title: Text('أرشفة'),
                              dense: true,
                            ),
                          ),
                        ],
                  ),
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
