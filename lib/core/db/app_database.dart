import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'schema/catalog_schema.dart';
import 'schema/cash_schema.dart';
import 'schema/capital_schema.dart';
import 'schema/core_schema.dart';
import 'schema/currency_schema.dart';
import 'schema/document_schema.dart';
import 'schema/inventory_schema.dart';
import 'schema/general_ledger_schema.dart';
import 'schema/sync_schema.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  static const dbName = 'accounting_system.db';
  // Never decrease this value. Earlier builds used a higher schema version;
  // 11 restores a monotonic upgrade path and preserves existing databases.
  static const dbVersion = 17;

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
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> createSchema(Database db, int version) async {
    // onCreate/onUpgrade are already executed inside sqflite's transaction.
    await createCoreSchema(db);
    await createCurrencySchema(db);
    await createCatalogSchema(db);
    await createInventorySchema(db);
    await createDocumentSchema(db);
    await createCashSchema(db);
    await createSyncSchema(db);
    await createGeneralLedgerSchema(db);
    await createCapitalSchema(db);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    // All schema declarations use IF NOT EXISTS. Re-running them is an
    // additive migration; no user row is deleted or recreated.
    await createSchema(db, newVersion);
    if (oldVersion < 12) {
      await _addProductMetadataColumns(db);
    }
    if (oldVersion < 13) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(keyboard_shortcuts)',
      );
      final names = columns.map((row) => row['name']).toSet();
      if (!names.contains('key_id')) {
        await db.execute(
          'ALTER TABLE keyboard_shortcuts ADD COLUMN key_id INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 15) {
      await _addCurrencyColumns(db);
    }
    if (oldVersion < 17) {
      await _separateCapitalFromCashboxes(db);
    }
  }

  /// v17: capital is recorded independently. Existing deposits were already
  /// received in a cashbox, so migrate them as fully allocated capital.
  Future<void> _separateCapitalFromCashboxes(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(capital_contributions)');
    final matches = columns.where((row) => row['name'] == 'cashbox_id');
    if (matches.isEmpty || matches.first['notnull'] == 0) return;
    await db.execute('ALTER TABLE capital_contributions RENAME TO capital_contributions_v16');
    await db.execute('''CREATE TABLE capital_contributions (
      id TEXT PRIMARY KEY,
      entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
      financial_year_id TEXT NOT NULL REFERENCES financial_years(id) ON DELETE RESTRICT,
      partner_id TEXT REFERENCES capital_partners(id) ON DELETE RESTRICT,
      cashbox_id TEXT REFERENCES cashboxes(id) ON DELETE RESTRICT,
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      note TEXT,
      occurred_at TEXT NOT NULL,
      created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
      origin_device_id TEXT REFERENCES devices(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      UNIQUE(entity_id, financial_year_id, id)
    )''');
    await db.execute('''INSERT INTO capital_contributions
      SELECT id, entity_id, financial_year_id, partner_id, cashbox_id, amount_minor,
             note, occurred_at, created_by, origin_device_id, created_at
      FROM capital_contributions_v16''');
    await db.execute('''INSERT OR IGNORE INTO capital_cash_allocations
      (id, entity_id, financial_year_id, cashbox_id, amount_minor, note,
       occurred_at, created_by, origin_device_id, created_at)
      SELECT 'legacy-' || id, entity_id, financial_year_id, cashbox_id,
             amount_minor, 'ترحيل إيداع رأس مال سابق', occurred_at, created_by,
             origin_device_id, created_at
      FROM capital_contributions_v16 WHERE cashbox_id IS NOT NULL''');
    await db.execute('DROP TABLE capital_contributions_v16');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_capital_contributions_entity_year ON capital_contributions(entity_id, financial_year_id, occurred_at DESC)',
    );
  }

  Future<void> _addCurrencyColumns(Database db) async {
    Future<void> add(String table, String name, String declaration) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      if (columns.any((row) => row['name'] == name)) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $name $declaration');
    }

    for (final table in const ['sales', 'purchase_invoices']) {
      await add(table, 'currency_code', 'TEXT');
      await add(
        table,
        'exchange_rate_micros',
        'INTEGER NOT NULL DEFAULT 1000000 CHECK(exchange_rate_micros > 0)',
      );
      await add(table, 'foreign_subtotal_minor', 'INTEGER');
      await add(table, 'foreign_discount_minor', 'INTEGER');
      await add(table, 'foreign_final_minor', 'INTEGER');
      await add(table, 'foreign_paid_minor', 'INTEGER');
    }
    await add('transactions', 'currency_code', 'TEXT');
    await add(
      'transactions',
      'exchange_rate_micros',
      'INTEGER NOT NULL DEFAULT 1000000 CHECK(exchange_rate_micros > 0)',
    );
    await add('transactions', 'foreign_amount_minor', 'INTEGER');
  }

  Future<void> _addProductMetadataColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(products)');
    final names = columns.map((row) => row['name']).toSet();
    if (!names.contains('item_type')) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN item_type TEXT NOT NULL DEFAULT 'stocked' CHECK(item_type IN ('stocked','non_stocked'))",
      );
    }
    if (!names.contains('location')) {
      await db.execute('ALTER TABLE products ADD COLUMN location TEXT');
    }
    if (!names.contains('cost_price_minor')) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN cost_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(cost_price_minor >= 0)',
      );
    }
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
