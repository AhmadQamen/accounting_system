import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

class LocalContext {
  const LocalContext({
    required this.entityId,
    this.membershipId = '',
    this.serverUserId = '',
    required this.userId,
    required this.deviceId,
    required this.financialYearId,
    required this.defaultWarehouseId,
    required this.defaultCashboxId,
    this.entityName = '',
    required this.currencyCode,
    this.timezone = 'UTC',
    this.role = '',
    this.deviceRevoked = false,
  });

  final String entityId;
  final String membershipId;
  final String serverUserId;

  /// Entity-scoped local user key. The server user id remains [serverUserId].
  final String userId;
  final String deviceId;
  final String financialYearId;
  final String defaultWarehouseId;
  final String defaultCashboxId;
  final String entityName;
  final String currencyCode;
  final String timezone;
  final String role;
  final bool deviceRevoked;
}

class LocalContextUnavailableException implements Exception {
  const LocalContextUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalContextService {
  LocalContextService({Future<Database> Function()? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => AppDatabase.instance.database);

  static final instance = LocalContextService();

  final Future<Database> Function() _databaseProvider;
  LocalContext? _cached;

  Future<LocalContext> get current async => _cached ??= await _loadActive();

  Future<LocalContext> activateAuthenticatedContext({
    required String entityId,
    required String entityName,
    required String currencyCode,
    required String timezone,
    required String membershipId,
    required String role,
    required String serverUserId,
    required String userName,
    required String userEmail,
    required String deviceId,
    required String deviceKey,
    required String deviceName,
    required String platform,
    required String appVersion,
    required bool deviceRevoked,
  }) async {
    final db = await _databaseProvider();
    final now = DateTime.now().toUtc();
    final nowText = now.toIso8601String();
    final localUserId = membershipId;

    await db.transaction((txn) async {
      await txn.insert('entities', {
        'id': entityId,
        'name': entityName,
        'currency_code': currencyCode,
        'timezone': timezone,
        'created_at': nowText,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'entities',
        {
          'name': entityName,
          'currency_code': currencyCode,
          'timezone': timezone,
          'updated_at': nowText,
        },
        where: 'id=?',
        whereArgs: [entityId],
      );
      await txn.insert('users', {
        'id': localUserId,
        'entity_id': entityId,
        'name': userName,
        'email': userEmail,
        'created_at': nowText,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'users',
        {'name': userName, 'email': userEmail, 'updated_at': nowText},
        where: 'id=? AND entity_id=?',
        whereArgs: [localUserId, entityId],
      );
      await txn.insert('devices', {
        'id': deviceId,
        'entity_id': entityId,
        'user_id': localUserId,
        'device_key': deviceKey,
        'name': deviceName,
        'platform': platform,
        'app_version': appVersion,
        'registration_revoked': deviceRevoked ? 1 : 0,
        'created_at': nowText,
        'updated_at': nowText,
        'revoked_at': deviceRevoked ? nowText : null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'devices',
        {
          'user_id': localUserId,
          'device_key': deviceKey,
          'name': deviceName,
          'platform': platform,
          'app_version': appVersion,
          'registration_revoked': deviceRevoked ? 1 : 0,
          'revoked_at': deviceRevoked ? nowText : null,
          'updated_at': nowText,
        },
        where: 'id=? AND entity_id=?',
        whereArgs: [deviceId, entityId],
      );

      String? financialYearId;
      String? warehouseId;
      String? cashboxId;
      if (!deviceRevoked) {
        financialYearId = await _ensureFinancialYear(
          txn,
          entityId,
          now,
          nowText,
        );
        warehouseId = await _ensureWarehouse(txn, entityId, nowText);
        cashboxId = await _ensureCashbox(txn, entityId, nowText);
      }

      await txn.insert('organization_contexts', {
        'entity_id': entityId,
        'membership_id': membershipId,
        'server_user_id': serverUserId,
        'local_user_id': localUserId,
        'device_id': deviceId,
        'financial_year_id': financialYearId,
        'default_warehouse_id': warehouseId,
        'default_cashbox_id': cashboxId,
        'entity_name': entityName,
        'currency_code': currencyCode,
        'timezone': timezone,
        'role': role,
        'device_revoked': deviceRevoked ? 1 : 0,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('sync_cursors', {
        'entity_id': entityId,
        'device_id': deviceId,
        'server_sequence': 0,
        'last_acknowledged_sequence': 0,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('sync_entity_state', {
        'entity_id': entityId,
        'device_id': deviceId,
        'device_revoked': deviceRevoked ? 1 : 0,
        'sync_enabled': deviceRevoked ? 0 : 1,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_state', {
        'singleton': 1,
        'active_entity_id': entityId,
        'updated_at': nowText,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    _cached = null;
    if (deviceRevoked) {
      throw const LocalContextUnavailableException(
        'تم إلغاء هذا الجهاز من الإدارة.',
      );
    }
    return current;
  }

  Future<LocalContext> switchTo(String entityId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      'organization_contexts',
      columns: ['device_revoked'],
      where: 'entity_id=?',
      whereArgs: [entityId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const LocalContextUnavailableException(
        'لم يتم تجهيز المؤسسة على هذا الجهاز.',
      );
    }
    if (rows.first['device_revoked'] == 1) {
      throw const LocalContextUnavailableException(
        'تم إلغاء هذا الجهاز من الإدارة.',
      );
    }
    await db.insert('app_state', {
      'singleton': 1,
      'active_entity_id': entityId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _cached = null;
    return current;
  }

  Future<LocalContext> _loadActive() async {
    final db = await _databaseProvider();
    final rows = await db.rawQuery('''
SELECT c.*
FROM app_state s
JOIN organization_contexts c ON c.entity_id = s.active_entity_id
WHERE s.singleton = 1
LIMIT 1
''');
    if (rows.isEmpty) {
      throw const LocalContextUnavailableException(
        'اختر مؤسسة وسجّل الجهاز قبل فتح مساحة العمل.',
      );
    }
    final row = rows.first;
    if (row['device_revoked'] == 1) {
      throw const LocalContextUnavailableException(
        'تم إلغاء هذا الجهاز من الإدارة.',
      );
    }
    String requiredValue(String column) {
      final value = row[column]?.toString();
      if (value == null || value.isEmpty) {
        throw LocalContextUnavailableException(
          'سياق المؤسسة غير مكتمل: $column',
        );
      }
      return value;
    }

    return LocalContext(
      entityId: requiredValue('entity_id'),
      membershipId: requiredValue('membership_id'),
      serverUserId: requiredValue('server_user_id'),
      userId: requiredValue('local_user_id'),
      deviceId: requiredValue('device_id'),
      financialYearId: requiredValue('financial_year_id'),
      defaultWarehouseId: requiredValue('default_warehouse_id'),
      defaultCashboxId: requiredValue('default_cashbox_id'),
      entityName: requiredValue('entity_name'),
      currencyCode: requiredValue('currency_code'),
      timezone: requiredValue('timezone'),
      role: requiredValue('role'),
      deviceRevoked: row['device_revoked'] == 1,
    );
  }

  Future<String> _ensureFinancialYear(
    Transaction txn,
    String entityId,
    DateTime now,
    String nowText,
  ) async {
    final rows = await txn.query(
      'financial_years',
      columns: ['id'],
      where: 'entity_id=? AND is_open=1',
      whereArgs: [entityId],
      orderBy: 'starts_on DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id']! as String;
    final id = deterministicContextId(entityId, 'financial-year-${now.year}');
    await txn.insert('financial_years', {
      'id': id,
      'entity_id': entityId,
      'name': '${now.year}',
      'starts_on': DateTime.utc(now.year).toIso8601String(),
      'ends_on': DateTime.utc(now.year, 12, 31, 23, 59, 59).toIso8601String(),
      'is_open': 1,
      'created_at': nowText,
      'updated_at': nowText,
    });
    return id;
  }

  Future<String> _ensureWarehouse(
    Transaction txn,
    String entityId,
    String nowText,
  ) async {
    final rows = await txn.query(
      'warehouses',
      columns: ['id'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [entityId],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id']! as String;
    final id = deterministicContextId(entityId, 'default-warehouse');
    await txn.insert('warehouses', {
      'id': id,
      'entity_id': entityId,
      'name': 'المستودع المحلي',
      'created_at': nowText,
      'updated_at': nowText,
    });
    return id;
  }

  Future<String> _ensureCashbox(
    Transaction txn,
    String entityId,
    String nowText,
  ) async {
    final rows = await txn.query(
      'cashboxes',
      columns: ['id'],
      where: 'entity_id=? AND deleted_at IS NULL',
      whereArgs: [entityId],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id']! as String;
    final id = deterministicContextId(entityId, 'default-cashbox');
    await txn.insert('cashboxes', {
      'id': id,
      'entity_id': entityId,
      'name': 'الصندوق المحلي',
      'created_at': nowText,
      'updated_at': nowText,
    });
    return id;
  }

  void clearCache() => _cached = null;
}

/// Stable fallback IDs are required because v1 has no financial-year event
/// and its bootstrap has no warehouse snapshot. Every new device therefore
/// creates the same dependency IDs for the same organization.
String deterministicContextId(String entityId, String dependency) =>
    uuid.v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', '$entityId:$dependency');
