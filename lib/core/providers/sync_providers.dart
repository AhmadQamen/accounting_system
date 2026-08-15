import 'package:accounting_system/core/sync/sync_engine.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine());
final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  return ref.read(syncEngineProvider).status();
});
