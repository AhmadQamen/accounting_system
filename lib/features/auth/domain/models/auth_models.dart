class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken']?.toString();
    final refreshToken = json['refreshToken']?.toString();
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw const FormatException('Invalid authentication response.');
    }
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Map<String, String> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

class Membership {
  const Membership({
    required this.membershipId,
    required this.entityId,
    required this.entityName,
    required this.currencyCode,
    required this.timezone,
    required this.role,
  });

  final String membershipId;
  final String entityId;
  final String entityName;
  final String currencyCode;
  final String timezone;
  final String role;

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    membershipId: json['membershipId']?.toString() ?? '',
    entityId: json['entityId']?.toString() ?? '',
    entityName: json['entityName']?.toString() ?? '',
    currencyCode: json['currencyCode']?.toString() ?? '',
    timezone: json['timezone']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
  );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.memberships,
  });

  final String id;
  final String name;
  final String email;
  final List<Membership> memberships;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawMemberships = json['memberships'];
    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      memberships:
          rawMemberships is List
              ? rawMemberships
                  .whereType<Map>()
                  .map(
                    (item) =>
                        Membership.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList(growable: false)
              : const [],
    );
  }
}
