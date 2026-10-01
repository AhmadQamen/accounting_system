import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/master_data/models/product_unit_hierarchy.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:sqflite/sqflite.dart';

class MasterDataRepository {
  MasterDataRepository(this._database);
  final AppDatabase _database;
  final _outbox = const OutboxService();

  Future<List<Party>> listParties({String? type, String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final where = <String>['entity_id = ?', 'deleted_at IS NULL'];
    final args = <Object?>[ctx.entityId];
    if (type != null && type != 'all') {
      where.add(
        type == 'customer'
            ? "type IN ('customer','both')"
            : "type IN ('supplier','both')",
      );
    }
    if (search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR phone LIKE ?)');
      args.add('%${search.trim()}%');
      args.add('%${search.trim()}%');
    }
    final rows = await db.query(
      'parties',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Party.fromSql).toList(growable: false);
  }

  Future<String> saveParty({
    String? id,
    required String name,
    String? phone,
    required String type,
  }) async {
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
        await txn.update(
          'parties',
          {
            'name': name.trim(),
            'phone': phone?.trim(),
            'type': type,
            'updated_at': now,
            'version': await _nextVersion(txn, 'parties', partyId),
          },
          where: 'id = ? AND entity_id = ?',
          whereArgs: [partyId, ctx.entityId],
        );
      }
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'party',
        partyId,
        id == null ? 'PartyCreated' : 'PartyUpdated',
        now,
      );
    });
    return partyId;
  }

  Future<void> archiveParty(String id) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.update(
        'parties',
        {'deleted_at': now, 'updated_at': now},
        where: 'id = ? AND entity_id = ?',
        whereArgs: [id, ctx.entityId],
      );
      await _enqueueDeleted(
        txn,
        ctx.entityId,
        'party',
        id,
        'PartyDeleted',
        now,
      );
    });
  }

  Future<List<Category>> listCategories() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'categories',
      where: 'entity_id = ? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name',
    );
    return rows.map(Category.fromSql).toList(growable: false);
  }

  Future<String> saveCategory({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final categoryId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('categories', {
          'id': categoryId,
          'entity_id': ctx.entityId,
          'name': name.trim(),
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'categories',
          {
            'name': name.trim(),
            'updated_at': now,
            'version': await _nextVersion(txn, 'categories', categoryId),
          },
          where: 'id = ? AND entity_id = ?',
          whereArgs: [categoryId, ctx.entityId],
        );
      }
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'category',
        categoryId,
        id == null ? 'CategoryCreated' : 'CategoryUpdated',
        now,
      );
    });
    return categoryId;
  }

  Future<List<Product>> listProducts({String search = ''}) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final args = <Object?>[ctx.entityId];
    var where = 'p.entity_id = ? AND p.deleted_at IS NULL';
    if (search.trim().isNotEmpty) {
      where +=
          ' AND (p.name LIKE ? OR EXISTS (SELECT 1 FROM product_units u JOIN barcodes b ON b.product_unit_id = u.id WHERE u.product_id = p.id AND b.deleted_at IS NULL AND b.code LIKE ?))';
      args.add('%${search.trim()}%');
      args.add('%${search.trim()}%');
    }
    final rows = await db.rawQuery('''
SELECT p.*, c.name AS category_name,
       (SELECT u.id FROM product_units u WHERE u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL LIMIT 1) AS primary_unit_id,
       (SELECT u.name FROM product_units u WHERE u.product_id=p.id AND u.is_primary=1 AND u.deleted_at IS NULL LIMIT 1) AS primary_unit_name
FROM products p
LEFT JOIN categories c ON c.id=p.category_id
WHERE $where
ORDER BY p.name COLLATE NOCASE
''', args);
    return rows.map(Product.fromSql).toList(growable: false);
  }

  Future<String> createProduct({
    required String name,
    String? categoryId,
    double minQuantity = 0,
    String itemType = 'stocked',
    String? location,
    int costPriceMinor = 0,
    String primaryUnitName = 'Unit',
    int salePriceMinor = 0,
    String? barcode,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('اسم المنتج مطلوب');
    if (minQuantity < 0)
      throw ArgumentError('الحد الأدنى للمخزون لا يمكن أن يكون سالباً');
    if (itemType != 'stocked' && itemType != 'non_stocked') {
      throw ArgumentError('نوع المادة غير صالح');
    }
    if (costPriceMinor < 0) throw ArgumentError('سعر الكلفة لا يمكن أن يكون سالباً');
    if (primaryUnitName.trim().isEmpty) {
      throw ArgumentError('اسم وحدة الأساس مطلوب');
    }
    if (salePriceMinor < 0) {
      throw ArgumentError('Sale price must be non-negative');
    }
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final productId = uuid.v4();
    final unitId = uuid.v4();
    final inventoryItemId = uuid.v4();
    final barcodeId =
        barcode != null && barcode.trim().isNotEmpty ? uuid.v4() : null;
    await _database.transaction((txn) async {
      if (categoryId != null) {
        final category = await txn.query(
          'categories',
          columns: ['id'],
          where: 'id=? AND entity_id=? AND deleted_at IS NULL',
          whereArgs: [categoryId, ctx.entityId],
          limit: 1,
        );
        if (category.isEmpty) throw StateError('التصنيف المحدد غير موجود');
      }
      if (barcode != null && barcode.trim().isNotEmpty) {
        final duplicate = await txn.query(
          'barcodes',
          columns: ['id'],
          where: 'entity_id=? AND code=? AND deleted_at IS NULL',
          whereArgs: [ctx.entityId, barcode.trim()],
          limit: 1,
        );
        if (duplicate.isNotEmpty) {
          throw StateError('الباركود مستخدم مسبقاً لوحدة أخرى');
        }
      }
      await txn.insert('products', {
        'id': productId,
        'entity_id': ctx.entityId,
        'category_id': categoryId,
        'name': name.trim(),
        'min_quantity': minQuantity,
        'item_type': itemType,
        'location': location?.trim().isEmpty ?? true ? null : location!.trim(),
        'cost_price_minor': costPriceMinor,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('product_units', {
        'id': unitId,
        'entity_id': ctx.entityId,
        'product_id': productId,
        'name':
            primaryUnitName.trim().isEmpty ? 'Unit' : primaryUnitName.trim(),
        'factor': 1.0,
        'is_primary': 1,
        'sale_price_minor': salePriceMinor,
        'created_at': now,
        'updated_at': now,
      });
      if (itemType == 'stocked') {
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
      }
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
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'product',
        productId,
        'ProductCreated',
        now,
      );
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'product_unit',
        unitId,
        'ProductUnitCreated',
        now,
      );
      if (barcodeId != null) {
        await _enqueueMaster(
          txn,
          ctx.entityId,
          'barcode',
          barcodeId,
          'BarcodeCreated',
          now,
        );
      }
    });
    return productId;
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    String? categoryId,
    required double minQuantity,
    String itemType = 'stocked',
    String? location,
    int costPriceMinor = 0,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('اسم المنتج مطلوب');
    if (minQuantity < 0)
      throw ArgumentError('الحد الأدنى للمخزون لا يمكن أن يكون سالباً');
    if (itemType != 'stocked' && itemType != 'non_stocked') {
      throw ArgumentError('نوع المادة غير صالح');
    }
    if (costPriceMinor < 0) throw ArgumentError('سعر الكلفة لا يمكن أن يكون سالباً');
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      if (categoryId != null) {
        final category = await txn.query(
          'categories',
          columns: ['id'],
          where: 'id=? AND entity_id=? AND deleted_at IS NULL',
          whereArgs: [categoryId, ctx.entityId],
          limit: 1,
        );
        if (category.isEmpty) throw StateError('التصنيف المحدد غير موجود');
      }
      final updated = await txn.update(
        'products',
        {
          'name': name.trim(),
          'category_id': categoryId,
          'min_quantity': minQuantity,
          'item_type': itemType,
          'location': location?.trim().isEmpty ?? true ? null : location!.trim(),
          'cost_price_minor': costPriceMinor,
          'updated_at': now,
          'version': await _nextVersion(txn, 'products', id),
        },
        where: 'id=? AND entity_id=? AND deleted_at IS NULL',
        whereArgs: [id, ctx.entityId],
      );
      if (updated != 1) throw StateError('المنتج غير موجود');
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'product',
        id,
        'ProductUpdated',
        now,
      );
    });
  }

  Future<List<ProductUnit>> listProductUnits(String productId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'product_units',
      where: 'entity_id=? AND product_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId, productId],
      orderBy: 'is_primary DESC, name COLLATE NOCASE',
    );
    return ProductUnitHierarchy.ordered(rows.map(ProductUnit.fromSql));
  }

  Future<String> saveProductUnit({
    required String productId,
    String? id,
    required String name,
    String? parentUnitId,
    double unitsPerParent = 1,
    int salePriceMinor = 0,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Unit name is required');
    if (salePriceMinor < 0) {
      throw ArgumentError('Sale price must be non-negative');
    }
    final ctx = await LocalContextService.instance.current;
    final unitId = id ?? uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final product = await txn.query(
        'products',
        columns: ['id'],
        where: 'id=? AND entity_id=? AND deleted_at IS NULL',
        whereArgs: [productId, ctx.entityId],
        limit: 1,
      );
      if (product.isEmpty) {
        throw StateError('المنتج المحدد غير موجود');
      }
      final unitRows = await txn.query(
        'product_units',
        where: 'entity_id=? AND product_id=? AND deleted_at IS NULL',
        whereArgs: [ctx.entityId, productId],
      );
      final units = unitRows.map(ProductUnit.fromSql).toList(growable: false);
      ProductUnit? current;
      if (id != null) {
        for (final unit in units) {
          if (unit.id == unitId) {
            current = unit;
            break;
          }
        }
        if (current == null) {
          throw StateError('الوحدة المحددة غير موجودة');
        }
      }
      final duplicates = await txn.query(
        'product_units',
        columns: ['id'],
        where:
            'entity_id=? AND product_id=? AND name=? AND id<>? AND deleted_at IS NULL',
        whereArgs: [ctx.entityId, productId, name.trim(), id ?? ''],
        limit: 1,
      );
      if (duplicates.isNotEmpty) {
        throw StateError('هذه الوحدة مضافة للمنتج مسبقاً');
      }

      final isBase = current?.isPrimary ?? false;
      late final double factor;
      if (isBase) {
        factor = 1;
      } else {
        if (parentUnitId == null) {
          throw ArgumentError(
            'اختر الوحدة الأصغر التي تحتويها هذه العبوة',
          );
        }
        if (parentUnitId == unitId) {
          throw ArgumentError('لا يمكن أن تحتوي الوحدة نفسها');
        }
        ProductUnit? parent;
        for (final unit in units) {
          if (unit.id == parentUnitId) {
            parent = unit;
            break;
          }
        }
        if (parent == null) {
          throw StateError('الوحدة الأصغر المحددة غير موجودة');
        }
        final expectedParent =
            current == null
                ? (ProductUnitHierarchy.ordered(units).lastOrNull)
                : ProductUnitHierarchy.parentOf(current, units);
        if (expectedParent == null || expectedParent.id != parent.id) {
          throw StateError(
            'للحفاظ على سلسلة تحويل واضحة، أضف العبوة فوق آخر وحدة في السلسلة',
          );
        }
        factor = ProductUnitHierarchy.factorToBase(
          parent: parent,
          unitsPerParent: unitsPerParent,
        );
        if (current != null) {
          final largerUnits = ProductUnitHierarchy.ordered(
            units.where((unit) => unit.id != unitId && unit.factor > current!.factor),
          );
          final nextUnit = largerUnits.firstOrNull;
          if (nextUnit != null && factor >= nextUnit.factor) {
            throw StateError(
              'معامل ${current.name} يجب أن يبقى أصغر من معامل ${nextUnit.name}',
            );
          }
        }
        if (units.any(
          (unit) =>
              unit.id != unitId && (unit.factor - factor).abs() < 0.0000001,
        )) {
          throw StateError('توجد وحدة أخرى بنفس معامل التحويل');
        }
      }
      if (id == null) {
        await txn.insert('product_units', {
          'id': unitId,
          'entity_id': ctx.entityId,
          'product_id': productId,
          'name': name.trim(),
          'factor': factor,
          'is_primary': 0,
          'sale_price_minor': salePriceMinor,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'product_units',
          {
            'name': name.trim(),
            'factor': factor,
            'is_primary': isBase ? 1 : 0,
            'sale_price_minor': salePriceMinor,
            'updated_at': now,
            'version': await _nextVersion(txn, 'product_units', unitId),
          },
          where: 'id=? AND entity_id=? AND product_id=?',
          whereArgs: [unitId, ctx.entityId, productId],
        );
      }
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'product_unit',
        unitId,
        id == null ? 'ProductUnitCreated' : 'ProductUnitUpdated',
        now,
      );
    });
    return unitId;
  }

  Future<List<Barcode>> listBarcodes(String productId) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
SELECT b.*, u.name AS unit_name
FROM barcodes b
JOIN product_units u ON u.id=b.product_unit_id
WHERE b.entity_id=? AND u.product_id=? AND b.deleted_at IS NULL AND u.deleted_at IS NULL
ORDER BY b.code
''',
      [ctx.entityId, productId],
    );
    return rows.map(Barcode.fromSql).toList(growable: false);
  }

  Future<ProductInsights> productInsights(
    String productId, {
    int movementLimit = 40,
    int documentLimit = 30,
    Database? database,
    LocalContext? context,
  }) async {
    final ctx = context ?? await LocalContextService.instance.current;
    final db = database ?? await _database.database;
    final unitsFuture = db.query(
      'product_units',
      where: 'entity_id=? AND product_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId, productId],
      orderBy: 'is_primary DESC, name COLLATE NOCASE',
    );
    final barcodesFuture = db.rawQuery(
      '''SELECT b.*, u.name AS unit_name FROM barcodes b
         JOIN product_units u ON u.id=b.product_unit_id
         WHERE b.entity_id=? AND u.product_id=? AND b.deleted_at IS NULL AND u.deleted_at IS NULL
         ORDER BY b.code''',
      [ctx.entityId, productId],
    );
    final stockFuture = db.rawQuery(
      '''
SELECT i.warehouse_id, w.name warehouse_name, i.current_quantity,
       i.inventory_value_minor, p.min_quantity
FROM inventory_items i
JOIN warehouses w ON w.id=i.warehouse_id
JOIN products p ON p.id=i.product_id
WHERE i.entity_id=? AND i.product_id=? AND w.deleted_at IS NULL
ORDER BY w.name COLLATE NOCASE
''',
      [ctx.entityId, productId],
    );
    final movementsFuture = db.rawQuery(
      '''
SELECT m.movement_type, m.quantity_delta, m.reference_type, m.reference_id,
       m.occurred_at, w.name warehouse_name
FROM inventory_movements m
JOIN inventory_items i ON i.id=m.inventory_item_id
JOIN warehouses w ON w.id=i.warehouse_id
WHERE m.entity_id=? AND i.product_id=?
ORDER BY m.occurred_at DESC, m.created_at DESC
LIMIT ?
''',
      [ctx.entityId, productId, movementLimit],
    );
    // Each branch is a posted/draft/void document that contains this product.
    // The page preserves status so reversals and returns are never hidden.
    final documentsFuture = db.rawQuery(
      '''
SELECT * FROM (
  SELECT s.id, 'sale' type, s.invoice_number number, s.status, s.occurred_at
  FROM sales s JOIN sale_items x ON x.sale_id=s.id JOIN inventory_items i ON i.id=x.inventory_item_id
  WHERE s.entity_id=? AND i.product_id=? AND s.deleted_at IS NULL AND x.deleted_at IS NULL
  UNION
  SELECT p.id, 'purchase', p.invoice_number, p.status, p.occurred_at
  FROM purchase_invoices p JOIN purchase_items x ON x.purchase_invoice_id=p.id JOIN inventory_items i ON i.id=x.inventory_item_id
  WHERE p.entity_id=? AND i.product_id=? AND p.deleted_at IS NULL AND x.deleted_at IS NULL
  UNION
  SELECT r.id, 'sale_return', r.return_number, r.status, r.occurred_at
  FROM sale_return_invoices r JOIN sale_return_items x ON x.sale_return_invoice_id=r.id JOIN inventory_items i ON i.id=x.inventory_item_id
  WHERE r.entity_id=? AND i.product_id=? AND r.deleted_at IS NULL
  UNION
  SELECT r.id, 'purchase_return', r.return_number, r.status, r.occurred_at
  FROM purchase_return_invoices r JOIN purchase_return_items x ON x.purchase_return_invoice_id=r.id JOIN inventory_items i ON i.id=x.inventory_item_id
  WHERE r.entity_id=? AND i.product_id=? AND r.deleted_at IS NULL
  UNION
  SELECT w.id, 'waste', w.waste_number, w.status, w.occurred_at
  FROM waste_invoices w JOIN waste_items x ON x.waste_invoice_id=w.id JOIN inventory_items i ON i.id=x.inventory_item_id
  WHERE w.entity_id=? AND i.product_id=? AND w.deleted_at IS NULL
) ORDER BY occurred_at DESC LIMIT ?
''',
      [
        ctx.entityId,
        productId,
        ctx.entityId,
        productId,
        ctx.entityId,
        productId,
        ctx.entityId,
        productId,
        ctx.entityId,
        productId,
        documentLimit,
      ],
    );
    final stocks = await stockFuture;
    final movements = await movementsFuture;
    final documents = await documentsFuture;
    return ProductInsights(
      units: ProductUnitHierarchy.ordered(
        (await unitsFuture).map(ProductUnit.fromSql),
      ),
      barcodes: (await barcodesFuture)
          .map(Barcode.fromSql)
          .toList(growable: false),
      stockByWarehouse: stocks
          .map((row) {
            final quantity = (row['current_quantity'] as num?)?.toDouble() ?? 0;
            final value = (row['inventory_value_minor'] as num?)?.toInt() ?? 0;
            return ProductWarehouseStock(
              warehouseId: row['warehouse_id']?.toString() ?? '',
              warehouseName: row['warehouse_name']?.toString() ?? '',
              baseQuantity: quantity,
              inventoryValueMinor: value,
              averageCostMinor:
                  quantity.abs() < 0.000001 ? 0 : (value / quantity).round(),
              isLowStock:
                  quantity <= ((row['min_quantity'] as num?)?.toDouble() ?? 0),
            );
          })
          .toList(growable: false),
      movements: movements
          .map(
            (row) => ProductMovementSummary(
              type: row['movement_type']?.toString() ?? '',
              quantityDelta: (row['quantity_delta'] as num?)?.toDouble() ?? 0,
              referenceType: row['reference_type']?.toString() ?? '',
              referenceId: row['reference_id']?.toString() ?? '',
              warehouseName: row['warehouse_name']?.toString() ?? '',
              occurredAt: DateTime.tryParse(
                row['occurred_at']?.toString() ?? '',
              ),
            ),
          )
          .toList(growable: false),
      documents: documents
          .map(
            (row) => ProductDocumentLink(
              id: row['id']?.toString() ?? '',
              type: row['type']?.toString() ?? '',
              number: row['number']?.toString() ?? '',
              status: row['status']?.toString() ?? '',
              occurredAt: DateTime.tryParse(
                row['occurred_at']?.toString() ?? '',
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<String> addBarcode({
    required String productUnitId,
    required String code,
  }) async {
    if (code.trim().isEmpty) throw ArgumentError('Barcode is required');
    final ctx = await LocalContextService.instance.current;
    final id = uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final unit = await txn.query(
        'product_units',
        columns: ['id'],
        where: 'id=? AND entity_id=? AND deleted_at IS NULL',
        whereArgs: [productUnitId, ctx.entityId],
        limit: 1,
      );
      if (unit.isEmpty) throw StateError('الوحدة المحددة غير موجودة');
      final duplicate = await txn.query(
        'barcodes',
        columns: ['id'],
        where: 'entity_id=? AND code=? AND deleted_at IS NULL',
        whereArgs: [ctx.entityId, code.trim()],
        limit: 1,
      );
      if (duplicate.isNotEmpty)
        throw StateError('الباركود مستخدم مسبقاً لوحدة أخرى');
      await txn.insert('barcodes', {
        'id': id,
        'entity_id': ctx.entityId,
        'product_unit_id': productUnitId,
        'code': code.trim(),
        'created_at': now,
        'updated_at': now,
      });
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'barcode',
        id,
        'BarcodeCreated',
        now,
      );
    });
    return id;
  }

  Future<List<ProductSpecification>> listProductSpecifications(
    String productId,
  ) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'product_specifications',
      where: 'entity_id=? AND product_id=? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId, productId],
      orderBy: 'title',
    );
    return rows.map(ProductSpecification.fromSql).toList(growable: false);
  }

  Future<String> addProductSpecification({
    required String productId,
    required String title,
    required String value,
  }) async {
    if (title.trim().isEmpty || value.trim().isEmpty)
      throw ArgumentError('Specification title and value are required');
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
    });
    return id;
  }

  Future<List<Warehouse>> listWarehouses() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'warehouses',
      where: 'entity_id = ? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name',
    );
    return rows.map(Warehouse.fromSql).toList(growable: false);
  }

  Future<String> saveWarehouse({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final warehouseId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('warehouses', {
          'id': warehouseId,
          'entity_id': ctx.entityId,
          'name': name.trim(),
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'warehouses',
          {
            'name': name.trim(),
            'updated_at': now,
            'version': await _nextVersion(txn, 'warehouses', warehouseId),
          },
          where: 'id = ? AND entity_id = ?',
          whereArgs: [warehouseId, ctx.entityId],
        );
      }
      await _enqueueMaster(
        txn,
        ctx.entityId,
        'warehouse',
        warehouseId,
        id == null ? 'WarehouseCreated' : 'WarehouseUpdated',
        now,
      );
    });
    return warehouseId;
  }

  Future<List<FinancialYear>> listFinancialYears() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'financial_years',
      where: 'entity_id = ?',
      whereArgs: [ctx.entityId],
      orderBy: 'starts_on DESC',
    );
    return rows.map(FinancialYear.fromSql).toList(growable: false);
  }

  Future<String> createFinancialYear({
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    if (!endsOn.isAfter(startsOn))
      throw ArgumentError('Financial year end must be after start');
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
    });
    return id;
  }

  Future<void> activateFinancialYear(String id) async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'financial_years',
      where: 'id=? AND entity_id=? AND is_open=1',
      whereArgs: [id, ctx.entityId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Financial year must be open');
    await db.update('app_context', {
      'financial_year_id': id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'singleton=1');
    LocalContextService.instance.clearCache();
  }

  Future<void> closeFinancialYear(String id) async {
    final ctx = await LocalContextService.instance.current;
    if (id == ctx.financialYearId) {
      throw StateError(
        'Activate another open financial year before closing the current year',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      final changed = await txn.update(
        'financial_years',
        {
          'is_open': 0,
          'closed_at': now,
          'closed_by': ctx.userId,
          'updated_at': now,
        },
        where: 'id=? AND entity_id=? AND is_open=1',
        whereArgs: [id, ctx.entityId],
      );
      if (changed == 0) throw StateError('Open financial year not found');
    });
  }

  Future<void> archiveWarehouse(String id) async {
    final ctx = await LocalContextService.instance.current;
    if (id == ctx.defaultWarehouseId)
      throw StateError('Cannot archive the default warehouse');
    final db = await _database.database;
    final balances = await db.rawQuery(
      'SELECT COUNT(*) c FROM inventory_items WHERE entity_id=? AND warehouse_id=? AND ABS(current_quantity) > 0.000001',
      [ctx.entityId, id],
    );
    if ((balances.first['c'] as num).toInt() > 0)
      throw StateError('Warehouse has stock and cannot be archived');
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.update(
        'warehouses',
        {'deleted_at': now, 'updated_at': now},
        where: 'id=? AND entity_id=?',
        whereArgs: [id, ctx.entityId],
      );
    });
  }

  Future<List<Cashbox>> listCashboxes() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final rows = await db.query(
      'cashboxes',
      where: 'entity_id = ? AND deleted_at IS NULL',
      whereArgs: [ctx.entityId],
      orderBy: 'name',
    );
    return rows.map(Cashbox.fromSql).toList(growable: false);
  }

  Future<String> saveCashbox({String? id, required String name}) async {
    final ctx = await LocalContextService.instance.current;
    final now = DateTime.now().toUtc().toIso8601String();
    final cashboxId = id ?? uuid.v4();
    await _database.transaction((txn) async {
      if (id == null) {
        await txn.insert('cashboxes', {
          'id': cashboxId,
          'entity_id': ctx.entityId,
          'name': name.trim(),
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'cashboxes',
          {
            'name': name.trim(),
            'updated_at': now,
            'version': await _nextVersion(txn, 'cashboxes', cashboxId),
          },
          where: 'id = ? AND entity_id = ?',
          whereArgs: [cashboxId, ctx.entityId],
        );
      }
      if (id == null) {
        await _enqueueMaster(
          txn,
          ctx.entityId,
          'cashbox',
          cashboxId,
          'CashboxCreated',
          now,
        );
      }
    });
    return cashboxId;
  }

  Future<void> _enqueueMaster(
    DatabaseExecutor db,
    String entityId,
    String aggregateType,
    String aggregateId,
    String eventType,
    String occurredAt,
  ) async {
    final table = switch (aggregateType) {
      'party' => 'parties',
      'category' => 'categories',
      'product' => 'products',
      'product_unit' => 'product_units',
      'barcode' => 'barcodes',
      'warehouse' => 'warehouses',
      'cashbox' => 'cashboxes',
      _ => throw ArgumentError('Unsupported catalog aggregate $aggregateType'),
    };
    final rows = await db.query(
      table,
      where: 'id=? AND entity_id=?',
      whereArgs: [aggregateId, entityId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('$table record not found');
    final row = rows.single;
    final payload = switch (aggregateType) {
      'party' => <String, Object?>{
        'id': aggregateId,
        'name': row['name'],
        'type': (row['type'] as String).toUpperCase(),
        'phone': row['phone'],
        'email': null,
        'address': null,
        'taxNumber': null,
        'openingBalanceMinor': 0,
        'creditLimitMinor': null,
        'active': row['deleted_at'] == null,
        'updatedAt': row['updated_at'],
      },
      'category' => <String, Object?>{
        'id': aggregateId,
        'name': row['name'],
        'updatedAt': row['updated_at'],
      },
      'product' => <String, Object?>{
        'id': aggregateId,
        'categoryId': row['category_id'],
        'name': row['name'],
        'minQuantity': row['min_quantity'],
        'active': row['deleted_at'] == null,
        'itemType': (row['item_type'] as String).toUpperCase(),
        'location': row['location'],
        'costPriceMinor': row['cost_price_minor'] as int,
        'updatedAt': row['updated_at'],
      },
      'product_unit' => <String, Object?>{
        'id': aggregateId,
        'productId': row['product_id'],
        'name': row['name'],
        'factor': row['factor'],
        'primary': row['is_primary'] == 1,
        'salePriceMinor': row['sale_price_minor'] as int,
        'updatedAt': row['updated_at'],
      },
      'barcode' => <String, Object?>{
        'id': aggregateId,
        'productUnitId': row['product_unit_id'],
        'code': row['code'],
        'createdAt': row['created_at'],
      },
      'warehouse' => <String, Object?>{
        'id': aggregateId,
        'name': row['name'],
        'active': row['deleted_at'] == null,
        'updatedAt': row['updated_at'],
      },
      'cashbox' => <String, Object?>{
        'id': aggregateId,
        'name': row['name'],
        'createdAt': row['created_at'],
      },
      _ => throw StateError('Unreachable aggregate'),
    };
    await _outbox.enqueueEvent(
      db,
      entityId: entityId,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      eventType: eventType,
      aggregateVersion: (row['version'] as num).toInt(),
      occurredAt: DateTime.parse(occurredAt),
      payload: payload,
    );
  }

  Future<void> _enqueueDeleted(
    DatabaseExecutor db,
    String entityId,
    String aggregateType,
    String aggregateId,
    String eventType,
    String deletedAt,
  ) async {
    final table = aggregateType == 'party' ? 'parties' : 'categories';
    final rows = await db.query(
      table,
      columns: ['version'],
      where: 'id=?',
      whereArgs: [aggregateId],
      limit: 1,
    );
    await _outbox.enqueueEvent(
      db,
      entityId: entityId,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      eventType: eventType,
      aggregateVersion: (rows.single['version'] as num).toInt() + 1,
      occurredAt: DateTime.parse(deletedAt),
      payload: {'id': aggregateId, 'deletedAt': deletedAt},
    );
  }

  Future<int> _nextVersion(dynamic db, String table, String id) async {
    final rows = await db.query(
      table,
      columns: ['version'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return (((rows.isEmpty ? null : rows.first['version']) as num?)?.toInt() ??
            0) +
        1;
  }
}
