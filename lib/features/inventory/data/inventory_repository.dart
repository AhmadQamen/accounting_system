import 'dart:convert';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/inventory_ledger_service.dart';
import 'package:accounting_system/core/services/outbox_service.dart';

class InventoryRepository {
  InventoryRepository(this._database);
  final AppDatabase _database;
  final _ledger = const InventoryLedgerService();
  final _outbox = const OutboxService();

  Future<List<Map<String, Object?>>> listInventory({String search = '', String? warehouseId}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final args = <Object?>[ctx.entityId];
    var filter = 'i.entity_id = ? AND p.deleted_at IS NULL AND w.deleted_at IS NULL';
    if (warehouseId != null) {
      filter += ' AND i.warehouse_id = ?';
      args.add(warehouseId);
    }
    if (search.trim().isNotEmpty) {
      filter += ' AND p.name LIKE ?';
      args.add('%${search.trim()}%');
    }
    return db.rawQuery('''
SELECT i.id AS inventory_item_id, i.product_id, i.warehouse_id,
       i.current_quantity, i.inventory_value_minor,
       p.name AS product_name, p.min_quantity,
       w.name AS warehouse_name,
       u.id AS primary_unit_id, u.name AS primary_unit_name, u.factor AS primary_unit_factor
FROM inventory_items i
JOIN products p ON p.id=i.product_id
JOIN warehouses w ON w.id=i.warehouse_id
LEFT JOIN product_units u ON u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL
WHERE $filter
ORDER BY p.name COLLATE NOCASE, w.name COLLATE NOCASE
''', args);
  }

  Future<List<Map<String, Object?>>> listSellableProducts({String search = '', String? warehouseId}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final warehouse = warehouseId ?? ctx.defaultWarehouseId;
    final args = <Object?>[ctx.entityId, warehouse];
    var searchFilter = '';
    if (search.trim().isNotEmpty) {
      searchFilter = '''AND (p.name LIKE ? OR EXISTS (
        SELECT 1 FROM product_units bu JOIN barcodes b ON b.product_unit_id=bu.id
        WHERE bu.product_id=p.id AND b.deleted_at IS NULL AND b.code LIKE ?))''';
      args.add('%${search.trim()}%');
      args.add('%${search.trim()}%');
    }
    return db.rawQuery('''
SELECT p.id AS product_id, p.name AS product_name,
       u.id AS product_unit_id, u.name AS unit_name, u.factor,
       i.id AS inventory_item_id, COALESCE(i.current_quantity,0) AS current_quantity,
       COALESCE(i.inventory_value_minor,0) AS inventory_value_minor
FROM products p
JOIN product_units u ON u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL
LEFT JOIN inventory_items i ON i.product_id=p.id AND i.warehouse_id=?
WHERE p.entity_id=? AND p.deleted_at IS NULL $searchFilter
ORDER BY p.name COLLATE NOCASE
''', [warehouse, ctx.entityId, ...args.skip(2)]);
  }


  Future<String> ensureInventoryItemForProduct({
    required String productId,
    required String warehouseId,
  }) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final existing = await db.query(
      'inventory_items',
      columns: ['id'],
      where: 'entity_id=? AND product_id=? AND warehouse_id=?',
      whereArgs: [ctx.entityId, productId, warehouseId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    late String id;
    await _database.transaction((txn) async {
      id = await _ledger.ensureInventoryItem(
        txn,
        entityId: ctx.entityId,
        productId: productId,
        warehouseId: warehouseId,
      );
      await _outbox.enqueue(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'inventory_item',
        aggregateId: id,
        action: 'create',
        payload: {
          'id': id,
          'entity_id': ctx.entityId,
          'product_id': productId,
          'warehouse_id': warehouseId,
        },
      );
    });
    return id;
  }

  Future<String> addOpeningBalance({
    required String productId,
    required String warehouseId,
    required double quantity,
    required int totalValueMinor,
  }) async {
    if (quantity <= 0) throw ArgumentError('quantity must be > 0');
    final ctx = await LocalContextService.instance.current;
    final referenceId = uuid.v4();
    await _database.transaction((txn) async {
      final inventoryItemId = await _ledger.ensureInventoryItem(txn, entityId: ctx.entityId, productId: productId, warehouseId: warehouseId);
      await _ledger.recordMovement(
        txn,
        entityId: ctx.entityId,
        financialYearId: ctx.financialYearId,
        inventoryItemId: inventoryItemId,
        movementType: 'opening_balance',
        quantityDelta: quantity,
        valueDeltaMinor: totalValueMinor,
        referenceType: 'opening_balance',
        referenceId: referenceId,
        createdBy: ctx.userId,
        originDeviceId: ctx.deviceId,
      );
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'inventory_opening', aggregateId: referenceId, action: 'post', payload: {'id': referenceId, 'product_id': productId, 'warehouse_id': warehouseId, 'quantity': quantity, 'value_minor': totalValueMinor});
    });
    return referenceId;
  }

  Future<String> postAdjustment({
    required String warehouseId,
    required List<InventoryAdjustmentInput> items,
    String? note,
  }) async {
    if (items.isEmpty) throw ArgumentError('Adjustment needs items');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = 'ADJ-${ctx.deviceId.substring(0, 4).toUpperCase()}-${now.microsecondsSinceEpoch}';
    await _database.transaction((txn) async {
      await txn.insert('inventory_adjustments', {
        'id': id,
        'entity_id': ctx.entityId,
        'financial_year_id': ctx.financialYearId,
        'warehouse_id': warehouseId,
        'adjustment_number': number,
        'status': 'draft',
        'note': note,
        'created_by': ctx.userId,
        'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final input in items) {
        final rows = await txn.query('inventory_items', where: 'id = ?', whereArgs: [input.inventoryItemId], limit: 1);
        if (rows.isEmpty) throw StateError('Inventory item not found');
        final before = (rows.first['current_quantity'] as num).toDouble();
        final delta = input.countedQuantity - before;
        final average = before == 0 ? 0 : Money.divideByQuantity((rows.first['inventory_value_minor'] as num).toInt(), before);
        final valueDelta = Money.multiplyByQuantity(average, delta.abs()) * (delta < 0 ? -1 : 1);
        final itemId = uuid.v4();
        await txn.insert('inventory_adjustment_items', {
          'id': itemId,
          'entity_id': ctx.entityId,
          'inventory_adjustment_id': id,
          'inventory_item_id': input.inventoryItemId,
          'product_unit_id': input.productUnitId,
          'quantity_before': before,
          'counted_quantity': input.countedQuantity,
          'quantity_delta': delta,
          'unit_factor_at_adjustment': input.unitFactor,
          'value_delta_minor': valueDelta,
          'created_at': now.toIso8601String(),
        });
        if (delta != 0) {
          await _ledger.recordMovement(txn,
              entityId: ctx.entityId,
              financialYearId: ctx.financialYearId,
              inventoryItemId: input.inventoryItemId,
              movementType: 'adjustment',
              quantityDelta: delta,
              valueDeltaMinor: valueDelta,
              referenceType: 'inventory_adjustment',
              referenceId: id,
              referenceItemId: itemId,
              createdBy: ctx.userId,
              originDeviceId: ctx.deviceId,
              occurredAt: now);
        }
      }
      await txn.update('inventory_adjustments', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'inventory_adjustment', aggregateId: id, action: 'post', payload: {'id': id, 'number': number, 'items': items.map((e) => e.toJson()).toList()});
    });
    return id;
  }

  Future<String> postTransfer({
    required String fromWarehouseId,
    required String toWarehouseId,
    required List<InventoryTransferInput> items,
    String? note,
  }) async {
    if (fromWarehouseId == toWarehouseId) throw ArgumentError('Warehouses must differ');
    if (items.isEmpty) throw ArgumentError('Transfer needs items');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    final number = 'TRF-${ctx.deviceId.substring(0, 4).toUpperCase()}-${now.microsecondsSinceEpoch}';
    await _database.transaction((txn) async {
      await txn.insert('inventory_transfers', {
        'id': id, 'entity_id': ctx.entityId, 'financial_year_id': ctx.financialYearId,
        'transfer_number': number, 'from_warehouse_id': fromWarehouseId, 'to_warehouse_id': toWarehouseId,
        'status': 'draft', 'note': note, 'created_by': ctx.userId, 'origin_device_id': ctx.deviceId,
        'occurred_at': now.toIso8601String(), 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String(),
      });
      for (final input in items) {
        final sourceId = await _ledger.ensureInventoryItem(txn, entityId: ctx.entityId, productId: input.productId, warehouseId: fromWarehouseId);
        final destId = await _ledger.ensureInventoryItem(txn, entityId: ctx.entityId, productId: input.productId, warehouseId: toWarehouseId);
        final sourceRows = await txn.query('inventory_items', where: 'id = ?', whereArgs: [sourceId], limit: 1);
        final sourceQty = (sourceRows.first['current_quantity'] as num).toDouble();
        if (sourceQty < input.baseQuantity) throw StateError('Insufficient stock for transfer');
        final average = sourceQty == 0 ? 0 : Money.divideByQuantity((sourceRows.first['inventory_value_minor'] as num).toInt(), sourceQty);
        final value = Money.multiplyByQuantity(average, input.baseQuantity);
        final itemId = uuid.v4();
        await txn.insert('inventory_transfer_items', {
          'id': itemId, 'entity_id': ctx.entityId, 'inventory_transfer_id': id,
          'product_id': input.productId, 'product_unit_id': input.productUnitId,
          'quantity': input.quantity, 'unit_factor_at_transfer': input.unitFactor,
          'base_quantity': input.baseQuantity, 'inventory_value_minor': value,
          'created_at': now.toIso8601String(),
        });
        await _ledger.recordMovement(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, inventoryItemId: sourceId, movementType: 'transfer_out', quantityDelta: -input.baseQuantity, valueDeltaMinor: -value, referenceType: 'inventory_transfer', referenceId: id, referenceItemId: itemId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
        await _ledger.recordMovement(txn, entityId: ctx.entityId, financialYearId: ctx.financialYearId, inventoryItemId: destId, movementType: 'transfer_in', quantityDelta: input.baseQuantity, valueDeltaMinor: value, referenceType: 'inventory_transfer', referenceId: id, referenceItemId: itemId, createdBy: ctx.userId, originDeviceId: ctx.deviceId, occurredAt: now);
      }
      await txn.update('inventory_transfers', {'status': 'posted', 'posted_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}, where: 'id = ?', whereArgs: [id]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'inventory_transfer', aggregateId: id, action: 'post', payload: {'id': id, 'number': number, 'from': fromWarehouseId, 'to': toWarehouseId, 'items': items.map((e) => e.toJson()).toList()});
    });
    return id;
  }

  Future<List<Map<String, Object?>>> movementHistory({String? inventoryItemId}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT m.*, p.name AS product_name, w.name AS warehouse_name
FROM inventory_movements m
JOIN inventory_items i ON i.id=m.inventory_item_id
JOIN products p ON p.id=i.product_id
JOIN warehouses w ON w.id=i.warehouse_id
WHERE m.entity_id=? ${inventoryItemId == null ? '' : 'AND m.inventory_item_id=?'}
ORDER BY m.occurred_at DESC
LIMIT 500
''', inventoryItemId == null ? [ctx.entityId] : [ctx.entityId, inventoryItemId]);
  }

  Future<Map<String, Object?>> verifyCache() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final mismatches = await db.rawQuery('''
SELECT i.id, i.current_quantity,
       COALESCE(SUM(m.quantity_delta),0) AS ledger_quantity,
       i.inventory_value_minor,
       COALESCE(SUM(m.value_delta_minor),0) AS ledger_value
FROM inventory_items i
LEFT JOIN inventory_movements m ON m.inventory_item_id=i.id
WHERE i.entity_id=?
GROUP BY i.id
HAVING ABS(i.current_quantity - COALESCE(SUM(m.quantity_delta),0)) > 0.000001
    OR i.inventory_value_minor <> COALESCE(SUM(m.value_delta_minor),0)
''', [ctx.entityId]);
    return {'ok': mismatches.isEmpty, 'mismatches': jsonEncode(mismatches)};
  }
}

class InventoryAdjustmentInput {
  const InventoryAdjustmentInput({required this.inventoryItemId, required this.productUnitId, required this.countedQuantity, this.unitFactor = 1});
  final String inventoryItemId;
  final String productUnitId;
  final double countedQuantity;
  final double unitFactor;
  Map<String, Object?> toJson() => {'inventory_item_id': inventoryItemId, 'product_unit_id': productUnitId, 'counted_quantity': countedQuantity, 'unit_factor': unitFactor};
}

class InventoryTransferInput {
  const InventoryTransferInput({required this.productId, required this.productUnitId, required this.quantity, required this.unitFactor});
  final String productId;
  final String productUnitId;
  final double quantity;
  final double unitFactor;
  double get baseQuantity => quantity * unitFactor;
  Map<String, Object?> toJson() => {'product_id': productId, 'product_unit_id': productUnitId, 'quantity': quantity, 'unit_factor': unitFactor, 'base_quantity': baseQuantity};
}
