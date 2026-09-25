import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/auth/domain/provider/organization_members_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class OrganizationMembersScreen extends ConsumerWidget {
  const OrganizationMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(organizationMembersProvider);
    return MyScaffold(
      appBar: const BlurAppBar(title: Text('أعضاء المؤسسة')),
      body: PremiumPage(
        maxWidth: 980,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageIntro(
              eyebrow: 'ORGANIZATION',
              title: 'أعضاء المؤسسة',
              subtitle: 'الحسابات الفعّالة ضمن المؤسسة المختارة.',
              icon: Iconsax.profile_2user,
            ),
            const SizedBox(height: 18),
            members.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, _) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => CustomSnackBar.showErrorSnackbar('$error'),
                );
                return EmptyState(
                  icon: Iconsax.warning_2,
                  title: 'تعذر تحميل الأعضاء',
                  subtitle: '$error',
                );
              },
              data:
                  (snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (snapshot.isCached)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StatusPill(
                            label: 'عرض آخر نسخة محلية',
                            color: context.colors.warning,
                            icon: Iconsax.cloud_minus,
                          ),
                        ),
                      snapshot.members.isEmpty
                          ? const EmptyState(
                            icon: Iconsax.profile_2user,
                            title: 'لا يوجد أعضاء فعّالون',
                            subtitle: 'لا توجد عضويات فعّالة في هذه المؤسسة.',
                          )
                          : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.members.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final member = snapshot.members[index];
                              return PremiumPanel(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(
                                        member.name.isEmpty
                                            ? '?'
                                            : member.name[0].toUpperCase(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            member.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            member.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusPill(
                                      label: _roleLabel(member.role),
                                      color: context.colors.primary,
                                      icon: Iconsax.user_tag,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String role) =>
    const {
      'OWNER': 'مالك',
      'ADMIN': 'مدير',
      'ACCOUNTANT': 'محاسب',
      'CASHIER': 'أمين صندوق',
      'VIEWER': 'مشاهد',
    }[role] ??
    role;
