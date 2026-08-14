import 'package:accounting_system/core/sync/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine());
final syncStatusProvider = FutureProvider<Map<String, Object?>>((ref) async {
  return ref.read(syncEngineProvider).status();
});
