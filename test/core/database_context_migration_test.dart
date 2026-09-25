import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/services/outbox_service.dart';
import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/data/device_key_storage.dart';
import 'package:accounting_system/features/auth/data/organization_context_coordinator.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fallback dependency ids are stable across devices', () {
    expect(
      deterministicContextId('entity-a', 'default-warehouse'),
      deterministicContextId('entity-a', 'default-warehouse'),
    );
    expect(
      deterministicContextId('entity-a', 'default-warehouse'),
      isNot(deterministicContextId('entity-b', 'default-warehouse')),
    );
    expect(
      deterministicContextId('entity-a', 'default-cashbox'),
      isNot(deterministicContextId('entity-a', 'default-warehouse')),
    );
  });

  test('database deletion is blocked by outbox and drafts', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    await db.insert('sync_outbox', {
      'event_id': 'pending-event',
      'entity_id': 'entity-a',
      'aggregate_type': 'party',
      'aggregate_id': 'party-a',
      'event_type': 'PartyCreated',
      'aggregate_version': 1,
      'occurred_at': '2026-01-01T00:00:00Z',
      'payload_json': '{}',
      'created_at': '2026-01-01T00:00:00Z',
    });
    await db.insert('entities', {
      'id': 'entity-a',
      'name': 'Entity',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    await db.insert('sales', {
      'id': 'draft-a',
      'entity_id': 'entity-a',
      'financial_year_id': 'year-a',
      'invoice_number': 'D-1',
      'occurred_at': '2026-01-01T00:00:00Z',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    final blockers = await AppDatabase.instance.deletionBlockersFor(db);

    expect(blockers, hasLength(2));
    expect(blockers.join(' '), contains('مزامنة'));
    expect(blockers.join(' '), contains('مسودة'));
  });

  test('a new database has event sync and entity context schema', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);

    final outbox = await db.rawQuery('PRAGMA table_info(sync_outbox)');
    expect(
      outbox.map((column) => column['name']),
      containsAll([
        'event_id',
        'entity_id',
        'event_type',
        'aggregate_version',
        'occurred_at',
        'server_sequence',
      ]),
    );
    final changes = await db.rawQuery('PRAGMA table_info(sync_changes)');
    expect(
      changes.map((column) => column['name']),
      containsAll(['event_id', 'event_type', 'server_sequence', 'occurred_at']),
    );
    expect(await _tableExists(db, 'organization_contexts'), isTrue);
    expect(await _tableExists(db, 'sync_cursors'), isTrue);
    expect(await _tableExists(db, 'sync_entity_state'), isTrue);
  });

  test('switching organizations isolates data outbox and cursors', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
    final contexts = LocalContextService(databaseProvider: () async => db);

    await _activate(contexts, entity: 'entity-a', membership: 'membership-a');
    await _activate(contexts, entity: 'entity-b', membership: 'membership-b');
    await db.insert('parties', {
      'id': 'party-a',
      'entity_id': 'entity-a',
      'type': 'customer',
      'name': 'Party A',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    await db.insert('parties', {
      'id': 'party-b',
      'entity_id': 'entity-b',
      'type': 'customer',
      'name': 'Party B',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });
    const outbox = OutboxService();
    await outbox.enqueueEvent(
      db,
      entityId: 'entity-a',
      aggregateType: 'party',
      aggregateId: 'party-a',
      eventType: 'PartyCreated',
      aggregateVersion: 1,
      occurredAt: DateTime.utc(2026),
      payload: _catalogPartyPayload('party-a'),
    );
    await outbox.enqueueEvent(
      db,
      entityId: 'entity-b',
      aggregateType: 'party',
      aggregateId: 'party-b',
      eventType: 'PartyCreated',
      aggregateVersion: 1,
      occurredAt: DateTime.utc(2026),
      payload: _catalogPartyPayload('party-b'),
    );
    await db.update(
      'sync_cursors',
      {'server_sequence': 11},
      where: 'entity_id=?',
      whereArgs: ['entity-a'],
    );
    await db.update(
      'sync_cursors',
      {'server_sequence': 29},
      where: 'entity_id=?',
      whereArgs: ['entity-b'],
    );

    expect((await contexts.current).entityId, 'entity-b');
    final contextA = await contexts.switchTo('entity-a');
    expect(contextA.entityId, 'entity-a');
    expect(
      await db.query(
        'parties',
        where: 'entity_id=?',
        whereArgs: [contextA.entityId],
      ),
      hasLength(1),
    );
    expect(
      await db.query(
        'sync_outbox',
        where: 'entity_id=?',
        whereArgs: [contextA.entityId],
      ),
      hasLength(1),
    );
    expect(
      (await db.query(
        'sync_cursors',
        where: 'entity_id=?',
        whereArgs: [contextA.entityId],
      )).single['server_sequence'],
      11,
    );
    expect((await contexts.switchTo('entity-b')).entityId, 'entity-b');
    expect(
      (await db.query(
        'sync_cursors',
        where: 'entity_id=?',
        whereArgs: ['entity-b'],
      )).single['server_sequence'],
      29,
    );
  });

  test('device key is generated once even for concurrent reads', () async {
    final values = MemorySecureValueStore();
    final storage = SecureDeviceKeyStorage(store: values);
    final keys = await Future.wait([
      storage.getOrCreate(),
      storage.getOrCreate(),
      storage.getOrCreate(),
    ]);
    expect(keys.toSet(), hasLength(1));
    expect(values.writeCount, 1);
    expect(
      await SecureDeviceKeyStorage(store: values).getOrCreate(),
      keys.first,
    );
    expect(values.writeCount, 1);
  });

  test(
    'organization activation registers and stores the server device',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await AppDatabase.instance.createSchema(db, AppDatabase.dbVersion);
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/v1'));
      addTearDown(dio.close);
      var registerRequests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            registerRequests++;
            expect(options.path, '/entities/entity-a/devices/register');
            expect((options.data as Map)['deviceKey'], 'secure-device-key');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'deviceId': 'server-device-a', 'revoked': false},
              ),
            );
          },
        ),
      );
      final contexts = LocalContextService(databaseProvider: () async => db);
      final coordinator = OrganizationContextCoordinator(
        apiClient: ApiClient(dio: dio),
        deviceKeyStorage: FixedDeviceKeyStorage('secure-device-key'),
        localContextService: contexts,
        platform: 'windows',
        packageInfoLoader:
            () async => PackageInfo(
              appName: 'Accounting',
              packageName: 'accounting.test',
              version: '1.2.3',
              buildNumber: '4',
            ),
      );

      final result = await coordinator.activate(
        user: const AuthUser(
          id: 'server-user',
          name: 'User',
          email: 'user@example.com',
          memberships: [],
        ),
        membership: const Membership(
          membershipId: 'membership-a',
          entityId: 'entity-a',
          entityName: 'Entity A',
          currencyCode: 'USD',
          timezone: 'UTC',
          role: 'OWNER',
        ),
      );

      expect(registerRequests, 1);
      expect(result.deviceId, 'server-device-a');
      expect(result.revoked, isFalse);
      expect((await contexts.current).deviceId, 'server-device-a');
      final stored = await db.query(
        'devices',
        where: 'entity_id=?',
        whereArgs: ['entity-a'],
      );
      expect(stored.single['app_version'], '1.2.3');
    },
  );
}

Future<void> _activate(
  LocalContextService contexts, {
  required String entity,
  required String membership,
}) {
  return contexts.activateAuthenticatedContext(
    entityId: entity,
    entityName: entity,
    currencyCode: 'USD',
    timezone: 'UTC',
    membershipId: membership,
    role: 'OWNER',
    serverUserId: 'server-user',
    userName: 'User',
    userEmail: 'user@example.com',
    deviceId: 'device-$entity',
    deviceKey: 'stable-device-key',
    deviceName: 'Test Device',
    platform: 'test',
    appVersion: '1.0.0',
    deviceRevoked: false,
  );
}

Future<bool> _tableExists(Database db, String name) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: "type='table' AND name=?",
    whereArgs: [name],
  );
  return rows.isNotEmpty;
}

class MemorySecureValueStore implements SecureValueStore {
  final Map<String, String> values = {};
  int writeCount = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}

class FixedDeviceKeyStorage implements DeviceKeyStorage {
  FixedDeviceKeyStorage(this.value);
  final String value;

  @override
  Future<String> getOrCreate() async => value;
}

Map<String, Object?> _catalogPartyPayload(String id) => {
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
