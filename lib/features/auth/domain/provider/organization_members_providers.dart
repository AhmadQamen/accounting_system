import 'package:accounting_system/core/providers/app_providers.dart';
import 'package:accounting_system/features/auth/data/organization_members_repository.dart';
import 'package:accounting_system/features/auth/domain/models/organization_member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final organizationMembersRepositoryProvider =
    Provider<OrganizationMembersRepository>(
      (ref) => OrganizationMembersRepository(
        apiClient: ref.watch(apiClientProvider),
      ),
    );

final organizationMembersProvider = FutureProvider<OrganizationMembersSnapshot>(
  (ref) => ref.read(organizationMembersRepositoryProvider).load(),
);
