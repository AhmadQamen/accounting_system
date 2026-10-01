import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/features/master_data/data/master_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'product insights keeps base quantities, average cost and document links',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      const at = '2026-09-27T10:00:00Z';
      await db.insert('entities', {
        'id': 'e',
        'name': 'Entity',
        'currency_code': 'IQD',
        'timezone': 'UTC',
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('financial_years', {
        'id': 'fy',
        'entity_id': 'e',
        'name': '2026',
        'starts_on': at,
        'ends_on': at,
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('categories', {
        'id': 'c',
        'entity_id': 'e',
        'name': 'Food',
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('products', {
        'id': 'p',
        'entity_id': 'e',
        'category_id': 'c',
        'name': 'Rice',
        'min_quantity': 5.0,
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('product_units', {
        'id': 'u',
        'entity_id': 'e',
        'product_id': 'p',
        'name': 'Bag',
        'factor': 1.0,
        'is_primary': 1,
        'sale_price_minor': 150000,
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('barcodes', {
        'id': 'b',
        'entity_id': 'e',
        'product_unit_id': 'u',
        'code': '6281',
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('warehouses', {
        'id': 'w',
        'entity_id': 'e',
        'name': 'Main',
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('inventory_items', {
        'id': 'i',
        'entity_id': 'e',
        'product_id': 'p',
        'warehouse_id': 'w',
        'current_quantity': 4.0,
        'inventory_value_minor': 40000,
        'updated_at': at,
      });
      await db.insert('inventory_movements', {
        'id': 'm',
        'entity_id': 'e',
        'financial_year_id': 'fy',
        'inventory_item_id': 'i',
        'movement_type': 'purchase',
        'quantity_delta': 4.0,
        'value_delta_minor': 40000,
        'reference_type': 'purchase',
        'reference_id': 'doc',
        'occurred_at': at,
        'created_at': at,
      });
      await db.insert('sales', {
        'id': 's',
        'entity_id': 'e',
        'financial_year_id': 'fy',
        'invoice_number': 'SAL-1',
        'status': 'posted',
        'subtotal_minor': 1,
        'final_minor': 1,
        'occurred_at': at,
        'created_at': at,
        'updated_at': at,
      });
      await db.insert('sale_items', {
        'id': 'si',
        'entity_id': 'e',
        'sale_id': 's',
        'inventory_item_id': 'i',
        'product_unit_id': 'u',
        'quantity': 1.0,
        'unit_factor_at_sale': 1.0,
        'base_quantity': 1.0,
        'unit_price_minor': 150000,
        'line_total_minor': 150000,
        'created_at': at,
        'updated_at': at,
      });

      final result = await MasterDataRepository(
        AppDatabase.instance,
      ).productInsights(
        'p',
        database: db,
        context: const LocalContext(
          entityId: 'e',
          userId: 'user',
          deviceId: 'device',
          financialYearId: 'fy',
          defaultWarehouseId: 'w',
          defaultCashboxId: '',
          currencyCode: 'IQD',
        ),
      );
      expect(result.stockByWarehouse.single.baseQuantity, 4.0);
      expect(result.stockByWarehouse.single.averageCostMinor, 10000);
      expect(result.stockByWarehouse.single.isLowStock, isTrue);
      expect(result.movements.single.quantityDelta, 4.0);
      expect(result.documents.single.number, 'SAL-1');
      expect(result.units.single.salePriceMinor, 150000);
      expect(result.barcodes.single.code, '6281');
    },
  );
}
