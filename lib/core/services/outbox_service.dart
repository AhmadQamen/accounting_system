import 'dart:convert';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:sqflite/sqflite.dart';

class OutboxService {
  const OutboxService();

  Future<String> enqueue(
    DatabaseExecutor db, {
    required String entityId,
    required String aggregateType,
    required String aggregateId,
    required String action,
    required Map<String, Object?> payload,
    String? operationId,
  }) async {
    final id = operationId ?? uuid.v4();
    await db.insert(
      'sync_outbox',
      {
        'operation_id': id,
        'entity_id': entityId,
        'aggregate_type': aggregateType,
        'aggregate_id': aggregateId,
        'action': action,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id;
  }
}
