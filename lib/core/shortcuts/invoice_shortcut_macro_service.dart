import 'package:accounting_system/core/db/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'invoice_shortcut_macro.dart';

class InvoiceShortcutMacroService {
  Future<List<InvoiceShortcutMacro>> all() async {
    final db = await AppDatabase.instance.database;
    return (await db.query('invoice_shortcut_macros', orderBy: 'name')).map(InvoiceShortcutMacro.fromSql).toList();
  }
  Future<void> save(InvoiceShortcutMacro macro) async {
    final db = await AppDatabase.instance.database;
    await db.insert('invoice_shortcut_macros', macro.toSql(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> delete(String id) async => (await AppDatabase.instance.database).delete('invoice_shortcut_macros', where: 'id=?', whereArgs: [id]);
}
