import 'dart:convert';

import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'catalog envelope preserves eventId, camelCase payload and integer money',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      const outbox = OutboxService();
      final occurredAt = DateTime.utc(2026, 9, 24, 10, 30);

      await outbox.enqueueEvent(
        db,
        entityId: 'entity-test',
        aggregateType: 'cash_transfer',
        aggregateId: 'transfer-test',
        eventType: 'CashTransferred',
        aggregateVersion: 1,
        occurredAt: occurredAt,
        eventId: 'event-fixed',
        payload: const {
          'transferId': 'transfer-test',
          'transferNumber': 'TR-001',
          'fromCashboxId': 'cash-a',
          'toCashboxId': 'cash-b',
          'amountMinor': 50000,
          'outTransactionId': 'tx-out',
          'inTransactionId': 'tx-in',
          'note': null,
        },
      );

      final row = (await db.query('sync_outbox')).single;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      expect(row['event_id'], 'event-fixed');
      expect(row['aggregate_type'], 'cash_transfer');
      expect(row['event_type'], 'CashTransferred');
      expect(row['aggregate_version'], 1);
      expect(row['occurred_at'], occurredAt.toIso8601String());
      expect(payload['amountMinor'], isA<int>());
      expect(
        payload.keys,
        containsAll(const [
          'transferId',
          'transferNumber',
          'fromCashboxId',
          'toCashboxId',
          'outTransactionId',
          'inTransactionId',
        ]),
      );
    },
  );

  test('product unit create and update preserve integer sale price', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    const outbox = OutboxService();

    for (final entry in const [
      ('ProductUnitCreated', 125000),
      ('ProductUnitUpdated', 987654321),
    ]) {
      await outbox.enqueueEvent(
        db,
        entityId: 'entity-price',
        aggregateType: 'product_unit',
        aggregateId: 'unit-price',
        eventType: entry.$1,
        aggregateVersion: 1,
        occurredAt: DateTime.utc(2026),
        payload: {
          'id': 'unit-price',
          'productId': 'product-price',
          'name': 'Unit',
          'factor': 1.0,
          'primary': true,
          'salePriceMinor': entry.$2,
          'updatedAt': '2026-01-01T00:00:00Z',
        },
      );
    }

    final rows = await db.query('sync_outbox', orderBy: 'aggregate_version');
    final prices = rows.map((row) {
      final payload = jsonDecode(row['payload_json'] as String) as Map;
      expect(payload['salePriceMinor'], isA<int>());
      return payload['salePriceMinor'];
    });
    expect(prices, [125000, 987654321]);

    await expectLater(
      outbox.enqueueEvent(
        db,
        entityId: 'entity-price',
        aggregateType: 'product_unit',
        aggregateId: 'unit-negative',
        eventType: 'ProductUnitCreated',
        aggregateVersion: 1,
        occurredAt: DateTime.utc(2026),
        payload: const {
          'id': 'unit-negative',
          'productId': 'product-price',
          'name': 'Unit',
          'factor': 1.0,
          'primary': false,
          'salePriceMinor': -1,
          'updatedAt': '2026-01-01T00:00:00Z',
        },
      ),
      throwsArgumentError,
    );
  });

  test('document v2 validates item economics before entering outbox', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    const outbox = OutboxService();
    final payload = <String, Object?>{
      'documentId': 'sale-v2',
      'documentNumber': 'S-002',
      'financialYearId': 'year-1',
      'partyId': null,
      'warehouseId': 'warehouse-1',
      'cashboxId': 'cashbox-1',
      'subtotalMinor': 1000,
      'discountMinor': 100,
      'finalMinor': 900,
      'paidMinor': 900,
      'dueDate': null,
      'note': null,
      'postedAt': '2026-09-27T12:00:00Z',
      'items': <Map<String, Object?>>[
        {
          'itemId': 'item-1',
          'productId': 'product-1',
          'productUnitId': 'unit-1',
          'warehouseId': 'warehouse-1',
          'unitFactor': 1.0,
          'baseQuantity': 2.0,
          'netAmountMinor': 900,
          'costAmountMinor': 500,
          'inventoryMovementId': 'movement-1',
        },
      ],
    };

    await outbox.enqueueEvent(
      db,
      entityId: 'entity-v2',
      aggregateType: 'sale',
      aggregateId: 'sale-v2',
      eventType: 'SalePosted',
      aggregateVersion: 1,
      occurredAt: DateTime.utc(2026, 9, 27, 12),
      payload: payload,
    );
    expect(await db.query('sync_outbox'), hasLength(1));

    final invalid = Map<String, Object?>.from(payload);
    invalid['items'] = [
      Map<String, Object?>.from(
        (payload['items'] as List<Map<String, Object?>>).single,
      )..remove('netAmountMinor'),
    ];
    await expectLater(
      outbox.enqueueEvent(
        db,
        entityId: 'entity-v2',
        aggregateType: 'sale',
        aggregateId: 'sale-invalid',
        eventType: 'SalePosted',
        aggregateVersion: 1,
        occurredAt: DateTime.utc(2026, 9, 27, 12),
        payload: invalid,
      ),
      throwsArgumentError,
    );
  });

  test(
    'product, category and barcode payloads match the supported catalog',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      const outbox = OutboxService();
      final at = DateTime.utc(2026, 9, 26, 12);

      final entries =
          <({String type, String aggregate, Map<String, Object?> payload})>[
            (
              type: 'CategoryCreated',
              aggregate: 'category-1',
              payload: {
                'id': 'category-1',
                'name': 'Food',
                'updatedAt': at.toIso8601String(),
              },
            ),
            (
              type: 'ProductUpdated',
              aggregate: 'product-1',
              payload: {
                'id': 'product-1',
                'categoryId': 'category-1',
                'name': 'Rice',
                'minQuantity': 12.5,
                'active': true,
                'itemType': 'STOCKED',
                'location': null,
                'costPriceMinor': 0,
                'updatedAt': at.toIso8601String(),
              },
            ),
            (
              type: 'BarcodeCreated',
              aggregate: 'barcode-1',
              payload: {
                'id': 'barcode-1',
                'productUnitId': 'unit-1',
                'code': '6281234567890',
                'createdAt': at.toIso8601String(),
              },
            ),
          ];
      for (final entry in entries) {
        await outbox.enqueueEvent(
          db,
          entityId: 'entity-products',
          aggregateType:
              entry.type.startsWith('Category')
                  ? 'category'
                  : entry.type.startsWith('Product')
                  ? 'product'
                  : 'barcode',
          aggregateId: entry.aggregate,
          eventType: entry.type,
          aggregateVersion: 1,
          occurredAt: at,
          payload: entry.payload,
        );
      }

      final rows = await db.query('sync_outbox', orderBy: 'event_type');
      expect(rows, hasLength(3));
      final product = rows.singleWhere(
        (row) => row['event_type'] == 'ProductUpdated',
      );
      final payload = jsonDecode(product['payload_json'] as String) as Map;
      expect(payload['name'], 'Rice');
      expect(payload['categoryId'], 'category-1');
      expect(payload['minQuantity'], 12.5);
      expect(payload['itemType'], 'STOCKED');
      expect(payload['costPriceMinor'], 0);
      expect(payload.keys, hasLength(9));
    },
  );

  test(
    'aggregate event versions advance independently from projection versions',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      const outbox = OutboxService();
      for (final type in ['PartyCreated', 'PartyUpdated']) {
        await outbox.enqueueEvent(
          db,
          entityId: 'entity-test',
          aggregateType: 'party',
          aggregateId: 'party-test',
          eventType: type,
          aggregateVersion: 1,
          occurredAt: DateTime.utc(2026),
          payload: const {
            'id': 'party-test',
            'name': 'Test',
            'type': 'CUSTOMER',
            'phone': null,
            'email': null,
            'address': null,
            'taxNumber': null,
            'openingBalanceMinor': 0,
            'creditLimitMinor': null,
            'active': true,
            'updatedAt': '2026-01-01T00:00:00Z',
          },
        );
      }
      final rows = await db.query('sync_outbox', orderBy: 'aggregate_version');
      expect(rows.map((row) => row['aggregate_version']), [1, 2]);
    },
  );

  test(
    'draft stays local and invalid catalog payload rolls back transaction',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      const outbox = OutboxService();
      await db.insert('entities', {
        'id': 'entity-test',
        'name': 'Test Entity',
        'currency_code': 'USD',
        'timezone': 'UTC',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      await outbox.enqueue(
        db,
        entityId: 'entity-test',
        aggregateType: 'sale',
        aggregateId: 'draft-sale',
        action: 'draft',
        payload: const {'id': 'draft-sale'},
      );
      expect(await db.query('sync_outbox'), isEmpty);

      await expectLater(
        db.transaction((txn) async {
          await txn.insert('categories', {
            'id': 'category-test',
            'entity_id': 'entity-test',
            'name': 'Test',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          });
          await outbox.enqueueEvent(
            txn,
            entityId: 'entity-test',
            aggregateType: 'cash_session',
            aggregateId: 'session-test',
            eventType: 'CashSessionOpened',
            aggregateVersion: 1,
            occurredAt: DateTime.utc(2026),
            payload: const {'cashbox_id': 'cash-test'},
          );
        }),
        throwsArgumentError,
      );
      expect(await db.query('categories'), isEmpty);
    },
  );
}
