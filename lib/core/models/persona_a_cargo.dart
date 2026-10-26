/// Estado de una persona vista desde su cuidador (RF-26).
enum EstadoPersona {
  /// Ronda activa, sin novedades.
  activa,

  /// Pausó su ronda: no se reciben alertas.
  enPausa,

  /// Tiene una alerta sin atender.
  alerta,
}

/// Última ubicación conocida.
class Ubicacion {
  const Ubicacion({
    required this.latitud,
    required this.longitud,
    required this.descripcion,
    required this.fecha,
  });

  final double latitud;
  final double longitud;

  /// Texto legible: "Casa · Calle 5 # 38-20".
  final String descripcion;
  final DateTime fecha;

  /// Enlace de Google Maps (el mismo formato de RF-16).
  Uri get enlaceMapa => Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitud,$longitud');
}

/// Una alerta de la persona, como la ve el cuidador.
class AlertaPersona {
  const AlertaPersona({required this.fecha, required this.atendida, this.estabaBien = false});

  final DateTime fecha;

  /// El cuidador ya la marcó como atendida.
  final bool atendida;

  /// La persona respondió "Estoy bien" a tiempo (no se avisó a nadie).
  final bool estabaBien;
}

/// Alguien que invitó a este usuario como cuidador (RF-05, RF-26).
/// El cuidador solo LEE estos datos (RF-27): no los puede cambiar.
class PersonaACargo {
  const PersonaACargo({
    required this.id,
    required this.nombre,
    required this.celular,
    this.relacion = '',
    required this.estado,
    this.ubicacion,
    this.ultimoEstoyBien,
    this.cumplimiento,
    this.alertas = const [],
  });

  final String id;
  final String nombre;

  /// 10 dígitos, sin +57.
  final String celular;

  /// "Mamá", "Papá"...
  final String relacion;
  final EstadoPersona estado;
  final Ubicacion? ubicacion;
  final DateTime? ultimoEstoyBien;

  /// Porcentaje de tomas de medicamentos cumplidas (RF-22). `null` si no usa.
  final int? cumplimiento;

  /// Alertas recientes, de la más nueva a la más vieja.
  final List<AlertaPersona> alertas;

  Uri get enlaceLlamada => Uri(scheme: 'tel', path: '+57$celular');

  PersonaACargo copyWith({EstadoPersona? estado, List<AlertaPersona>? alertas}) => PersonaACargo(
        id: id,
        nombre: nombre,
        celular: celular,
        relacion: relacion,
        estado: estado ?? this.estado,
        ubicacion: ubicacion,
        ultimoEstoyBien: ultimoEstoyBien,
        cumplimiento: cumplimiento,
        alertas: alertas ?? this.alertas,
      );

  /// Dos personas de ejemplo para probar y para la demo, mientras no hay
  /// servidor. Las fechas se calculan desde [ahora] para que se vean recientes.
  static List<PersonaACargo> ejemplos(DateTime ahora) => [
        PersonaACargo(
          id: 'ejemplo-rosa',
          nombre: 'Rosa Gómez',
          celular: '3104567890',
          relacion: 'Mamá',
          estado: EstadoPersona.activa,
          ubicacion: Ubicacion(
            latitud: 3.4372,
            longitud: -76.5225,
            descripcion: 'Casa · Calle 5 # 38-20, Cali',
            fecha: ahora.subtract(const Duration(minutes: 15)),
          ),
          ultimoEstoyBien: ahora.subtract(const Duration(hours: 2)),
          cumplimiento: 92,
          alertas: [
            AlertaPersona(
              fecha: ahora.subtract(const Duration(days: 1, hours: 3)),
              atendida: true,
              estabaBien: true,
            ),
          ],
        ),
        PersonaACargo(
          id: 'ejemplo-jorge',
          nombre: 'Jorge Ramírez',
          celular: '3157778899',
          relacion: 'Papá',
          estado: EstadoPersona.enPausa,
          ubicacion: Ubicacion(
            latitud: 3.4476,
            longitud: -76.5418,
            descripcion: 'Parque del Perro, Cali',
            fecha: ahora.subtract(const Duration(hours: 1)),
          ),
          ultimoEstoyBien: ahora.subtract(const Duration(days: 1, hours: 5)),
          cumplimiento: 75,
        ),
      ];
}
