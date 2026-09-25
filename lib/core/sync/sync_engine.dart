import 'dart:async';
import 'dart:convert';

import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:accounting_system/core/sync/domain_event_projector.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:sqflite/sqflite.dart';

class DeviceRevokedSyncException implements Exception {
  const DeviceRevokedSyncException();

  @override
  String toString() => 'تم إلغاء هذا الجهاز؛ المزامنة متوقفة لهذه المؤسسة.';
}

class SyncEngine {
  SyncEngine({
    required SyncTransport transport,
    AppDatabase? database,
    DomainEventProjector? projector,
    Future<Database> Function()? databaseProvider,
    Future<LocalContext> Function()? contextProvider,
  }) : _transport = transport,
       _databaseProvider =
           databaseProvider ??
           (() => (database ?? AppDatabase.instance).database),
       _contextProvider =
           contextProvider ?? (() => LocalContextService.instance.current),
       _projector = projector ?? const SqliteDomainEventProjector();

  static const pushBatchSize = 100;
  static const pullBatchSize = 500;
  static final Map<String, Future<void>> _entitySyncs = {};

  final SyncTransport _transport;
  final Future<Database> Function() _databaseProvider;
  final Future<LocalContext> Function() _contextProvider;
  final DomainEventProjector _projector;

  Future<SyncStatus> status() async {
    final context = await _contextProvider();
    final db = await _databaseProvider();
    try {
      final remote = await _transport.status(
        entityId: context.entityId,
        deviceId: context.deviceId,
      );
      await _setRevoked(db, context.entityId, remote.deviceRevoked);
    } on NetworkException {
      // Local status remains useful while offline.
    } on ServerException {
      // A transient server error must not disable local work.
    } on PermissionException catch (error) {
      await _disableEntity(db, context.entityId, error.message);
    }
    return _localStatus(db, context.entityId);
  }

  Future<void> syncNow({bool rebuild = false}) async {
    final context = await _contextProvider();
    final existing = _entitySyncs[context.entityId];
    if (existing != null) return existing;

    final future = _runSync(context, rebuild: rebuild);
    _entitySyncs[context.entityId] = future;
    try {
      await future;
    } finally {
      if (identical(_entitySyncs[context.entityId], future)) {
        _entitySyncs.remove(context.entityId);
      }
    }
  }

  Future<void> rebuild() => syncNow(rebuild: true);

  Future<void> _runSync(LocalContext context, {required bool rebuild}) async {
    final db = await _databaseProvider();
    await _assertSyncEnabled(db, context.entityId);
    try {
      final remote = await _transport.status(
        entityId: context.entityId,
        deviceId: context.deviceId,
      );
      if (remote.deviceRevoked) {
        await _setRevoked(db, context.entityId, true);
        throw const DeviceRevokedSyncException();
      }

      final state = await _entityState(db, context.entityId);
      final bootstrapped = state?['bootstrap_completed'] == 1;
      if (!bootstrapped || rebuild) {
        await _bootstrap(db, context, rebuild: rebuild);
      }

      await _pushOutbox(db, context);
      final finalCursor = await _pullAll(db, context);
      await _transport.ack(
        entityId: context.entityId,
        deviceId: context.deviceId,
        serverSequence: finalCursor,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await db.update(
        'sync_cursors',
        {'last_acknowledged_sequence': finalCursor, 'updated_at': now},
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
      await db.update(
        'sync_entity_state',
        {'last_sync_at': now, 'last_error': null, 'updated_at': now},
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
    } on PermissionException catch (error) {
      await _disableEntity(db, context.entityId, error.message);
      rethrow;
    } catch (error) {
      await _recordSyncError(db, context.entityId, error.toString());
      rethrow;
    }
  }

  Future<void> _bootstrap(
    Database db,
    LocalContext context, {
    required bool rebuild,
  }) async {
    final response = await _transport.bootstrap(
      entityId: context.entityId,
      deviceId: context.deviceId,
    );
    if (response.snapshotVersion != 1) {
      throw FormatException(
        'Unsupported bootstrap snapshot version ${response.snapshotVersion}.',
      );
    }
    final cashboxes = response.snapshot['cashboxes'];
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      if (cashboxes is List) {
        for (final raw in cashboxes.whereType<Map>()) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['id']?.toString();
          final name = row['name']?.toString();
          if (id == null || id.isEmpty || name == null || name.isEmpty) {
            throw const FormatException('Invalid cashbox bootstrap row.');
          }
          final existing = await transaction.query(
            'cashboxes',
            columns: ['id'],
            where: 'id=? AND entity_id=?',
            whereArgs: [id, context.entityId],
            limit: 1,
          );
          final values = <String, Object?>{
            'name': name,
            'current_balance_minor':
                (row['current_balance_minor'] as num?)?.toInt() ?? 0,
            'updated_at': row['updated_at']?.toString() ?? now,
            'version': (row['snapshot_version'] as num?)?.toInt() ?? 1,
          };
          if (existing.isEmpty) {
            await transaction.insert('cashboxes', {
              'id': id,
              'entity_id': context.entityId,
              ...values,
              'created_at': row['updated_at']?.toString() ?? now,
            });
          } else {
            await transaction.update(
              'cashboxes',
              values,
              where: 'id=? AND entity_id=?',
              whereArgs: [id, context.entityId],
            );
          }
        }
      }

      // The v1 snapshot is partial: merge only the collections it contains
      // and never clear unrelated business tables. Its sequence is still the
      // server's atomic hand-off point for subsequent pull requests.
      await transaction.update(
        'sync_entity_state',
        {
          'bootstrap_completed': 1,
          'bootstrap_server_sequence': response.serverSequence,
          'updated_at': now,
          'last_error': null,
        },
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
      await transaction.update(
        'sync_cursors',
        {
          'server_sequence': response.serverSequence,
          if (rebuild) 'last_acknowledged_sequence': 0,
          'updated_at': now,
        },
        where: 'entity_id=?',
        whereArgs: [context.entityId],
      );
    });
  }

  Future<void> _pushOutbox(Database db, LocalContext context) async {
    while (true) {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await db.query(
        'sync_outbox',
        where:
            "entity_id=? AND status IN ('pending','failed','syncing') "
            'AND (next_retry_at IS NULL OR next_retry_at<=?)',
        whereArgs: [context.entityId, now],
        orderBy: 'created_at ASC',
        limit: pushBatchSize,
      );
      if (rows.isEmpty) return;
      final events = rows.map(DomainEvent.fromOutbox).toList(growable: false);
      final eventIds = events.map((event) => event.eventId).toList();
      await _setOutboxStatus(db, eventIds, 'syncing');

      List<SyncPushResult> results;
      try {
        results = await _transport.push(
          entityId: context.entityId,
          deviceId: context.deviceId,
          events: events,
        );
      } on ValidationException catch (error) {
        await _rejectBatch(db, eventIds, error.message);
        rethrow;
      } on UnauthorizedException {
        await _setOutboxStatus(db, eventIds, 'pending');
        rethrow;
      } on PermissionException {
        await _setOutboxStatus(db, eventIds, 'pending');
        rethrow;
      } on ServerException catch (error) {
        await _retryBatch(db, rows, error.message);
        rethrow;
      } on AppException catch (error) {
        if (error.statusCode >= 400 && error.statusCode < 500) {
          await _rejectBatch(db, eventIds, error.message);
        } else {
          await _retryBatch(db, rows, error.message);
        }
        rethrow;
      } on NetworkException catch (error) {
        await _retryBatch(db, rows, error.message);
        rethrow;
      } catch (_) {
        await _setOutboxStatus(db, eventIds, 'pending');
        rethrow;
      }

      await db.transaction((transaction) async {
        final byId = {for (final result in results) result.eventId: result};
        for (final event in events) {
          final result = byId[event.eventId];
          if (result == null) {
            await _markMissingResult(transaction, event.eventId);
            continue;
          }
          await _applyPushResult(
            transaction,
            context: context,
            event: event,
            result: result,
          );
        }
      });

      if (rows.length < pushBatchSize) return;
    }
  }

  Future<void> _applyPushResult(
    Transaction transaction, {
    required LocalContext context,
    required DomainEvent event,
    required SyncPushResult result,
  }) async {
    final status = result.status.toUpperCase();
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction.insert('sync_operations', {
      'id': event.eventId,
      'entity_id': context.entityId,
      'device_id': context.deviceId,
      'event_id': event.eventId,
      'server_sequence': result.serverSequence,
      'operation_type': event.eventType,
      'client_created_at': event.occurredAt,
      'server_received_at': now,
      'status': status,
      'error_message': result.errorMessage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    switch (status) {
      case 'ACCEPTED':
      case 'ALREADY_ACCEPTED':
        if (result.serverSequence != null) {
          await transaction.insert('sync_changes', {
            'event_id': event.eventId,
            'entity_id': context.entityId,
            'server_sequence': result.serverSequence,
            'aggregate_type': event.aggregateType,
            'aggregate_id': event.aggregateId,
            'event_type': event.eventType,
            'aggregate_version': event.aggregateVersion,
            'payload_json': jsonEncode(event.payload),
            'occurred_at': event.occurredAt,
            'received_at': now,
            'applied_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await transaction.delete(
          'sync_outbox',
          where: 'event_id=?',
          whereArgs: [event.eventId],
        );
        return;
      case 'CONFLICT':
        await transaction.update(
          'sync_outbox',
          {
            'status': 'conflict',
            'server_sequence': result.serverSequence,
            'last_error': result.errorMessage ?? result.errorCode,
            'next_retry_at': null,
          },
          where: 'event_id=?',
          whereArgs: [event.eventId],
        );
        await transaction.insert('sync_conflicts', {
          'id': 'push:${event.eventId}',
          'entity_id': context.entityId,
          'aggregate_type': event.aggregateType,
          'aggregate_id': event.aggregateId,
          'local_version': event.aggregateVersion,
          'local_payload_json': jsonEncode(event.payload),
          'server_payload_json': jsonEncode({
            'errorCode': result.errorCode,
            'errorMessage': result.errorMessage,
          }),
          'status': 'open',
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        return;
      case 'REJECTED':
      default:
        await transaction.update(
          'sync_outbox',
          {
            'status': 'rejected',
            'last_error':
                result.errorMessage ??
                result.errorCode ??
                'Unknown push result: $status',
            'next_retry_at': null,
          },
          where: 'event_id=?',
          whereArgs: [event.eventId],
        );
    }
  }

  Future<int> _pullAll(Database db, LocalContext context) async {
    var cursor = await _readCursor(db, context.entityId);
    while (true) {
      final batch = await _transport.pull(
        entityId: context.entityId,
        deviceId: context.deviceId,
        afterServerSequence: cursor,
        limit: pullBatchSize,
      );
      if (batch.lastServerSequence < cursor) {
        throw const FormatException('Pull cursor moved backwards.');
      }
      await db.transaction((transaction) async {
        for (final event in batch.events) {
          final sequence = event.serverSequence;
          if (sequence == null) {
            throw const FormatException('Pulled event has no serverSequence.');
          }
          final existing = await transaction.query(
            'sync_changes',
            columns: ['event_id'],
            where: 'event_id=?',
            whereArgs: [event.eventId],
            limit: 1,
          );
          if (existing.isEmpty) {
            await _projector.apply(
              transaction,
              entityId: context.entityId,
              event: event,
            );
            await transaction.insert('sync_changes', {
              'event_id': event.eventId,
              'entity_id': context.entityId,
              'server_sequence': sequence,
              'aggregate_type': event.aggregateType,
              'aggregate_id': event.aggregateId,
              'event_type': event.eventType,
              'aggregate_version': event.aggregateVersion,
              'payload_json': jsonEncode(event.payload),
              'occurred_at': event.occurredAt,
              'received_at': event.receivedAt,
              'applied_at': DateTime.now().toUtc().toIso8601String(),
            });
            await transaction.rawInsert(
              'INSERT INTO sync_aggregate_versions '
              '(entity_id, aggregate_type, aggregate_id, aggregate_version, updated_at) '
              'VALUES (?,?,?,?,?) ON CONFLICT(entity_id, aggregate_type, aggregate_id) '
              'DO UPDATE SET aggregate_version=MAX(aggregate_version, excluded.aggregate_version), '
              'updated_at=excluded.updated_at',
              [
                context.entityId,
                event.aggregateType,
                event.aggregateId,
                event.aggregateVersion,
                DateTime.now().toUtc().toIso8601String(),
              ],
            );
          }
        }
        await transaction.update(
          'sync_cursors',
          {
            'server_sequence': batch.lastServerSequence,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'entity_id=?',
          whereArgs: [context.entityId],
        );
      });
      cursor = batch.lastServerSequence;
      if (!batch.hasMore) return cursor;
    }
  }

  Future<SyncStatus> _localStatus(Database db, String entityId) async {
    final pending = await db.rawQuery(
      "SELECT COUNT(*) c FROM sync_outbox WHERE entity_id=? AND status IN ('pending','failed','syncing')",
      [entityId],
    );
    final conflicts = await db.rawQuery(
      "SELECT COUNT(*) c FROM sync_conflicts WHERE entity_id=? AND status='open'",
      [entityId],
    );
    final rejected = await db.rawQuery(
      "SELECT COUNT(*) c FROM sync_outbox WHERE entity_id=? AND status='rejected'",
      [entityId],
    );
    final state = await _entityState(db, entityId);
    final cursor = await db.query(
      'sync_cursors',
      where: 'entity_id=?',
      whereArgs: [entityId],
      limit: 1,
    );
    final quarantine = await db.rawQuery(
      'SELECT COUNT(*) c FROM legacy_sync_quarantine',
    );
    return SyncStatus(
      pending: (pending.first['c'] as num).toInt(),
      conflicts: (conflicts.first['c'] as num).toInt(),
      lastSyncAt:
          state == null
              ? null
              : DateTime.tryParse('${state['last_sync_at'] ?? ''}'),
      lastServerSeq:
          cursor.isEmpty
              ? 0
              : ((cursor.first['server_sequence'] as num?) ?? 0).toInt(),
      backendConfigured: true,
      deviceRevoked: state?['device_revoked'] == 1,
      quarantinedLegacyOperations: (quarantine.first['c'] as num).toInt(),
      rejected: (rejected.first['c'] as num).toInt(),
      lastError: state?['last_error']?.toString(),
    );
  }

  Future<Map<String, Object?>?> _entityState(
    Database db,
    String entityId,
  ) async {
    final rows = await db.query(
      'sync_entity_state',
      where: 'entity_id=?',
      whereArgs: [entityId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> _readCursor(Database db, String entityId) async {
    final rows = await db.query(
      'sync_cursors',
      columns: ['server_sequence'],
      where: 'entity_id=?',
      whereArgs: [entityId],
      limit: 1,
    );
    return rows.isEmpty
        ? 0
        : ((rows.first['server_sequence'] as num?) ?? 0).toInt();
  }

  Future<void> _assertSyncEnabled(Database db, String entityId) async {
    final state = await _entityState(db, entityId);
    if (state != null &&
        (state['device_revoked'] == 1 || state['sync_enabled'] == 0)) {
      throw const DeviceRevokedSyncException();
    }
  }

  Future<void> _setRevoked(Database db, String entityId, bool revoked) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      await transaction.update(
        'sync_entity_state',
        {
          'device_revoked': revoked ? 1 : 0,
          if (revoked) 'sync_enabled': 0,
          if (revoked) 'last_error': 'DEVICE_REVOKED',
          'updated_at': now,
        },
        where: 'entity_id=?',
        whereArgs: [entityId],
      );
      await transaction.update(
        'organization_contexts',
        {'device_revoked': revoked ? 1 : 0, 'updated_at': now},
        where: 'entity_id=?',
        whereArgs: [entityId],
      );
    });
  }

  Future<void> _disableEntity(
    Database db,
    String entityId,
    String reason,
  ) async {
    await db.update(
      'sync_entity_state',
      {
        'sync_enabled': 0,
        'last_error': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_id=?',
      whereArgs: [entityId],
    );
  }

  Future<void> _recordSyncError(
    Database db,
    String entityId,
    String error,
  ) async {
    await db.update(
      'sync_entity_state',
      {
        'last_error': error,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'entity_id=?',
      whereArgs: [entityId],
    );
  }

  Future<void> _setOutboxStatus(
    DatabaseExecutor db,
    List<String> eventIds,
    String status,
  ) async {
    if (eventIds.isEmpty) return;
    final placeholders = List.filled(eventIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE sync_outbox SET status=? WHERE event_id IN ($placeholders)',
      [status, ...eventIds],
    );
  }

  Future<void> _rejectBatch(
    Database db,
    List<String> eventIds,
    String message,
  ) async {
    if (eventIds.isEmpty) return;
    final placeholders = List.filled(eventIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE sync_outbox SET status=?, last_error=?, next_retry_at=NULL '
      'WHERE event_id IN ($placeholders)',
      ['rejected', message, ...eventIds],
    );
  }

  Future<void> _retryBatch(
    Database db,
    List<Map<String, Object?>> rows,
    String message,
  ) async {
    await db.transaction((transaction) async {
      for (final row in rows) {
        final attempts = ((row['attempt_count'] as num?)?.toInt() ?? 0) + 1;
        final capped = attempts > 6 ? 6 : attempts;
        await transaction.update(
          'sync_outbox',
          {
            'status': 'failed',
            'attempt_count': attempts,
            'last_error': message,
            'next_retry_at':
                DateTime.now()
                    .toUtc()
                    .add(Duration(minutes: 1 << capped))
                    .toIso8601String(),
          },
          where: 'event_id=?',
          whereArgs: [row['event_id']],
        );
      }
    });
  }

  Future<void> _markMissingResult(
    Transaction transaction,
    String eventId,
  ) async {
    await transaction.rawUpdate(
      'UPDATE sync_outbox SET status=?, attempt_count=attempt_count+1, '
      'last_error=?, next_retry_at=? WHERE event_id=?',
      [
        'failed',
        'SERVER_RESULT_MISSING',
        DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 2))
            .toIso8601String(),
        eventId,
      ],
    );
  }
}
