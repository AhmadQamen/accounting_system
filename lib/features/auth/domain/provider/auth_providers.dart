import 'dart:async';

import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/features/auth/data/auth_repository.dart';
import 'package:accounting_system/features/auth/data/device_key_storage.dart';
import 'package:accounting_system/features/auth/data/organization_context_coordinator.dart';
import 'package:accounting_system/features/auth/domain/models/organization_activation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'auth_notifier.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    dio: ref.watch(dioProvider),
    apiClient: ref.watch(apiClientProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
  );
});

final deviceKeyStorageProvider = Provider<DeviceKeyStorage>(
  (ref) => SecureDeviceKeyStorage(),
);

final organizationActivatorProvider = Provider<OrganizationActivator>((ref) {
  return OrganizationContextCoordinator(
    apiClient: ref.watch(apiClientProvider),
    deviceKeyStorage: ref.watch(deviceKeyStorageProvider),
  );
});

final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final notifier = AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
    organizationActivator: ref.watch(organizationActivatorProvider),
  );
  unawaited(notifier.initialize());
  return notifier;
});
