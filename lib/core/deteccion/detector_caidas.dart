import 'dart:math';

/// Una posible caída que pasó todos los filtros.
class CaidaDetectada {
  const CaidaDetectada({required this.fecha, required this.confianza});

  /// Momento del golpe.
  final DateTime fecha;

  /// RF-09: de 0 a 1. Solo llegan aquí las de [DetectorCaidas.confianzaMinima] o más.
  final double confianza;
}

/// Por qué un golpe NO terminó en alerta (RF-09, RF-10). Queda en el registro
/// interno; a la persona no se le muestra nada.
enum MotivoDescarte {
  /// Después del golpe hubo movimiento: se cayó el celular y lo recogieron,
  /// o la persona siguió andando.
  siguioEnMovimiento,

  /// Antes del golpe venía una racha de sacudidas: trotar, saltar, bailar.
  ejercicio,

  /// Golpe flojo y sin cambio de postura: un portazo, sentarse fuerte.
  confianzaBaja,

  /// Ya hubo una alerta hace poco (RF-10).
  enEspera,
}

class Descarte {
  const Descarte({required this.fecha, required this.motivo, this.confianza});

  final DateTime fecha;
  final MotivoDescarte motivo;
  final double? confianza;
}

/// RF-06 y RF-09: detecta caídas con el acelerómetro y el giroscopio.
///
/// Una caída se ve así en los sensores:
/// 1. un golpe fuerte (pico de aceleración),
/// 2. y después, casi nada de movimiento: la persona quedó en el piso,
///    normalmente con el celular en otra postura que antes.
///
/// No sabe de pantallas ni de sensores reales: recibe lecturas con su hora y
/// devuelve una [CaidaDetectada] cuando la hay. Así se puede probar con
/// caídas "dibujadas" a mano.
///
/// LOS UMBRALES SON UN PUNTO DE PARTIDA, tomados de valores típicos de la
/// literatura. RF-06 pide ajustarlos probando con datos reales.
class DetectorCaidas {
  static const gravedad = 9.80665;

  /// Golpe: 2,5 g. Caminar llega a ~1,5 g; dejarse caer en una silla, ~2 g.
  static const umbralGolpe = 2.5 * gravedad;

  /// Sacudida de ejercicio: 1,8 g. Trotar y saltar la pasan a cada paso.
  static const umbralSacudida = 1.8 * gravedad;

  /// Tres sacudidas o más en los 4 s anteriores al golpe: es ejercicio.
  static const sacudidasDeEjercicio = 3;
  static const ventanaEjercicio = Duration(seconds: 4);

  /// Lo que tarda un golpe en subir: una sacudida tan pegada es el golpe mismo.
  static const inicioDelGolpe = Duration(milliseconds: 300);

  /// Tras el golpe se dejan pasar los rebotes antes de mirar si hay quietud.
  static const asentamiento = Duration(milliseconds: 1000);

  /// Cuánto se observa después. Con el celular quieto todo ese rato, es caída.
  static const observacion = Duration(milliseconds: 2500);

  /// "Quieto": la aceleración es casi solo la gravedad y el celular no gira.
  static const toleranciaQuietud = 1.5; // m/s² alrededor de 1 g
  static const giroQuieto = 0.6; // rad/s
  static const fraccionQuieta = 0.8;

  /// Un golpe a 4 g o más cuenta como "fuerte del todo" para la confianza.
  static const golpeFuerte = 4.0 * gravedad;

  /// Un cambio de postura de 60° o más cuenta completo (de pie → acostado: ~90°).
  static const cambioPosturaCompleto = 60.0;

  static const confianzaMinima = 0.6;

  // ---------- Estado ----------

  /// Sacudidas recientes, para reconocer ejercicio.
  final List<DateTime> _sacudidas = [];
  bool _enSacudida = false;

  /// Hacia dónde apunta la gravedad, suavizada (la "postura" del celular).
  List<double>? _postura;

  // Un golpe en estudio.
  DateTime? _golpeEn;
  double _pico = 0;
  bool _eraEjercicio = false;
  List<double>? _posturaAntes;
  int _muestras = 0;
  int _quietas = 0;
  final List<double> _suma = [0, 0, 0];

  /// Último giro medido (rad/s). El giroscopio llega por su propio canal.
  double _giro = 0;

  /// Los golpes que no llegaron a alerta, del más viejo al más nuevo.
  final List<Descarte> descartes = [];
  static const _maximoDescartes = 50;

  void giroscopio(double x, double y, double z) => _giro = sqrt(x * x + y * y + z * z);

  /// Una lectura del acelerómetro (m/s², con gravedad). Devuelve la caída si
  /// con esta lectura se confirma una.
  CaidaDetectada? acelerometro(DateTime t, double x, double y, double z) {
    final magnitud = sqrt(x * x + y * y + z * z);
    _contarSacudida(t, magnitud);

    final golpeEn = _golpeEn;
    if (golpeEn == null) {
      if (magnitud >= umbralGolpe) {
        _golpeEn = t;
        _pico = magnitud;
        _posturaAntes = _postura == null ? null : List.of(_postura!);
        // La subida de este mismo golpe no cuenta como ejercicio.
        _eraEjercicio =
            _sacudidas.where((s) => t.difference(s) > inicioDelGolpe).length >= sacudidasDeEjercicio;
        _muestras = 0;
        _quietas = 0;
        _suma.fillRange(0, 3, 0);
      } else {
        _actualizarPostura(x, y, z);
      }
      return null;
    }

    final desdeGolpe = t.difference(golpeEn);
    if (desdeGolpe < asentamiento) {
      if (magnitud > _pico) _pico = magnitud;
      return null;
    }

    // Observación: ¿quedó quieto?
    _muestras++;
    _suma[0] += x;
    _suma[1] += y;
    _suma[2] += z;
    if ((magnitud - gravedad).abs() <= toleranciaQuietud && _giro <= giroQuieto) _quietas++;
    if (desdeGolpe < asentamiento + observacion) return null;

    return _decidir(golpeEn);
  }

  CaidaDetectada? _decidir(DateTime golpeEn) {
    final quietud = _muestras == 0 ? 0.0 : _quietas / _muestras;
    final fuerza = ((_pico - umbralGolpe) / (golpeFuerte - umbralGolpe)).clamp(0.0, 1.0);
    final postura = (_cambioDePostura() / cambioPosturaCompleto).clamp(0.0, 1.0);
    // Quedar quieto es lo que más pesa; el golpe y la postura lo confirman.
    final confianza = 0.45 * quietud + 0.25 * fuerza + 0.30 * postura;
    final eraEjercicio = _eraEjercicio;

    // La postura nueva es el punto de partida para lo que venga.
    if (_muestras > 0) _postura = [for (final s in _suma) s / _muestras];
    _golpeEn = null;

    if (quietud < fraccionQuieta) {
      _descartar(golpeEn, MotivoDescarte.siguioEnMovimiento, confianza);
      return null;
    }
    if (eraEjercicio) {
      _descartar(golpeEn, MotivoDescarte.ejercicio, confianza);
      return null;
    }
    if (confianza < confianzaMinima) {
      _descartar(golpeEn, MotivoDescarte.confianzaBaja, confianza);
      return null;
    }
    return CaidaDetectada(fecha: golpeEn, confianza: confianza);
  }

  /// Ángulo (grados) entre la postura de antes del golpe y la de después.
  double _cambioDePostura() {
    final antes = _posturaAntes;
    if (antes == null || _muestras == 0) return 0;
    final despues = [for (final s in _suma) s / _muestras];
    final punto = antes[0] * despues[0] + antes[1] * despues[1] + antes[2] * despues[2];
    final normas = _norma(antes) * _norma(despues);
    if (normas == 0) return 0;
    return acos((punto / normas).clamp(-1.0, 1.0)) * 180 / pi;
  }

  static double _norma(List<double> v) => sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);

  /// Filtro suave: sigue a la gravedad y no a los pasos.
  void _actualizarPostura(double x, double y, double z) {
    final p = _postura;
    if (p == null) {
      _postura = [x, y, z];
      return;
    }
    const peso = 0.05;
    p[0] += peso * (x - p[0]);
    p[1] += peso * (y - p[1]);
    p[2] += peso * (z - p[2]);
  }

  /// Cuenta una sacudida cada vez que la aceleración sube del umbral (no una
  /// por lectura: un solo salto dura varias lecturas).
  void _contarSacudida(DateTime t, double magnitud) {
    _sacudidas.removeWhere((s) => t.difference(s) > ventanaEjercicio);
    if (magnitud >= umbralSacudida) {
      if (!_enSacudida) _sacudidas.add(t);
      _enSacudida = true;
    } else {
      _enSacudida = false;
    }
  }

  void _descartar(DateTime fecha, MotivoDescarte motivo, [double? confianza]) {
    descartes.add(Descarte(fecha: fecha, motivo: motivo, confianza: confianza));
    if (descartes.length > _maximoDescartes) descartes.removeAt(0);
  }

  /// RF-10: la caída sí se detectó, pero no se alerta porque hubo otra hace poco.
  void anotarEnEspera(CaidaDetectada caida) => _descartar(caida.fecha, MotivoDescarte.enEspera, caida.confianza);

  /// Olvida el golpe en estudio (al pausar la ronda, por ejemplo).
  void reiniciar() {
    _golpeEn = null;
    _sacudidas.clear();
    _enSacudida = false;
    _postura = null;
    _giro = 0;
  }
}
