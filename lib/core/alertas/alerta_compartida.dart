import '../utils/formato.dart';

/// Dónde estaba el celular cuando sonó la alerta.
class Posicion {
  const Posicion(this.latitud, this.longitud);

  final double latitud;
  final double longitud;

  /// Enlace de Google Maps (RF-16), con 5 decimales (~1 m).
  String get enlaceMapa =>
      'https://www.google.com/maps/search/?api=1&query=${latitud.toStringAsFixed(5)},${longitud.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) => other is Posicion && other.latitud == latitud && other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);
}

/// Una alerta que la persona no canceló (RF-15), como queda en el servidor
/// para sus cuidadores: `personas/{uid}/alertas/{id}`.
class AlertaCompartida {
  const AlertaCompartida({
    required this.id,
    required this.fecha,
    this.posicion,
    this.atendida = false,
  });

  /// Lo crea el celular de la persona: si la subida se reintenta, no se duplica.
  final String id;

  /// Cuándo se detectó la posible caída.
  final DateTime fecha;

  /// `null` si no se pudo obtener la ubicación.
  final Posicion? posicion;

  /// Algún cuidador ya la marcó como atendida.
  final bool atendida;

  /// Un ID nuevo, único para este celular.
  static String nuevoId(DateTime ahora) => 'a${ahora.microsecondsSinceEpoch}';

  /// El SMS que les llega a los contactos (RF-15, RF-16): quién, a qué hora,
  /// dónde y qué hacer.
  static String mensajeSms({required String nombre, required DateTime fecha, Posicion? posicion}) {
    final quien = nombre.trim().isEmpty ? 'Tu contacto' : nombre.trim();
    final llamar = nombre.trim().isEmpty ? 'Llámalo ya' : 'Llama ya a ${primerNombre(nombre)}';
    final donde = posicion == null ? 'No pudimos obtener su ubicación.' : 'Ubicación: ${posicion.enlaceMapa}';
    return 'Rondó: $quien pudo haberse caído (${horaCorta(fecha)}) y no respondió. $donde '
        '$llamar. Emergencias: 123.';
  }
}
