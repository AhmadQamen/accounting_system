import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/core/sync/api_sync_transport.dart';
import 'package:accounting_system/core/sync/sync_engine.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncTransportProvider = Provider<SyncTransport>(
  (ref) => ApiSyncTransport(ref.watch(apiClientProvider)),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(transport: ref.watch(syncTransportProvider)),
);
final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  return ref.read(syncEngineProvider).status();
});
