import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/sync/api_sync_transport.dart';
import 'package:accounting_system/core/sync/sync_engine.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/sync/sync_transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final syncTransportProvider = Provider<SyncTransport>(
  (ref) => ApiSyncTransport(ref.watch(apiClientProvider)),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    transport: ref.watch(syncTransportProvider),
    onStageChanged: (stage) => ref.read(syncStageProvider.notifier).set(stage),
  ),
);
final syncStageProvider = StateNotifierProvider<SyncStageNotifier, SyncStage>(
  (ref) => SyncStageNotifier(),
);

class SyncStageNotifier extends StateNotifier<SyncStage> {
  SyncStageNotifier() : super(SyncStage.idle);
  void set(SyncStage value) => state = value;
}

final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.read(syncEngineProvider).status();
});
final syncOperationsProvider = FutureProvider<List<SyncOperation>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.read(syncEngineProvider).operations();
});
