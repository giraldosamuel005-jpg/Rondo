import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C67),
        ),
        useMaterial3: true,
      );
}