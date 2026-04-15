import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_data.dart' show AppDatabase;
import '../domain/models/notification_model.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const table = 'notifications';

  static const createTable =
      '''
CREATE TABLE IF NOT EXISTS $table (
  id TEXT PRIMARY KEY,
  title TEXT,
  body TEXT,
  date TEXT,
  userId TEXT,
  isRead INTEGER DEFAULT 0
)
''';

  /// Add or update notification
  Future<void> addOrUpdate(NotificationModel notification) async {
    final db = await AppDatabase.instance.database;

    await db.insert(
      table,
      notification.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bulk insert (normal)
  Future<void> insertNotifications(
    List<NotificationModel> notifications,
  ) async {
    final db = await AppDatabase.instance.database;

    final batch = db.batch();

    for (final n in notifications) {
      batch.insert(
        table,
        n.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Bulk insert (fast)
  Future<void> insertNotificationsFast(
    List<NotificationModel> notifications,
  ) async {
    final db = await AppDatabase.instance.database;

    if (notifications.isEmpty) return;

    final columns = notifications.first.toJson().keys.toList();

    final placeholders = '(${List.filled(columns.length, '?').join(',')})';
    final valuesBlock = List.filled(
      notifications.length,
      placeholders,
    ).join(',');

    final sql =
        '''
INSERT OR REPLACE INTO $table (${columns.join(',')})
VALUES $valuesBlock
''';

    final args = <dynamic>[];

    for (final n in notifications) {
      final map = n.toJson();
      for (final col in columns) {
        args.add(map[col]);
      }
    }

    await db.rawInsert(sql, args);
  }

  /// ✅ Mark single notification as read
  Future<void> markAsRead(String id) async {
    final db = await AppDatabase.instance.database;

    await db.update(table, {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// ✅ Mark all notifications as read
  Future<void> markAllAsRead() async {
    final db = await AppDatabase.instance.database;

    await db.update(table, {'is_read': 1});
  }

  /// ✅ Get unread notifications only
  Future<List<NotificationModel>> getUnread() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      table,
      where: 'is_read = 0',
      orderBy: 'date DESC',
    );

    return result.map(NotificationModel.fromJson).toList();
  }

  /// Delete notification
  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;

    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Get notification by id
  Future<NotificationModel?> get(String id) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return NotificationModel.fromJson(result.first);
  }

  /// Get all notifications
  Future<List<NotificationModel>> getAll() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(table, orderBy: 'date DESC');

    return result.map(NotificationModel.fromJson).toList();
  }

  /// Clear all notifications
  Future<void> clear() async {
    final db = await AppDatabase.instance.database;
    await db.delete(table);
  }
}
