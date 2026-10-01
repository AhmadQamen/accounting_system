import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/services/inventory_ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> fixture() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    const at = '2026-09-30T10:00:00Z';
    await db.insert('entities', {
      'id': 'entity-a',
      'name': 'المؤسسة',
      'currency_code': 'IQD',
      'timezone': 'Asia/Damascus',
      'created_at': at,
      'updated_at': at,
    });
    await db.insert('financial_years', {
      'id': 'year-a',
      'entity_id': 'entity-a',
      'name': '2026',
      'starts_on': at,
      'ends_on': '2026-12-31T23:59:59Z',
      'created_at': at,
      'updated_at': at,
    });
    await db.insert('products', {
      'id': 'product-a',
      'entity_id': 'entity-a',
      'name': 'منتج',
      'cost_price_minor': 10000,
      'created_at': at,
      'updated_at': at,
    });
    await db.insert('warehouses', {
      'id': 'warehouse-a',
      'entity_id': 'entity-a',
      'name': 'المستودع',
      'created_at': at,
      'updated_at': at,
    });
    return db;
  }

  test('uses weighted average for multiple stock receipts and sale profit', () async {
    final db = await fixture();
    addTearDown(db.close);
    const ledger = InventoryLedgerService();
    final inventoryItemId = await ledger.ensureInventoryItem(
      db,
      entityId: 'entity-a',
      productId: 'product-a',
      warehouseId: 'warehouse-a',
    );

    Future<void> receipt({
      required String referenceId,
      required double quantity,
      required int unitCostMinor,
    }) => ledger.recordMovement(
      db,
      entityId: 'entity-a',
      financialYearId: 'year-a',
      inventoryItemId: inventoryItemId,
      movementType: 'opening_balance',
      quantityDelta: quantity,
      valueDeltaMinor: Money.multiplyByQuantity(unitCostMinor, quantity),
      referenceType: 'opening_balance',
      referenceId: referenceId,
    );

    await receipt(referenceId: 'opening-1', quantity: 10, unitCostMinor: 10000);
    await receipt(referenceId: 'opening-2', quantity: 30, unitCostMinor: 20000);

    final weightedAverage = await ledger.currentAverageUnitCostMinor(
      db,
      inventoryItemId,
    );
    expect(weightedAverage, 17500);

    const soldQuantity = 4.0;
    final saleCost = Money.multiplyByQuantity(weightedAverage, soldQuantity);
    const netSale = 96000;
    expect(saleCost, 70000);
    expect(netSale - saleCost, 26000);

    await ledger.recordMovement(
      db,
      entityId: 'entity-a',
      financialYearId: 'year-a',
      inventoryItemId: inventoryItemId,
      movementType: 'sale',
      quantityDelta: -soldQuantity,
      valueDeltaMinor: -saleCost,
      referenceType: 'sale',
      referenceId: 'sale-1',
    );
    expect(
      await ledger.currentAverageUnitCostMinor(db, inventoryItemId),
      17500,
    );
  });
}
