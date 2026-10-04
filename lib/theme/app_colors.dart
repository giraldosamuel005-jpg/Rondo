import 'package:flutter/material.dart';

/// Colores de Rondó, tomados de docs/DESIGN.md (estilo Bevel)
/// y ajustados para que adultos mayores los lean bien.
class AppColors {
  AppColors._(); // Nadie necesita crear un "AppColors"; solo se usan sus colores.

  // Superficies
  static const paperWhite = Color(0xFFFFFFFF); // Fondo de las pantallas
  static const cloudCard = Color(0xFFEBF0F8); // Fondo de campos y tarjetas
  static const charcoal = Color(0xFF1F2025); // Botón principal

  // Texto
  static const ink = Color(0xFF222326); // Títulos y texto principal
  static const bodyGray = Color(0xFF5E6064); // Texto secundario (más oscuro que el original #747679)

  // Estados
  static const fieldBorder = Color(0xFFC9D2E0); // Borde de los campos
  static const error = Color(0xFFC62828); // Mensajes de error

  // Degradado "Hero Sky" para la parte de arriba del login
  static const heroSkyTop = Color(0xFFD2E5FF);
  static const heroSkyBottom = Color(0xFFFFF9EE);
}
