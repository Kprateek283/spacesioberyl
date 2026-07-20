import 'package:flutter/material.dart';

/// Material 3 color roles for a high-contrast Black & White minimalist design system.
class AppColors {
  // Primary
  static const Color primary = Color(0xFF000000);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1A1A1A);
  static const Color onPrimaryContainer = Color(0xFFF5F5F5);
  static const Color primaryFixedDim = Color(0xFF333333);
  static const Color surfaceTint = Color(0xFF000000);

  // Secondary
  static const Color secondary = Color(0xFF4D4D4D);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE0E0E0);
  static const Color onSecondaryContainer = Color(0xFF1A1A1A);

  // Tertiary
  static const Color tertiary = Color(0xFF666666);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFF0F0F0);
  static const Color onTertiaryContainer = Color(0xFF333333);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Warning (community Material 3 extension role — not in the base spec, but
  // used consistently across the wireframes for "in_progress"/"pending" chips)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFFFBEB);
  static const Color onWarningContainer = Color(0xFFB45309);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Background / Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF000000);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF000000);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color onSurfaceVariant = Color(0xFF4D4D4D);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFAFAFA);
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEEEEEE);
  static const Color surfaceContainerHighest = Color(0xFFE0E0E0);

  static const Color outline = Color(0xFF757575);
  static const Color outlineVariant = Color(0xFFE0E0E0);

  static const Color inverseSurface = Color(0xFF121212);
  static const Color inverseOnSurface = Color(0xFFF5F5F5);
  static const Color inversePrimary = Color(0xFFE0E0E0);

  // Legacy aliases kept for call sites that reference the old grayscale
  // theme's names — all now resolve into the new palette above.
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = Color(0xFF757575);
  static const Color border = outlineVariant;
  static const Color success = Color(0xFF2E7D32); // Explicit success green
  static const Color info = secondary;
}
