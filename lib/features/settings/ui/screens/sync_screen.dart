import 'dart:convert';

import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final operations = ref.watch(syncOperationsProvider);
    final stage = ref.watch(syncStageProvider);
    final colors = context.colors;

    return MyScaffold(
      appBar: const BlurAppBar(title: Text('المزامنة')),
      body: PremiumPage(
        maxWidth: 1240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageIntro(
              eyebrow: 'SYNC CENTER',
              title: 'مركز المزامنة',
              subtitle: 'تابع ما تم حفظه محليًا وما وصل إلى بقية الأجهزة.',
              icon: Iconsax.refresh,
            ),
            const SizedBox(height: 18),
            status.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر قراءة حالة المزامنة',
                    subtitle: '$error',
                  ),
              data:
                  (value) => Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            _MetricCard(
                              'العمليات المعلقة',
                              '${(value.pending - value.failed).clamp(0, value.pending)}',
                              Iconsax.refresh,
                              colors.warning,
                            ),
                            _MetricCard(
                              'العمليات الفاشلة',
                              '${value.failed + value.rejected + value.conflicts}',
                              Iconsax.close_circle,
                              colors.error,
                            ),
                            _MetricCard(
                              'آخر مزامنة',
                              _lastSync(value.lastSyncAt),
                              Iconsax.clock,
                              colors.primary,
                            ),
                            _MetricCard(
                              'حالة الاتصال',
                              value.deviceRevoked
                                  ? 'الجهاز ملغى'
                                  : value.lastError != null
                                  ? 'يوجد خطأ'
                                  : 'متصل',
                              Iconsax.global,
                              value.deviceRevoked || value.lastError != null
                                  ? colors.error
                                  : colors.success,
                            ),
                          ];
                          final width =
                              constraints.maxWidth >= 920
                                  ? (constraints.maxWidth - 36) / 4
                                  : constraints.maxWidth >= 560
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final card in cards)
                                SizedBox(width: width, child: card),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.icon(
                          onPressed:
                              value.deviceRevoked || stage != SyncStage.idle
                                  ? null
                                  : () => _sync(context, ref),
                          icon:
                              stage == SyncStage.idle
                                  ? const Icon(Iconsax.refresh)
                                  : const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                          label: Text(_stageText(stage)),
                        ),
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(
              title: 'عمليات المزامنة',
              subtitle: 'تفاصيل الحفظ المحلي والإرسال إلى الخادم',
            ),
            const SizedBox(height: 10),
            operations.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (error, _) => EmptyState(
                    icon: Iconsax.warning_2,
                    title: 'تعذر قراءة العمليات',
                    subtitle: '$error',
                  ),
              data:
                  (items) =>
                      items.isEmpty
                          ? const EmptyState(
                            icon: Iconsax.tick_circle,
                            title: 'لا توجد عمليات مزامنة',
                            subtitle:
                                'ستظهر العمليات الجديدة هنا بعد حفظها محليًا.',
                          )
                          : LayoutBuilder(
                            builder:
                                (context, constraints) =>
                                    constraints.maxWidth >= 760
                                        ? _OperationsTable(items: items)
                                        : _OperationsCards(items: items),
                          ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(syncEngineProvider).syncNow();
      ref.invalidate(syncStatusProvider);
      ref.invalidate(syncOperationsProvider);
      if (context.mounted)
        CustomSnackBar.showSuccessSnackbar('اكتملت المزامنة.');
    } catch (error) {
      if (context.mounted) CustomSnackBar.showErrorSnackbar('$error');
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => PremiumPanel(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OperationsTable extends StatelessWidget {
  const _OperationsTable({required this.items});
  final List<SyncOperation> items;
  @override
  Widget build(BuildContext context) => PremiumPanel(
    padding: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('العملية')),
          DataColumn(label: Text('تاريخ الإنشاء')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('المحاولات')),
          DataColumn(label: Text('التفاصيل')),
        ],
        rows:
            items
                .map(
                  (item) => DataRow(
                    cells: [
                      DataCell(Text(_eventLabel(item.eventType))),
                      DataCell(Text(_date(item.createdAt))),
                      DataCell(_StatusPill(item: item)),
                      DataCell(Text('${item.attemptCount}')),
                      DataCell(_OperationActions(item: item)),
                    ],
                  ),
                )
                .toList(),
      ),
    ),
  );
}

class _OperationsCards extends StatelessWidget {
  const _OperationsCards({required this.items});
  final List<SyncOperation> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _eventLabel(item.eventType),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusPill(item: item),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_date(item.createdAt)} • ${item.attemptCount} محاولة',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                if (item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.errorMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
                const SizedBox(height: 8),
                _OperationActions(item: item),
              ],
            ),
          ),
        ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.item});
  final SyncOperation item;
  @override
  Widget build(BuildContext context) {
    final color =
        item.isDone
            ? context.colors.success
            : item.isFailed
            ? context.colors.error
            : context.colors.warning;
    final label =
        item.isDone
            ? 'تمت'
            : item.isFailed
            ? 'فشلت'
            : 'معلقة';
    return StatusPill(
      label: label,
      color: color,
      icon:
          item.isDone
              ? Iconsax.tick_circle
              : item.isFailed
              ? Iconsax.close_circle
              : Iconsax.refresh,
    );
  }
}

class _OperationActions extends ConsumerWidget {
  const _OperationActions({required this.item});
  final SyncOperation item;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 4,
    children: [
      if (item.errorMessage != null)
        IconButton(
          tooltip: 'نسخ الخطأ',
          onPressed:
              () => Clipboard.setData(ClipboardData(text: item.errorMessage!)),
          icon: const Icon(Iconsax.copy, size: 18),
        ),
      if (item.payloadJson != null)
        IconButton(
          tooltip: 'عرض البيانات',
          onPressed: () => _showPayload(context, item.payloadJson!),
          icon: const Icon(Iconsax.code, size: 18),
        ),
      if (item.isFailed)
        IconButton(
          tooltip: 'إعادة المحاولة',
          onPressed: () async {
            await ref.read(syncEngineProvider).retryOperation(item.eventId);
            ref.invalidate(syncOperationsProvider);
            ref.invalidate(syncStatusProvider);
          },
          icon: const Icon(Iconsax.refresh, size: 18),
        ),
    ],
  );
}

void _showPayload(BuildContext context, String payload) {
  String shown = payload;
  try {
    shown = const JsonEncoder.withIndent('  ').convert(jsonDecode(payload));
  } catch (_) {}
  showDialog<void>(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('بيانات العملية'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: SelectableText(shown, textDirection: TextDirection.ltr),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
  );
}

String _stageText(SyncStage stage) => switch (stage) {
  SyncStage.pushing => 'جاري رفع التغييرات',
  SyncStage.pulling => 'جاري تنزيل التحديثات',
  SyncStage.applying => 'جاري تطبيق البيانات',
  SyncStage.idle => 'مزامنة الآن',
};
String _lastSync(DateTime? date) => date == null ? 'لم تتم بعد' : _date(date);
String _date(DateTime date) =>
    '${date.toLocal().year}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().day.toString().padLeft(2, '0')} ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
String _eventLabel(String type) =>
    const {
      'ProductCreated': 'إنشاء منتج',
      'ProductUpdated': 'تعديل منتج',
      'PartyCreated': 'إنشاء طرف',
      'PartyUpdated': 'تعديل طرف',
      'SalePosted': 'فاتورة بيع',
      'PaymentRecorded': 'دفعة',
      'ExpenseRecorded': 'مصروف',
      'InventoryAdjusted': 'تسوية مخزون',
    }[type] ??
    type;
