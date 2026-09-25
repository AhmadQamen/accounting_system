import 'dart:convert';

class DomainEvent {
  const DomainEvent({
    required this.eventId,
    required this.aggregateType,
    required this.aggregateId,
    required this.eventType,
    required this.aggregateVersion,
    required this.occurredAt,
    required this.payload,
    this.serverSequence,
    this.receivedAt,
  });

  final String eventId;
  final String aggregateType;
  final String aggregateId;
  final String eventType;
  final int aggregateVersion;
  final String occurredAt;
  final Map<String, dynamic> payload;
  final int? serverSequence;
  final String? receivedAt;

  factory DomainEvent.fromJson(Map<String, dynamic> json) => DomainEvent(
    eventId: _requiredString(json, 'eventId'),
    aggregateType: _requiredString(json, 'aggregateType'),
    aggregateId: _requiredString(json, 'aggregateId'),
    eventType: _requiredString(json, 'eventType'),
    aggregateVersion: _requiredInt(json, 'aggregateVersion'),
    occurredAt: _requiredString(json, 'occurredAt'),
    payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
    serverSequence: _optionalInt(json['serverSequence']),
    receivedAt: json['receivedAt']?.toString(),
  );

  factory DomainEvent.fromOutbox(Map<String, Object?> row) {
    final rawPayload = row['payload_json'];
    final decoded = rawPayload is String ? jsonDecode(rawPayload) : rawPayload;
    if (decoded is! Map) {
      throw const FormatException(
        'Outbox event payload must be a JSON object.',
      );
    }
    return DomainEvent(
      eventId: row['event_id']! as String,
      aggregateType: row['aggregate_type']! as String,
      aggregateId: row['aggregate_id']! as String,
      eventType: row['event_type']! as String,
      aggregateVersion: (row['aggregate_version']! as num).toInt(),
      occurredAt: row['occurred_at']! as String,
      payload: Map<String, dynamic>.from(decoded),
      serverSequence: _optionalInt(row['server_sequence']),
    );
  }

  Map<String, dynamic> toPushJson() => {
    'eventId': eventId,
    'aggregateType': aggregateType,
    'aggregateId': aggregateId,
    'eventType': eventType,
    'aggregateVersion': aggregateVersion,
    'occurredAt': occurredAt,
    'payload': payload,
  };
}

class SyncPushResult {
  const SyncPushResult({
    required this.eventId,
    required this.status,
    this.serverSequence,
    this.errorCode,
    this.errorMessage,
  });

  final String eventId;
  final String status;
  final int? serverSequence;
  final String? errorCode;
  final String? errorMessage;

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
    eventId: _requiredString(json, 'eventId'),
    status: _requiredString(json, 'status'),
    serverSequence: _optionalInt(json['serverSequence']),
    errorCode: json['errorCode']?.toString(),
    errorMessage: json['errorMessage']?.toString(),
  );
}

class SyncPullBatch {
  const SyncPullBatch({
    required this.events,
    required this.lastServerSequence,
    required this.hasMore,
  });

  final List<DomainEvent> events;
  final int lastServerSequence;
  final bool hasMore;
}

class SyncBootstrap {
  const SyncBootstrap({
    required this.serverSequence,
    required this.snapshotVersion,
    required this.snapshot,
  });

  final int serverSequence;
  final int snapshotVersion;
  final Map<String, dynamic> snapshot;
}

class RemoteSyncStatus {
  const RemoteSyncStatus({
    required this.deviceRevoked,
    required this.latestServerSequence,
    required this.lastPulledSequence,
    this.serverTime,
  });

  final bool deviceRevoked;
  final int latestServerSequence;
  final int lastPulledSequence;
  final String? serverTime;
}

abstract interface class SyncTransport {
  Future<SyncBootstrap> bootstrap({
    required String entityId,
    required String deviceId,
  });

  Future<List<SyncPushResult>> push({
    required String entityId,
    required String deviceId,
    required List<DomainEvent> events,
  });

  Future<SyncPullBatch> pull({
    required String entityId,
    required String deviceId,
    required int afterServerSequence,
    int limit = 500,
  });

  Future<void> ack({
    required String entityId,
    required String deviceId,
    required int serverSequence,
  });

  Future<RemoteSyncStatus> status({
    required String entityId,
    required String deviceId,
  });
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString();
  if (value == null || value.isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _optionalInt(json[key]);
  if (value == null) throw FormatException('Missing $key.');
  return value;
}

int? _optionalInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
