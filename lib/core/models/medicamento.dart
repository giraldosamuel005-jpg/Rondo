/// Un medicamento que la persona toma (RF-20) y sus cálculos (RF-21).
class Medicamento {
  Medicamento({
    required this.id,
    required this.nombre,
    required this.dosis,
    required this.unidadesPorToma,
    required this.frecuenciaHoras,
    required this.unidadesDisponibles,
    required this.primeraToma,
  })  : assert(unidadesPorToma > 0),
        assert(frecuenciaHoras > 0);

  /// Identificador local (más adelante, el de Firebase).
  final String id;

  final String nombre;

  /// Descriptiva: "500 mg", "1 gota"...
  final String dosis;

  /// Cuántas unidades por toma (1 pastilla, 2 gotas...). Mayor a cero.
  final int unidadesPorToma;

  /// Cada cuántas horas se toma.
  final int frecuenciaHoras;

  /// Cuántas unidades le quedan.
  final int unidadesDisponibles;

  /// Fecha y hora de la primera toma ("fecha de inicio" de RF-20): de ahí
  /// salen todas las demás, cada [frecuenciaHoras].
  final DateTime primeraToma;

  /// Frecuencias para elegir con un toque, sin escribir.
  static const frecuencias = [4, 6, 8, 12, 24];

  /// Desde cuántos días restantes se avisa que se está acabando.
  static const diasAviso = 3;

  // ---------- RF-21 ----------

  /// unidades por toma × (24 ÷ frecuencia).
  double get unidadesPorDia => unidadesPorToma * (24 / frecuenciaHoras);

  /// unidades disponibles ÷ unidades por día, redondeado hacia abajo.
  int get diasRestantes => (unidadesDisponibles / unidadesPorDia).floor();

  bool get seEstaAcabando => diasRestantes <= diasAviso;

  /// "Quedan 2 días" / "Queda 1 día".
  String get diasTexto => diasRestantes == 1 ? 'Queda 1 día' : 'Quedan $diasRestantes días';

  /// "Te quedan 2 días de Losartán. Recuerda reponerlo." (o "Te queda 1 día").
  String get avisoReponer => 'Te ${diasTexto.toLowerCase()} de $nombre. Recuerda reponerlo.';

  // ---------- Horarios ----------

  /// La primera toma programada en [ahora] o después.
  DateTime proximaToma(DateTime ahora) {
    if (!ahora.isAfter(primeraToma)) return primeraToma;
    final paso = Duration(hours: frecuenciaHoras);
    final pasos = (ahora.difference(primeraToma).inMicroseconds / paso.inMicroseconds).ceil();
    return primeraToma.add(paso * pasos);
  }

  /// La toma que "toca" ahora: la próxima si falta 1 hora o menos;
  /// si no, la última que ya pasó.
  DateTime dosisActual(DateTime ahora) {
    final proxima = proximaToma(ahora);
    if (proxima.difference(ahora) <= const Duration(hours: 1)) return proxima;
    final anterior = proxima.subtract(Duration(hours: frecuenciaHoras));
    return anterior.isBefore(primeraToma) ? proxima : anterior;
  }

  /// "Cada 8 horas", "Una vez al día".
  String get frecuenciaTexto => frecuenciaHoras == 24 ? 'Una vez al día' : 'Cada $frecuenciaHoras horas';

  Medicamento copyWith({
    String? nombre,
    String? dosis,
    int? unidadesPorToma,
    int? frecuenciaHoras,
    int? unidadesDisponibles,
    DateTime? primeraToma,
  }) {
    return Medicamento(
      id: id,
      nombre: nombre ?? this.nombre,
      dosis: dosis ?? this.dosis,
      unidadesPorToma: unidadesPorToma ?? this.unidadesPorToma,
      frecuenciaHoras: frecuenciaHoras ?? this.frecuenciaHoras,
      unidadesDisponibles: unidadesDisponibles ?? this.unidadesDisponibles,
      primeraToma: primeraToma ?? this.primeraToma,
    );
  }

  // ---------- Validaciones (mensajes de RF-20 y RF-21) ----------

  static const errorIncompleto = 'Ingresa el nombre del medicamento, la dosis y la frecuencia.';
  static const errorUnidadesPorToma = 'Las unidades por toma deben ser un número mayor a cero.';
  static const errorRepetido = 'Este medicamento ya está registrado.';
  static const errorDisponibles = 'Ingresa cuántas unidades tienes para calcular los días restantes.';

  /// `null` si todo está bien. [otros] son los ya registrados; [idEditando]
  /// es el del que se está editando (para que no choque consigo mismo).
  static String? validar({
    required String nombre,
    required String dosis,
    required int? frecuenciaHoras,
    required int unidadesPorToma,
    required int? unidadesDisponibles,
    required List<Medicamento> otros,
    String? idEditando,
  }) {
    if (nombre.trim().isEmpty || dosis.trim().isEmpty || frecuenciaHoras == null) {
      return errorIncompleto;
    }
    if (unidadesPorToma <= 0) return errorUnidadesPorToma;
    if (unidadesDisponibles == null) return errorDisponibles;
    final repetido = otros.any(
      (m) => m.id != idEditando && m.nombre.trim().toLowerCase() == nombre.trim().toLowerCase(),
    );
    return repetido ? errorRepetido : null;
  }
}

/// Registro de una toma (RF-22): con esto se calcula el cumplimiento.
class TomaMedicamento {
  const TomaMedicamento({
    required this.medicamentoId,
    required this.horaProgramada,
    required this.tomada,
    this.horaReal,
  });

  final String medicamentoId;
  final DateTime horaProgramada;
  final bool tomada;

  /// Vacía si no la tomó.
  final DateTime? horaReal;
}
