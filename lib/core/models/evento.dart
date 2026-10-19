/// Tipos de cosas que quedan registradas en el Historial.
/// Más adelante: alertas de caída, "Estoy bien", tomas de medicamentos...
enum TipoEvento { rondaActivada, rondaPausada, rondaReanudada }

/// Algo que pasó, con su hora.
class Evento {
  const Evento({required this.tipo, required this.fecha});

  final TipoEvento tipo;
  final DateTime fecha;
}
