import 'package:accounting_system/features/auth/domain/models/auth_models.dart';

class OrganizationActivationResult {
  const OrganizationActivationResult({
    required this.deviceId,
    required this.revoked,
  });

  final String deviceId;
  final bool revoked;
}

abstract interface class OrganizationActivator {
  Future<OrganizationActivationResult> activate({
    required AuthUser user,
    required Membership membership,
  });
}
