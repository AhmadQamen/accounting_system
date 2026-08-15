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
  static const dbVersion = 5;

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
      await _ensureColumn(db, 'purchase_items', 'cost_amount_minor', 'INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await createSchema(db, newVersion);
      await _ensureColumn(db, 'sale_items', 'net_amount_minor', 'INTEGER NOT NULL DEFAULT 0');
    }
  }


  Future<void> _ensureColumn(DatabaseExecutor db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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

  Future<void> deleteDB() async {
    _configureFactoryForPlatform();
    final dbPath = await getPath;
    await close();
    await databaseFactory.deleteDatabase(dbPath);
    // Reset the in-memory workspace identifiers as well; the next open will
    // bootstrap a fresh local entity/year/warehouse/cashbox.
    // Import is intentionally avoided here to keep the database layer low-level.
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
