import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/errors/exceptions.dart';
import 'package:accounting_system/core/network/api_endpoints.dart';
import 'package:accounting_system/core/utils/api_client.dart';
import 'package:accounting_system/features/auth/domain/models/organization_member.dart';
import 'package:sqflite/sqflite.dart';

class OrganizationMembersRepository {
  OrganizationMembersRepository({
    required ApiClient apiClient,
    AppDatabase? database,
    Future<LocalContext> Function()? contextProvider,
  }) : _apiClient = apiClient,
       _databaseProvider = (() => (database ?? AppDatabase.instance).database),
       _contextProvider =
           contextProvider ?? (() => LocalContextService.instance.current);

  final ApiClient _apiClient;
  final Future<Database> Function() _databaseProvider;
  final Future<LocalContext> Function() _contextProvider;

  Future<OrganizationMembersSnapshot> load({bool refresh = true}) async {
    final context = await _contextProvider();
    final db = await _databaseProvider();
    final cached = await _readCached(db, context.entityId);
    if (!refresh) return cached;
    try {
      final members = await _apiClient.get<List<OrganizationMember>>(
        url: ApiEndpoints.organizationMembers(context.entityId),
        parseResponse: (data) {
          final json = Map<String, dynamic>.from(data as Map);
          final responseEntityId = json['entityId']?.toString();
          if (responseEntityId != context.entityId) {
            throw const FormatException(
              'استجابة أعضاء المؤسسة لا تطابق المؤسسة المختارة.',
            );
          }
          final rows = json['members'];
          if (rows is! List)
            throw const FormatException('استجابة الأعضاء غير صالحة.');
          return rows
              .whereType<Map>()
              .map(
                (row) =>
                    OrganizationMember.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(growable: false);
        },
      );
      final refreshedAt = DateTime.now().toUtc();
      await _replaceCache(db, context.entityId, members, refreshedAt);
      return OrganizationMembersSnapshot(
        members: members,
        isCached: false,
        refreshedAt: refreshedAt,
      );
    } on NetworkException {
      if (cached.members.isNotEmpty) return cached;
      rethrow;
    } on ServerException {
      if (cached.members.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<OrganizationMembersSnapshot> _readCached(
    Database db,
    String entityId,
  ) async {
    final rows = await db.query(
      'organization_members',
      where: 'entity_id=?',
      whereArgs: [entityId],
      orderBy: 'name COLLATE NOCASE, email COLLATE NOCASE',
    );
    final refreshedAt =
        rows.isEmpty
            ? null
            : DateTime.tryParse(rows.first['refreshed_at']?.toString() ?? '');
    return OrganizationMembersSnapshot(
      members: rows
          .map(
            (row) => OrganizationMember(
              membershipId: row['membership_id']!.toString(),
              userId: row['user_id']!.toString(),
              name: row['name']!.toString(),
              email: row['email']!.toString(),
              role: row['role']!.toString(),
            ),
          )
          .toList(growable: false),
      isCached: true,
      refreshedAt: refreshedAt,
    );
  }

  Future<void> _replaceCache(
    Database db,
    String entityId,
    List<OrganizationMember> members,
    DateTime refreshedAt,
  ) => db.transaction((txn) async {
    await txn.delete(
      'organization_members',
      where: 'entity_id=?',
      whereArgs: [entityId],
    );
    final stamp = refreshedAt.toIso8601String();
    for (final member in members) {
      await txn.insert('organization_members', {
        'entity_id': entityId,
        'membership_id': member.membershipId,
        'user_id': member.userId,
        'name': member.name,
        'email': member.email,
        'role': member.role,
        'refreshed_at': stamp,
      });
    }
  });
}
