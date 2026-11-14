import '../models/medicamento.dart';

/// Un aviso de toma (RF-22): a esa hora suena una notificación en el celular.
class Recordatorio {
  const Recordatorio({
    required this.id,
    required this.medicamentoId,
    required this.hora,
    required this.titulo,
    required this.cuerpo,
  });

  /// El número con que Android la identifica. Sale del medicamento y la hora,
  /// así la misma toma siempre tiene el mismo y no se repite.
  final int id;
  final String medicamentoId;
  final DateTime hora;
  final String titulo;
  final String cuerpo;

  /// Hasta dónde se programa. Al abrir la app se vuelve a programar, así que
  /// solo se quedaría sin avisos quien no la abra en una semana.
  static const horizonte = Duration(days: 7);

  /// Android no deja programar más de 500 alarmas por app.
  static const maximo = 300;

  /// Los avisos de las tomas que vienen, del más cercano al más lejano.
  /// No incluye las que ya pasaron ni las que la persona ya registró
  /// ([yaRegistrada]).
  static List<Recordatorio> planear({
    required List<Medicamento> medicamentos,
    required bool Function(String medicamentoId, DateTime hora) yaRegistrada,
    required DateTime ahora,
  }) {
    final hasta = ahora.add(horizonte);
    final plan = <Recordatorio>[];
    for (final m in medicamentos) {
      final paso = Duration(hours: m.frecuenciaHoras);
      for (var hora = m.proximaToma(ahora); !hora.isAfter(hasta); hora = hora.add(paso)) {
        if (!hora.isAfter(ahora) || yaRegistrada(m.id, hora)) continue;
        plan.add(Recordatorio(
          id: _id(m.id, hora),
          medicamentoId: m.id,
          hora: hora,
          titulo: 'Hora de tu medicamento',
          cuerpo: '${m.nombre} ${m.dosis}. Toca para registrar tu toma.',
        ));
      }
    }
    plan.sort((a, b) => a.hora.compareTo(b.hora));
    return plan.length > maximo ? plan.sublist(0, maximo) : plan;
  }

  /// Un número de 31 bits estable (no cambia entre una apertura y otra de la
  /// app, a diferencia de `hashCode`).
  static int _id(String medicamentoId, DateTime hora) {
    var n = 17;
    for (final letra in medicamentoId.codeUnits) {
      n = (n * 31 + letra) & 0x7fffffff;
    }
    return (n * 31 + hora.millisecondsSinceEpoch ~/ 60000) & 0x7fffffff;
  }

  @override
  bool operator ==(Object other) =>
      other is Recordatorio &&
      other.id == id &&
      other.medicamentoId == medicamentoId &&
      other.hora == hora &&
      other.titulo == titulo &&
      other.cuerpo == cuerpo;

  @override
  int get hashCode => Object.hash(id, hora, cuerpo);
}
