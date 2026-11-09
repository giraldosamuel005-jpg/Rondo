import 'vinculo.dart';

/// Un error para mostrarle a la persona tal cual.
class ErrorVinculo implements Exception {
  const ErrorVinculo(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// El código ya existe en el servidor: hay que intentar con otro.
class CodigoOcupado implements Exception {
  const CodigoOcupado();
}

/// Habla con el servidor de vínculos. La app usa la versión de Firebase; las
/// pruebas, una en memoria. Así las pantallas no dependen de Firebase.
abstract interface class ServicioVinculos {
  /// Entra (o sigue) con una sesión anónima y devuelve su ID.
  Future<String> iniciarSesion();

  Future<void> cerrarSesion();

  /// Lanza [CodigoOcupado] si el código ya existe.
  Future<void> crearInvitacion(Invitacion invitacion);

  /// Solo la persona que la creó.
  Future<void> revocarInvitacion(String codigo);

  /// Acepta la invitación y crea el vínculo en una sola operación.
  /// Lanza [ErrorVinculo] si no se puede (ver `Invitacion.errorAlAceptar`).
  Future<Vinculo> aceptarInvitacion(
    String codigo, {
    required String cuidadorUid,
    required String cuidadorNombre,
  });

  /// La persona corta el vínculo (y anula la invitación con que se creó).
  Future<void> revocarVinculo(Vinculo vinculo);

  /// Las invitaciones que creó esta persona.
  Stream<List<Invitacion>> invitacionesDe(String personaUid);

  /// Los vínculos de esta persona (activos o no).
  Stream<List<Vinculo>> cuidadoresDe(String personaUid);

  /// Los vínculos activos de este cuidador.
  Stream<List<Vinculo>> personasDe(String cuidadorUid);

  /// Lo que comparte esa persona. `null` si no ha publicado nada.
  Stream<EstadoCompartido?> estadoDe(String personaUid);

  /// `null` borra lo publicado.
  Future<void> publicarEstado(String personaUid, EstadoCompartido? estado);
}
