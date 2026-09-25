import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authNotifierProvider)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final wide = MediaQuery.sizeOf(context).width >= 920;

    return MyScaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 48 : 22,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child:
                    wide
                        ? Row(
                          children: [
                            const Expanded(child: _LoginStory()),
                            const SizedBox(width: 56),
                            SizedBox(
                              width: responsiveDialogWidth(context, 440),
                              child: _LoginCard(
                                loading: auth.isLoggingIn,
                                formKey: _formKey,
                                emailController: _emailController,
                                passwordController: _passwordController,
                                errorMessage: auth.errorMessage,
                                onLogin: _submit,
                              ),
                            ),
                          ],
                        )
                        : _LoginCard(
                          loading: auth.isLoggingIn,
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          errorMessage: auth.errorMessage,
                          onLogin: _submit,
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginStory extends StatelessWidget {
  const _LoginStory();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedEntrance(
      offset: const Offset(.04, 0),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: .24),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: colors.onPrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'إدارة مالية\nواضحة من أول نظرة.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 1.18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'مبيعات، مشتريات، مخزون وصناديق في مساحة واحدة هادئة وسريعة — وتبقى أعمالك مستمرة حتى بدون اتصال.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.8,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FeatureChip(
                  icon: Icons.cloud_off_outlined,
                  label: 'Offline‑First',
                ),
                _FeatureChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'مخزون لحظي',
                ),
                _FeatureChip(
                  icon: Icons.insights_rounded,
                  label: 'تقارير واضحة',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: .82),
        border: Border.all(color: context.colors.border.withValues(alpha: .75)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final bool loading;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String? errorMessage;
  final Future<void> Function() onLogin;
  const _LoginCard({
    required this.loading,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.errorMessage,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedEntrance(
      delay: const Duration(milliseconds: 110),
      offset: const Offset(0, .035),
      child: PremiumPanel(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryTint,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً بعودتك',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'الدخول الآمن إلى مساحة العمل',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty || !email.contains('@')) {
                    return 'أدخل بريدًا إلكترونيًا صالحًا';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: loading ? null : (_) => onLogin(),
                validator:
                    (value) =>
                        (value?.isEmpty ?? true) ? 'أدخل كلمة المرور' : null,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: loading ? null : onLogin,
                  icon:
                      loading
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.onPrimary,
                            ),
                          )
                          : const Icon(Icons.arrow_forward_rounded),
                  label: Text(loading ? 'جاري الدخول…' : 'تسجيل الدخول'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: colors.secondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'اتصال مشفّر، وتُحفظ بيانات الجلسة داخل التخزين الآمن للجهاز.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
