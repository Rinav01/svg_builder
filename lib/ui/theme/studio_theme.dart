import 'package:flutter/material.dart';

/// Refined Solid-Matte Creative Studio Design System (Figma / Rive / Linear aesthetic).
///
/// Built around the user's strict 3-pillar palette with disciplined 85 / 12 / 3 visual balance:
/// - 85% Complementary 1 (Structural Foundation): Deep Slate Obsidian (`#0D1014` / `#13171D` / `#1A2028`)
/// - 12% Complementary 2 (Interactive Harmony): Cool Teal-Cyan (`#06B6D4` / `#22D3EE`)
/// - 3% Shining Offset Color (Exclusive Focal Accent): Electric Amber-Gold (`#F59E0B` / `#FBBF24`)
///
/// Zero glassmorphism, zero gaudy neon double-borders, zero ALL-CAPS monospace spam.
class StudioTheme {
  StudioTheme._();

  // --- Complementary 1: Deep Slate Obsidian (85% Structural Surfaces) ---
  static const Color obsidianVoid = Color(0xFF0D1014);
  static const Color obsidianSurface = Color(0xFF13171D);
  static const Color obsidianElevated = Color(0xFF1A2028);
  static const Color obsidianCard = Color(0xFF202731);
  static const Color obsidianBorder = Color(0xFF232B36);
  static const Color obsidianBorderBright = Color(0xFF2E3846);

  // --- Complementary 2: Cool Teal-Cyan (12% Interactive & Selection Harmony) ---
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentCyanBright = Color(0xFF22D3EE);
  static const Color accentCyanSurface = Color(0xFF11262E);

  // --- Shining Offset Color: Electric Amber-Gold (3% Exclusive Focal & Keyframe Accent) ---
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentAmberBright = Color(0xFFFBBF24);
  static const Color accentAmberSurface = Color(0xFF291F0E);

  // --- Semantic Status & Typography ---
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF526072);
  static const Color dangerCrimson = Color(0xFFEF4444);
  static const Color successEmerald = Color(0xFF10B981);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: obsidianVoid,
      canvasColor: obsidianSurface,
      dividerColor: obsidianBorder,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        onPrimary: obsidianVoid,
        secondary: accentAmber,
        onSecondary: obsidianVoid,
        surface: obsidianSurface,
        onSurface: textPrimary,
        error: dangerCrimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: obsidianSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 46,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: obsidianSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: obsidianBorderBright),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: obsidianElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: obsidianBorderBright),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: obsidianElevated,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: obsidianBorderBright),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: obsidianElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: obsidianBorderBright),
        ),
        textStyle: const TextStyle(
          color: textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
