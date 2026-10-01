import 'dart:convert';
import 'package:flutter/services.dart';

class InvoiceShortcutLine {
  const InvoiceShortcutLine({required this.productId, required this.quantity});
  final String productId;
  final double quantity;
  Map<String, Object> toJson() => {'productId': productId, 'quantity': quantity};
  factory InvoiceShortcutLine.fromJson(Map<String, dynamic> json) => InvoiceShortcutLine(
    productId: json['productId'] as String, quantity: (json['quantity'] as num).toDouble());
}

class InvoiceShortcutMacro {
  const InvoiceShortcutMacro({required this.id, required this.name, required this.key, required this.keyLabel, required this.lines, this.ctrl = false, this.shift = false, this.alt = false});
  final String id, name, keyLabel;
  final LogicalKeyboardKey key;
  final List<InvoiceShortcutLine> lines;
  final bool ctrl, shift, alt;
  String get displayLabel => [if (ctrl) 'Ctrl', if (shift) 'Shift', if (alt) 'Alt', keyLabel].join(' + ');
  Map<String, Object> toSql() => {'id': id, 'name': name, 'key_id': key.keyId, 'key_label': keyLabel, 'ctrl': ctrl ? 1 : 0, 'shift': shift ? 1 : 0, 'alt': alt ? 1 : 0, 'lines_json': jsonEncode(lines.map((e) => e.toJson()).toList()), 'created_at': DateTime.now().toUtc().toIso8601String(), 'updated_at': DateTime.now().toUtc().toIso8601String()};
  factory InvoiceShortcutMacro.fromSql(Map<String, Object?> row) => InvoiceShortcutMacro(
    id: row['id'] as String, name: row['name'] as String, key: LogicalKeyboardKey(row['key_id'] as int), keyLabel: row['key_label'] as String,
    ctrl: row['ctrl'] == 1, shift: row['shift'] == 1, alt: row['alt'] == 1,
    lines: (jsonDecode(row['lines_json'] as String) as List).map((e) => InvoiceShortcutLine.fromJson(Map<String, dynamic>.from(e as Map))).toList());
}
