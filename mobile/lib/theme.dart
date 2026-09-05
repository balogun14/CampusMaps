import 'package:flutter/material.dart';

// Google Maps palette — https://about.google/brand-resource-center/
class GoogleColors {
  GoogleColors._();
  static const blue = Color(0xFF1A73E8); // primary actions, route
  static const blueLight = Color(0xFF4285F4);
  static const blueBg = Color(0xFFE8F0FE);
  static const red = Color(0xFFEA4335); // destination pin, errors
  static const green = Color(0xFF34A853); // navigation banner, origin
  static const yellow = Color(0xFFFBBC05);
  static const textPrimary = Color(0xFF202124);
  static const textSecondary = Color(0xFF5F6368);
  static const textTertiary = Color(0xFF80868B);
  static const border = Color(0xFFDADCE0);
  static const divider = Color(0xFFE8EAED);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceHover = Color(0xFFF1F3F4);
  static const shadow = Color(0x26000000); // 15% black
  static const shadowStrong = Color(0x4D3C4043); // 30%
}

class AppTheme {
  AppTheme._();

  // --- legacy aliases kept for compat (map to Google palette) ---
  static const coral = GoogleColors.red;
  static const coralLight = Color(0xFFEF6C60);
  static const teal = GoogleColors.blue;
  static const tealLight = Color(0xFF8AB4F8);
  static const sunny = GoogleColors.yellow;
  static const purple = GoogleColors.textSecondary;
  static const purpleLight = Color(0xFFDADCE0);

  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF202124);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: GoogleColors.surface,
        colorScheme: const ColorScheme.light(
          primary: GoogleColors.blue,
          secondary: GoogleColors.green,
          tertiary: GoogleColors.yellow,
          surface: Colors.white,
          error: GoogleColors.red,
          onSurface: GoogleColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: GoogleColors.textPrimary,
          titleTextStyle: TextStyle(
            color: GoogleColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: GoogleColors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: GoogleColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: GoogleColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: GoogleColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: GoogleColors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dividerTheme: const DividerThemeData(
          color: GoogleColors.divider,
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF323232),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

class DarkPremium {
  DarkPremium._();
  static const bg = Color(0xFF0F1115);
  static const card = Color(0xFF1A1E23);
  static const cardElevated = Color(0xFF232830);
  static const border = Color(0xFF2F353D);
  static const divider = Color(0xFF2A3038);
  static const textPrimary = Color(0xFFE8EAED);
  static const textSecondary = Color(0xFF9AA0A6);
  static const textTertiary = Color(0xFF5F6368);
  static const neonBlue = Color(0xFF00E5FF);
  static const neonCyan = Color(0xFF4ECDC4);
  static const neonGreen = Color(0xFF00E676);
  static const neonYellow = Color(0xFFFFD600);
  static const route = Color(0xFF00E5FF);
  static const routeGlow = Color(0x3300E5FF);
  static const routeOutline = Color(0xFF0F1115);
  static const pinOrigin = Color(0xFF00E676);
  static const pinDest = Color(0xFFFF5252);
}

class Editorial {
  Editorial._();
  static const paper = Color(0xFFFEF7E0); // warm cream paper
  static const paperDark = Color(0xFFF5EFE2);
  static const card = Color(0xFFFFFBF5);
  static const cardElevated = Color(0xFFFDF8F0);
  static const border = Color(0xFFE8E0D6);
  static const divider = Color(0xFFEDE6DB);
  static const ink = Color(0xFF2B2A26);
  static const inkSecondary = Color(0xFF6B665E);
  static const inkTertiary = Color(0xFF9A9590);
  static const sage = Color(0xFF8A9A8B); // parks
  static const sageLight = Color(0xFFD4DDD0);
  static const terracotta = Color(0xFFC17A56);
  static const terracottaLight = Color(0xFFE8C4B0);
  static const coral = Color(0xFFE85D4A); // editorial route
  static const coralLight = Color(0xFFFFE8E0);
  static const mustard = Color(0xFFF2C14E); // campus dashed
  static const mustardLight = Color(0xFFFEF3C7);
  static const navy = Color(0xFF1A2744);
  static const route = Color(0xFFE85D4A);
  static const routeOutline = Color(0xFFFFFBF5);
  static const routeGlow = Color(0x33E85D4A);
  static const pinOrigin = Color(0xFF2B5A3E); // deep sage
  static const pinDest = Color(0xFFE85D4A);
  static const campusWash = Color(0x148A9A8B);
  static const campusBorder = Color(0x408A9A8B);
}

class AppColors {
  AppColors._();
  static const origin = GoogleColors.green; // Google green for start
  static const destination = GoogleColors.red; // Google red for end
  static const route = GoogleColors.blue;
  static const routeNavigate = GoogleColors.blue;
  static const routeOutline = Colors.white;
  static const recording = GoogleColors.red;
  static const trail = GoogleColors.red;
  static const campus = GoogleColors.yellow;
}
