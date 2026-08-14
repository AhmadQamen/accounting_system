import 'package:accounting_system/core/db/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'shortcut_model.dart';

class KeyboardShortcutService {
  KeyboardShortcutService._();
  static final instance = KeyboardShortcutService._();

  static const table = 'keyboard_shortcuts';

  static const createTable =
      '''
CREATE TABLE IF NOT EXISTS $table (
  action TEXT PRIMARY KEY,

  key_label TEXT NOT NULL,

  ctrl INTEGER NOT NULL DEFAULT 0,
  shift INTEGER NOT NULL DEFAULT 0,
  alt INTEGER NOT NULL DEFAULT 0
)
''';

  Future<Database> get db => AppDatabase.instance.database;

  Future<void> insertDefaults() async {
    final db = await this.db;

    for (final shortcut in defaultShortcuts) {
      await db.insert(
        table,
        shortcut.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<List<ShortcutModel>> getAll() async {
    final db = await this.db;

    final rows = await db.query(table);

    if (rows.isEmpty) {
      await insertDefaults();
      return List.from(defaultShortcuts);
    }

    return rows.map(ShortcutModel.fromJson).toList();
  }

  Future<void> update(ShortcutModel shortcut) async {
    final db = await this.db;

    await db.update(
      table,
      shortcut.toJson(),
      where: 'action = ?',
      whereArgs: [shortcut.action],
    );
  }

  Future<ShortcutModel?> getByAction(String action) async {
    final db = await this.db;

    final rows = await db.query(
      table,
      where: 'action = ?',
      whereArgs: [action],
    );

    if (rows.isEmpty) return null;

    return ShortcutModel.fromJson(rows.first);
  }
}
