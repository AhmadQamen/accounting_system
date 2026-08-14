import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BarcodeReader {
  String _buffer = '';

  bool isEnabled = false;

  void Function(String barcode)? onBarcodeSubmit;

  // أقل طول يعتبر باركود
  static const int _minBarcodeLength = 6;

  // أقصى زمن بين حرفين (بالميلي ثانية)
  static const int _maxGapMs = 50;

  DateTime? _lastKeyTime;

  void enable() {
    isEnabled = true;
  }

  void disable() {
    isEnabled = false;
    reset();
  }

  void reset() {
    _buffer = '';
    _lastKeyTime = null;
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (!isEnabled || onBarcodeSubmit == null) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent || event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();

    // إذا توقف المستخدم فترة طويلة نعتبر أنه بدأ إدخال جديد
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!).inMilliseconds > _maxGapMs) {
      _buffer = '';
    }

    _lastKeyTime = now;

    // انتهاء القراءة
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_buffer.length < _minBarcodeLength) {
        reset();
        return KeyEventResult.ignored;
      }

      final barcode = _buffer;
      reset();

      onBarcodeSubmit?.call(barcode);

      return KeyEventResult.handled;
    }

    final character = event.character;

    if (character == null || character.isEmpty) {
      return KeyEventResult.ignored;
    }
    final isAllowed = RegExp(r'[0-9]').hasMatch(character);

    if (!isAllowed) {
      return KeyEventResult.ignored;
    }
    if (character.runes.length != 1) {
      return KeyEventResult.ignored;
    }

    final code = character.runes.first;

    final isPrintable =
        (code >= 0x20 && code <= 0x7E) || (code >= 0x0600 && code <= 0x06FF);

    if (!isPrintable) {
      return KeyEventResult.ignored;
    }

    _buffer += character;

    return KeyEventResult.handled;
  }
}
