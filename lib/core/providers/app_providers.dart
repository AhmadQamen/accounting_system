import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/network/dio_factory.dart';
import 'package:accounting_system/core/shortcuts/keyboard_shortcut_service.dart';
import 'package:accounting_system/features/auth/data/auth_session_manager.dart';
import 'package:accounting_system/features/auth/data/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../extensions/network_checker.dart';
import '../utils/api_client.dart';

final globalContainer = ProviderContainer();
final networkInfoProvider = Provider<NetworkInfo>((ref) => NetworkInfoImpl());

final dioProvider = Provider<Dio>((ref) => createAppDio());

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final authSessionManagerProvider = Provider<AuthSessionManager>(
  (ref) => AuthSessionManager(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(authSessionManagerProvider);
  return ApiClient(
    dio: ref.watch(dioProvider),
    getAccessToken: session.readAccessToken,
    refreshSession: session.refreshSession,
    onSessionExpired: session.expireSession,
  );
});

final appInitializerProvider = FutureProvider<void>((ref) async {
  await AppDatabase.instance.database;
  await KeyboardShortcutService.instance.insertDefaults();
  timeago.setLocaleMessages('ar', timeago.ArMessages());
});
