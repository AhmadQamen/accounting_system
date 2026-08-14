import 'package:flutter/material.dart';

/// ============================================
/// 🎨 DARK COLORS (Accounting — Sand & Sage)
/// ============================================
///
/// ملاحظة توافقية:
/// تم الإبقاء على أسماء tokens القديمة مثل purple / amber حتى لا تتأثر
/// بقية ملفات المشروع الحالية، لكن دلالتها البصرية أصبحت:
/// purple => Primary Sand  (#D4A373)
/// amber  => Secondary Sage (#CCD5AE)
abstract final class AppColors {
  // ============================================
  // 🌑 SURFACES
  // ============================================
  static const bgDeep = Color(0xFF171612);
  static const bgPage = Color(0xFF1E1C18);
  static const bgElevated = Color(0xFF292620);

  static const border = Color(0x24FFFFFF);
  static const borderPurple = Color(0x66D4A373);

  // ============================================
  // 🟤 PRIMARY — Sand / Warm Tan (#D4A373)
  // ============================================
  static const purple = Color(0xFFD4A373);
  static const purpleLight = Color(0xFFE4C29F);
  static const purpleTint = Color(0x2ED4A373);
  static const purpleDim = Color(0x1FD4A373);

  // ============================================
  // 🌿 SECONDARY — Sage (#CCD5AE)
  // ============================================
  static const amber = Color(0xFFCCD5AE);
  static const amberTint = Color(0x2ECCD5AE);
  static const amberDim = Color(0x1FCCD5AE);

  // ============================================
  // 🔵 INFORMATION
  // ============================================
  static const blue = Color(0xFF7EA6C4);
  static const blueLight = Color(0xFFA7C3D6);
  static const blueDark = Color(0xFF5E86A3);
  static const blueDim = Color(0x247EA6C4);

  // ============================================
  // 🟩 SUCCESS
  // ============================================
  static const success = Color(0xFF93B77B);
  static const successDim = Color(0x2493B77B);

  // ============================================
  // 🔴 ERROR
  // ============================================
  static const error = Color(0xFFE07A6A);
  static const errorLight = Color(0xFFF0A093);
  static const errorDark = Color(0xFFBE5F52);
  static const errorDim = Color(0x24E07A6A);

  // ============================================
  // ⬜ MUTED
  // ============================================
  static const muted = Color(0xFF343028);

  // ============================================
  // 📝 TEXT
  // ============================================
  static const textPrimary = Color(0xFFF4F0E8);
  static const textSecondary = Color(0xB3F4F0E8);
  static const textDim = Color(0x73F4F0E8);
}

/// ============================================
/// 🎨 LIGHT COLORS (Accounting — Sand & Sage)
/// ============================================
abstract final class AppLightColors {
  // ============================================
  // ☀️ SURFACES
  // ============================================
  static const bgDeep = Color(0xFFF3EFE7);
  static const bgPage = Color(0xFFFAF8F3);
  static const bgElevated = Color(0xFFFFFFFF);

  static const border = Color(0xFFE2D8C8);
  static const borderPurple = Color(0x66D4A373);

  // ============================================
  // 🟤 PRIMARY — Sand / Warm Tan (#D4A373)
  // ============================================
  static const purple = Color(0xFFD4A373);
  static const purpleLight = Color(0xFFE2BC95);
  static const purpleTint = Color(0xFFF6EADF);
  static const purpleDim = Color(0x29D4A373);

  // ============================================
  // 🌿 SECONDARY — Sage (#CCD5AE)
  // ============================================
  static const amber = Color(0xFFCCD5AE);
  static const amberTint = Color(0xFFF1F4E7);
  static const amberDim = Color(0x33CCD5AE);

  // ============================================
  // 🔵 INFORMATION
  // ============================================
  static const blue = Color(0xFF5E86A3);
  static const blueLight = Color(0xFF86A9BF);
  static const blueDark = Color(0xFF426981);
  static const blueDim = Color(0x245E86A3);

  // ============================================
  // 🟩 SUCCESS
  // ============================================
  static const success = Color(0xFF6F9B5B);
  static const successDim = Color(0x246F9B5B);

  // ============================================
  // 🔴 ERROR
  // ============================================
  static const error = Color(0xFFC85D50);
  static const errorLight = Color(0xFFDC8378);
  static const errorDark = Color(0xFFA8453A);
  static const errorDim = Color(0x24C85D50);

  // ============================================
  // ⬜ MUTED
  // ============================================
  static const muted = Color(0xFFF0EBE2);

  // ============================================
  // 📝 TEXT
  // ============================================
  static const textPri = Color(0xFF332C25);
  static const textSec = Color(0xA6332C25);
  static const textDim = Color(0x66332C25);
}
