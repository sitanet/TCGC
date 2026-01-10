import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - The CityGate Church Official Palette
  static const Color jasper = Color(0xFF811A19);      // Dark Red
  static const Color sardine = Color(0xFFE74625);     // Orange-Red
  static const Color urim = Color(0xFFFFFFFF);        // White
  static const Color thummim = Color(0xFFDCC06C);     // Gold (Primary)
  static const Color goldVariant1 = Color(0xFFD8A085); // Gold variant
  static const Color goldVariant2 = Color(0xFFF7D485); // Light Gold

  // Light Mode Colors
  static const Color primaryGold = thummim;           // #DCC06C
  static const Color primaryGoldLight = goldVariant2; // #F7D485
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = urim;
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);
  static const Color textPrimaryDark = urim;
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color dividerDark = Color(0xFF404040);

  // Accent Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = jasper;                  // Using brand dark red
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color liveRed = sardine;               // Using brand orange-red

  // Category Colors (for Teens section)
  static const Color orange = Color(0xFFFF9800);
  static const Color teal = Color(0xFF26A69A);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color maroon = Color(0xFF800000);

  // Wallet Card Gradient
  static const List<Color> walletGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
  ];
}
