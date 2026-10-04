import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema global de Rondó. Todos los botones, campos y textos lo usan.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paperWhite,

      // Paleta: le dice a Flutter qué color usar para cada "rol".
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.charcoal,
        primary: AppColors.charcoal,
        onPrimary: AppColors.cloudCard,
        surface: AppColors.paperWhite,
        onSurface: AppColors.ink,
        error: AppColors.error,
      ),

      // Letras: Inter, con los pesos y el espaciado del design.md.
      textTheme: TextTheme(
        // Título grande ("Bienvenido")
        headlineLarge: GoogleFonts.inter(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.0, // -0.03em: letras apretadas, como en Bevel
          height: 1.1,
          color: AppColors.ink,
        ),
        // Título de sección
        titleLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.24,
          color: AppColors.ink,
        ),
        // Texto principal
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          height: 1.4,
          color: AppColors.ink,
        ),
        // Texto secundario / de ayuda
        bodyMedium: GoogleFonts.inter(
          fontSize: 16,
          height: 1.4,
          color: AppColors.bodyGray,
        ),
        // Texto de los botones
        labelLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Campos de texto: fondo Cloud Card + borde visible.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cloudCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        hintStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.bodyGray),
        errorStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.error),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      // Botón principal: píldora Charcoal, ancho completo, 56 px de alto.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.charcoal,
          foregroundColor: AppColors.cloudCard,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(), // Bordes totalmente redondos (radio 128 px del design.md)
          textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),


      // Botón secundario con borde ("Entrar con huella").
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.charcoal, width: 1.5),
          textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),



      // Botones de texto ("Crear cuenta", "Reenviar").
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 48), // Área mínima cómoda para el dedo
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
