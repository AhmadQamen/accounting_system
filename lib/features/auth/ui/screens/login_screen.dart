<<<<<<< HEAD
import 'dart:io' show Platform;

import 'package:accounting_system/core/theme/app_theme_colors.dart';
import 'package:accounting_system/core/ui/components/app_logo_icon.dart';
import 'package:accounting_system/core/ui/components/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/ui/components/my_scaffold.dart';
import '../../domain/provider/auth_providers.dart';

/// Desktop breakpoint — matches the pattern used across Mandoobi/NerdX.
const double _kDesktopBreakpoint = 720;

bool get _isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController(text: "+963900000000");
  final _passwordController = TextEditingController(text: "admin1234");
  final _formKey = GlobalKey<FormState>();

  bool _rememberMe = true;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // final phone = _phoneController.text.trim();
    // final password = _passwordController.text;

    await ref.read(authNotifierProvider.notifier).login();

    // if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoggingIn;

    return MyScaffold(
      forceWindowsBackground: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;

          if (isDesktop) {
            return _DesktopLayout(
              colors: colors,
              controller: _controller,
              fade: _fade,
              slide: _slide,
              formKey: _formKey,
              phoneController: _phoneController,
              passwordController: _passwordController,
              isLoading: isLoading,
              rememberMe: _rememberMe,
              onRememberMeChanged: (v) => setState(() => _rememberMe = v),
              onLogin: _login,
            );
          }

          return _MobileLayout(
            colors: colors,
            controller: _controller,
            fade: _fade,
            slide: _slide,
            formKey: _formKey,
            phoneController: _phoneController,
            passwordController: _passwordController,
            isLoading: isLoading,
            rememberMe: _rememberMe,
            onRememberMeChanged: (v) => setState(() => _rememberMe = v),
            onLogin: _login,
          );
        },
      ),
    );
  }
}

/// ============================================
/// 📱 MOBILE / NARROW LAYOUT
/// ============================================
class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.colors,
    required this.controller,
    required this.fade,
    required this.slide,
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.isLoading,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onLogin,
  });

  final AppThemeColors colors;
  final AnimationController controller;
  final Animation<double> fade;
  final Animation<double> slide;
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, slide.value),
              child: Opacity(opacity: fade.value, child: child),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BrandLogo(colors: colors, size: 96, iconSize: 60),
                  const SizedBox(height: 20),
                  _BrandTitle(colors: colors, fontSize: 34),
                  const SizedBox(height: 6),
                  _BrandSubtitle(colors: colors),
                  const SizedBox(height: 32),
                  _AuthCard(
                    colors: colors,
                    child: _AuthFormFields(
                      colors: colors,
                      phoneController: phoneController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      rememberMe: rememberMe,
                      onRememberMeChanged: onRememberMeChanged,
                      onLogin: onLogin,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FooterHint(colors: colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================
/// 🖥️ DESKTOP / WINDOWS LAYOUT
/// Split screen: brand panel (right, RTL-first) + form panel (left)
/// ============================================
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.colors,
    required this.controller,
    required this.fade,
    required this.slide,
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.isLoading,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onLogin,
  });

  final AppThemeColors colors;
  final AnimationController controller;
  final Animation<double> fade;
  final Animation<double> slide;
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Branding panel
        Expanded(flex: 5, child: _BrandPanel(colors: colors)),
        // Form panel
        Expanded(
          flex: 4,
          child: ColoredBox(
            color: colors.bgPage,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, slide.value),
                      child: Opacity(opacity: fade.value, child: child),
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'تسجيل الدخول',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _BrandSubtitle(colors: colors),
                          const SizedBox(height: 32),
                          _AuthFormFields(
                            colors: colors,
                            phoneController: phoneController,
                            passwordController: passwordController,
                            isLoading: isLoading,
                            rememberMe: rememberMe,
                            onRememberMeChanged: onRememberMeChanged,
                            onLogin: onLogin,
                            dense: true,
                          ),
                          const SizedBox(height: 24),
                          _FooterHint(colors: colors),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Left/right brand showcase panel shown only on desktop widths.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.purple, colors.purpleLight],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative ambient blobs
          Positioned(
            top: -60,
            right: -40,
            child: _Blob(
              color: Colors.white.withValues(alpha: 0.08),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _Blob(
              color: Colors.white.withValues(alpha: 0.06),
              size: 280,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrandLogo(
                    colors: colors,
                    size: 108,
                    iconSize: 68,
                    onGradient: true,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'PharmaX',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'منصّة إدارة الصيدليات والمستودعات\nبإدارة ذكية وسريعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// ============================================
/// 🔁 SHARED PIECES
/// ============================================

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({
    required this.colors,
    required this.size,
    required this.iconSize,
    this.onGradient = false,
  });

  final AppThemeColors colors;
  final double size;
  final double iconSize;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onGradient
            ? Colors.white.withValues(alpha: 0.14)
            : colors.bgElevated,
        border: Border.all(
          color: onGradient
              ? Colors.white.withValues(alpha: 0.35)
              : colors.border,
          width: 1,
        ),
        boxShadow: onGradient
            ? null
            : [
                BoxShadow(
                  color: colors.purple.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: AppLogoIcon(
        width: iconSize,
        height: iconSize,
        colored: !onGradient,
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.colors, required this.fontSize});

  final AppThemeColors colors;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [colors.purple, colors.amber],
      ).createShader(bounds),
      child: Text(
        'PharmaX',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _BrandSubtitle extends StatelessWidget {
  const _BrandSubtitle({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      'أهلاً فيك، سجّل دخولك للمتابعة',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
    );
  }
}

class _FooterHint extends StatelessWidget {
  const _FooterHint({required this.colors});

  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      'PharmaX © ${DateTime.now().year} — جميع الحقوق محفوظة',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textDim,
      ),
    );
  }
}

/// Frosted / glass card wrapping the auth form fields (used on mobile only —
/// desktop places the fields directly on the form panel background).
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.colors, required this.child});

  final AppThemeColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Shared form fields used by both mobile (inside the glass card) and
/// desktop (directly on the panel).
class _AuthFormFields extends StatelessWidget {
  const _AuthFormFields({
    required this.colors,
    required this.phoneController,
    required this.passwordController,
    required this.isLoading,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onLogin,
    this.dense = false,
  });

  final AppThemeColors colors;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onLogin;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PhoneField(colors: colors, controller: phoneController),
        const SizedBox(height: 16),
        PasswordField(
          controller: passwordController,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _RememberMeCheckbox(
              colors: colors,
              value: rememberMe,
              onChanged: onRememberMeChanged,
            ),
            const Spacer(),
            _HoverTextButton(
              colors: colors,
              label: 'نسيت كلمة المرور؟',
              onPressed: isLoading ? null : () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PrimaryButton(
          colors: colors,
          label: 'تسجيل الدخول',
          isLoading: isLoading,
          onPressed: onLogin,
        ),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.colors, required this.controller});

  final AppThemeColors colors;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: 'رقم الهاتف',
        hintText: '09xxxxxxxx',
        prefixText: '+963 ',
        prefixIcon: Icon(Icons.phone_iphone_rounded, color: colors.purple),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'يرجى إدخال رقم الهاتف';
        return null;
      },
    );
  }
}

class _RememberMeCheckbox extends StatelessWidget {
  const _RememberMeCheckbox({
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final AppThemeColors colors;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'تذكرني',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text button with desktop mouse-hover feedback (matches Mandoobi pattern).
class _HoverTextButton extends StatefulWidget {
  const _HoverTextButton({
    required this.colors,
    required this.label,
    required this.onPressed,
  });

  final AppThemeColors colors;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_HoverTextButton> createState() => _HoverTextButtonState();
}

class _HoverTextButtonState extends State<_HoverTextButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.colors.purple;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _hovering ? 0.7 : 1,
          child: Text(
            widget.label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary gradient login button with press + hover feedback, works for
/// both touch (mobile) and mouse (Windows/desktop).
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.colors,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final AppThemeColors colors;
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final scale = _pressed
        ? 0.98
        : (_hovering && _isDesktopPlatform ? 1.01 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: widget.isLoading
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [colors.purple, colors.purpleLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.purple.withValues(
                    alpha: _hovering && _isDesktopPlatform ? 0.45 : 0.35,
                  ),
                  blurRadius: _hovering && _isDesktopPlatform ? 22 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
=======
import 'package:accounting_system/core/theme/theme_extension.dart';import 'package:accounting_system/features/auth/domain/provider/auth_providers.dart';import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';
class LoginScreen extends ConsumerWidget{const LoginScreen({super.key});@override Widget build(BuildContext context,WidgetRef ref){final auth=ref.watch(authNotifierProvider);return Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Card(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Container(width:72,height:72,decoration:BoxDecoration(color:context.colors.primary.withValues(alpha:.18),borderRadius:BorderRadius.circular(22)),child:Icon(Icons.account_balance_wallet_outlined,size:36,color:context.colors.primary)),const SizedBox(height:18),const Text('Accounting System',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text('محاسب بسيط • Offline First',style:TextStyle(color:context.colors.textSecondary)),const SizedBox(height:28),const TextField(decoration:InputDecoration(labelText:'المستخدم'),controller:null),const SizedBox(height:12),const TextField(obscureText:true,decoration:InputDecoration(labelText:'كلمة المرور')),const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:auth.isLoggingIn?null:()=>ref.read(authNotifierProvider).login(),child:auth.isLoggingIn?const CircularProgressIndicator():const Text('دخول محلي'))),const SizedBox(height:12),Text('هذه النسخة تعمل محلياً. اربط Backend المصادقة لاحقاً للمزامنة متعددة الأجهزة.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall)])))))));}}
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
