import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/aviso_alerta.dart';
import 'package:rondo/core/models/contacto.dart';

class UbicacionFalsa implements LectorUbicacion {
  UbicacionFalsa(this.posicion);

  final Posicion? posicion;
  int lecturas = 0;

  @override
  Future<Posicion?> leer() async {
    lecturas++;
    return posicion;
  }
}

class SmsFalso implements EnviadorSms {
  SmsFalso({this.sinPermiso = false, this.fallanA = const {}});

  final bool sinPermiso;
  final Set<String> fallanA;
  final Map<String, String> enviados = {};

  @override
  Future<void> enviar(String celular, String texto) async {
    if (sinPermiso) throw const SinPermisoSms();
    if (fallanA.contains(celular)) throw StateError('sin señal');
    enviados[celular] = texto;
  }
}

void main() {
  const ana = Contacto(nombre: 'Ana María', celular: '3001234567');
  const luis = Contacto(nombre: 'Luis', celular: '3009876543');
  final fecha = DateTime(2026, 11, 10, 15, 42);
  const casa = Posicion(3.4372, -76.5225);

  Future<ResultadoAviso> avisar(
    SmsFalso sms, {
    Posicion? posicion = casa,
    bool usarUbicacion = true,
    bool usarSms = true,
    bool servidor = false,
    UbicacionFalsa? ubicacion,
  }) =>
      AvisoDeAlerta(ubicacion: ubicacion ?? UbicacionFalsa(posicion), sms: sms).avisar(
        nombre: 'Rosa Gómez',
        contactos: const [ana, luis],
        fecha: fecha,
        usarUbicacion: usarUbicacion,
        usarSms: usarSms,
        alServidor: ({required fecha, posicion}) async => servidor,
      );

  test('el SMS dice quién, a qué hora, dónde y qué hacer', () {
    final texto = AlertaCompartida.mensajeSms(nombre: 'Rosa Gómez', fecha: fecha, posicion: casa);
    expect(texto, contains('Rosa Gómez pudo haberse caído (3:42 p. m.)'));
    expect(texto, contains('https://www.google.com/maps/search/?api=1&query=3.43720,-76.52250'));
    expect(texto, contains('Llama ya a Rosa'));
    expect(texto, contains('123'));
  });

  test('a cada contacto le llega el SMS con la ubicación', () async {
    final sms = SmsFalso();
    final r = await avisar(sms, servidor: true);

    expect(sms.enviados.keys, [ana.celular, luis.celular]);
    expect(sms.enviados[ana.celular], contains('google.com/maps'));
    expect(r.conSms, [ana, luis]);
    expect(r.posicion, casa);
    expect(r.llegoACuidadores, isTrue);
    expect(r.nadieAvisado, isFalse);
  });

  test('sin ubicación igual avisa, y lo dice en el SMS', () async {
    final sms = SmsFalso();
    final r = await avisar(sms, posicion: null);

    expect(r.posicion, isNull);
    expect(sms.enviados[ana.celular], contains('No pudimos obtener su ubicación.'));
    expect(r.conSms, hasLength(2));
  });

  test('si la persona apagó la ubicación en Rondó, ni se lee', () async {
    final ubicacion = UbicacionFalsa(casa);
    final r = await avisar(SmsFalso(), usarUbicacion: false, ubicacion: ubicacion);

    expect(ubicacion.lecturas, 0);
    expect(r.posicion, isNull);
  });

  test('sin permiso de SMS no se envía a nadie y lo dice', () async {
    final r = await avisar(SmsFalso(sinPermiso: true), servidor: true);

    expect(r.faltaPermisoSms, isTrue);
    expect(r.sinSms, [ana, luis]);
    expect(r.nadieAvisado, isFalse); // Los cuidadores sí la recibieron
  });

  test('con el SMS apagado en Rondó no se intenta enviar', () async {
    final sms = SmsFalso();
    final r = await avisar(sms, usarSms: false);

    expect(sms.enviados, isEmpty);
    expect(r.faltaPermisoSms, isTrue);
  });

  test('si falla el SMS de uno, los demás sí salen', () async {
    final r = await avisar(SmsFalso(fallanA: {ana.celular}));

    expect(r.conSms, [luis]);
    expect(r.sinSms, [ana]);
  });

  test('sin SMS ni servidor, nadie fue avisado (alarma local, RF-17)', () async {
    final r = await avisar(SmsFalso(fallanA: {ana.celular, luis.celular}));

    expect(r.nadieAvisado, isTrue);
  });
}
