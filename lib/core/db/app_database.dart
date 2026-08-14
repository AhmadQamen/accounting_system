import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static const _dbName = 'pharma_x.db';
  static const _dbVersion = 2;

  Future<Database> _initDB() async {
    final dbPath = await getPath;
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {}

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {}
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// delete database (useful for testing)
  Future<void> deleteDB() async {
    final dbPath = await getPath;

    await deleteDatabase(dbPath);
    _database = null;
  }

  Future<String> get getPath async {
    if (Platform.isWindows) {
      final appDir = Directory('${Platform.environment['APPDATA']}\\pharma_x');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return join(appDir.path, _dbName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return join(dir.path, _dbName);
    }
  }
}
