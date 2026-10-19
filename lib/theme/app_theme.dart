import 'package:flutter/material.dart';

/// Paleta de la Pokéball: rojo, blanco y negro.
class AppColors {
  static const Color red = Color(0xFFE01B1B);
  static const Color redDark = Color(0xFFB71010);
  static const Color redGlow = Color(0xCCEE1515);
  static const Color white = Color(0xFFF7F7F7);
  static const Color black = Color(0xFF222224);
  static const Color grey = Color(0xFFD9D9D9);
  static const Color panel = Color(0xFFEDEDED);
  static const Color border = Color(0xFFDADADA);
  static const Color muted = Color(0xFF6B6B70);
}

ThemeData buildPokeballTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.red,
      onPrimary: Colors.white,
      secondary: AppColors.black,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.black,
    ),
    scaffoldBackgroundColor: AppColors.black,
  );
}
