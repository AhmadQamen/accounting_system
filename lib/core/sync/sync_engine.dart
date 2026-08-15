import 'dart:convert';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/utils/app_logger.dart';
import 'package:sqflite/sqflite.dart';

class SyncPushResult {
  const SyncPushResult({required this.operationId, required this.accepted, this.error});
  final String operationId;
  final bool accepted;
  final String? error;
}

class SyncPullBatch {
  const SyncPullBatch({required this.changes, required this.lastServerSeq});
  final List<Map<String, Object?>> changes;
  final int lastServerSeq;
}

abstract class SyncTransport {
  Future<SyncPushResult> push(Map<String, Object?> operation);
  Future<SyncPullBatch> pull({required String entityId, required int afterServerSeq});
}

/// Default transport used until a real backend contract is supplied.
/// Local accounting remains fully operational; sync status will report that
/// the backend is not configured instead of inventing API endpoints.
class DisabledSyncTransport implements SyncTransport {
  const DisabledSyncTransport();
  @override
  Future<SyncPullBatch> pull({required String entityId, required int afterServerSeq}) {
    throw const SyncBackendUnavailableException();
  }

  @override
  Future<SyncPushResult> push(Map<String, Object?> operation) {
    throw const SyncBackendUnavailableException();
  }
}

class SyncBackendUnavailableException implements Exception {
  const SyncBackendUnavailableException();
  @override
  String toString() => 'Sync backend is not configured';
}

class SyncEngine {
  SyncEngine({AppDatabase? database, SyncTransport? transport})
      : _database = database ?? AppDatabase.instance,
        _transport = transport ?? const DisabledSyncTransport();

  final AppDatabase _database;
  final SyncTransport _transport;

  Future<SyncStatus> status() async {
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final pending = await db.rawQuery("SELECT COUNT(*) c FROM sync_outbox WHERE entity_id=? AND status IN ('pending','failed')", [ctx.entityId]);
    final conflicts = await db.rawQuery("SELECT COUNT(*) c FROM sync_conflicts WHERE entity_id=? AND status='open'", [ctx.entityId]);
    final device = await db.query('devices', columns: ['last_sync_at','last_pulled_server_seq'], where: 'id=?', whereArgs: [ctx.deviceId], limit: 1);
    return SyncStatus(
      pending: (pending.first['c'] as num).toInt(),
      conflicts: (conflicts.first['c'] as num).toInt(),
      lastSyncAt: device.isEmpty ? null : DateTime.tryParse('${device.first['last_sync_at'] ?? ''}'),
      lastServerSeq: device.isEmpty ? 0 : ((device.first['last_pulled_server_seq'] as num?) ?? 0).toInt(),
      backendConfigured: _transport is! DisabledSyncTransport,
    );
  }

  Future<void> syncNow() async {
    AppLogger.info('sync_start');
    final ctx = await LocalContextService.instance.current;
    final db = await _database.database;
    final pending = await db.query(
      'sync_outbox',
      where: "entity_id=? AND status IN ('pending','failed') AND (next_retry_at IS NULL OR next_retry_at<=?)",
      whereArgs: [ctx.entityId, DateTime.now().toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
      limit: 100,
    );

    for (final row in pending) {
      final operationId = row['operation_id'] as String;
      await db.update('sync_outbox', {'status': 'syncing'}, where: 'operation_id=?', whereArgs: [operationId]);
      try {
        final result = await _transport.push(row);
        if (result.accepted) {
          await db.update('sync_outbox', {'status': 'done', 'last_error': null}, where: 'operation_id=?', whereArgs: [operationId]);
          await db.insert('sync_operations', {
            'id': operationId,
            'entity_id': ctx.entityId,
            'device_id': ctx.deviceId,
            'user_id': ctx.userId,
            'operation_type': '${row['aggregate_type']}:${row['action']}',
            'client_created_at': row['created_at'],
            'server_received_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'done',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        } else {
          await _markFailed(db, row, result.error ?? 'Rejected by server');
        }
      } catch (e) {
        await _markFailed(db, row, e.toString());
        if (e is SyncBackendUnavailableException) rethrow;
      }
    }

    final deviceRows = await db.query('devices', where: 'id=?', whereArgs: [ctx.deviceId], limit: 1);
    var cursor = deviceRows.isEmpty ? 0 : (deviceRows.first['last_pulled_server_seq'] as num).toInt();
    final batch = await _transport.pull(entityId: ctx.entityId, afterServerSeq: cursor);
    await _database.transaction((txn) async {
      for (final change in batch.changes) {
        await _applyChange(txn, ctx.entityId, change);
      }
      await _rebuildCaches(txn, ctx.entityId);
      cursor = batch.lastServerSeq;
      await txn.update('devices', {'last_pulled_server_seq': cursor, 'last_sync_at': DateTime.now().toUtc().toIso8601String(), 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'id=?', whereArgs: [ctx.deviceId]);
    });
  }

  Future<void> _markFailed(dynamic db, Map<String, Object?> row, String error) async {
    final attempts = ((row['attempt_count'] as num?)?.toInt() ?? 0) + 1;
    final capped = attempts > 6 ? 6 : attempts;
    final minutes = 1 << capped;
    await db.update('sync_outbox', {
      'status': 'failed',
      'attempt_count': attempts,
      'last_error': error,
      'next_retry_at': DateTime.now().toUtc().add(Duration(minutes: minutes)).toIso8601String(),
    }, where: 'operation_id=?', whereArgs: [row['operation_id']]);
  }

  Future<void> _applyChange(dynamic db, String entityId, Map<String, Object?> change) async {
    final table = change['table_name'] as String;
    final recordId = change['record_id'] as String;
    final type = change['change_type'] as String;
    final serverVersion = (change['record_version'] as num?)?.toInt() ?? 1;
    final payloadRaw = change['payload_json'];
    final decoded = payloadRaw is String && payloadRaw.isNotEmpty
        ? jsonDecode(payloadRaw)
        : <String, dynamic>{};
    final payload = decoded is Map<String, dynamic>
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};

    if (!_allowedPullTables.contains(table)) return;
    if (payload['entity_id'] != null && payload['entity_id'] != entityId) return;

    if (type == 'delete') {
      if (_softDeleteTables.contains(table)) {
        await db.update(
          table,
          {'deleted_at': change['changed_at']},
          where: 'id=? AND entity_id=?',
          whereArgs: [recordId, entityId],
        );
      } else {
        await _recordConflict(
          db,
          entityId: entityId,
          table: table,
          recordId: recordId,
          serverVersion: serverVersion,
          serverPayload: payloadRaw?.toString(),
          reason: 'Remote delete rejected for immutable accounting data',
        );
      }
      return;
    }

    payload['id'] = recordId;
    payload['entity_id'] = entityId;
    if (_nonVersionedTables.contains(table)) {
      payload.remove('version');
    } else {
      payload['version'] = serverVersion;
    }

    // Cache fields are rebuilt from immutable ledgers after the whole batch.
    if (table == 'parties') payload.remove('current_balance_minor');
    if (table == 'cashboxes') payload.remove('current_balance_minor');
    if (table == 'inventory_items') {
      payload.remove('current_quantity');
      payload.remove('inventory_value_minor');
      payload.putIfAbsent('current_quantity', () => 0.0);
      payload.putIfAbsent('inventory_value_minor', () => 0);
    }

    final existing = await db.query(
      table,
      where: 'id=? AND entity_id=?',
      whereArgs: [recordId, entityId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(table, payload, conflictAlgorithm: ConflictAlgorithm.ignore);
      await _recordAppliedChange(db, entityId, change, payloadRaw);
      return;
    }

    final local = existing.first;
    if (_appendOnlyTables.contains(table)) {
      if (type != 'insert') {
        await _recordConflict(
          db,
          entityId: entityId,
          table: table,
          recordId: recordId,
          localVersion: (local['version'] as num?)?.toInt(),
          serverVersion: serverVersion,
          localPayload: jsonEncode(local),
          serverPayload: payloadRaw?.toString(),
          reason: 'Remote mutation attempted on append-only row',
        );
      }
      await _recordAppliedChange(db, entityId, change, payloadRaw);
      return;
    }

    if (_documentTables.contains(table) &&
        (local['status'] == 'posted' || local['status'] == 'void')) {
      await _recordConflict(
        db,
        entityId: entityId,
        table: table,
        recordId: recordId,
        localVersion: (local['version'] as num?)?.toInt(),
        serverVersion: serverVersion,
        localPayload: jsonEncode(local),
        serverPayload: payloadRaw?.toString(),
        reason: 'Posted/void document is immutable locally',
      );
      return;
    }

    final pending = await db.rawQuery(
      "SELECT COUNT(*) c FROM sync_outbox WHERE entity_id=? AND aggregate_id=? AND status IN ('pending','syncing','failed')",
      [entityId, recordId],
    );
    final hasPendingLocalMutation = (pending.first['c'] as num).toInt() > 0;
    final localVersion = (local['version'] as num?)?.toInt() ?? 1;
    if (hasPendingLocalMutation && serverVersion >= localVersion) {
      await _recordConflict(
        db,
        entityId: entityId,
        table: table,
        recordId: recordId,
        localVersion: localVersion,
        serverVersion: serverVersion,
        localPayload: jsonEncode(local),
        serverPayload: payloadRaw?.toString(),
        reason: 'Local pending mutation conflicts with server version',
      );
      return;
    }

    if (serverVersion <= localVersion) {
      await _recordAppliedChange(db, entityId, change, payloadRaw);
      return;
    }

    final update = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('entity_id');
    await db.update(
      table,
      update,
      where: 'id=? AND entity_id=?',
      whereArgs: [recordId, entityId],
    );
    await _recordAppliedChange(db, entityId, change, payloadRaw);
  }

  Future<void> _recordAppliedChange(
    dynamic db,
    String entityId,
    Map<String, Object?> change,
    Object? payloadRaw,
  ) async {
    await db.insert(
      'sync_changes',
      {
        'id': uuid.v4(),
        'entity_id': entityId,
        'server_seq': change['server_seq'],
        'table_name': change['table_name'],
        'record_id': change['record_id'],
        'change_type': change['change_type'],
        'record_version': change['record_version'] ?? 1,
        'payload_json': payloadRaw,
        'changed_at': change['changed_at'],
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _recordConflict(
    dynamic db, {
    required String entityId,
    required String table,
    required String recordId,
    int? localVersion,
    required int serverVersion,
    String? localPayload,
    String? serverPayload,
    required String reason,
  }) async {
    AppLogger.warning('sync_conflict', {'table': table, 'record_id': recordId, 'reason': reason});
    await db.insert('sync_conflicts', {
      'id': uuid.v4(),
      'entity_id': entityId,
      'aggregate_type': table,
      'aggregate_id': recordId,
      'local_version': localVersion,
      'server_version': serverVersion,
      'local_payload_json': localPayload,
      'server_payload_json': jsonEncode({'reason': reason, 'payload': serverPayload}),
      'status': 'open',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _rebuildCaches(dynamic db, String entityId) async {
    await db.rawUpdate('''
UPDATE inventory_items
SET current_quantity = COALESCE((SELECT SUM(m.quantity_delta) FROM inventory_movements m WHERE m.inventory_item_id=inventory_items.id),0),
    inventory_value_minor = COALESCE((SELECT SUM(m.value_delta_minor) FROM inventory_movements m WHERE m.inventory_item_id=inventory_items.id),0)
WHERE entity_id=?
''', [entityId]);
    await db.rawUpdate('''
UPDATE cashboxes
SET current_balance_minor = COALESCE((SELECT SUM(CASE t.direction WHEN 'in' THEN t.amount_minor ELSE -t.amount_minor END) FROM transactions t WHERE t.cashbox_id=cashboxes.id),0)
WHERE entity_id=?
''', [entityId]);
    await db.rawUpdate('''
UPDATE parties
SET current_balance_minor = COALESCE((SELECT SUM(l.balance_delta_minor) FROM party_ledger_entries l WHERE l.party_id=parties.id),0)
WHERE entity_id=?
''', [entityId]);
  }

  static const _softDeleteTables = {'parties','categories','products','product_specifications','product_units','barcodes','warehouses','cashboxes'};
  static const _nonVersionedTables = {
    'inventory_movements','transactions','party_ledger_entries',
    'sale_return_items','purchase_return_items','waste_items'
  };
  static const _appendOnlyTables = {
    'inventory_movements','transactions','party_ledger_entries',
    'sale_items','purchase_items','sale_return_items','purchase_return_items','waste_items'
  };
  static const _documentTables = {
    'sales','purchase_invoices','sale_return_invoices','purchase_return_invoices','waste_invoices'
  };
  static const _allowedPullTables = {
    'parties','categories','products','product_specifications','product_units','barcodes','warehouses','cashboxes',
    'inventory_items','inventory_movements','sales','sale_items','purchase_invoices','purchase_items',
    'sale_return_invoices','sale_return_items','purchase_return_invoices','purchase_return_items','waste_invoices','waste_items',
    'transactions','party_ledger_entries'
  };
}
