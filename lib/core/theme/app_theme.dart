import 'package:flutter/material.dart';

class StandardTheme {
  static ThemeData theme = ThemeData(
    brightness: Brightness.dark,

    scaffoldBackgroundColor: const Color(0xFF101010),

    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),

    cardTheme: const CardThemeData(color: Color(0xFF1A1A1A)),

    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.white),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101010),
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),

      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),

      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
      ),

      labelStyle: TextStyle(color: Colors.white70),

      hintStyle: TextStyle(color: Colors.white38),
    ),
  );
}
