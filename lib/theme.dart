import 'package:flutter/material.dart';

class AppTheme {
  static const cream     = Color(0xFFFFF5E6);
  static const brownDark = Color(0xFF3E2009);
  static const brownMed  = Color(0xFF6F3B1A);
  static const caramel   = Color(0xFFC47D2E);
  static const surface   = Color(0xFFFAF7F4);
  static const white     = Color(0xFFFFFFFF);
  static const grey100   = Color(0xFFF5F5F5);
  static const grey300   = Color(0xFFE0E0E0);
  static const grey600   = Color(0xFF757575);
  static const green     = Color(0xFF2E7D32);
  static const greenLight= Color(0xFFE8F5E9);
  static const red       = Color(0xFFC62828);
  static const redLight  = Color(0xFFFFEBEE);
  static const blue      = Color(0xFF1565C0);
  static const blueLight = Color(0xFFE3F2FD);
  static const yellow    = Color(0xFFFFF9C4);
  static const orange    = Color(0xFFFFF3E0);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: brownMed,
      onPrimary: white,
      secondary: caramel,
      onSecondary: white,
      surface: surface,
      onSurface: brownDark,
      outline: grey300,
    ),
    scaffoldBackgroundColor: surface,
    fontFamily: 'sans-serif',
    appBarTheme: const AppBarTheme(
      backgroundColor: brownDark,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: white,
      indicatorColor: caramel.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    cardTheme: CardTheme(
      color: white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: grey300),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: brownMed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brownMed,
        foregroundColor: white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: grey300, thickness: 1, space: 1),
  );
}
