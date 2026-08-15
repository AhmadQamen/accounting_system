import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';

class FinancialYearsScreen extends ConsumerWidget {
  const FinancialYearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currentId = ref.watch(localContextProvider).asData?.value.financialYearId;
    final compact = showCompactPageAppBar(context);

    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('السنوات المالية')) : null,
      body: PremiumPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedEntrance(
              child: PageIntro(
                eyebrow: 'FINANCIAL PERIODS',
                title: 'السنوات المالية',
                subtitle: 'افصل الفترات المحاسبية بوضوح، وحدد السنة الحالية قبل اعتماد المستندات.',
                icon: Icons.calendar_month_outlined,
                actions: [
                  FilledButton.icon(
                    onPressed: () => _createYear(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('سنة مالية جديدة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<FinancialYear>>(
              future: ref.read(masterDataRepositoryProvider).listFinancialYears(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) return EmptyState(icon: Iconsax.warning_2, title: 'تعذر تحميل السنوات المالية', subtitle: '${snapshot.error}');
                final rows = snapshot.data ?? const <FinancialYear>[];
                final openCount = rows.where((r) => r.isOpen).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 680;
                        final width = narrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                                child: MetricCard(
                                label: 'الفترات المسجلة',
                                value: '${rows.length}',
                                icon: Icons.calendar_month_outlined,
                                accent: context.colors.primary,
                                caption: '$openCount مفتوحة حالياً',
                              ),
                            ),
                            SizedBox(
                              width: width,
                                child: MetricCard(
                                label: 'السنة الحالية',
                                value: rows.where((r) => r.id == currentId).map((e) => e.name).firstOrNull ?? '—',
                                icon: Iconsax.tick_circle,
                                accent: context.colors.success,
                                caption: 'تستقبل المستندات الجديدة',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'السجل المالي', subtitle: 'الفترات المفتوحة والمغلقة والحالية'),
                            const SizedBox(height: 14),
                            if (rows.isEmpty)
                              const EmptyState(title: 'لا توجد سنوات مالية', subtitle: 'أنشئ سنة مالية قبل البدء بإدخال المستندات.', icon: Icons.calendar_month_outlined)
                            else
                              ...rows.indexed.map((entry) => _YearRow(
                                    row: entry.$2,
                                    currentId: currentId,
                                    showDivider: entry.$1 != rows.length - 1,
                                    onAction: (action) => _handleAction(context, ref, entry.$2.id!, action),
                                  )),
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

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String id, String action) async {
    try {
      if (action == 'activate') {
        await ref.read(masterDataRepositoryProvider).activateFinancialYear(id);
        ref.invalidate(localContextProvider);
      } else if (action == 'close') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('إغلاق السنة المالية'),
            content: const Text('بعد الإغلاق لن يمكن إنشاء مستندات جديدة على هذه السنة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إغلاق')),
            ],
          ),
        );
        if (confirmed == true) await ref.read(masterDataRepositoryProvider).closeFinancialYear(id);
      }
      ref.read(dataRevisionProvider.notifier).state++;
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _createYear(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final nextYear = now.year + 1;
    final name = TextEditingController(text: '$nextYear');
    var start = DateTime(nextYear, 1, 1);
    var end = DateTime(nextYear, 12, 31, 23, 59, 59);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Row(children: [Icon(Icons.calendar_month_outlined, color: context.colors.primary), const SizedBox(width: 10), const Text('سنة مالية جديدة')]),
          content: SizedBox(
            width: responsiveDialogWidth(context, 470),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم السنة', prefixIcon: Icon(Icons.calendar_month_outlined))),
                const SizedBox(height: 12),
                _DateChoice(
                  title: 'تاريخ البداية',
                  date: start,
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2200));
                    if (picked != null) setLocal(() => start = picked);
                  },
                ),
                const SizedBox(height: 8),
                _DateChoice(
                  title: 'تاريخ النهاية',
                  date: end,
                  onTap: () async {
                    final picked = await showDatePicker(context: dialogContext, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2200));
                    if (picked != null) setLocal(() => end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Iconsax.tick_circle, size: 17), label: const Text('إنشاء')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ref.read(masterDataRepositoryProvider).createFinancialYear(name: name.text, startsOn: start, endsOn: end);
        ref.read(dataRevisionProvider.notifier).state++;
      } catch (error) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    name.dispose();
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({required this.row, required this.currentId, required this.showDivider, required this.onAction});
  final FinancialYear row;
  final String? currentId;
  final bool showDivider;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = row.id!;
    final open = row.isOpen;
    final current = id == currentId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final identity = Row(
                children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: (open ? colors.success : colors.textSecondary).withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(open ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: open ? colors.success : colors.textSecondary, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                        if (current) StatusPill(label: 'الحالية', color: colors.primary, compact: true),
                      ]),
                      const SizedBox(height: 3),
                      Text('${row.startsOn.toLocal().toString().split(' ').first} — ${row.endsOn.toLocal().toString().split(' ').first}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textDim, fontSize: 10.5)),
                    ]),
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(label: open ? 'مفتوحة' : 'مغلقة', color: open ? colors.success : colors.textSecondary, compact: true),
                  if (open && !current)
                    PopupMenuButton<String>(
                      onSelected: onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'activate', child: ListTile(leading: Icon(Iconsax.tick_circle), title: Text('تعيين كسنة حالية'), dense: true)),
                        PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.lock_outline_rounded), title: Text('إغلاق السنة'), dense: true)),
                      ],
                    ),
                ],
              );
              if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 7), Align(alignment: AlignmentDirectional.centerEnd, child: actions)]);
              return Row(children: [Expanded(child: identity), const SizedBox(width: 10), actions]);
            },
          ),
        ),
        if (showDivider) Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  const _DateChoice({required this.title, required this.date, required this.onTap});
  final String title;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.muted.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(title),
        subtitle: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
        trailing: const Icon(Icons.chevron_left_rounded, size: 17),
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
