import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rondo_colors.dart';
import 'rondo_text.dart';

/// Tema global de Rondó, en claro y oscuro.
/// Los colores propios del diseño viven en [RondoColors] (`context.rondo`).
class RondoTheme {
  RondoTheme._();

  static ThemeData light() => _build(RondoColors.light, Brightness.light);
  static ThemeData dark() => _build(RondoColors.dark, Brightness.dark);

  static ThemeData _build(RondoColors c, Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brillo,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.bg,
      onSurface: c.text,
      error: c.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: c.bg,
      textTheme: RondoText.textTheme(c),
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accentSoft,
        selectionHandleColor: c.accent,
      ),

      // Mensajes temporales: cápsula oscura sobre fondo claro (y al revés).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: GoogleFonts.geist(fontSize: 15, color: c.bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg,
        showDragHandle: true,
        dragHandleColor: c.textSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentLink,
          minimumSize: const Size(44, 44),
          textStyle: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
