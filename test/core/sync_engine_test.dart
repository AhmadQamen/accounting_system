import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/core/sync/domain_event_projector.dart';
import 'package:accounting_system/core/sync/sync_engine.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('network loss after push resends the same eventId', () async {
    final fixture = await _fixture();
    addTearDown(fixture.db.close);
    await _event(fixture.db, 'event-stable');
    fixture.transport.failPushOnce = true;

    await expectLater(
      fixture.engine.syncNow(),
      throwsA(isA<NetworkException>()),
    );
    var row = (await fixture.db.query('sync_outbox')).single;
    expect(row['event_id'], 'event-stable');
    expect(row['status'], 'failed');
    await fixture.db.update('sync_outbox', {'next_retry_at': null});

    await fixture.engine.syncNow();
    expect(fixture.transport.pushedIds, ['event-stable', 'event-stable']);
    expect(await fixture.db.query('sync_outbox'), isEmpty);
  });

  test('duplicate pulled event is not projected twice', () async {
    final projector = _CountingProjector();
    final fixture = await _fixture(projector: projector);
    addTearDown(fixture.db.close);
    final event = _pulled('remote-1', 1);
    fixture.transport.pullBatches.addAll([
      SyncPullBatch(events: [event], lastServerSequence: 1, hasMore: true),
      SyncPullBatch(events: [event], lastServerSequence: 2, hasMore: false),
    ]);

    await fixture.engine.syncNow();
    expect(projector.calls, 1);
    expect(await fixture.db.query('sync_changes'), hasLength(1));
    expect(fixture.transport.acks, [2]);
  });

  test(
    'pull projection failure rolls back event and cursor and sends no ack',
    () async {
      final fixture = await _fixture(projector: _FailingProjector());
      addTearDown(fixture.db.close);
      fixture.transport.pullBatches.add(
        SyncPullBatch(
          events: [_pulled('bad-event', 4)],
          lastServerSequence: 4,
          hasMore: false,
        ),
      );

      await expectLater(fixture.engine.syncNow(), throwsStateError);
      expect(await fixture.db.query('sync_changes'), isEmpty);
      final cursor = (await fixture.db.query('sync_cursors')).single;
      expect(cursor['server_sequence'], 0);
      expect(fixture.transport.acks, isEmpty);
    },
  );

  test('partial HTTP 200 push results are persisted per event', () async {
    final fixture = await _fixture();
    addTearDown(fixture.db.close);
    for (final id in ['accepted', 'duplicate', 'conflict', 'rejected']) {
      await _event(fixture.db, id);
    }
    fixture.transport.pushResults = const [
      SyncPushResult(
        eventId: 'accepted',
        status: 'ACCEPTED',
        serverSequence: 1,
      ),
      SyncPushResult(
        eventId: 'duplicate',
        status: 'ALREADY_ACCEPTED',
        serverSequence: 2,
      ),
      SyncPushResult(
        eventId: 'conflict',
        status: 'CONFLICT',
        errorCode: 'VERSION_CONFLICT',
      ),
      SyncPushResult(
        eventId: 'rejected',
        status: 'REJECTED',
        errorCode: 'INVALID_EVENT',
      ),
    ];

    await fixture.engine.syncNow();
    final rows = await fixture.db.query('sync_outbox', orderBy: 'event_id');
    expect(rows.map((row) => row['event_id']), ['conflict', 'rejected']);
    expect(rows.map((row) => row['status']), ['conflict', 'rejected']);
    expect(await fixture.db.query('sync_conflicts'), hasLength(1));
    expect(await fixture.db.query('sync_operations'), hasLength(4));
  });

  test('partial bootstrap replays history from zero and runs once', () async {
    final fixture = await _fixture();
    addTearDown(fixture.db.close);
    fixture.transport.bootstrapSequence = 37;
    fixture.transport.pullBatches.add(
      const SyncPullBatch(events: [], lastServerSequence: 37, hasMore: false),
    );

    await fixture.engine.syncNow();
    await fixture.engine.syncNow();

    expect(fixture.transport.bootstrapCalls, 1);
    expect(fixture.transport.pullAfter, [0, 37]);
  });

  test(
    'incomplete initial replay sends no ack and remains uninitialized',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.db.close);
      fixture.transport.bootstrapSequence = 37;

      await expectLater(
        fixture.engine.syncNow(),
        throwsA(isA<IncompleteInitialSyncException>()),
      );

      expect(fixture.transport.pullAfter, [0]);
      expect(fixture.transport.acks, isEmpty);
      final state = (await fixture.db.query('sync_entity_state')).single;
      expect(state['bootstrap_completed'], 0);
      expect(state['last_sync_at'], isNull);
    },
  );

  test(
    'new device restores complete history after cashbox-only bootstrap',
    () async {
      final server = _MemoryEventServer();
      final a = await _deviceFixture(server, 'device-a');
      final events = _secondDeviceEvents();
      const projector = SqliteDomainEventProjector();

      for (final event in events) {
        await a.db.transaction((txn) async {
          await projector.apply(txn, entityId: 'entity-test', event: event);
          await const OutboxService().enqueueEvent(
            txn,
            entityId: 'entity-test',
            aggregateType: event.aggregateType,
            aggregateId: event.aggregateId,
            eventType: event.eventType,
            aggregateVersion: event.aggregateVersion,
            occurredAt: DateTime.parse(event.occurredAt),
            payload: event.payload,
            eventId: event.eventId,
          );
        });
      }

      await a.engine.syncNow();
      final aInventory =
          (await a.db.query('inventory_items')).single['current_quantity'];
      final aCash =
          (await a.db.query(
            'cashboxes',
            where: 'id=?',
            whereArgs: ['cashbox-remote'],
          )).single['current_balance_minor'];
      final aParty =
          (await a.db.query('parties')).single['current_balance_minor'];
      await a.db.close();

      final b = await _deviceFixture(server, 'device-b');
      addTearDown(b.db.close);
      await b.engine.syncNow();

      expect(server.pullAfterByDevice['device-b']?.first, 0);
      expect(await b.db.query('products'), hasLength(1));
      expect(await b.db.query('parties'), hasLength(1));
      expect(await b.db.query('sales'), hasLength(1));
      expect(
        (await b.db.query('inventory_items')).single['current_quantity'],
        aInventory,
      );
      expect(
        (await b.db.query(
          'cashboxes',
          where: 'id=?',
          whereArgs: ['cashbox-remote'],
        )).single['current_balance_minor'],
        aCash,
      );
      expect(
        (await b.db.query('parties')).single['current_balance_minor'],
        aParty,
      );
      expect(
        (await b.db.query('sync_entity_state')).single['bootstrap_completed'],
        1,
      );
    },
  );

  test(
    'second device builds sale, payment and reversal ledgers once',
    () async {
      final fixture = await _fixture();
      addTearDown(fixture.db.close);
      final events = _secondDeviceEvents();
      fixture.transport.pullBatches.add(
        SyncPullBatch(events: events, lastServerSequence: 9, hasMore: false),
      );

      await fixture.engine.syncNow();

      var inventory =
          (await fixture.db.query(
            'inventory_items',
            where: 'id=?',
            whereArgs: ['inventory-1'],
          )).single;
      var cashbox =
          (await fixture.db.query(
            'cashboxes',
            where: 'id=?',
            whereArgs: ['cashbox-remote'],
          )).single;
      var party =
          (await fixture.db.query(
            'parties',
            where: 'id=?',
            whereArgs: ['party-remote'],
          )).single;
      expect(inventory['current_quantity'], 10.0);
      expect(inventory['inventory_value_minor'], 1000);
      expect(cashbox['current_balance_minor'], 200);
      expect(party['current_balance_minor'], -200);
      expect(
        await fixture.db.query('sales', where: 'id=?', whereArgs: ['sale-1']),
        hasLength(1),
      );
      expect(
        (await fixture.db.query(
          'sales',
          where: 'id=?',
          whereArgs: ['sale-1'],
        )).single['status'],
        'void',
      );
      expect(await fixture.db.query('inventory_movements'), hasLength(3));
      expect(await fixture.db.query('transactions'), hasLength(3));
      expect(await fixture.db.query('party_ledger_entries'), hasLength(5));

      fixture.transport.pullBatches.add(
        SyncPullBatch(
          events: [events[6]],
          lastServerSequence: 10,
          hasMore: false,
        ),
      );
      await fixture.engine.syncNow();

      inventory =
          (await fixture.db.query(
            'inventory_items',
            where: 'id=?',
            whereArgs: ['inventory-1'],
          )).single;
      cashbox =
          (await fixture.db.query(
            'cashboxes',
            where: 'id=?',
            whereArgs: ['cashbox-remote'],
          )).single;
      party =
          (await fixture.db.query(
            'parties',
            where: 'id=?',
            whereArgs: ['party-remote'],
          )).single;
      expect(inventory['current_quantity'], 10.0);
      expect(cashbox['current_balance_minor'], 200);
      expect(party['current_balance_minor'], -200);
      expect(await fixture.db.query('sync_changes'), hasLength(9));
      expect(fixture.transport.acks, [9, 10]);
    },
  );

  test('known event failure keeps cursor and ack unchanged', () async {
    final fixture = await _fixture();
    addTearDown(fixture.db.close);
    fixture.transport.pullBatches.add(
      SyncPullBatch(
        events: [
          DomainEvent(
            eventId: 'bad-payment',
            aggregateType: 'party_payment',
            aggregateId: 'payment-missing-party',
            eventType: 'PartyPaymentPosted',
            aggregateVersion: 1,
            occurredAt: '2026-09-24T10:30:00Z',
            serverSequence: 1,
            payload: const {
              'paymentId': 'payment-missing-party',
              'paymentNumber': 'PAY-BAD',
              'financialYearId': 'year-remote',
              'partyId': 'party-does-not-exist',
              'cashboxId': 'cashbox-does-not-exist',
              'direction': 'RECEIVE',
              'amountMinor': 100,
              'cashTransactionId': 'cash-bad',
              'partyLedgerEntryId': 'party-bad',
              'note': null,
              'postedAt': '2026-09-24T10:30:00Z',
            },
          ),
        ],
        lastServerSequence: 1,
        hasMore: false,
      ),
    );

    await expectLater(
      fixture.engine.syncNow(),
      throwsA(isA<DomainEventApplyException>()),
    );
    expect(
      (await fixture.db.query('sync_cursors')).single['server_sequence'],
      0,
    );
    expect(await fixture.db.query('sync_changes'), isEmpty);
    expect(fixture.transport.acks, isEmpty);
  });
}

List<DomainEvent> _secondDeviceEvents() {
  const at = '2026-09-24T10:30:00.000Z';
  DomainEvent event(
    int seq,
    String id,
    String aggregateType,
    String aggregateId,
    String eventType,
    Map<String, dynamic> payload, {
    int version = 1,
  }) => DomainEvent(
    eventId: id,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    eventType: eventType,
    aggregateVersion: version,
    occurredAt: at,
    payload: payload,
    serverSequence: seq,
  );
  return [
    event(1, 'ev-wh', 'warehouse', 'warehouse-remote', 'WarehouseCreated', {
      'id': 'warehouse-remote',
      'name': 'Remote Warehouse',
      'active': true,
      'updatedAt': at,
    }),
    event(2, 'ev-box', 'cashbox', 'cashbox-remote', 'CashboxCreated', {
      'id': 'cashbox-remote',
      'name': 'Remote Cashbox',
      'createdAt': at,
    }),
    event(3, 'ev-party', 'party', 'party-remote', 'PartyCreated', {
      ..._partyPayload('party-remote'),
      'updatedAt': at,
    }),
    event(4, 'ev-product', 'product', 'product-1', 'ProductCreated', {
      'id': 'product-1',
      'categoryId': null,
      'name': 'Product',
      'minQuantity': 0.0,
      'active': true,
      'updatedAt': at,
    }),
    event(5, 'ev-unit', 'product_unit', 'unit-1', 'ProductUnitCreated', {
      'id': 'unit-1',
      'productId': 'product-1',
      'name': 'Unit',
      'factor': 1.0,
      'primary': true,
      'updatedAt': at,
    }),
    event(
      6,
      'ev-opening',
      'inventory_opening',
      'opening-1',
      'InventoryOpeningPosted',
      {
        'openingId': 'opening-1',
        'financialYearId': 'year-remote',
        'warehouseId': 'warehouse-remote',
        'items': [
          {
            'movementId': 'movement-opening',
            'inventoryItemId': 'inventory-1',
            'productId': 'product-1',
            'productUnitId': 'unit-1',
            'quantity': 10.0,
            'unitFactor': 1.0,
            'baseQuantity': 10.0,
            'unitCostMinor': 100,
            'valueMinor': 1000,
          },
        ],
      },
    ),
    event(7, 'ev-sale', 'sale', 'sale-1', 'SalePosted', {
      'documentId': 'sale-1',
      'documentNumber': 'S-001',
      'financialYearId': 'year-remote',
      'partyId': 'party-remote',
      'warehouseId': 'warehouse-remote',
      'cashboxId': 'cashbox-remote',
      'subtotalMinor': 500,
      'discountMinor': 0,
      'finalMinor': 500,
      'paidMinor': 300,
      'note': null,
      'postedAt': at,
      'cashTransactionId': 'cash-sale',
      'partyLedgerEntryId': 'party-sale',
      'items': [
        {
          'itemId': 'sale-item-1',
          'inventoryItemId': 'inventory-1',
          'productId': 'product-1',
          'productUnitId': 'unit-1',
          'quantity': 2.0,
          'unitFactor': 1.0,
          'baseQuantity': 2.0,
          'unitAmountMinor': 250,
          'lineDiscountMinor': 0,
          'lineTotalMinor': 500,
          'costAmountMinor': 200,
          'inventoryMovementId': 'movement-sale',
        },
      ],
    }),
    event(8, 'ev-payment', 'party_payment', 'payment-1', 'PartyPaymentPosted', {
      'paymentId': 'payment-1',
      'paymentNumber': 'PAY-001',
      'financialYearId': 'year-remote',
      'partyId': 'party-remote',
      'cashboxId': 'cashbox-remote',
      'direction': 'RECEIVE',
      'amountMinor': 200,
      'cashTransactionId': 'cash-payment',
      'partyLedgerEntryId': 'party-payment',
      'note': null,
      'postedAt': at,
    }),
    event(9, 'ev-void', 'sale', 'sale-1', 'SaleVoided', {
      'documentId': 'sale-1',
      'reason': 'Test cancellation',
      'voidedAt': at,
      'reversals': [
        {
          'reversalId': 'rev-inventory',
          'reversalOfId': 'movement-sale',
          'ledgerType': 'INVENTORY',
        },
        {
          'reversalId': 'rev-cash',
          'reversalOfId': 'cash-sale',
          'ledgerType': 'CASH',
        },
        {
          'reversalId': 'rev-party-sale',
          'reversalOfId': 'party-sale',
          'ledgerType': 'PARTY',
        },
        {
          'reversalId': 'rev-party-paid',
          'reversalOfId': 'ev-sale:party:payment',
          'ledgerType': 'PARTY',
        },
      ],
    }, version: 2),
  ];
}

Future<_Fixture> _fixture({DomainEventProjector? projector}) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
  final contexts = LocalContextService(databaseProvider: () async => db);
  await contexts.activateAuthenticatedContext(
    entityId: 'entity-test',
    entityName: 'Test Entity',
    currencyCode: 'USD',
    timezone: 'UTC',
    membershipId: 'membership-test',
    role: 'owner',
    serverUserId: 'user-test',
    userName: 'Test User',
    userEmail: 'test@example.invalid',
    deviceId: 'device-test',
    deviceKey: 'device-key-test',
    deviceName: 'Test Device',
    platform: 'test',
    appVersion: '1.0.0',
    deviceRevoked: false,
  );
  final transport = _FakeTransport();
  final engine = SyncEngine(
    transport: transport,
    projector: projector,
    databaseProvider: () async => db,
    contextProvider: () => contexts.current,
  );
  return _Fixture(db, transport, engine);
}

Future<_DeviceFixture> _deviceFixture(
  _MemoryEventServer transport,
  String deviceId,
) async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
  final contexts = LocalContextService(databaseProvider: () async => db);
  await contexts.activateAuthenticatedContext(
    entityId: 'entity-test',
    entityName: 'Test Entity',
    currencyCode: 'USD',
    timezone: 'UTC',
    membershipId: 'membership-test',
    role: 'owner',
    serverUserId: 'user-test',
    userName: 'Test User',
    userEmail: 'test@example.invalid',
    deviceId: deviceId,
    deviceKey: 'key-$deviceId',
    deviceName: deviceId,
    platform: 'test',
    appVersion: '1.0.0',
    deviceRevoked: false,
  );
  return _DeviceFixture(
    db,
    SyncEngine(
      transport: transport,
      databaseProvider: () async => db,
      contextProvider: () => contexts.current,
    ),
  );
}

Future<void> _event(Database db, String id) =>
    const OutboxService().enqueueEvent(
      db,
      entityId: 'entity-test',
      aggregateType: 'party',
      aggregateId: 'party-$id',
      eventType: 'PartyCreated',
      aggregateVersion: 1,
      occurredAt: DateTime.utc(2026),
      payload: _partyPayload('party-$id'),
      eventId: id,
    );

DomainEvent _pulled(String id, int sequence) => DomainEvent(
  eventId: id,
  aggregateType: 'party',
  aggregateId: 'party-$id',
  eventType: 'PartyCreated',
  aggregateVersion: 1,
  occurredAt: '2026-01-01T00:00:00Z',
  payload: {'id': 'party-$id', 'name': 'Test'},
  serverSequence: sequence,
);

Map<String, Object?> _partyPayload(String id) => {
  'id': id,
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
};

class _Fixture {
  const _Fixture(this.db, this.transport, this.engine);
  final Database db;
  final _FakeTransport transport;
  final SyncEngine engine;
}

class _DeviceFixture {
  const _DeviceFixture(this.db, this.engine);
  final Database db;
  final SyncEngine engine;
}

class _MemoryEventServer implements SyncTransport {
  final List<DomainEvent> events = [];
  final Map<String, List<int>> pullAfterByDevice = {};

  @override
  Future<SyncBootstrap> bootstrap({
    required String entityId,
    required String deviceId,
  }) async => SyncBootstrap(
    serverSequence: events.length,
    snapshotVersion: 1,
    snapshot: const {
      'cashboxes': [
        {
          'id': 'cashbox-remote',
          'name': 'Remote Cashbox',
          'current_balance_minor': 0,
          'snapshot_version': 1,
        },
      ],
    },
  );

  @override
  Future<List<SyncPushResult>> push({
    required String entityId,
    required String deviceId,
    required List<DomainEvent> events,
  }) async {
    final results = <SyncPushResult>[];
    for (final event in events) {
      final existing = this.events.indexWhere(
        (e) => e.eventId == event.eventId,
      );
      if (existing >= 0) {
        results.add(
          SyncPushResult(
            eventId: event.eventId,
            status: 'ALREADY_ACCEPTED',
            serverSequence: existing + 1,
          ),
        );
        continue;
      }
      final sequence = this.events.length + 1;
      this.events.add(
        DomainEvent(
          eventId: event.eventId,
          aggregateType: event.aggregateType,
          aggregateId: event.aggregateId,
          eventType: event.eventType,
          aggregateVersion: event.aggregateVersion,
          occurredAt: event.occurredAt,
          payload: event.payload,
          serverSequence: sequence,
        ),
      );
      results.add(
        SyncPushResult(
          eventId: event.eventId,
          status: 'ACCEPTED',
          serverSequence: sequence,
        ),
      );
    }
    return results;
  }

  @override
  Future<SyncPullBatch> pull({
    required String entityId,
    required String deviceId,
    required int afterServerSequence,
    int limit = 500,
  }) async {
    pullAfterByDevice.putIfAbsent(deviceId, () => []).add(afterServerSequence);
    final page = events
        .where((event) => event.serverSequence! > afterServerSequence)
        .take(limit)
        .toList(growable: false);
    final last = page.isEmpty ? afterServerSequence : page.last.serverSequence!;
    return SyncPullBatch(
      events: page,
      lastServerSequence: last,
      hasMore: events.any((event) => event.serverSequence! > last),
    );
  }

  @override
  Future<void> ack({
    required String entityId,
    required String deviceId,
    required int serverSequence,
  }) async {}

  @override
  Future<RemoteSyncStatus> status({
    required String entityId,
    required String deviceId,
  }) async => RemoteSyncStatus(
    deviceRevoked: false,
    latestServerSequence: events.length,
    lastPulledSequence: 0,
  );
}

class _FakeTransport implements SyncTransport {
  bool failPushOnce = false;
  int bootstrapCalls = 0;
  int bootstrapSequence = 0;
  List<SyncPushResult>? pushResults;
  final List<String> pushedIds = [];
  final List<int> acks = [];
  final List<int> pullAfter = [];
  final List<SyncPullBatch> pullBatches = [];

  @override
  Future<SyncBootstrap> bootstrap({
    required String entityId,
    required String deviceId,
  }) async {
    bootstrapCalls++;
    return SyncBootstrap(
      serverSequence: bootstrapSequence,
      snapshotVersion: 1,
      snapshot: const {},
    );
  }

  @override
  Future<List<SyncPushResult>> push({
    required String entityId,
    required String deviceId,
    required List<DomainEvent> events,
  }) async {
    pushedIds.addAll(events.map((event) => event.eventId));
    if (failPushOnce) {
      failPushOnce = false;
      throw const NetworkException('offline after server receipt');
    }
    return pushResults ??
        events
            .map(
              (event) => SyncPushResult(
                eventId: event.eventId,
                status: 'ALREADY_ACCEPTED',
              ),
            )
            .toList();
  }

  @override
  Future<SyncPullBatch> pull({
    required String entityId,
    required String deviceId,
    required int afterServerSequence,
    int limit = 500,
  }) async {
    pullAfter.add(afterServerSequence);
    return pullBatches.isEmpty
        ? SyncPullBatch(
          events: const [],
          lastServerSequence: afterServerSequence,
          hasMore: false,
        )
        : pullBatches.removeAt(0);
  }

  @override
  Future<void> ack({
    required String entityId,
    required String deviceId,
    required int serverSequence,
  }) async => acks.add(serverSequence);

  @override
  Future<RemoteSyncStatus> status({
    required String entityId,
    required String deviceId,
  }) async => const RemoteSyncStatus(
    deviceRevoked: false,
    latestServerSequence: 0,
    lastPulledSequence: 0,
  );
}

class _CountingProjector implements DomainEventProjector {
  int calls = 0;
  @override
  Future<void> apply(
    Transaction transaction, {
    required String entityId,
    required DomainEvent event,
  }) async {
    calls++;
  }
}

class _FailingProjector implements DomainEventProjector {
  @override
  Future<void> apply(
    Transaction transaction, {
    required String entityId,
    required DomainEvent event,
  }) async {
    throw StateError('projection failed');
  }
}
