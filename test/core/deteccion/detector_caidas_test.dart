import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/deteccion/detector_caidas.dart';

import '../../support/movimientos.dart';

void main() {
  late DetectorCaidas detector;
  late Movimientos m;
  late List<CaidaDetectada> caidas;

  setUp(() {
    detector = DetectorCaidas();
    caidas = [];
    m = Movimientos(
      alGirar: detector.giroscopio,
      alAcelerar: (t, x, y, z) {
        final caida = detector.acelerometro(t, x, y, z);
        if (caida != null) caidas.add(caida);
      },
    );
  });

  const unRato = Duration(seconds: 2);
  const hastaDecidir = Duration(seconds: 4);

  test('caída: golpe fuerte y después queda quieta en otra postura', () {
    m.caminar(unRato);
    final golpeEn = m.ahora;
    m.golpe(3.5);
    m.quieto(hastaDecidir, postura: Movimientos.acostado);

    expect(caidas, hasLength(1));
    expect(caidas.single.fecha, golpeEn);
    expect(caidas.single.confianza, greaterThanOrEqualTo(DetectorCaidas.confianzaMinima));
    expect(detector.descartes, isEmpty);
  });

  test('un golpe muy fuerte cuenta aunque el celular quede en la misma postura', () {
    m.quieto(unRato);
    m.golpe(4.2);
    m.quieto(hastaDecidir);

    expect(caidas, hasLength(1));
  });

  test('caminar no es una caída', () {
    m.caminar(const Duration(seconds: 20));

    expect(caidas, isEmpty);
    expect(detector.descartes, isEmpty); // Ni siquiera hubo golpe
  });

  group('RF-09: falsos positivos', () {
    test('se cayó el celular y lo recogieron: después hubo movimiento', () {
      m.quieto(unRato);
      m.golpe(3.5);
      m.caminar(hastaDecidir, postura: Movimientos.acostado);

      expect(caidas, isEmpty);
      expect(detector.descartes.single.motivo, MotivoDescarte.siguioEnMovimiento);
    });

    test('ejercicio: venía trotando cuando llegó el golpe', () {
      m.trotar(const Duration(seconds: 4));
      m.golpe(3.5);
      m.quieto(hastaDecidir, postura: Movimientos.acostado);

      expect(caidas, isEmpty);
      expect(detector.descartes.single.motivo, MotivoDescarte.ejercicio);
    });

    test('golpe flojo y sin cambio de postura: no alcanza la confianza', () {
      m.quieto(unRato);
      m.golpe(2.6);
      m.quieto(hastaDecidir);

      expect(caidas, isEmpty);
      final descarte = detector.descartes.single;
      expect(descarte.motivo, MotivoDescarte.confianzaBaja);
      expect(descarte.confianza, lessThan(DetectorCaidas.confianzaMinima));
    });
  });

  test('después de descartar un golpe sigue detectando', () {
    m.quieto(unRato);
    m.golpe(3.5);
    m.caminar(const Duration(seconds: 6)); // La recogió y siguió caminando
    m.golpe(3.5);
    m.quieto(hastaDecidir, postura: Movimientos.acostado);

    expect(caidas, hasLength(1));
  });
}
