import 'package:flutter/material.dart';

/// ============================================
/// 🎨 DARK COLORS (Accounting — Coastal Meadow)
/// ============================================
///
/// Brand palette:
/// - Cerulean    #007991 — primary actions / selection / focus
/// - Seagrass    #439A86 — success / positive financial states
/// - Light Gold  #E9D985 — secondary accent / warning / highlights
/// - Space Indigo #222E50 — navigation / dark surfaces / typography anchor
///
/// Compatibility note:
/// Legacy token names such as `purple` and `amber` are intentionally retained
/// so existing screens keep compiling without structural changes.
abstract final class AppColors {
  // ============================================
  // 🌑 SURFACES — Space Indigo family
  // ============================================
  static const bgDeep = Color(0xFF18213A);
  static const bgPage = Color(0xFF222E50);
  static const bgElevated = Color(0xFF29385D);

  static const border = Color(0x335F8193);
  static const borderPurple = Color(0x66007991);

  // ============================================
  // 🌊 PRIMARY — Cerulean (#007991)
  // ============================================
  static const purple = Color(0xFF007991);
  static const purpleLight = Color(0xFF39A4B7);
  static const purpleTint = Color(0x38007991);
  static const purpleDim = Color(0x24007991);

  // ============================================
  // ✨ SECONDARY / ACCENT — Light Gold (#E9D985)
  // ============================================
  static const amber = Color(0xFFE9D985);
  static const amberTint = Color(0x38E9D985);
  static const amberDim = Color(0x24E9D985);

  // ============================================
  // 🌿 INFORMATION / SEAGRASS
  // ============================================
  static const blue = Color(0xFF439A86);
  static const blueLight = Color(0xFF76BBAA);
  static const blueDark = Color(0xFF2F7566);
  static const blueDim = Color(0x2E439A86);

  // ============================================
  // 🟩 SUCCESS — Seagrass (#439A86)
  // ============================================
  static const success = Color(0xFF439A86);
  static const successDim = Color(0x2E439A86);

  // ============================================
  // 🔴 ERROR — kept distinct from brand palette
  // ============================================
  static const error = Color(0xFFFF7A7A);
  static const errorLight = Color(0xFFFFA0A0);
  static const errorDark = Color(0xFFD85B65);
  static const errorDim = Color(0x24FF7A7A);

  // ============================================
  // ⬜ MUTED
  // ============================================
  static const muted = Color(0xFF314165);

  // ============================================
  // 📝 TEXT
  // ============================================
  static const textPrimary = Color(0xFFF8FAF4);
  static const textSecondary = Color(0xBFF8FAF4);
  static const textDim = Color(0x80F8FAF4);
}

/// ============================================
/// 🎨 LIGHT COLORS (Accounting — Coastal Meadow)
/// ============================================
abstract final class AppLightColors {
  // ============================================
  // ☀️ SURFACES — sea-glass neutrals
  // ============================================
  static const bgDeep = Color(0xFFEDF4F1);
  static const bgPage = Color(0xFFF7FAF8);
  static const bgElevated = Color(0xFFFFFFFF);

  static const border = Color(0xFFD5E2DE);
  static const borderPurple = Color(0x52007991);

  // ============================================
  // 🌊 PRIMARY — Cerulean (#007991)
  // ============================================
  static const purple = Color(0xFF007991);
  static const purpleLight = Color(0xFF36A1B4);
  static const purpleTint = Color(0xFFE1F2F3);
  static const purpleDim = Color(0x26007991);

  // ============================================
  // ✨ SECONDARY / ACCENT — Light Gold (#E9D985)
  // ============================================
  static const amber = Color(0xFFE9D985);
  static const amberTint = Color(0xFFFAF6DC);
  static const amberDim = Color(0x45E9D985);

  // ============================================
  // 🌿 INFORMATION / SEAGRASS (#439A86)
  // ============================================
  static const blue = Color(0xFF439A86);
  static const blueLight = Color(0xFF6FB5A4);
  static const blueDark = Color(0xFF2D7465);
  static const blueDim = Color(0x24439A86);

  // ============================================
  // 🟩 SUCCESS — Seagrass
  // ============================================
  static const success = Color(0xFF439A86);
  static const successDim = Color(0x24439A86);

  // ============================================
  // 🔴 ERROR
  // ============================================
  static const error = Color(0xFFD94F5C);
  static const errorLight = Color(0xFFED7A84);
  static const errorDark = Color(0xFFB83B48);
  static const errorDim = Color(0x24D94F5C);

  // ============================================
  // ⬜ MUTED
  // ============================================
  static const muted = Color(0xFFEDF3F1);

  // ============================================
  // 📝 TEXT — Space Indigo (#222E50)
  // ============================================
  static const textPri = Color(0xFF222E50);
  static const textSec = Color(0xB3222E50);
  static const textDim = Color(0x73222E50);
}
