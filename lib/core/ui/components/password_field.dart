import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final TextEditingController? confirmController;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'كلمة المرور',
    this.textInputAction,
    this.validator,
    this.confirmController,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  static String? defaultValidator(String? v, String label) {
    if (v == null || v.isEmpty) return 'يرجى إدخال $label';
    if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return TextFormField(
      controller: widget.controller,
      textAlign: TextAlign.right,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(Icons.lock_outline_rounded, color: colors.purple),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: colors.textSecondary,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator ?? (v) => defaultValidator(v, widget.label),
    );
  }
}
