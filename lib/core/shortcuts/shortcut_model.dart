import 'package:flutter/services.dart';

import 'shortcut_action.dart';

class ShortcutModel {
  final ShortcutAction action;

  final LogicalKeyboardKey key;
  final String keyLabel;

  final bool ctrl;
  final bool shift;
  final bool alt;

  final String label;
  final String description;

  const ShortcutModel({
    required this.action,
    required this.key,
    required this.keyLabel,
    required this.label,
    required this.description,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
  });

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'key_label': keyLabel,
    'ctrl': ctrl ? 1 : 0,
    'shift': shift ? 1 : 0,
    'alt': alt ? 1 : 0,
  };

  factory ShortcutModel.fromJson(Map<String, dynamic> json) {
    final action = ShortcutAction.values.byName(json['action']);

    final defaultShortcut = defaultShortcuts.firstWhere(
      (e) => e.action == action,
    );

    return ShortcutModel(
      action: action,
      key: defaultShortcut.key,
      keyLabel: json['key_label'],
      label: defaultShortcut.label,
      description: defaultShortcut.description,
      ctrl: (json['ctrl'] ?? 0) == 1,
      shift: (json['shift'] ?? 0) == 1,
      alt: (json['alt'] ?? 0) == 1,
    );
  }

  ShortcutModel copyWith({
    LogicalKeyboardKey? key,
    String? keyLabel,
    bool? ctrl,
    bool? shift,
    bool? alt,
  }) {
    return ShortcutModel(
      action: action,
      key: key ?? this.key,
      keyLabel: keyLabel ?? this.keyLabel,
      ctrl: ctrl ?? this.ctrl,
      shift: shift ?? this.shift,
      alt: alt ?? this.alt,
      label: label,
      description: description,
    );
  }

  String get displayLabel {
    final parts = <String>[];

    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');

    parts.add(keyLabel);

    return parts.join(' + ');
  }
}

final defaultShortcuts = [
  ShortcutModel(
    action: ShortcutAction.newSale,
    key: LogicalKeyboardKey.f1,
    keyLabel: 'F1',
    label: ShortcutAction.newSale.label,
    description: ShortcutAction.newSale.description,
  ),
  ShortcutModel(
    action: ShortcutAction.newReturn,
    key: LogicalKeyboardKey.f2,
    keyLabel: 'F2',
    label: ShortcutAction.newReturn.label,
    description: ShortcutAction.newReturn.description,
  ),
  ShortcutModel(
    action: ShortcutAction.newPurchase,
    key: LogicalKeyboardKey.f3,
    keyLabel: 'F3',
    label: ShortcutAction.newPurchase.label,
    description: ShortcutAction.newPurchase.description,
  ),
  ShortcutModel(
    action: ShortcutAction.newWaste,
    key: LogicalKeyboardKey.f4,
    keyLabel: 'F4',
    label: ShortcutAction.newWaste.label,
    description: ShortcutAction.newWaste.description,
  ),
  ShortcutModel(
    action: ShortcutAction.sync,
    key: LogicalKeyboardKey.f5,
    keyLabel: 'F5',
    label: ShortcutAction.sync.label,
    description: ShortcutAction.sync.description,
  ),
  ShortcutModel(
    action: ShortcutAction.viewSales,
    key: LogicalKeyboardKey.f6,
    keyLabel: 'F6',
    label: ShortcutAction.viewSales.label,
    description: ShortcutAction.viewSales.description,
  ),
  ShortcutModel(
    action: ShortcutAction.viewReturns,
    key: LogicalKeyboardKey.f7,
    keyLabel: 'F7',
    label: ShortcutAction.viewReturns.label,
    description: ShortcutAction.viewReturns.description,
  ),
  ShortcutModel(
    action: ShortcutAction.viewMovements,
    key: LogicalKeyboardKey.f8,
    keyLabel: 'F8',
    label: ShortcutAction.viewMovements.label,
    description: ShortcutAction.viewMovements.description,
  ),
  ShortcutModel(
    action: ShortcutAction.viewInventory,
    key: LogicalKeyboardKey.f9,
    keyLabel: 'F9',
    label: ShortcutAction.viewInventory.label,
    description: ShortcutAction.viewInventory.description,
  ),
  ShortcutModel(
    action: ShortcutAction.viewSuppliers,
    key: LogicalKeyboardKey.f10,
    keyLabel: 'F10',
    label: ShortcutAction.viewSuppliers.label,
    description: ShortcutAction.viewSuppliers.description,
  ),
  ShortcutModel(
    action: ShortcutAction.settings,
    key: LogicalKeyboardKey.f11,
    keyLabel: 'F11',
    label: ShortcutAction.settings.label,
    description: ShortcutAction.settings.description,
  ),
  ShortcutModel(
    action: ShortcutAction.medicineRef,
    key: LogicalKeyboardKey.f12,
    keyLabel: 'F12',
    label: ShortcutAction.medicineRef.label,
    description: ShortcutAction.medicineRef.description,
  ),
];
