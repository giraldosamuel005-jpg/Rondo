import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../permisos/permisos_sistema.dart';
import '../state/app_state.dart';
import 'detector_caidas.dart';

/// Una lectura de un sensor de tres ejes.
typedef Lectura = ({double x, double y, double z});

/// De dónde salen las lecturas. La app usa los sensores del celular; las
/// pruebas, una fuente que ellas mismas alimentan.
abstract interface class FuenteSensores {
  /// Aceleración en m/s², con la gravedad incluida.
  Stream<Lectura> acelerometro();

  /// Velocidad de giro en rad/s.
  Stream<Lectura> giroscopio();
}

/// Los sensores del celular, con `sensors_plus`, a unas 50 lecturas por segundo.
class SensoresDelCelular implements FuenteSensores {
  const SensoresDelCelular();

  @override
  Stream<Lectura> acelerometro() => accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
      .map((e) => (x: e.x, y: e.y, z: e.z));

  @override
  Stream<Lectura> giroscopio() =>
      gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) => (x: e.x, y: e.y, z: e.z));
}

/// RF-06, RF-09 y RF-10: vigila los sensores mientras la ronda está activa y
/// avisa por [caidas] cuando detecta una posible caída.
///
/// Escucha al [AppState]: solo vigila en una cuenta "para mí", con la ronda
/// activa (no en pausa) y el permiso de sensores encendido.
///
/// POR AHORA SOLO CON LA APP ABIERTA. Con la app cerrada Android corta los
/// sensores; para eso hace falta un servicio en primer plano (pendiente).
class VigilanteCaidas extends ChangeNotifier {
  VigilanteCaidas(this._estado, this._sensores, {DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now {
    _estado.addListener(_revisar);
    _revisar();
  }

  /// RF-10: después de una alerta de caída, las siguientes se ignoran este rato.
  static const espera = Duration(seconds: 60);

  static const errorSensores =
      'No pudimos acceder a los sensores del celular. La detección de caídas está desactivada.';
  static const errorPermiso = 'Activa el permiso de sensores de movimiento para usar la detección de caídas.';

  final AppState _estado;
  final FuenteSensores _sensores;
  final DateTime Function() _reloj;

  final detector = DetectorCaidas();
  final _caidas = StreamController<CaidaDetectada>.broadcast();
  StreamSubscription<Lectura>? _acelerometro;
  StreamSubscription<Lectura>? _giroscopio;
  bool _fallaron = false;
  DateTime? _ultimaAlerta;
  bool _cerrado = false;

  /// Cada posible caída que debe abrir la alerta (RF-13).
  Stream<CaidaDetectada> get caidas => _caidas.stream;

  /// Está leyendo los sensores ahora mismo.
  bool get vigilando => _acelerometro != null;

  /// La ronda está activa: debería estar vigilando.
  bool get _rondaActiva =>
      !_estado.esCuidador && _estado.tipo != null && _estado.rondaActivaDesde != null && !_estado.rondaEnPausa;

  /// Por qué no está vigilando aunque la ronda esté activa, para mostrárselo a
  /// la persona (RF-06, RF-32: no fallar en silencio). `null` si todo va bien.
  String? get aviso {
    if (!_rondaActiva) return null;
    if (!_estado.tienePermiso(PermisoSistema.sensores)) return errorPermiso;
    return _fallaron ? errorSensores : null;
  }

  void _revisar() {
    if (_cerrado) return;
    final debe = _rondaActiva && _estado.tienePermiso(PermisoSistema.sensores);
    if (debe && !vigilando && !_fallaron) {
      _empezar();
    } else if (!debe && (vigilando || _fallaron)) {
      _parar();
      _fallaron = false; // Al reanudar se vuelve a intentar
      notifyListeners();
    }
  }

  void _empezar() {
    detector.reiniciar();
    try {
      _acelerometro = _sensores.acelerometro().listen(_alLeer, onError: _alFallar);
      // Sin giroscopio (hay celulares que no traen) se sigue solo con el acelerómetro.
      _giroscopio = _sensores.giroscopio().listen((g) => detector.giroscopio(g.x, g.y, g.z), onError: (Object _) {});
    } catch (error) {
      _alFallar(error);
      return;
    }
    notifyListeners();
  }

  void _parar() {
    _acelerometro?.cancel();
    _giroscopio?.cancel();
    _acelerometro = null;
    _giroscopio = null;
  }

  void _alFallar(Object _) {
    _parar();
    _fallaron = true;
    notifyListeners();
  }

  void _alLeer(Lectura a) {
    final ahora = _reloj();
    final caida = detector.acelerometro(ahora, a.x, a.y, a.z);
    if (caida == null) return;

    final ultima = _ultimaAlerta;
    if (ultima != null && ahora.difference(ultima) < espera) {
      detector.anotarEnEspera(caida); // RF-10: queda en el registro interno
      return;
    }
    _ultimaAlerta = ahora;
    _caidas.add(caida);
  }

  @override
  void dispose() {
    _cerrado = true;
    _estado.removeListener(_revisar);
    _parar();
    _caidas.close();
    super.dispose();
  }
}
