import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/sync/domain_event_projector.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:accounting_system/features/master_data/models/product_unit_hierarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const piece = ProductUnit(
    id: 'piece',
    productId: 'product-a',
    name: 'قطعة',
    factor: 1,
    isPrimary: true,
    salePriceMinor: 100,
  );
  const box = ProductUnit(
    id: 'box',
    productId: 'product-a',
    name: 'علبة',
    factor: 24,
    salePriceMinor: 2000,
  );
  const carton = ProductUnit(
    id: 'carton',
    productId: 'product-a',
    name: 'طرد',
    factor: 288,
    salePriceMinor: 22000,
  );

  test('builds piece box carton hierarchy using base factors', () {
    final units = ProductUnitHierarchy.ordered([carton, piece, box]);
    expect(units.map((unit) => unit.id), ['piece', 'box', 'carton']);
    expect(ProductUnitHierarchy.parentOf(box, units)?.id, 'piece');
    expect(ProductUnitHierarchy.unitsPerParent(box, units), 24);
    expect(ProductUnitHierarchy.parentOf(carton, units)?.id, 'box');
    expect(ProductUnitHierarchy.unitsPerParent(carton, units), 12);
    expect(
      ProductUnitHierarchy.factorToBase(parent: box, unitsPerParent: 12),
      288,
    );
    expect(3 * carton.factor, 864);
  });

  test('rejects a package that does not contain more than one child unit', () {
    expect(
      () => ProductUnitHierarchy.factorToBase(
        parent: piece,
        unitsPerParent: 1,
      ),
      throwsArgumentError,
    );
  });

  test('second device rebuilds the same hierarchy from contract events', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
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
    const projector = SqliteDomainEventProjector();
    final events = <DomainEvent>[
      _event('product-event', 'product', 'product-a', 'ProductCreated', {
        'id': 'product-a',
        'categoryId': null,
        'name': 'منتج',
        'minQuantity': 0.0,
        'itemType': 'stocked',
        'location': null,
        'costPriceMinor': 0,
        'updatedAt': at,
      }),
      _unitEvent(piece, at),
      _unitEvent(box, at),
      _unitEvent(carton, at),
    ];
    await db.transaction((txn) async {
      for (final event in events) {
        await projector.apply(txn, entityId: 'entity-a', event: event);
      }
    });

    final rows = await db.query('product_units', where: 'entity_id=?', whereArgs: ['entity-a']);
    final rebuilt = ProductUnitHierarchy.ordered(rows.map(ProductUnit.fromSql));
    expect(ProductUnitHierarchy.parentOf(rebuilt[1], rebuilt)?.name, 'قطعة');
    expect(ProductUnitHierarchy.unitsPerParent(rebuilt[1], rebuilt), 24);
    expect(ProductUnitHierarchy.parentOf(rebuilt[2], rebuilt)?.name, 'علبة');
    expect(ProductUnitHierarchy.unitsPerParent(rebuilt[2], rebuilt), 12);
    expect(rebuilt[2].factor, 288);
  });
}

DomainEvent _unitEvent(ProductUnit unit, String at) => _event(
  '${unit.id}-event',
  'product_unit',
  unit.id!,
  'ProductUnitCreated',
  {
    'id': unit.id,
    'productId': unit.productId,
    'name': unit.name,
    'factor': unit.factor,
    'primary': unit.isPrimary,
    'salePriceMinor': unit.salePriceMinor,
    'updatedAt': at,
  },
);

DomainEvent _event(
  String eventId,
  String aggregateType,
  String aggregateId,
  String eventType,
  Map<String, dynamic> payload,
) => DomainEvent(
  eventId: eventId,
  aggregateType: aggregateType,
  aggregateId: aggregateId,
  eventType: eventType,
  aggregateVersion: 1,
  occurredAt: '2026-09-30T10:00:00Z',
  payload: payload,
);
