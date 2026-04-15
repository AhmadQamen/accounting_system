import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CustomDialog {
  static Future<bool> showDeleteDialog({
    required BuildContext context,
    String? content,
  }) async {
    return await showDialogu(
      context: context,
      title: "تحذير",
      text: content ?? "هل أنت متأكد من الحذف؟",
    );
  }

  static Future<bool> showDialogu({
    required BuildContext context,
    required String title,
    required String text,
  }) async {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.warning_2, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'تراجع',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            child: Text(
                              'تأكيد',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  static Future<T?> showDialogg<T>({
    required BuildContext context,
    required Widget widget,
  }) async {
    return await showDialog<T?>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 600, maxWidth: 600),
          child: widget,
        ),
      ),
    );
  }
}
