import '../utils/formato.dart';

/// Contacto de emergencia (RF-04): recibe las alertas que no se cancelan.
class Contacto {
  const Contacto({
    required this.nombre,
    required this.celular,
    this.relacion = '',
    this.esCuidador = false,
  });

  final String nombre;

  /// 10 dígitos, sin el +57.
  final String celular;

  /// Opcional: "Hija", "Vecino"...
  final String relacion;

  final bool esCuidador;

  String get iniciales => inicialesDe(nombre);

  /// "Hija · +57 320 652 3232", o solo el número si no hay relación.
  String get detalle {
    final numero = formatearCelular(celular);
    return relacion.isEmpty ? numero : '$relacion · $numero';
  }
}
