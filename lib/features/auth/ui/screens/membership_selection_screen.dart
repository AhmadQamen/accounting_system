import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/auth/domain/models/auth_models.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_notifier.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MembershipSelectionScreen extends ConsumerWidget {
  const MembershipSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final hasMemberships = auth.memberships.isNotEmpty;
    final registering = auth.status == AuthStatus.registeringDevice;
    final revoked = auth.status == AuthStatus.deviceRevoked;

    return MyScaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: PremiumPanel(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        hasMemberships
                            ? Icons.domain_rounded
                            : Icons.domain_disabled_rounded,
                        color: context.colors.primary,
                        size: 42,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        revoked
                            ? 'هذا الجهاز ملغى'
                            : registering
                            ? 'جاري تسجيل الجهاز'
                            : hasMemberships
                            ? 'اختر المؤسسة'
                            : 'الحساب غير مربوط بمؤسسة',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        revoked
                            ? 'ألغت الإدارة صلاحية هذا الجهاز للمؤسسة المحددة. المزامنة متوقفة.'
                            : registering
                            ? 'يتم ربط الجهاز بالمؤسسة والتحقق من صلاحيته…'
                            : hasMemberships
                            ? 'مرحبًا ${auth.user?.name ?? ''}، اختر مساحة العمل التي تريد فتحها.'
                            : 'تواصل مع مسؤول النظام لإضافة حسابك إلى مؤسسة، ثم سجّل الدخول مجددًا.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                      if (registering) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (auth.errorMessage != null && !registering) ...[
                        const SizedBox(height: 16),
                        Text(
                          auth.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (hasMemberships && !registering) ...[
                        const SizedBox(height: 26),
                        ...auth.memberships.map(
                          (membership) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MembershipTile(
                              membership: membership,
                              onTap:
                                  () => ref
                                      .read(authNotifierProvider)
                                      .selectMembership(membership),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed:
                            auth.isLoggingOut
                                ? null
                                : () => ref.read(authNotifierProvider).logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          auth.isLoggingOut
                              ? 'جاري تسجيل الخروج…'
                              : 'تسجيل الخروج',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipTile extends StatelessWidget {
  const _MembershipTile({required this.membership, required this.onTap});

  final Membership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.primaryTint,
                foregroundColor: context.colors.primary,
                child: const Icon(Icons.business_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.entityName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${membership.role} • ${membership.currencyCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
