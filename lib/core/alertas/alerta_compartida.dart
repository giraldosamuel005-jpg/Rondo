import '../utils/formato.dart';

/// Un punto en el mapa.
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
    this.estabaBien = false,
    this.prueba = false,
  });

  /// Lo crea el celular de la persona: si la subida se reintenta, no se duplica.
  final String id;

  /// Cuándo se detectó la posible caída (o se pidió ayuda).
  final DateTime fecha;

  /// `null` si no se pudo obtener la ubicación.
  final Posicion? posicion;

  /// Algún cuidador ya la marcó como atendida, o la persona avisó que está bien.
  final bool atendida;

  /// Después de enviarla, la persona avisó que está bien.
  final bool estabaBien;

  /// La envió desde "Probar la alerta": no es una emergencia.
  final bool prueba;

  /// Un ID nuevo, único para este celular.
  static String nuevoId(DateTime ahora) => 'a${ahora.microsecondsSinceEpoch}';

  /// El SMS que les llega a los contactos (RF-15, RF-16): quién, a qué hora,
  /// dónde y qué hacer.
  static String mensajeSms({
    required String nombre,
    required DateTime fecha,
    Posicion? posicion,
    bool pidioAyuda = false,
    bool prueba = false,
  }) {
    final sinNombre = nombre.trim().isEmpty;
    final quien = sinNombre ? 'Tu contacto' : nombre.trim();
    final donde = posicion == null ? 'No pudimos obtener su ubicación.' : 'Ubicación: ${posicion.enlaceMapa}';
    if (prueba) {
      return 'Rondó, PRUEBA: $quien está probando sus alertas (${horaCorta(fecha)}). No es una emergencia. $donde';
    }
    final llamar = sinNombre ? 'Llama ya' : 'Llama ya a ${primerNombre(nombre)}';
    final que = pidioAyuda
        ? 'pidió ayuda (${horaCorta(fecha)})'
        : 'pudo haberse caído (${horaCorta(fecha)}) y no respondió';
    return 'Rondó: $quien $que. $donde $llamar. Emergencias: 123.';
  }

  /// El SMS cuando, después de la alerta, la persona avisa que está bien.
  static String mensajeEstoyBien({required String nombre, required DateTime fecha}) {
    final quien = nombre.trim().isEmpty ? 'Tu contacto' : nombre.trim();
    return 'Rondó: $quien avisó que está bien (${horaCorta(fecha)}). Ya no necesita ayuda.';
  }
}

/// Qué pasó al subir la alerta para los cuidadores con Rondó.
enum EntregaServidor {
  /// El servidor la recibió.
  recibida,

  /// No hay ningún cuidador vinculado: no había a quién avisarle por ahí.
  sinCuidadores,

  /// Sin conexión: queda en cola y sale sola cuando vuelva.
  pendiente,

  /// El servidor la rechazó, o falló.
  fallo,
}

/// Por donde la alerta llega a los cuidadores con Rondó.
abstract interface class ServidorAlertas {
  Future<EntregaServidor> publicarAlerta(AlertaCompartida alerta);

  /// La persona avisó que está bien: los cuidadores lo ven.
  Future<void> resolverAlerta(String alertaId);
}
