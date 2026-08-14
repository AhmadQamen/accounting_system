import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';

class ReportsRepository {
  ReportsRepository(this._database);
  final AppDatabase _database;

  Future<Map<String, int>> dashboard() async {
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
    return {
      'cash': cash,
      'salesToday': sales,
      'purchasesToday': purchases,
      'customerReceivables': customerReceivables,
      'supplierPayables': supplierPayables,
      'inventoryValue': inventoryValue,
      'lowStock': lowStock,
      'pendingSync': pendingSync,
    };
  }

  Future<Map<String, Object?>> salesReport(DateTime from, DateTime to) async {
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
    final result = rows.first;
    final gross = (result['gross_sales'] as num).toInt();
    final returns = (result['returns'] as num).toInt();
    final cogs = (result['cogs'] as num).toInt();
    return {...result, 'net_sales': gross - returns, 'gross_profit': gross - returns - cogs};
  }

  Future<Map<String, Object?>> purchasesReport(DateTime from, DateTime to) async {
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
    final result = rows.first;
    final gross = (result['gross_purchases'] as num).toInt();
    final returns = (result['returns'] as num).toInt();
    return {...result, 'net_purchases': gross - returns};
  }

  Future<List<Map<String, Object?>>> inventoryBalances({String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final args = <Object?>[ctx.entityId];
    var extra = '';
    if (search.trim().isNotEmpty) {
      extra = 'AND p.name LIKE ?';
      args.add('%${search.trim()}%');
    }
    return db.rawQuery('''
SELECT p.name product_name, w.name warehouse_name,
       i.current_quantity, i.inventory_value_minor, p.min_quantity
FROM inventory_items i
JOIN products p ON p.id=i.product_id
JOIN warehouses w ON w.id=i.warehouse_id
WHERE i.entity_id=? AND p.deleted_at IS NULL AND w.deleted_at IS NULL $extra
ORDER BY p.name COLLATE NOCASE, w.name COLLATE NOCASE
''', args);
  }

  Future<List<Map<String, Object?>>> partyBalances() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query(
      'parties',
      columns: ['id', 'name', 'phone', 'type', 'current_balance_minor'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> cashBalances() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query(
      'cashboxes',
      columns: ['id', 'name', 'current_balance_minor'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<Map<String, Object?>> cashFlowReport(DateTime from, DateTime to) async {
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
    return rows.first;
  }
}
