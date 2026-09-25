import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:accounting_system/core/utils/app_logger.dart';
import 'schema/catalog_schema.dart';
import 'schema/cash_schema.dart';
import 'schema/core_schema.dart';
import 'schema/document_schema.dart';
import 'schema/inventory_schema.dart';
import 'schema/sync_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  static const dbName = 'accounting_system.db';
  static const legacyDbName = 'pharma_x.db';
  static const dbVersion = 10;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  void _configureFactoryForPlatform() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> _initDB() async {
    _configureFactoryForPlatform();
    final dbPath = await getPath;
    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: createSchema,
        onUpgrade: migrate,
      ),
    );
  }

  Future<void> createSchema(Database db, int version) async {
    // onCreate/onUpgrade are already executed inside sqflite's transaction.
    await createCoreSchema(db);
    await createCatalogSchema(db);
    await createInventorySchema(db);
    await createDocumentSchema(db);
    await createCashSchema(db);
    await createSyncSchema(db);
  }

  Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('db_migration', {'from': oldVersion, 'to': newVersion});
    // The supplied legacy snapshot had no business tables in _onCreate.
    // Re-running CREATE TABLE IF NOT EXISTS is therefore a safe, additive
    // migration for v1/v2 databases while preserving any tables/data that
    // may already exist on a real installation.
    if (oldVersion < 3) {
      await createSchema(db, newVersion);
    }
    if (oldVersion < 4) {
      await createSchema(db, newVersion);
      await _ensureColumn(
        db,
        'purchase_items',
        'cost_amount_minor',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await createSchema(db, newVersion);
      await _ensureColumn(
        db,
        'sale_items',
        'net_amount_minor',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) {
      await createSchema(db, newVersion);
      await _ensureColumn(
        db,
        'product_units',
        'sale_price_minor',
        'INTEGER NOT NULL DEFAULT 0 CHECK(sale_price_minor >= 0)',
      );
      await db.execute('''
UPDATE product_units
SET sale_price_minor = COALESCE((
  SELECT si.unit_price_minor
  FROM sale_items si
  JOIN sales s ON s.id = si.sale_id
  WHERE si.product_unit_id = product_units.id
    AND si.deleted_at IS NULL
    AND s.deleted_at IS NULL
    AND s.status = 'posted'
  ORDER BY s.occurred_at DESC, si.created_at DESC
  LIMIT 1
), sale_price_minor)
WHERE sale_price_minor = 0
''');
    }
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }
    if (oldVersion < 8) {
      await createSyncSchema(db);
      await _ensureColumn(
        db,
        'sync_entity_state',
        'bootstrap_completed',
        'INTEGER NOT NULL DEFAULT 0 CHECK(bootstrap_completed IN (0,1))',
      );
      await _ensureColumn(
        db,
        'sync_entity_state',
        'bootstrap_server_sequence',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 9) {
      await createSyncSchema(db);
    }
    if (oldVersion < 10 && newVersion >= 10) {
      await createSyncSchema(db);
      await _ensureColumn(
        db,
        'legacy_sync_quarantine',
        'review_status',
        "TEXT NOT NULL DEFAULT 'pending_review'",
      );
      await _ensureColumn(db, 'legacy_sync_quarantine', 'reviewed_at', 'TEXT');
      await _ensureColumn(
        db,
        'legacy_sync_quarantine',
        'resolution_note',
        'TEXT',
      );
      final now = DateTime.now().toUtc().toIso8601String();
      // v8/v9 treated the cashbox-only bootstrap snapshot as complete and
      // skipped older events. Replaying from zero is safe because sync_changes
      // deduplicates already applied eventIds.
      await db.update('sync_entity_state', {
        'bootstrap_completed': 0,
        'updated_at': now,
      });
      await db.update('sync_cursors', {
        'server_sequence': 0,
        'last_acknowledged_sequence': 0,
        'updated_at': now,
      });
      await db.insert('migration_reports', {
        'migration_key': 'v10_replay_partial_bootstrap_history',
        'affected_rows':
            Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sync_entity_state'),
            ) ??
            0,
        'details': jsonEncode({
          'reason': 'Bootstrap v1 contains cashboxes only',
          'action':
              'Reset cursor to zero; preserve projections and deduplicate by eventId',
        }),
        'created_at': now,
      });
    }
  }

  Future<void> _migrateToV7(Database db) async {
    await createCoreSchema(db);
    await _ensureColumn(db, 'devices', 'platform', 'TEXT');
    await _ensureColumn(db, 'devices', 'app_version', 'TEXT');
    await _ensureColumn(
      db,
      'devices',
      'registration_revoked',
      'INTEGER NOT NULL DEFAULT 0 CHECK(registration_revoked IN (0,1))',
    );

    final outboxColumns = await db.rawQuery('PRAGMA table_info(sync_outbox)');
    final hasLegacyOutbox = outboxColumns.any((row) => row['name'] == 'action');
    if (hasLegacyOutbox) {
      await db.execute(
        'ALTER TABLE sync_outbox RENAME TO sync_outbox_v6_archive',
      );
      await db.execute('DROP INDEX IF EXISTS idx_sync_outbox_status');
      await db.execute('DROP INDEX IF EXISTS idx_sync_outbox_aggregate');
    }

    final changesColumns = await db.rawQuery('PRAGMA table_info(sync_changes)');
    final hasLegacyChanges = changesColumns.any(
      (row) => row['name'] == 'table_name',
    );
    if (hasLegacyChanges) {
      await db.execute(
        'ALTER TABLE sync_changes RENAME TO sync_changes_v6_archive',
      );
      await db.execute('DROP INDEX IF EXISTS idx_sync_changes_seq');
    }

    await createSyncSchema(db);
    await _ensureColumn(db, 'sync_operations', 'event_id', 'TEXT');
    await _ensureColumn(db, 'sync_operations', 'server_sequence', 'INTEGER');

    final now = DateTime.now().toUtc().toIso8601String();
    if (hasLegacyOutbox) {
      await db.rawInsert(
        '''
INSERT OR IGNORE INTO legacy_sync_quarantine (
  operation_id, entity_id, aggregate_type, aggregate_id, legacy_action,
  payload_json, legacy_status, legacy_created_at, quarantine_reason,
  quarantined_at
)
SELECT operation_id, entity_id, aggregate_type, aggregate_id, action,
       payload_json, status, created_at,
       'LEGACY_ACTION_HAS_NO_VERIFIED_EVENT_MAPPING', ?
FROM sync_outbox_v6_archive
''',
        [now],
      );
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM legacy_sync_quarantine'),
          ) ??
          0;
      await db.insert('migration_reports', {
        'migration_key': 'v7_legacy_outbox_quarantine',
        'affected_rows': count,
        'details': jsonEncode({
          'reason': 'Legacy action payloads were preserved without conversion',
          'archiveTable': 'sync_outbox_v6_archive',
        }),
        'created_at': now,
      });
    }
    if (hasLegacyChanges) {
      final count =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sync_changes_v6_archive'),
          ) ??
          0;
      await db.insert('migration_reports', {
        'migration_key': 'v7_legacy_row_changes_archive',
        'affected_rows': count,
        'details': jsonEncode({
          'reason': 'Row changes have no trustworthy domain event identity',
          'archiveTable': 'sync_changes_v6_archive',
        }),
        'created_at': now,
      });
    }

    final legacyContextCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM app_context'),
        ) ??
        0;
    if (legacyContextCount > 0) {
      await db.insert('migration_reports', {
        'migration_key': 'v7_legacy_local_context_ignored',
        'affected_rows': legacyContextCount,
        'details': jsonEncode({
          'reason': 'Locally generated identity cannot replace /me membership',
          'action': 'Preserved but not activated',
        }),
        'created_at': now,
      });
    }
  }

  Future<void> _ensureColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists)
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<List<String>> deletionBlockers() async {
    final db = await database;
    return deletionBlockersFor(db);
  }

  Future<List<String>> deletionBlockersFor(Database db) async {
    final blockers = <String>[];
    final outbox =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sync_outbox'),
        ) ??
        0;
    if (outbox > 0) blockers.add('$outbox حدث مزامنة غير محسوم');
    final legacy =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM legacy_sync_quarantine WHERE review_status='pending_review'",
          ),
        ) ??
        0;
    if (legacy > 0) blockers.add('$legacy عملية قديمة معزولة بانتظار المراجعة');
    var drafts = 0;
    for (final table in const [
      'sales',
      'purchase_invoices',
      'sale_return_invoices',
      'purchase_return_invoices',
      'waste_invoices',
      'inventory_adjustments',
      'inventory_transfers',
      'expenses',
      'cash_transfers',
    ]) {
      final exists =
          Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?",
              [table],
            ),
          ) ??
          0;
      if (exists == 0) continue;
      drafts +=
          Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM $table WHERE status='draft'",
            ),
          ) ??
          0;
    }
    if (drafts > 0) blockers.add('$drafts مسودة محلية غير مرحّلة');
    return blockers;
  }

  Future<void> deleteDB() async {
    final blockers = await deletionBlockers();
    if (blockers.isNotEmpty) {
      throw DatabaseDeletionBlockedException(blockers);
    }
    _configureFactoryForPlatform();
    final dbPath = await getPath;
    await close();
    await databaseFactory.deleteDatabase(dbPath);
    // The next authenticated organization selection recreates its local
    // projections. No local user or organization identity is bootstrapped.
  }

  Future<String> get getPath async {
    if (Platform.isWindows) {
      final root = Platform.environment['APPDATA'];
      final appDir = Directory(join(root ?? '.', 'accounting_system'));
      if (!await appDir.exists()) await appDir.create(recursive: true);
      final target = join(appDir.path, dbName);
      final legacy = join(root ?? '.', 'pharma_x', legacyDbName);
      await _migrateLegacyFileIfNeeded(legacy, target);
      return target;
    }

    final dir = await getApplicationDocumentsDirectory();
    final target = join(dir.path, dbName);
    final legacy = join(dir.path, legacyDbName);
    await _migrateLegacyFileIfNeeded(legacy, target);
    return target;
  }

  Future<void> _migrateLegacyFileIfNeeded(String legacy, String target) async {
    final targetFile = File(target);
    if (await targetFile.exists()) return;
    final legacyFile = File(legacy);
    if (!await legacyFile.exists()) return;
    await targetFile.parent.create(recursive: true);
    await legacyFile.copy(target);
  }
}

class DatabaseDeletionBlockedException implements Exception {
  const DatabaseDeletionBlockedException(this.reasons);

  final List<String> reasons;

  @override
  String toString() =>
      'تعذر حذف البيانات المحلية حتى لا تفقد بيانات غير مستعادة:\n'
      '${reasons.map((reason) => '• $reason').join('\n')}';
}
