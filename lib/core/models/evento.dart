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

/// Filtros de la pestaña Historial.
enum FiltroHistorial {
  todo('Todo'),
  alertas('Alertas'),
  medicamentos('Medicamentos');

  const FiltroHistorial(this.etiqueta);

  final String etiqueta;

  bool incluye(TipoEvento tipo) => switch (this) {
        FiltroHistorial.todo => true,
        FiltroHistorial.alertas => tipo == TipoEvento.alertaEnviada || tipo == TipoEvento.alertaCancelada,
        FiltroHistorial.medicamentos => tipo == TipoEvento.tomaRegistrada || tipo == TipoEvento.tomaOmitida,
      };
}

/// Junta los eventos por día, conservando el orden en que vienen.
List<({DateTime dia, List<Evento> eventos})> agruparPorDia(List<Evento> eventos) {
  final grupos = <({DateTime dia, List<Evento> eventos})>[];
  final porDia = <DateTime, List<Evento>>{};
  for (final evento in eventos) {
    final dia = DateTime(evento.fecha.year, evento.fecha.month, evento.fecha.day);
    final delDia = porDia[dia];
    if (delDia != null) {
      delDia.add(evento);
    } else {
      final nuevo = [evento];
      porDia[dia] = nuevo;
      grupos.add((dia: dia, eventos: nuevo));
    }
  }
  return grupos;
}
