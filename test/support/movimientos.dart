import 'dart:math';

/// Dibuja movimientos como los vería el celular: una lectura cada 20 ms.
/// Quien la usa dice qué hacer con cada lectura ([alAcelerar], [alGirar]).
class Movimientos {
  Movimientos({required this.alAcelerar, required this.alGirar, DateTime? desde})
      : ahora = desde ?? DateTime(2026, 11, 13, 10);

  static const g = 9.80665;
  static const paso = Duration(milliseconds: 20);

  /// De pie, con el celular en el bolsillo: la gravedad va por el eje Y.
  static const dePie = [0.0, g, 0.0];

  /// Acostado, con el celular boca arriba: la gravedad va por el eje Z.
  static const acostado = [0.0, 0.0, g];

  final void Function(DateTime t, double x, double y, double z) alAcelerar;
  final void Function(double x, double y, double z) alGirar;
  DateTime ahora;

  void _lectura(List<double> a, {double giro = 0}) {
    alGirar(giro, 0, 0);
    alAcelerar(ahora, a[0], a[1], a[2]);
    ahora = ahora.add(paso);
  }

  /// Sin moverse, en esa postura.
  void quieto(Duration cuanto, {List<double> postura = dePie}) {
    for (var t = Duration.zero; t < cuanto; t += paso) {
      _lectura(postura);
    }
  }

  /// Un golpe de [ges] veces la gravedad, de unos 60 ms.
  void golpe(double ges, {List<double> postura = dePie}) {
    for (var i = 0; i < 3; i++) {
      _lectura([for (final eje in postura) eje * ges], giro: 3);
    }
  }

  /// Caminar: la aceleración sube y baja suave (0,7 g a 1,3 g) y el celular gira.
  void caminar(Duration cuanto, {List<double> postura = dePie}) {
    var i = 0;
    for (var t = Duration.zero; t < cuanto; t += paso) {
      final onda = 1 + 0.3 * sin(i++ * 2 * pi / 25); // Dos pasos por segundo
      _lectura([for (final eje in postura) eje * onda], giro: 1.2);
    }
  }

  /// Trotar o saltar: una sacudida de 2,1 g en cada pisada (cada 360 ms).
  void trotar(Duration cuanto, {List<double> postura = dePie}) {
    var i = 0;
    for (var t = Duration.zero; t < cuanto; t += paso) {
      final pisada = i++ % 18 < 2;
      _lectura([for (final eje in postura) eje * (pisada ? 2.1 : 0.9)], giro: 1.5);
    }
  }
}
