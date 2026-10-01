import 'package:flutter/material.dart';

/// ============================================
/// 🎨 DARK COLORS (Accounting — Ledger Teal)
/// ============================================
///
/// Brand palette:
/// - Ledger Blue #2E5077 — navigation and restrained surface accent
/// - Teal        #4DA1A9 — primary actions / selection / focus
/// - Mint        #79D7BE — positive states / soft accent
/// - Ivory       #F6F4F0 — typography / highlights
///
/// Compatibility note:
/// Legacy token names such as `purple` and `amber` are intentionally retained
/// so existing screens keep compiling without structural changes.
abstract final class AppColors {
  // ============================================
  // 🌑 SURFACES — calm navy base, with Ledger Blue reserved for elevation.
  // Keeping #2E5077 as the page background made the entire interface read as
  // one large blue block.  These shades give content and the background art
  // distinct visual planes while preserving the requested palette.
  // ============================================
  static const bgDeep = Color(0xFF07131F);
  static const bgPage = Color(0xFF0B1C2C);
  static const bgElevated = Color(0xFF122B42);

  static const border = Color(0x2665BFAE);
  static const borderPurple = Color(0x423D8D95);

  // ============================================
  // 🌊 PRIMARY — Teal (#4DA1A9)
  // ============================================
  static const purple = Color(0xFF3D8D95);
  static const purpleLight = Color(0xFF65BFAE);
  static const purpleTint = Color(0x383D8D95);
  static const purpleDim = Color(0x243D8D95);

  // ============================================
  // ✨ SECONDARY / ACCENT — Mint (#79D7BE)
  // ============================================
  // A warm warning hue stays distinct from success/primary states.
  static const amber = Color(0xFFE6C875);
  static const amberTint = Color(0x38E6C875);
  static const amberDim = Color(0x24E6C875);

  // ============================================
  // 🌿 INFORMATION / MINT
  // ============================================
  static const blue = Color(0xFF65BFAE);
  static const blueLight = Color(0xFF8CD2C4);
  static const blueDark = Color(0xFF3D8D95);
  static const blueDim = Color(0x2E65BFAE);

  // ============================================
  // 🟩 SUCCESS — Mint (#79D7BE)
  // ============================================
  static const success = Color(0xFF65BFAE);
  static const successDim = Color(0x2E65BFAE);

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
  static const muted = Color(0xFF193852);

  // ============================================
  // 📝 TEXT
  // ============================================
  static const textPrimary = Color(0xFFF6F4F0);
  static const textSecondary = Color(0xBFF6F4F0);
  static const textDim = Color(0x80F6F4F0);
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
