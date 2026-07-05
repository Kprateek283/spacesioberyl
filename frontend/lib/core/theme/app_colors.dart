import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary
  static const Color primary = Colors.black;
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFE0E0E0);
  static const Color onPrimaryContainer = Colors.black;

  // Backgrounds
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  
  // Text
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0xFF424242); // Grey 800
  static const Color textTertiary = Color(0xFF757575); // Grey 600

  // Borders
  static const Color border = Color(0xFFE0E0E0); // Grey 300

  // Status / Semantic (Keep slightly muted but clean, mostly grayscale if possible, or use standard status colors)
  static const Color success = Color(0xFF424242); // Black/Grey theme
  static const Color error = Color(0xFF424242);
  static const Color warning = Color(0xFF424242);
  static const Color info = Color(0xFF424242);
}
