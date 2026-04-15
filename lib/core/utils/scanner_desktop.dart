import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BarcodeScannerListener extends StatefulWidget {
  final Widget child;
  final void Function(String barcode) onBarcode;

  const BarcodeScannerListener({
    super.key,
    required this.child,
    required this.onBarcode,
  });

  @override
  State<BarcodeScannerListener> createState() => _BarcodeScannerListenerState();
}

class _BarcodeScannerListenerState extends State<BarcodeScannerListener> {
  final FocusNode _focusNode = FocusNode();
  String buffer = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.enter) {
        if (buffer.isNotEmpty) {
          widget.onBarcode(buffer);
          buffer = '';
        }
      } else {
        final label = key.keyLabel;
        if (label.isNotEmpty) {
          buffer += label;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKey,
      child: widget.child,
    );
  }
}
