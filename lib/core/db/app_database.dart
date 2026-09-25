import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
  static const dbVersion = 1;

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
      options: OpenDatabaseOptions(version: dbVersion, onCreate: createSchema),
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
      return join(appDir.path, dbName);
    }

    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, dbName);
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
