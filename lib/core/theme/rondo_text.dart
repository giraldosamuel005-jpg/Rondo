import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rondo_colors.dart';

/// Escala tipográfica de Rondó (docs/DESIGN.md, sección 3.3). Fuente: Geist.
///
/// | Estilo del diseño | En Flutter          |
/// |-------------------|---------------------|
/// | brand             | displayLarge        |
/// | alertTitle        | displayMedium       |
/// | title             | headlineLarge       |
/// | stat              | titleLarge          |
/// | headline          | titleMedium         |
/// | body              | bodyLarge           |
/// | callout           | bodyMedium          |
/// | label             | labelLarge          |
/// | caption           | bodySmall           |
class RondoText {
  RondoText._();

  static TextTheme textTheme(RondoColors c) {
    return TextTheme(
      displayLarge: GoogleFonts.geist(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        height: 1.05,
        color: c.text,
      ),
      displayMedium: GoogleFonts.geist(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.05,
        color: c.text,
      ),
      headlineLarge: GoogleFonts.geist(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
        color: c.text,
      ),
      titleLarge: GoogleFonts.geist(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: c.text,
      ),
      titleMedium: GoogleFonts.geist(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.text,
      ),
      bodyLarge: GoogleFonts.geist(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: c.text,
      ),
      bodyMedium: GoogleFonts.geist(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: c.textSecondary,
      ),
      labelLarge: GoogleFonts.geist(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: c.textSecondary,
      ),
      bodySmall: GoogleFonts.geist(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: c.textSecondary,
      ),
    );
  }

  /// Dígitos de las casillas del código.
  static TextStyle codeDigit(RondoColors c) => GoogleFonts.geist(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: c.text,
      );

  /// Número del celular en la pantalla Entrar.
  static TextStyle phone(RondoColors c) => GoogleFonts.geist(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c.text,
      );

  /// Cuenta regresiva de la alerta ("0:10"): números de ancho fijo para que
  /// no "bailen" al cambiar.
  static TextStyle countdown(RondoColors c) => GoogleFonts.geist(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
        color: c.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
