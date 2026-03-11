import 'package:flutter/material.dart';

/// App Color Palette
class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF3B82F6); // Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);

  // Button Colors - Light Theme (Purple)
  static const Color buttonPrimaryLight = Color(0xFF7C3AED); // Purple
  static const Color buttonPrimaryLightEnd = Color(
    0xFF8B5CF6,
  ); // Lighter Purple

  // Button Colors - Dark Theme (Orange)
  static const Color buttonPrimaryDark = Color(0xFFF59E0B); // Orange
  static const Color buttonPrimaryDarkEnd = Color(0xFFFBBF24); // Lighter Orange

  // Golden Accent for Tile Borders
  static const Color goldenAccent = Color(0xFFFFD700);
  static const Color goldenAccentLight = Color(0xFFFFE066);
  static const Color goldenAccentDark = Color(0xFFB8860B);

  // Navy Blue (for active session cards)
  static const Color navyBlue = Color(0xFF1E3A5F);
  static const Color navyBlueLight = Color(0xFF2D4A6F);

  // Secondary Colors
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF7C3AED);

  // Accent Colors
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color accentLight = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0891B2);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);

  // Neutral Colors - Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Neutral Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF475569);
  static const Color dividerDark = Color(0xFF334155);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textDisabledLight = Color(0xFFCBD5E1);

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color textDisabledDark = Color(0xFF475569);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundDark, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Territory Colors
  static const Color territoryActive = Color(0xFF3B82F6);
  static const Color territoryCompleted = Color(0xFF10B981);
  static const Color territoryPaused = Color(0xFFF59E0B);
  static const Color territoryCancelled = Color(0xFFEF4444);

  // Priority Colors
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF10B981);

  // Map Colors
  static const Color mapPolygonFill = Color(0x333B82F6);
  static const Color mapPolygonBorder = Color(0xFF3B82F6);
  static const Color mapMarker = Color(0xFFEF4444);
  static const Color mapPath = Color(0xFF10B981);
}
