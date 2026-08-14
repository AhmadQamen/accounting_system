import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency = ref.watch(localContextProvider).asData?.value?.currencyCode ?? 'USD';
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'المبيعات'),
              Tab(text: 'المشتريات'),
              Tab(text: 'المخزون'),
              Tab(text: 'الأطراف'),
              Tab(text: 'الصناديق'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _moneySummary(
              context,
              ref.read(reportsRepositoryProvider).salesReport(from, to),
              currency,
              const [
                ('إجمالي المبيعات', 'gross_sales'),
                ('الخصومات', 'discounts'),
                ('المرتجعات', 'returns'),
                ('صافي المبيعات', 'net_sales'),
                ('تكلفة البضاعة', 'cogs'),
                ('مجمل الربح', 'gross_profit'),
              ],
            ),
            _moneySummary(
              context,
              ref.read(reportsRepositoryProvider).purchasesReport(from, to),
              currency,
              const [
                ('إجمالي المشتريات', 'gross_purchases'),
                ('الخصومات', 'discounts'),
                ('مرتجعات الشراء', 'returns'),
                ('صافي المشتريات', 'net_purchases'),
              ],
            ),
            _inventory(context, ref, currency),
            _parties(context, ref, currency),
            _cash(context, ref, currency, from, to),
          ],
        ),
      ),
    );
  }

  Widget _moneySummary(
    BuildContext context,
    Future<Map<String, Object?>> future,
    String currency,
    List<(String, String)> fields,
  ) {
    return FutureBuilder<Map<String, Object?>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final row = snapshot.data ?? const <String, Object?>{};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('الفترة: الشهر الحالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...fields.map(
              (field) => Card(
                child: ListTile(
                  title: Text(field.$1),
                  trailing: Text(
                    Money(((row[field.$2] ?? 0) as num).toInt()).format(
                      locale: Localizations.localeOf(context).toString(),
                      currencyCode: currency,
                    ),
                  ),
                ),
              ),
            ),
            if (row['invoice_count'] != null)
              Card(child: ListTile(title: const Text('عدد الفواتير'), trailing: Text('${row['invoice_count']}'))),
          ],
        );
      },
    );
  }

  Widget _inventory(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: ref.read(reportsRepositoryProvider).inventoryBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            final qty = (row['current_quantity'] as num).toDouble();
            final min = (row['min_quantity'] as num).toDouble();
            return ListTile(
              leading: Icon(min > 0 && qty <= min ? Icons.warning_amber : Icons.inventory_2_outlined),
              title: Text('${row['product_name']}'),
              subtitle: Text('${row['warehouse_name']} • الكمية $qty'),
              trailing: Text(Money((row['inventory_value_minor'] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
            );
          },
        );
      },
    );
  }

  Widget _parties(BuildContext context, WidgetRef ref, String currency) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: ref.read(reportsRepositoryProvider).partyBalances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final rows = snapshot.data ?? const <Map<String, Object?>>[];
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            final balance = (row['current_balance_minor'] as num).toInt();
            return ListTile(
              title: Text('${row['name']}'),
              subtitle: Text('${row['type']} • ${balance > 0 ? 'مدين لنا' : balance < 0 ? 'نحن مدينون له' : 'متعادل'}'),
              trailing: Text(Money(balance).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
            );
          },
        );
      },
    );
  }

  Widget _cash(BuildContext context, WidgetRef ref, String currency, DateTime from, DateTime to) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        ref.read(reportsRepositoryProvider).cashBalances(),
        ref.read(reportsRepositoryProvider).cashFlowReport(from, to),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final boxes = snapshot.data![0] as List<Map<String, Object?>>;
        final flow = snapshot.data![1] as Map<String, Object?>;
        Widget moneyTile(String title, String key) => Card(
              child: ListTile(
                title: Text(title),
                trailing: Text(Money((flow[key] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
              ),
            );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            moneyTile('إجمالي الداخل هذا الشهر', 'total_in'),
            moneyTile('إجمالي الخارج هذا الشهر', 'total_out'),
            moneyTile('صافي التدفق', 'net_flow'),
            moneyTile('المصروفات', 'expenses'),
            const SizedBox(height: 12),
            const Text('أرصدة الصناديق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...boxes.map(
              (row) => ListTile(
                title: Text('${row['name']}'),
                trailing: Text(Money((row['current_balance_minor'] as num).toInt()).format(locale: Localizations.localeOf(context).toString(), currencyCode: currency)),
              ),
            ),
          ],
        );
      },
    );
  }
}
