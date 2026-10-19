/// Funciones para mostrar datos de forma legible.
library;

/// "3206523232" → "+57 320 652 3232".
String formatearCelular(String celular) {
  if (celular.length != 10) return '+57 $celular';
  return '+57 ${celular.substring(0, 3)} ${celular.substring(3, 6)} ${celular.substring(6)}';
}

/// "María José Castaño" → "MJ". Máximo dos letras.
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// "María José Castaño" → "María".
String primerNombre(String nombre) => nombre.trim().split(RegExp(r'\s+')).first;

const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// "Martes, 6 de octubre".
String fechaLarga(DateTime fecha) =>
    '${_dias[fecha.weekday - 1]}, ${fecha.day} de ${_meses[fecha.month - 1]}';

/// "7:02 a. m.", "3:45 p. m.".
String horaCorta(DateTime fecha) {
  final hora = fecha.hour % 12 == 0 ? 12 : fecha.hour % 12;
  final minutos = fecha.minute.toString().padLeft(2, '0');
  final sufijo = fecha.hour < 12 ? 'a. m.' : 'p. m.';
  return '$hora:$minutos $sufijo';
}
