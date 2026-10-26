/// Tipos de cosas que quedan registradas en el Historial.
enum TipoEvento {
  rondaActivada,
  rondaPausada,
  rondaReanudada,

  /// La persona respondió "Estoy bien" durante la cuenta regresiva (RF-14).
  alertaCancelada,

  /// Se avisó a los contactos: se acabó el tiempo o pidió ayuda (RF-15).
  alertaEnviada,

  /// La persona tocó "Estoy bien" en Inicio para decir que está sin novedad (RF-12).
  estoyBien,

  /// Marcó que tomó una dosis (RF-22).
  tomaRegistrada,

  /// Marcó que no tomó una dosis (RF-22).
  tomaOmitida,
}

/// Algo que pasó, con su hora.
class Evento {
  const Evento({required this.tipo, required this.fecha, this.detalle});

  final TipoEvento tipo;
  final DateTime fecha;

  /// Información extra, por ejemplo "Avisamos a Ana y Luis".
  final String? detalle;
}
