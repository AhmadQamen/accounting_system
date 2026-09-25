import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/data/device_key_storage.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:accounting_system/features/auth/domain/models/organization_activation.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OrganizationContextCoordinator implements OrganizationActivator {
  OrganizationContextCoordinator({
    required ApiClient apiClient,
    required DeviceKeyStorage deviceKeyStorage,
    LocalContextService? localContextService,
    Future<PackageInfo> Function()? packageInfoLoader,
    String? platform,
  }) : _apiClient = apiClient,
       _deviceKeyStorage = deviceKeyStorage,
       _localContextService =
           localContextService ?? LocalContextService.instance,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _platform = platform ?? defaultTargetPlatform.name;

  final ApiClient _apiClient;
  final DeviceKeyStorage _deviceKeyStorage;
  final LocalContextService _localContextService;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final String _platform;

  @override
  Future<OrganizationActivationResult> activate({
    required AuthUser user,
    required Membership membership,
  }) async {
    final deviceKey = await _deviceKeyStorage.getOrCreate();
    final packageInfo = await _packageInfoLoader();
    final deviceName = '${user.name} - $_platform';
    final registration = await _apiClient.post<OrganizationActivationResult>(
      url: ApiEndpoints.registerDevice(membership.entityId),
      body: {
        'deviceKey': deviceKey,
        'name': deviceName,
        'platform': _platform,
        'appVersion': packageInfo.version,
      },
      parseResponse: (data) {
        final json = Map<String, dynamic>.from(data as Map);
        final deviceId = json['deviceId']?.toString() ?? '';
        if (deviceId.isEmpty) {
          throw const FormatException('Device registration has no deviceId.');
        }
        return OrganizationActivationResult(
          deviceId: deviceId,
          revoked: json['revoked'] == true,
        );
      },
    );

    try {
      await _localContextService.activateAuthenticatedContext(
        entityId: membership.entityId,
        entityName: membership.entityName,
        currencyCode: membership.currencyCode,
        timezone: membership.timezone,
        membershipId: membership.membershipId,
        role: membership.role,
        serverUserId: user.id,
        userName: user.name,
        userEmail: user.email,
        deviceId: registration.deviceId,
        deviceKey: deviceKey,
        deviceName: deviceName,
        platform: _platform,
        appVersion: packageInfo.version,
        deviceRevoked: registration.revoked,
      );
    } on LocalContextUnavailableException {
      if (!registration.revoked) rethrow;
    }
    return registration;
  }
}
