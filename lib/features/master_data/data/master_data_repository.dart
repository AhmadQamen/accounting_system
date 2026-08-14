import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:sqflite/sqflite.dart';

class MasterDataRepository {
  MasterDataRepository(this._database);
  final AppDatabase _database;
  final _outbox = const OutboxService();

  Future<List<Map<String, Object?>>> listParties({String? type, String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final where = <String>['entity_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[ctx.entityId];
    if (type != null && type != 'all') {
      where.add(type == 'customer'
          ? "type IN ('customer','both')"
          : "type IN ('supplier','both')");
    }
    if (search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR phone LIKE ?)');
      args.add('%${search.trim()}%');
      args.add('%${search.trim()}%');
    }
    return db.query('parties', where: where.join(' AND '), whereArgs: args, orderBy: 'name COLLATE NOCASE');
  }

  Future<String> saveParty({String? id, required String name, String? phone, required String type}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final partyId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('parties', {
          'id': partyId,
          'entity_id': ctx.entityId,
          'name': name.trim(),
          'phone': phone?.trim(),
          'type': type,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update('parties', {
          'name': name.trim(),
          'phone': phone?.trim(),
          'type': type,
          'updated_at': now,
          'version': await _nextVersion(txn, 'parties', partyId),
        }, where: 'id = ? AND entity_id = ?', whereArgs: [partyId, ctx.entityId]);
      }
      await _outbox.enqueue(txn,
          entityId: ctx.entityId,
          aggregateType: 'party',
          aggregateId: partyId,
          action: id == null ? 'create' : 'update',
          payload: {'id': partyId, 'name': name.trim(), 'phone': phone, 'type': type});
    });
    return partyId;
  }

  Future<void> archiveParty(String id) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.update('parties', {'deleted_at': now, 'updated_at': now},
          where: 'id = ? AND entity_id = ?', whereArgs: [id, ctx.entityId]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'party', aggregateId: id, action: 'delete', payload: {'id': id, 'deleted_at': now});
    });
  }

  Future<List<Map<String, Object?>>> listCategories() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('categories', where: 'entity_id = ? AND deleted_at IS NULL', whereArgs: [ctx.entityId], orderBy: 'name');
  }

  Future<String> saveCategory({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final categoryId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('categories', {'id': categoryId, 'entity_id': ctx.entityId, 'name': name.trim(), 'created_at': now, 'updated_at': now});
      } else {
        await txn.update('categories', {'name': name.trim(), 'updated_at': now, 'version': await _nextVersion(txn, 'categories', categoryId)}, where: 'id = ? AND entity_id = ?', whereArgs: [categoryId, ctx.entityId]);
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'category', aggregateId: categoryId, action: id == null ? 'create' : 'update', payload: {'id': categoryId, 'name': name.trim()});
    });
    return categoryId;
  }

  Future<List<Map<String, Object?>>> listProducts({String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final args = <Object?>[ctx.entityId];
    var where = 'p.entity_id = ? AND p.deleted_at IS NULL';
    if (search.trim().isNotEmpty) {
      where += ' AND (p.name LIKE ? OR EXISTS (SELECT 1 FROM product_units u JOIN barcodes b ON b.product_unit_id = u.id WHERE u.product_id = p.id AND b.deleted_at IS NULL AND b.code LIKE ?))';
      args.add('%${search.trim()}%');
      args.add('%${search.trim()}%');
    }
    return db.rawQuery('''
SELECT p.*, c.name AS category_name,
       (SELECT u.id FROM product_units u WHERE u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL LIMIT 1) AS primary_unit_id,
       (SELECT u.name FROM product_units u WHERE u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL LIMIT 1) AS primary_unit_name
FROM products p
LEFT JOIN categories c ON c.id=p.category_id
WHERE $where
ORDER BY p.name COLLATE NOCASE
''', args);
  }

  Future<String> createProduct({required String name, String? categoryId, double minQuantity = 0, String primaryUnitName = 'Unit', String? barcode}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final productId = uuid.v4();
    final unitId = uuid.v4();
    final inventoryItemId = uuid.v4();
    final barcodeId = barcode != null && barcode.trim().isNotEmpty ? uuid.v4() : null;
    await _database.transaction((txn) async {
      await txn.insert('products', {
        'id': productId,
        'entity_id': ctx.entityId,
        'category_id': categoryId,
        'name': name.trim(),
        'min_quantity': minQuantity,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('product_units', {
        'id': unitId,
        'entity_id': ctx.entityId,
        'product_id': productId,
        'name': primaryUnitName.trim().isEmpty ? 'Unit' : primaryUnitName.trim(),
        'factor': 1.0,
        'is_primary': 1,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('inventory_items', {
        'id': inventoryItemId,
        'entity_id': ctx.entityId,
        'product_id': productId,
        'warehouse_id': ctx.defaultWarehouseId,
        'current_quantity': 0.0,
        'inventory_value_minor': 0,
        'updated_at': now,
        'version': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (barcode != null && barcode.trim().isNotEmpty) {
        await txn.insert('barcodes', {
          'id': barcodeId,
          'entity_id': ctx.entityId,
          'product_unit_id': unitId,
          'code': barcode.trim(),
          'created_at': now,
          'updated_at': now,
        });
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'product', aggregateId: productId, action: 'create', payload: {'id': productId, 'name': name.trim(), 'category_id': categoryId, 'min_quantity': minQuantity, 'primary_unit': {'id': unitId, 'name': primaryUnitName.trim().isEmpty ? 'Unit' : primaryUnitName.trim(), 'factor': 1.0}, 'barcode': barcodeId == null ? null : {'id': barcodeId, 'code': barcode!.trim(), 'product_unit_id': unitId}, 'inventory_item': {'id': inventoryItemId, 'warehouse_id': ctx.defaultWarehouseId, 'product_id': productId}});
    });
    return productId;
  }

  Future<List<Map<String, Object?>>> listProductUnits(String productId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query(
      'product_units',
      where: 'entity_id=? AND product_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId, productId],
      orderBy: 'is_primary DESC, name COLLATE NOCASE',
    );
  }

  Future<String> saveProductUnit({
    required String productId,
    String? id,
    required String name,
    required double factor,
    bool isPrimary = false,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Unit name is required');
    if (factor <= 0) throw ArgumentError('Unit factor must be > 0');
    final ctx = await LocalContextService.instance.current;
    final unitId = id ?? uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      if (isPrimary) {
        await txn.update(
          'product_units',
          {'is_primary': 0, 'updated_at': now},
          where: 'entity_id=? AND product_id=? AND id<>? AND deleted_at IS NULL',
          whereArgs: [ctx.entityId, productId, unitId],
        );
        factor = 1;
      }
      if (id == null) {
        await txn.insert('product_units', {
          'id': unitId,
          'entity_id': ctx.entityId,
          'product_id': productId,
          'name': name.trim(),
          'factor': factor,
          'is_primary': isPrimary ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update('product_units', {
          'name': name.trim(),
          'factor': factor,
          'is_primary': isPrimary ? 1 : 0,
          'updated_at': now,
          'version': await _nextVersion(txn, 'product_units', unitId),
        }, where: 'id=? AND entity_id=? AND product_id=?', whereArgs: [unitId, ctx.entityId, productId]);
      }
      await _outbox.enqueue(
        txn,
        entityId: ctx.entityId,
        aggregateType: 'product_unit',
        aggregateId: unitId,
        action: id == null ? 'create' : 'update',
        payload: {'id': unitId, 'product_id': productId, 'name': name.trim(), 'factor': factor, 'is_primary': isPrimary},
      );
    });
    return unitId;
  }

  Future<List<Map<String, Object?>>> listBarcodes(String productId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.rawQuery('''
SELECT b.*, u.name AS unit_name
FROM barcodes b
JOIN product_units u ON u.id=b.product_unit_id
WHERE b.entity_id=? AND u.product_id=? AND b.deleted_at IS NULL AND u.deleted_at IS NULL
ORDER BY b.code
''', [ctx.entityId, productId]);
  }

  Future<String> addBarcode({required String productUnitId, required String code}) async {
    if (code.trim().isEmpty) throw ArgumentError('Barcode is required');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.insert('barcodes', {
        'id': id,
        'entity_id': ctx.entityId,
        'product_unit_id': productUnitId,
        'code': code.trim(),
        'created_at': now,
        'updated_at': now,
      });
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'barcode', aggregateId: id, action: 'create', payload: {'id': id, 'product_unit_id': productUnitId, 'code': code.trim()});
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listProductSpecifications(String productId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('product_specifications', where: 'entity_id=? AND product_id=? AND deleted_at IS NULL', whereArgs: [ctx.entityId, productId], orderBy: 'title');
  }

  Future<String> addProductSpecification({required String productId, required String title, required String value}) async {
    if (title.trim().isEmpty || value.trim().isEmpty) throw ArgumentError('Specification title and value are required');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.insert('product_specifications', {
        'id': id,
        'entity_id': ctx.entityId,
        'product_id': productId,
        'title': title.trim(),
        'value': value.trim(),
        'created_at': now,
        'updated_at': now,
      });
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'product_specification', aggregateId: id, action: 'create', payload: {'id': id, 'product_id': productId, 'title': title.trim(), 'value': value.trim()});
    });
    return id;
  }

  Future<List<Map<String, Object?>>> listWarehouses() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('warehouses', where: 'entity_id = ? AND deleted_at IS NULL', whereArgs: [ctx.entityId], orderBy: 'name');
  }

  Future<String> saveWarehouse({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final warehouseId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('warehouses', {'id': warehouseId, 'entity_id': ctx.entityId, 'name': name.trim(), 'created_at': now, 'updated_at': now});
      } else {
        await txn.update('warehouses', {'name': name.trim(), 'updated_at': now, 'version': await _nextVersion(txn, 'warehouses', warehouseId)}, where: 'id = ? AND entity_id = ?', whereArgs: [warehouseId, ctx.entityId]);
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'warehouse', aggregateId: warehouseId, action: id == null ? 'create' : 'update', payload: {'id': warehouseId, 'name': name.trim()});
    });
    return warehouseId;
  }

  Future<List<Map<String, Object?>>> listFinancialYears() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('financial_years', where: 'entity_id = ?', whereArgs: [ctx.entityId], orderBy: 'starts_on DESC');
  }

  Future<String> createFinancialYear({required String name, required DateTime startsOn, required DateTime endsOn}) async {
    if (!endsOn.isAfter(startsOn)) throw ArgumentError('Financial year end must be after start');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.insert('financial_years', {
        'id': id,
        'entity_id': ctx.entityId,
        'name': name.trim(),
        'starts_on': startsOn.toUtc().toIso8601String(),
        'ends_on': endsOn.toUtc().toIso8601String(),
        'is_open': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'financial_year', aggregateId: id, action: 'create', payload: {'id': id, 'name': name.trim(), 'starts_on': startsOn.toUtc().toIso8601String(), 'ends_on': endsOn.toUtc().toIso8601String()});
    });
    return id;
  }

  Future<void> activateFinancialYear(String id) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query('financial_years', where: 'id=? AND entity_id=? AND is_open=1', whereArgs: [id, ctx.entityId], limit: 1);
    if (rows.isEmpty) throw StateError('Financial year must be open');
    await db.update('app_context', {'financial_year_id': id, 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'singleton=1');
    LocalContextService.instance.clearCache();
  }

  Future<void> closeFinancialYear(String id) async {
    final ctx = await LocalContextService.instance.current;
    if (id == ctx.financialYearId) {
      throw StateError('Activate another open financial year before closing the current year');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final changed = await txn.update('financial_years', {
        'is_open': 0,
        'closed_at': now,
        'closed_by': ctx.userId,
        'updated_at': now,
      }, where: 'id=? AND entity_id=? AND is_open=1', whereArgs: [id, ctx.entityId]);
      if (changed == 0) throw StateError('Open financial year not found');
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'financial_year', aggregateId: id, action: 'close', payload: {'id': id, 'is_open': false, 'closed_at': now});
    });
  }

  Future<void> archiveWarehouse(String id) async {
    final ctx = await LocalContextService.instance.current;
    if (id == ctx.defaultWarehouseId) throw StateError('Cannot archive the default warehouse');
    final db = await _database.database;
    final balances = await db.rawQuery('SELECT COUNT(*) c FROM inventory_items WHERE entity_id=? AND warehouse_id=? AND ABS(current_quantity) > 0.000001', [ctx.entityId, id]);
    if ((balances.first['c'] as num).toInt() > 0) throw StateError('Warehouse has stock and cannot be archived');
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.update('warehouses', {'deleted_at': now, 'updated_at': now}, where: 'id=? AND entity_id=?', whereArgs: [id, ctx.entityId]);
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'warehouse', aggregateId: id, action: 'delete', payload: {'id': id, 'deleted_at': now});
    });
  }

  Future<List<Map<String, Object?>>> listCashboxes() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    return db.query('cashboxes', where: 'entity_id = ? AND deleted_at IS NULL', whereArgs: [ctx.entityId], orderBy: 'name');
  }

  Future<String> saveCashbox({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final cashboxId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('cashboxes', {'id': cashboxId, 'entity_id': ctx.entityId, 'name': name.trim(), 'created_at': now, 'updated_at': now});
      } else {
        await txn.update('cashboxes', {'name': name.trim(), 'updated_at': now, 'version': await _nextVersion(txn, 'cashboxes', cashboxId)}, where: 'id = ? AND entity_id = ?', whereArgs: [cashboxId, ctx.entityId]);
      }
      await _outbox.enqueue(txn, entityId: ctx.entityId, aggregateType: 'cashbox', aggregateId: cashboxId, action: id == null ? 'create' : 'update', payload: {'id': cashboxId, 'name': name.trim()});
    });
    return cashboxId;
  }

  Future<int> _nextVersion(dynamic db, String table, String id) async {
    final rows = await db.query(table, columns: ['version'], where: 'id = ?', whereArgs: [id], limit: 1);
    return ((rows.firstOrNull?['version'] as num?)?.toInt() ?? 0) + 1;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
