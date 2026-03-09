import 'package:flutter/material.dart';

/// Modern, premium color palette for Tariqi app.
/// Uses harmonious blue tones with accent gradients and semantic colors.
abstract class AppColors {
  // ── Primary Brand Colors ──
  static const Color primaryBlue = Color(0xFF2260FF);
  static const Color primaryDark = Color(0xFF1A1E3D);
  static const Color primaryLight = Color(0xFF5B8DEF);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color accentPurple = Color(0xFF7C4DFF);

  // ── Surface & Background Colors ──
  static const Color scaffoldBg = Color(0xFFF5F7FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1E2235);
  static const Color darkCard = Color(0xFF262A40);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFF1A1E3D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic Colors ──
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Status Badges ──
  static const Color active = Color(0xFF10B981);
  static const Color pending = Color(0xFFF59E0B);
  static const Color completed = Color(0xFF6366F1);
  static const Color cancelled = Color(0xFFEF4444);

  // ── Borders & Dividers ──
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ── Legacy Compatibility ──
  static Color blueColor = primaryBlue;
  static Color lightBlueColor = const Color(0xffCAD6FF);
  static Color mediumBlueColor = const Color(0xff5a71ca);
  static Color whiteColor = const Color(0xffFFFFFF);
  static Color blackColor = const Color(0xff000000);
  static Color redColor = error;
  static Color otpBorder = const Color(0xffCBC8C8);
  static Color lightBalckColor = const Color(0xff2B2B2B);
  static Color greyColor = const Color(0xff2B2B2B);
  static Color greenColor = success;

  // ── Gradient Presets ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2260FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1E3D), Color(0xFF2D3250)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
