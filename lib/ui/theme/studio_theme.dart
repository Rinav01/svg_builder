import 'package:flutter/material.dart';

/// Solid Matte Pro Studio Design System built around a strict 3-pillar palette:
/// - Complementary 1 (Structural Foundation): Deep Slate Obsidian (`#0F1217` / `#161B22` / `#1E2530`)
/// - Complementary 2 (Interactive Harmony): Cool Teal-Cyan (`#06B6D4` / `#22D3EE`)
/// - Shining Offset Color (Focal Points, Keyframes, Primary CTAs): Electric Amber-Gold (`#F59E0B` / `#FBBF24`)
///
/// Strictly solid matte surfaces — zero glassmorphism or washed-out translucent blurs.
class StudioTheme {
  StudioTheme._();

  // --- Complementary 1: Deep Slate Obsidian (Structural Surfaces) ---
  static const Color obsidianVoid = Color(0xFF0F1217);
  static const Color obsidianSurface = Color(0xFF161B22);
  static const Color obsidianElevated = Color(0xFF1E2530);
  static const Color obsidianCard = Color(0xFF232B38);
  static const Color obsidianBorder = Color(0xFF2A3442);
  static const Color obsidianBorderBright = Color(0xFF384556);

  // --- Complementary 2: Cool Teal-Cyan (Interactive Harmony) ---
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentCyanBright = Color(0xFF22D3EE);
  static const Color accentCyanSurface = Color(0xFF102E37);

  // --- Shining Offset Color: Electric Amber-Gold (Focal & Keyframe Accent) ---
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentAmberBright = Color(0xFFFBBF24);
  static const Color accentAmberSurface = Color(0xFF33240B);

  // --- Semantic Status & Typography ---
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
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
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: obsidianElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: obsidianBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: obsidianElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: obsidianBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: obsidianElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: accentCyan),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
