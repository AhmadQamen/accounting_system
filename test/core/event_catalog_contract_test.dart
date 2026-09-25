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
      expect(await db.query('legacy_sync_quarantine'), isEmpty);

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
