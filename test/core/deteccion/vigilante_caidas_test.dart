import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/deteccion/detector_caidas.dart';
import 'package:rondo/core/deteccion/vigilante_caidas.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';

import '../../support/movimientos.dart';

/// Sensores que la prueba alimenta a mano.
class SensoresFalsos implements FuenteSensores {
  final _acelerometro = StreamController<Lectura>.broadcast(sync: true);
  final _giroscopio = StreamController<Lectura>.broadcast(sync: true);

  bool get escuchando => _acelerometro.hasListener;

  void acelerar(double x, double y, double z) => _acelerometro.add((x: x, y: y, z: z));
  void girar(double x, double y, double z) => _giroscopio.add((x: x, y: y, z: z));
  void fallar() => _acelerometro.addError(StateError('sin sensor'));

  @override
  Stream<Lectura> acelerometro() => _acelerometro.stream;

  @override
  Stream<Lectura> giroscopio() => _giroscopio.stream;
}

void main() {
  late AppState estado;
  late SensoresFalsos sensores;
  late VigilanteCaidas vigilante;
  late Movimientos m;
  late List<CaidaDetectada> caidas;

  AppState persona({bool conPermiso = true}) => AppState()
    ..iniciarSesion('3104567890')
    ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
    ..cambiarPermiso(PermisoSistema.sensores, conPermiso)
    ..activarRonda();

  void crear(AppState con) {
    estado = con;
    sensores = SensoresFalsos();
    // El reloj del vigilante es el de los movimientos dibujados.
    m = Movimientos(alGirar: sensores.girar, alAcelerar: (_, x, y, z) => sensores.acelerar(x, y, z));
    vigilante = VigilanteCaidas(estado, sensores, reloj: () => m.ahora);
    caidas = [];
    final sub = vigilante.caidas.listen(caidas.add);
    addTearDown(sub.cancel);
    addTearDown(vigilante.dispose);
  }

  Future<void> caerse() async {
    m.quieto(const Duration(seconds: 2));
    m.golpe(3.5);
    m.quieto(const Duration(seconds: 4), postura: Movimientos.acostado);
    await pumpEventQueue();
  }

  test('con la ronda activa y el permiso, vigila y avisa la caída', () async {
    crear(persona());
    expect(vigilante.vigilando, isTrue);
    expect(vigilante.aviso, isNull);

    await caerse();

    expect(caidas, hasLength(1));
  });

  test('en pausa deja de leer los sensores, y al reanudar vuelve', () {
    crear(persona());

    estado.alternarPausa();
    expect(sensores.escuchando, isFalse);
    expect(vigilante.aviso, isNull); // En pausa no es un error

    estado.alternarPausa();
    expect(sensores.escuchando, isTrue);
  });

  test('sin el permiso de sensores no vigila y lo dice', () {
    crear(persona(conPermiso: false));

    expect(sensores.escuchando, isFalse);
    expect(vigilante.aviso, VigilanteCaidas.errorPermiso);

    estado.cambiarPermiso(PermisoSistema.sensores, true);
    expect(sensores.escuchando, isTrue);
    expect(vigilante.aviso, isNull);
  });

  test('si los sensores fallan lo dice, sin quedarse callado', () {
    crear(persona());

    sensores.fallar();

    expect(vigilante.vigilando, isFalse);
    expect(vigilante.aviso, VigilanteCaidas.errorSensores);
  });

  test('un cuidador no vigila', () {
    crear(AppState()
      ..iniciarSesion('3001234567')
      ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador)
      ..cambiarPermiso(PermisoSistema.sensores, true));

    expect(sensores.escuchando, isFalse);
    expect(vigilante.aviso, isNull);
  });

  test('RF-10: otra caída enseguida no repite la alerta, pero queda anotada', () async {
    crear(persona());
    await caerse();
    await caerse(); // 6 s después: dentro de la espera

    expect(caidas, hasLength(1));
    expect(vigilante.detector.descartes.single.motivo, MotivoDescarte.enEspera);

    m.quieto(VigilanteCaidas.espera);
    await caerse();
    expect(caidas, hasLength(2));
  });
}
