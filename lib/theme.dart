import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final tripSageTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0E5C5C),
    primary: const Color(0xFF0E5C5C),
    secondary: const Color(0xFFFF6B4A),
  ),
  scaffoldBackgroundColor: const Color(0xFFF7F9F9),
  textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
    headlineSmall: GoogleFonts.gowunBatang(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1A2B2B),
    ),
    titleLarge: GoogleFonts.gowunBatang(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1A2B2B),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF7F9F9),
    foregroundColor: Color(0xFF1A2B2B),
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0E5C5C),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);