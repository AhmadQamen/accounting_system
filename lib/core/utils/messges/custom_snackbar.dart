import 'package:accounting_system/accounting_system.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CustomSnackBar {
  static void showSuccessSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _showCustomSnackbar(
      context,
      message: text,
      icon: Iconsax.tick_circle,
      color: Colors.green,
    );
  }

  static void showErrorSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _showCustomSnackbar(
      context,
      message: text,
      icon: Iconsax.close_circle,
      color: const Color.fromARGB(255, 158, 36, 27),
    );
  }

  static void showWarningSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _showCustomSnackbar(
      context,
      message: text,
      icon: Iconsax.warning_2,
      color: const Color.fromARGB(255, 161, 97, 1),
    );
  }

  static void showInfoSnackbar(String text) {
    final context = AccountingSystem.navigatorKey.currentContext;
    if (context == null) return;
    _showCustomSnackbar(
      context,
      message: text,
      icon: Iconsax.info_circle,
      color: const Color.fromARGB(255, 17, 94, 157),
    );
  }

  static void _showCustomSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.fixed,
        dismissDirection: DismissDirection.horizontal,
        padding: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
