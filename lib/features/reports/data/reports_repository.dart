import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';

class ReportsRepository {
  ReportsRepository(this._database);
  final AppDatabase _database;

  Future<DashboardMetrics> dashboard() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final today = DateTime.now().toUtc();
    final start = DateTime.utc(today.year, today.month, today.day).toIso8601String();
    Future<int> scalar(String sql, [List<Object?> args = const []]) async {
      final rows = await db.rawQuery(sql, args);
      return (rows.first.values.first as num?)?.toInt() ?? 0;
    }

    final cash = await scalar('SELECT COALESCE(SUM(current_balance_minor),0) FROM cashboxes WHERE entity_id=? AND deleted_at IS NULL', [ctx.entityId]);
    final sales = await scalar("SELECT COALESCE(SUM(final_minor),0) FROM sales WHERE entity_id=? AND status='posted' AND occurred_at>=?", [ctx.entityId, start]);
    final purchases = await scalar("SELECT COALESCE(SUM(final_minor),0) FROM purchase_invoices WHERE entity_id=? AND status='posted' AND occurred_at>=?", [ctx.entityId, start]);
    final customerReceivables = await scalar("SELECT COALESCE(SUM(CASE WHEN current_balance_minor>0 THEN current_balance_minor ELSE 0 END),0) FROM parties WHERE entity_id=? AND deleted_at IS NULL", [ctx.entityId]);
    final supplierPayables = await scalar("SELECT COALESCE(SUM(CASE WHEN current_balance_minor<0 THEN -current_balance_minor ELSE 0 END),0) FROM parties WHERE entity_id=? AND deleted_at IS NULL", [ctx.entityId]);
    final inventoryValue = await scalar('SELECT COALESCE(SUM(inventory_value_minor),0) FROM inventory_items WHERE entity_id=?', [ctx.entityId]);
    final lowStock = await scalar('''SELECT COUNT(*) FROM inventory_items i JOIN products p ON p.id=i.product_id WHERE i.entity_id=? AND p.min_quantity>0 AND i.current_quantity<=p.min_quantity''', [ctx.entityId]);
    final pendingSync = await scalar("SELECT COUNT(*) FROM sync_outbox WHERE entity_id=? AND status IN ('pending','failed')", [ctx.entityId]);
    return DashboardMetrics(
      cash: cash,
      salesToday: sales,
      purchasesToday: purchases,
      customerReceivables: customerReceivables,
      supplierPayables: supplierPayables,
      inventoryValue: inventoryValue,
      lowStock: lowStock,
      pendingSync: pendingSync,
    );
  }

  Future<SalesReport> salesReport(DateTime from, DateTime to) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final fromText = from.toUtc().toIso8601String();
    final toText = to.toUtc().toIso8601String();
    final rows = await db.rawQuery('''
SELECT COALESCE(SUM(s.final_minor),0) gross_sales,
       COALESCE(SUM(s.discount_minor),0) discounts,
       COALESCE((SELECT SUM(r.final_minor) FROM sale_return_invoices r WHERE r.entity_id=? AND r.status='posted' AND r.occurred_at>=? AND r.occurred_at<?),0) returns,
       COALESCE((SELECT SUM(si.cost_amount_minor) FROM sale_items si JOIN sales s2 ON s2.id=si.sale_id WHERE s2.entity_id=? AND s2.status='posted' AND s2.occurred_at>=? AND s2.occurred_at<?),0)
       - COALESCE((SELECT SUM(ri.cost_amount_minor) FROM sale_return_items ri JOIN sale_return_invoices r2 ON r2.id=ri.sale_return_invoice_id WHERE r2.entity_id=? AND r2.status='posted' AND r2.occurred_at>=? AND r2.occurred_at<?),0) cogs,
       COUNT(s.id) invoice_count
FROM sales s
WHERE s.entity_id=? AND s.status='posted' AND s.occurred_at>=? AND s.occurred_at<?
''', [ctx.entityId, fromText, toText, ctx.entityId, fromText, toText, ctx.entityId, fromText, toText, ctx.entityId, fromText, toText]);
    return SalesReport.fromSql(rows.first);
  }

  Future<PurchasesReport> purchasesReport(DateTime from, DateTime to) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final fromText = from.toUtc().toIso8601String();
    final toText = to.toUtc().toIso8601String();
    final rows = await db.rawQuery('''
SELECT COALESCE(SUM(p.final_minor),0) gross_purchases,
       COALESCE(SUM(p.discount_minor),0) discounts,
       COALESCE((SELECT SUM(r.final_minor) FROM purchase_return_invoices r WHERE r.entity_id=? AND r.status='posted' AND r.occurred_at>=? AND r.occurred_at<?),0) returns,
       COUNT(p.id) invoice_count
FROM purchase_invoices p
WHERE p.entity_id=? AND p.status='posted' AND p.occurred_at>=? AND p.occurred_at<?
''', [ctx.entityId, fromText, toText, ctx.entityId, fromText, toText]);
    return PurchasesReport.fromSql(rows.first);
  }

  Future<List<InventoryBalanceReport>> inventoryBalances({String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final args = <Object?>[ctx.entityId];
    var extra = '';
    if (search.trim().isNotEmpty) {
      extra = 'AND p.name LIKE ?';
      args.add('%${search.trim()}%');
    }
    final rows = await db.rawQuery('''
SELECT p.name product_name, w.name warehouse_name,
       i.current_quantity, i.inventory_value_minor, p.min_quantity
FROM inventory_items i
JOIN products p ON p.id=i.product_id
JOIN warehouses w ON w.id=i.warehouse_id
WHERE i.entity_id=? AND p.deleted_at IS NULL AND w.deleted_at IS NULL $extra
ORDER BY p.name COLLATE NOCASE, w.name COLLATE NOCASE
''', args);
    return rows.map(InventoryBalanceReport.fromSql).toList(growable: false);
  }

  Future<List<PartyBalanceReport>> partyBalances() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'parties',
      columns: ['id', 'name', 'phone', 'type', 'current_balance_minor'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(PartyBalanceReport.fromSql).toList(growable: false);
  }

  Future<List<CashBalanceReport>> cashBalances() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'cashboxes',
      columns: ['id', 'name', 'current_balance_minor'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(CashBalanceReport.fromSql).toList(growable: false);
  }

  Future<CashFlowReport> cashFlowReport(DateTime from, DateTime to) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery('''
SELECT COALESCE(SUM(CASE WHEN direction='in' THEN amount_minor ELSE 0 END),0) total_in,
       COALESCE(SUM(CASE WHEN direction='out' THEN amount_minor ELSE 0 END),0) total_out,
       COALESCE(SUM(CASE WHEN direction='in' THEN amount_minor ELSE -amount_minor END),0) net_flow,
       COALESCE(SUM(CASE WHEN kind='expense' THEN amount_minor ELSE 0 END),0) expenses
FROM transactions
WHERE entity_id=? AND occurred_at>=? AND occurred_at<?
''', [ctx.entityId, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]);
    return CashFlowReport.fromSql(rows.first);
  }


  Future<DashboardTrends> dashboardTrends({int days = 7}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final today = DateTime.now().toUtc();
    final start = DateTime.utc(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final fromText = start.toIso8601String();

    Future<List<DailyTotal>> grouped(String table) async {
      final rows = await db.rawQuery('''
SELECT substr(occurred_at, 1, 10) day, COALESCE(SUM(final_minor),0) total
FROM $table
WHERE entity_id=? AND status='posted' AND occurred_at>=?
GROUP BY substr(occurred_at, 1, 10)
ORDER BY day
''', [ctx.entityId, fromText]);
      return rows.map(DailyTotal.fromSql).toList(growable: false);
    }

    final sales = await grouped('sales');
    final purchases = await grouped('purchase_invoices');
    final salesValues = <int>[];
    final purchaseValues = <int>[];
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i)).toIso8601String().substring(0, 10);
      salesValues.add(_totalForDay(sales, day));
      purchaseValues.add(_totalForDay(purchases, day));
    }
    return DashboardTrends(sales: salesValues, purchases: purchaseValues);
  }

  Future<List<ActivityItem>> recentActivity({int limit = 7}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery('''
SELECT * FROM (
  SELECT 'sale' kind, s.id id, s.invoice_number display_number,
         s.final_minor amount_minor, s.occurred_at occurred_at,
         p.name party_name
  FROM sales s
  LEFT JOIN parties p ON p.id=s.party_id
  WHERE s.entity_id=? AND s.status='posted' AND s.deleted_at IS NULL
  UNION ALL
  SELECT 'purchase' kind, x.id id, x.invoice_number display_number,
         x.final_minor amount_minor, x.occurred_at occurred_at,
         p.name party_name
  FROM purchase_invoices x
  LEFT JOIN parties p ON p.id=x.party_id
  WHERE x.entity_id=? AND x.status='posted' AND x.deleted_at IS NULL
  UNION ALL
  SELECT 'expense' kind, e.id id, e.expense_number display_number,
         e.amount_minor amount_minor, e.occurred_at occurred_at,
         NULL party_name
  FROM expenses e
  WHERE e.entity_id=? AND e.status='posted' AND e.deleted_at IS NULL
)
ORDER BY occurred_at DESC
LIMIT ?
''', [ctx.entityId, ctx.entityId, ctx.entityId, limit]);
    return rows.map(ActivityItem.fromSql).toList(growable: false);
  }

  Future<List<LowStockItem>> lowStockItems({int limit = 5}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery('''
SELECT p.id product_id, p.name product_name, w.name warehouse_name,
       i.current_quantity, p.min_quantity
FROM inventory_items i
JOIN products p ON p.id=i.product_id
JOIN warehouses w ON w.id=i.warehouse_id
WHERE i.entity_id=? AND p.deleted_at IS NULL AND w.deleted_at IS NULL
  AND p.min_quantity>0 AND i.current_quantity<=p.min_quantity
ORDER BY (i.current_quantity / CASE WHEN p.min_quantity=0 THEN 1 ELSE p.min_quantity END) ASC,
         p.name COLLATE NOCASE
LIMIT ?
''', [ctx.entityId, limit]);
    return rows.map(LowStockItem.fromSql).toList(growable: false);
  }
  Future<DashboardData> dashboardData({int trendDays = 7, int activityLimit = 7, int lowStockLimit = 5}) async {
    final metricsFuture = dashboard();
    final trendsFuture = dashboardTrends(days: trendDays);
    final activityFuture = recentActivity(limit: activityLimit);
    final lowStockFuture = lowStockItems(limit: lowStockLimit);
    return DashboardData(
      metrics: await metricsFuture,
      trends: await trendsFuture,
      recentActivity: await activityFuture,
      lowStockItems: await lowStockFuture,
    );
  }

  Future<CashReportData> cashReportData(DateTime from, DateTime to) async {
    final balancesFuture = cashBalances();
    final flowFuture = cashFlowReport(from, to);
    return CashReportData(
      balances: await balancesFuture,
      flow: await flowFuture,
    );
  }

  int _totalForDay(List<DailyTotal> rows, String day) {
    for (final row in rows) {
      if (row.day == day) return row.totalMinor;
    }
    return 0;
  }

}
