import 'dart:io';
import 'package:accounting_system/features/notifications/db/notification_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _database = await _initDB();

    return _database!;
  }

  /// database name
  static const _dbName = "accounting.db";

  /// database version
  static const _dbVersion = 1;

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    // await deleteDB(); // Remove this line in production, it's just for testing to ensure a clean slate
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return db;
  }

  /// enable foreign keys
  Future<void> _onConfigure(Database db) async {
    await db.execute("PRAGMA foreign_keys = ON");
  }

  /// create tables
  Future<void> _onCreate(Database db, int version) async {
    /// inventory table
    await db.execute(NotificationService.createTable);
  }

  /// migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      /// example migration
      // await db.execute("ALTER TABLE customers ADD COLUMN email TEXT");
    }
  }

  /// close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// delete database (useful for testing)
  Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    await deleteDatabase(path);
    _database = null;
  }

  bool get _isDesktop => Platform.isWindows;
}
