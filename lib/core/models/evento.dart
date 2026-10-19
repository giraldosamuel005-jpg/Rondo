/// Tipos de cosas que quedan registradas en el Historial.
/// Más adelante: "Estoy bien", tomas de medicamentos...
enum TipoEvento {
  rondaActivada,
  rondaPausada,
  rondaReanudada,

  /// La persona respondió "Estoy bien" durante la cuenta regresiva (RF-14).
  alertaCancelada,

  /// Se avisó a los contactos: se acabó el tiempo o pidió ayuda (RF-15).
  alertaEnviada,
}

/// Algo que pasó, con su hora.
class Evento {
  const Evento({required this.tipo, required this.fecha, this.detalle});

  final TipoEvento tipo;
  final DateTime fecha;

  /// Información extra, por ejemplo "Avisamos a Ana y Luis".
  final String? detalle;
}
