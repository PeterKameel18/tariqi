import 'package:flutter/material.dart';

/// Modern, premium color palette for Tariqi app.
/// Uses harmonious blue tones with accent gradients and semantic colors.
abstract class AppColors {
  // ── Primary Brand Colors ──
  static const Color primaryBlue = Color(0xFF1F6BFF);
  static const Color primaryDark = Color(0xFF0E1B3D);
  static const Color primaryLight = Color(0xFF73A0FF);
  static const Color accentCyan = Color(0xFF17B5D8);
  static const Color accentBlue = Color(0xFF8EB9FF);
  static const Color accentMint = Color(0xFF8CE6D4);
  static const Color accentPurple = Color(0xFF5160D9);

  // ── Surface & Background Colors ──
  static const Color scaffoldBg = Color(0xFFF4F7FB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF16223F);
  static const Color darkCard = Color(0xFF1D2D52);
  static const Color elevatedSurface = Color(0xFFF8FAFD);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFF16213E);
  static const Color textSecondary = Color(0xFF5D6880);
  static const Color textHint = Color(0xFF8F9BB3);
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
  static const Color border = Color(0xFFDCE4F0);
  static const Color divider = Color(0xFFEDF2F8);

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
    colors: [Color(0xFF1F6BFF), Color(0xFF17B5D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0C1630), Color(0xFF153463)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient authBackground = LinearGradient(
    colors: [Color(0xFF09162D), Color(0xFF10284F), Color(0xFF174D76)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
