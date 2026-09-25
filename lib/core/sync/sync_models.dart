import 'package:accounting_system/core/configs/unset.dart';
import 'package:accounting_system/core/models/model_parsers.dart';

class SyncStatus {
  final int pending;
  final int conflicts;
  final DateTime? lastSyncAt;
  final int lastServerSeq;
  final bool backendConfigured;
  final bool deviceRevoked;
  final int quarantinedLegacyOperations;
  final int rejected;
  final String? lastError;

  const SyncStatus({
    this.pending = 0,
    this.conflicts = 0,
    this.lastSyncAt,
    this.lastServerSeq = 0,
    this.backendConfigured = false,
    this.deviceRevoked = false,
    this.quarantinedLegacyOperations = 0,
    this.rejected = 0,
    this.lastError,
  });

  factory SyncStatus.fromSql(Map<String, Object?> row) => SyncStatus(
    pending: intValue(row['pending']),
    conflicts: intValue(row['conflicts']),
    lastSyncAt: parseDate(row['last_sync_at']),
    lastServerSeq: intValue(row['last_server_seq']),
    backendConfigured: boolValue(row['backend_configured']),
    deviceRevoked: boolValue(row['device_revoked']),
    quarantinedLegacyOperations: intValue(row['quarantined_legacy_operations']),
    rejected: intValue(row['rejected']),
    lastError: row['last_error']?.toString(),
  );

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
    pending: intValue(json['pending']),
    conflicts: intValue(json['conflicts']),
    lastSyncAt: parseDate(json['lastSyncAt'] ?? json['last_sync_at']),
    lastServerSeq: intValue(json['lastServerSeq'] ?? json['last_server_seq']),
    backendConfigured: boolValue(
      json['backendConfigured'] ?? json['backend_configured'],
    ),
    deviceRevoked: boolValue(json['deviceRevoked'] ?? json['device_revoked']),
    quarantinedLegacyOperations: intValue(
      json['quarantinedLegacyOperations'] ??
          json['quarantined_legacy_operations'],
    ),
    rejected: intValue(json['rejected']),
    lastError: (json['lastError'] ?? json['last_error'])?.toString(),
  );

  Map<String, Object?> toSql() => {
    'pending': pending,
    'conflicts': conflicts,
    'last_sync_at': lastSyncAt?.toUtc().toIso8601String(),
    'last_server_seq': lastServerSeq,
    'backend_configured': backendConfigured ? 1 : 0,
    'device_revoked': deviceRevoked ? 1 : 0,
    'quarantined_legacy_operations': quarantinedLegacyOperations,
    'rejected': rejected,
    'last_error': lastError,
  };

  Map<String, dynamic> toJson() => {
    'pending': pending,
    'conflicts': conflicts,
    'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
    'lastServerSeq': lastServerSeq,
    'backendConfigured': backendConfigured,
    'deviceRevoked': deviceRevoked,
    'quarantinedLegacyOperations': quarantinedLegacyOperations,
    'rejected': rejected,
    'lastError': lastError,
  };

  SyncStatus copyWith({
    Object? pending = unset,
    Object? conflicts = unset,
    Object? lastSyncAt = unset,
    Object? lastServerSeq = unset,
    Object? backendConfigured = unset,
    Object? deviceRevoked = unset,
    Object? quarantinedLegacyOperations = unset,
    Object? rejected = unset,
    Object? lastError = unset,
  }) {
    return SyncStatus(
      pending: pending is Unset ? this.pending : pending as int,
      conflicts: conflicts is Unset ? this.conflicts : conflicts as int,
      lastSyncAt:
          lastSyncAt is Unset ? this.lastSyncAt : lastSyncAt as DateTime?,
      lastServerSeq:
          lastServerSeq is Unset ? this.lastServerSeq : lastServerSeq as int,
      backendConfigured:
          backendConfigured is Unset
              ? this.backendConfigured
              : backendConfigured as bool,
      deviceRevoked:
          deviceRevoked is Unset ? this.deviceRevoked : deviceRevoked as bool,
      quarantinedLegacyOperations:
          quarantinedLegacyOperations is Unset
              ? this.quarantinedLegacyOperations
              : quarantinedLegacyOperations as int,
      rejected: rejected is Unset ? this.rejected : rejected as int,
      lastError: lastError is Unset ? this.lastError : lastError as String?,
    );
  }
}
