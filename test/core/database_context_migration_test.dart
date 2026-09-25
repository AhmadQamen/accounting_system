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
    expect(await _tableExists(db, 'legacy_sync_quarantine'), isTrue);
  });

  test(
    'v6 migration preserves data and quarantines legacy sync rows',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await _createLegacyV6(db);
      await db.insert('entities', {
        'id': 'legacy-entity',
        'name': 'Legacy',
        'currency_code': 'USD',
        'timezone': 'UTC',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      await db.insert('parties', {
        'id': 'party-1',
        'entity_id': 'legacy-entity',
        'name': 'Preserved Party',
      });
      await db.insert('sync_outbox', {
        'operation_id': 'legacy-operation',
        'entity_id': 'legacy-entity',
        'aggregate_type': 'sale',
        'aggregate_id': 'sale-1',
        'action': 'post',
        'payload_json': '{"id":"sale-1"}',
        'created_at': '2026-01-01T00:00:00Z',
        'status': 'pending',
      });
      await db.insert('sync_changes', {
        'id': 'legacy-change',
        'entity_id': 'legacy-entity',
        'server_seq': 7,
        'table_name': 'parties',
        'record_id': 'party-1',
        'change_type': 'insert',
        'record_version': 1,
        'changed_at': '2026-01-01T00:00:00Z',
      });

      await AppDatabase.instance.migrate(db, 6, 9);

      expect(
        await db.query('parties', where: 'id=?', whereArgs: ['party-1']),
        hasLength(1),
      );
      expect(await db.query('sync_outbox'), isEmpty);
      final quarantined = await db.query('legacy_sync_quarantine');
      expect(quarantined, hasLength(1));
      expect(quarantined.single['operation_id'], 'legacy-operation');
      expect(
        quarantined.single['quarantine_reason'],
        'LEGACY_ACTION_HAS_NO_VERIFIED_EVENT_MAPPING',
      );
      expect(await _tableExists(db, 'sync_outbox_v6_archive'), isTrue);
      expect(await _tableExists(db, 'sync_changes_v6_archive'), isTrue);
      final reports = await db.query('migration_reports');
      expect(reports, hasLength(2));
    },
  );

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

Future<void> _createLegacyV6(Database db) async {
  await db.execute('''
CREATE TABLE entities (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, currency_code TEXT NOT NULL,
  timezone TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT, version INTEGER NOT NULL DEFAULT 1
)
''');
  await db.execute('''
CREATE TABLE users (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, name TEXT NOT NULL, email TEXT,
  phone TEXT, is_admin INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL, deleted_at TEXT, version INTEGER NOT NULL DEFAULT 1
)
''');
  await db.execute('''
CREATE TABLE devices (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, user_id TEXT, device_key TEXT NOT NULL,
  name TEXT NOT NULL, last_sync_at TEXT, last_pulled_server_seq INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, revoked_at TEXT,
  version INTEGER NOT NULL DEFAULT 1, UNIQUE(entity_id, device_key)
)
''');
  await db.execute('''
CREATE TABLE financial_years (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, name TEXT NOT NULL,
  starts_on TEXT NOT NULL, ends_on TEXT NOT NULL, is_open INTEGER NOT NULL DEFAULT 1,
  closed_at TEXT, closed_by TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1
)
''');
  await db.execute('''
CREATE TABLE app_context (
  singleton INTEGER PRIMARY KEY, entity_id TEXT, user_id TEXT, device_id TEXT,
  financial_year_id TEXT, default_warehouse_id TEXT, default_cashbox_id TEXT,
  updated_at TEXT NOT NULL
)
''');
  await db.execute('''
CREATE TABLE keyboard_shortcuts (
  action TEXT PRIMARY KEY, key_label TEXT NOT NULL, ctrl INTEGER NOT NULL DEFAULT 0,
  shift INTEGER NOT NULL DEFAULT 0, alt INTEGER NOT NULL DEFAULT 0
)
''');
  await db.execute('''
CREATE TABLE parties (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'customer', created_at TEXT, updated_at TEXT
)
''');
  await db.execute('''
CREATE TABLE sync_operations (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, operation_type TEXT NOT NULL,
  client_created_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending'
)
''');
  await db.execute('''
CREATE TABLE sync_outbox (
  operation_id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL, action TEXT NOT NULL, payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT, next_retry_at TEXT, status TEXT NOT NULL DEFAULT 'pending'
)
''');
  await db.execute('''
CREATE TABLE sync_changes (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, server_seq INTEGER NOT NULL,
  table_name TEXT NOT NULL, record_id TEXT NOT NULL, change_type TEXT NOT NULL,
  record_version INTEGER NOT NULL, payload_json TEXT, changed_at TEXT NOT NULL,
  applied_at TEXT
)
''');
  await db.execute('''
CREATE TABLE sync_conflicts (
  id TEXT PRIMARY KEY, entity_id TEXT NOT NULL, aggregate_type TEXT NOT NULL,
  aggregate_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at TEXT NOT NULL
)
''');
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
