import 'package:flutter/foundation.dart';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class LocalContext {
  const LocalContext({
    required this.entityId,
    required this.userId,
    required this.deviceId,
    required this.financialYearId,
    required this.defaultWarehouseId,
    required this.defaultCashboxId,
    required this.currencyCode,
  });

  final String entityId;
  final String userId;
  final String deviceId;
  final String financialYearId;
  final String defaultWarehouseId;
  final String defaultCashboxId;
  final String currencyCode;
}

class LocalContextService {
  LocalContextService._();
  static final instance = LocalContextService._();
  LocalContext? _cached;

  Future<LocalContext> get current async => _cached ??= await _loadOrBootstrap();

  Future<LocalContext> _loadOrBootstrap() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('app_context', where: 'singleton = 1', limit: 1);
    if (rows.isNotEmpty) {
      final row = rows.first;
      final entityRows = await db.query('entities', columns: ['currency_code'], where: 'id=?', whereArgs: [row['entity_id']], limit: 1);
      return _fromRow(row, currencyCode: entityRows.isEmpty ? 'USD' : entityRows.first['currency_code'] as String);
    }

    final now = DateTime.now().toUtc();
    final nowText = now.toIso8601String();
    final entityId = uuid.v4();
    final userId = uuid.v4();
    final deviceId = uuid.v4();
    final financialYearId = uuid.v4();
    final warehouseId = uuid.v4();
    final cashboxId = uuid.v4();
    final start = DateTime.utc(now.year, 1, 1).toIso8601String();
    final end = DateTime.utc(now.year, 12, 31, 23, 59, 59).toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('entities', {
        'id': entityId,
        'name': 'My Business',
        'currency_code': 'USD',
        'timezone': 'UTC',
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('users', {
        'id': userId,
        'entity_id': entityId,
        'name': 'Local Admin',
        'email': 'local@accounting.invalid',
        'is_admin': 1,
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('devices', {
        'id': deviceId,
        'entity_id': entityId,
        'user_id': userId,
        'device_key': '${defaultTargetPlatform.name}-${uuid.v4()}',
        'name': '${defaultTargetPlatform.name} device',
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('financial_years', {
        'id': financialYearId,
        'entity_id': entityId,
        'name': '${now.year}',
        'starts_on': start,
        'ends_on': end,
        'is_open': 1,
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('warehouses', {
        'id': warehouseId,
        'entity_id': entityId,
        'name': 'Main Warehouse',
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('cashboxes', {
        'id': cashboxId,
        'entity_id': entityId,
        'name': 'Main Cashbox',
        'created_at': nowText,
        'updated_at': nowText,
      });
      await txn.insert('app_context', {
        'singleton': 1,
        'entity_id': entityId,
        'user_id': userId,
        'device_id': deviceId,
        'financial_year_id': financialYearId,
        'default_warehouse_id': warehouseId,
        'default_cashbox_id': cashboxId,
        'updated_at': nowText,
      });
    });

    return LocalContext(
      entityId: entityId,
      userId: userId,
      deviceId: deviceId,
      financialYearId: financialYearId,
      defaultWarehouseId: warehouseId,
      defaultCashboxId: cashboxId,
      currencyCode: 'USD',
    );
  }

  LocalContext _fromRow(Map<String, Object?> row, {required String currencyCode}) => LocalContext(
        entityId: row['entity_id'] as String,
        userId: row['user_id'] as String,
        deviceId: row['device_id'] as String,
        financialYearId: row['financial_year_id'] as String,
        defaultWarehouseId: row['default_warehouse_id'] as String,
        defaultCashboxId: row['default_cashbox_id'] as String,
        currencyCode: currencyCode,
      );

  void clearCache() => _cached = null;
}
