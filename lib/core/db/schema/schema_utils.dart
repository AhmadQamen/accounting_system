import 'package:sqflite/sqflite.dart';

Future<void> executeStatements(DatabaseExecutor db, List<String> statements) async {
  for (final statement in statements) {
    await db.execute(statement);
  }
}
