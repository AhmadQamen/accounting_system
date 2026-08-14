import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:flutter/material.dart';

class ModernSplashScreen extends StatelessWidget {
  const ModernSplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(Icons.account_balance_wallet_outlined,
                  size: 42, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Accounting System',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Offline First Accounting',
                style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 24),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}
