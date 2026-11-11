import '../alertas/alerta_compartida.dart';
import 'ficha_publica.dart';
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

  // ---------- Ficha médica del QR (RF-24, RF-25) ----------

  /// Crea o actualiza la ficha que se ve al escanear el QR con ese token.
  Future<void> publicarFicha(String personaUid, String token, FichaPublica ficha);

  /// El QR de ese token deja de mostrar la ficha y dice "revocado". No tiene
  /// vuelta atrás: para volver a compartir se crea un token nuevo.
  Future<void> revocarFicha(String personaUid, String token);

  /// Cuándo abrieron la ficha de ese token, de la más reciente a la más vieja.
  Stream<List<DateTime>> consultasDe(String token);

  // ---------- Alertas (RF-15, RF-26) ----------

  /// La persona sube una alerta que no canceló. Termina cuando el servidor
  /// la recibió (sin internet queda en cola y se envía después).
  Future<void> publicarAlerta(String personaUid, AlertaCompartida alerta);

  /// Las alertas recientes de esa persona, de la más nueva a la más vieja.
  Stream<List<AlertaCompartida>> alertasDe(String personaUid);

  /// Un cuidador marca la alerta como atendida.
  Future<void> atenderAlerta(String personaUid, String alertaId, {required String cuidadorUid});

  /// Al cerrar sesión la persona borra sus alertas del servidor.
  Future<void> borrarAlertas(String personaUid);
}
