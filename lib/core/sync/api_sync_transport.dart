import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:accounting_system/core/utils/api_client.dart';

class ApiSyncTransport implements SyncTransport {
  const ApiSyncTransport(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<SyncBootstrap> bootstrap({
    required String entityId,
    required String deviceId,
  }) {
    return _apiClient.get<SyncBootstrap>(
      url: ApiEndpoints.syncBootstrap,
      queryParams: {'entityId': entityId, 'deviceId': deviceId},
      parseResponse: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return SyncBootstrap(
          serverSequence: (json['serverSequence'] as num).toInt(),
          snapshotVersion: (json['snapshotVersion'] as num?)?.toInt() ?? 1,
          snapshot: Map<String, dynamic>.from(
            json['snapshot'] as Map? ?? const {},
          ),
        );
      },
    );
  }

  @override
  Future<List<SyncPushResult>> push({
    required String entityId,
    required String deviceId,
    required List<DomainEvent> events,
  }) {
    return _apiClient.post<List<SyncPushResult>>(
      url: ApiEndpoints.syncPush,
      body: {
        'entityId': entityId,
        'deviceId': deviceId,
        'events': events.map((event) => event.toPushJson()).toList(),
      },
      parseResponse: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        final results = json['results'] as List? ?? const [];
        return results
            .whereType<Map>()
            .map(
              (item) =>
                  SyncPushResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<SyncPullBatch> pull({
    required String entityId,
    required String deviceId,
    required int afterServerSequence,
    int limit = 500,
  }) {
    return _apiClient.get<SyncPullBatch>(
      url: ApiEndpoints.syncPull,
      queryParams: {
        'entityId': entityId,
        'deviceId': deviceId,
        'after': afterServerSequence,
        'limit': limit,
      },
      parseResponse: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        final events = json['events'] as List? ?? const [];
        return SyncPullBatch(
          events: events
              .whereType<Map>()
              .map(
                (item) => DomainEvent.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false),
          lastServerSequence:
              (json['lastServerSequence'] as num?)?.toInt() ??
              afterServerSequence,
          hasMore: json['hasMore'] == true,
        );
      },
    );
  }

  @override
  Future<void> ack({
    required String entityId,
    required String deviceId,
    required int serverSequence,
  }) {
    return _apiClient.post<void>(
      url: ApiEndpoints.syncAck,
      body: {
        'entityId': entityId,
        'deviceId': deviceId,
        'serverSequence': serverSequence,
      },
      parseResponse: (_) {},
    );
  }

  @override
  Future<RemoteSyncStatus> status({
    required String entityId,
    required String deviceId,
  }) {
    return _apiClient.get<RemoteSyncStatus>(
      url: ApiEndpoints.syncStatus,
      queryParams: {'entityId': entityId, 'deviceId': deviceId},
      parseResponse: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        return RemoteSyncStatus(
          deviceRevoked: json['deviceRevoked'] == true,
          latestServerSequence:
              (json['latestServerSequence'] as num?)?.toInt() ?? 0,
          lastPulledSequence:
              (json['lastPulledSequence'] as num?)?.toInt() ?? 0,
          serverTime: json['serverTime']?.toString(),
        );
      },
    );
  }
}
