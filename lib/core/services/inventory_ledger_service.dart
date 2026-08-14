import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:sqflite/sqflite.dart';

class InventoryLedgerService {
  const InventoryLedgerService();

  Future<String> ensureInventoryItem(
    DatabaseExecutor db, {
    required String entityId,
    required String productId,
    required String warehouseId,
  }) async {
    final existing = await db.query(
      'inventory_items',
      columns: ['id'],
      where: 'entity_id = ? AND product_id = ? AND warehouse_id = ?',
      whereArgs: [entityId, productId, warehouseId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final id = uuid.v4();
    await db.insert('inventory_items', {
      'id': id,
      'entity_id': entityId,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'current_quantity': 0.0,
      'inventory_value_minor': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'version': 1,
    });
    return id;
  }

  Future<String> recordMovement(
    DatabaseExecutor db, {
    required String entityId,
    required String financialYearId,
    required String inventoryItemId,
    required String movementType,
    required double quantityDelta,
    required int valueDeltaMinor,
    required String referenceType,
    required String referenceId,
    String? referenceItemId,
    String? reversalOfId,
    String? createdBy,
    String? originDeviceId,
    DateTime? occurredAt,
  }) async {
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await db.insert('inventory_movements', {
      'id': id,
      'entity_id': entityId,
      'financial_year_id': financialYearId,
      'inventory_item_id': inventoryItemId,
      'movement_type': movementType,
      'quantity_delta': quantityDelta,
      'value_delta_minor': valueDeltaMinor,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'reference_item_id': referenceItemId,
      'reversal_of_id': reversalOfId,
      'created_by': createdBy,
      'origin_device_id': originDeviceId,
      'occurred_at': (occurredAt ?? now).toUtc().toIso8601String(),
      'created_at': now.toIso8601String(),
    });

    await db.rawUpdate(
      '''
UPDATE inventory_items
SET current_quantity = current_quantity + ?,
    inventory_value_minor = inventory_value_minor + ?,
    updated_at = ?,
    version = version + 1
WHERE id = ?
''',
      [quantityDelta, valueDeltaMinor, now.toIso8601String(), inventoryItemId],
    );
    return id;
  }

  Future<Map<String, num>> rebuildInventoryCache(
    DatabaseExecutor db,
    String inventoryItemId,
  ) async {
    final rows = await db.rawQuery(
      '''
SELECT COALESCE(SUM(quantity_delta), 0) AS quantity,
       COALESCE(SUM(value_delta_minor), 0) AS value_minor
FROM inventory_movements
WHERE inventory_item_id = ?
''',
      [inventoryItemId],
    );
    final quantity = (rows.first['quantity'] as num?)?.toDouble() ?? 0.0;
    final valueMinor = (rows.first['value_minor'] as num?)?.toInt() ?? 0;
    await db.update(
      'inventory_items',
      {
        'current_quantity': quantity,
        'inventory_value_minor': valueMinor,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [inventoryItemId],
    );
    return {'quantity': quantity, 'value_minor': valueMinor};
  }

  Future<int> currentAverageUnitCostMinor(
    DatabaseExecutor db,
    String inventoryItemId,
  ) async {
    final rows = await db.query(
      'inventory_items',
      columns: ['current_quantity', 'inventory_value_minor'],
      where: 'id = ?',
      whereArgs: [inventoryItemId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    final quantity = (rows.first['current_quantity'] as num?)?.toDouble() ?? 0;
    final value = (rows.first['inventory_value_minor'] as num?)?.toInt() ?? 0;
    if (quantity <= 0) return 0;
    return Money.divideByQuantity(value, quantity);
  }
}
