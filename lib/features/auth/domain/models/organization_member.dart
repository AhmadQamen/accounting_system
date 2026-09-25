class OrganizationMember {
  const OrganizationMember({
    required this.membershipId,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String membershipId;
  final String userId;
  final String name;
  final String email;
  final String role;

  factory OrganizationMember.fromJson(Map<String, dynamic> json) =>
      OrganizationMember(
        membershipId: json['membershipId']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
      );
}

class OrganizationMembersSnapshot {
  const OrganizationMembersSnapshot({
    required this.members,
    required this.isCached,
    this.refreshedAt,
  });

  final List<OrganizationMember> members;
  final bool isCached;
  final DateTime? refreshedAt;
}
