import 'package:flutter/material.dart';

class CustomSheet {
  static Future<T?> showMyBottomSheet<T>(
      BuildContext context, Widget Function(ScrollController) builder) async {
    return await showModalBottomSheet<T>(
      enableDrag: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => Scaffold(
          body: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: builder(controller)),
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
