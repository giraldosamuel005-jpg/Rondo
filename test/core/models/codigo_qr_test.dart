import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/codigo_qr.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/ficha_medica.dart';
import 'package:rondo/core/persistencia/almacen.dart';
import 'package:rondo/core/state/app_state.dart';

void main() {
  final ficha = FichaMedica(tipoSangre: TipoSangre.oPositivo, celularContactoEmergencia: '3001234567');

  group('el token', () {
    test('tiene 128 bits: 32 caracteres hexadecimales', () {
      final codigo = CodigoQr.nuevo();
      expect(codigo.token, hasLength(32));
      expect(CodigoQr.tokenValido(codigo.token), isTrue);
    });

    test('no se repite', () {
      final tokens = {for (var i = 0; i < 1000; i++) CodigoQr.nuevo().token};
      expect(tokens, hasLength(1000));
    });

    test('con la misma semilla sale el mismo token (para poder probarlo)', () {
      expect(CodigoQr.nuevo(azar: Random(7)).token, CodigoQr.nuevo(azar: Random(7)).token);
    });

    test('se reconocen los tokens inválidos', () {
      expect(CodigoQr.tokenValido(null), isFalse);
      expect(CodigoQr.tokenValido('abc'), isFalse);
      expect(CodigoQr.tokenValido('G' * 32), isFalse);
      expect(CodigoQr.tokenValido('A' * 32), isFalse); // Solo minúsculas
    });
  });

  test('el enlace lleva el token, no los datos médicos', () {
    final codigo = CodigoQr(token: 'a' * 32, creadoEn: DateTime(2026, 10, 26));
    expect(codigo.enlace, '${CodigoQr.urlBase}/f/${'a' * 32}');
  });

  group('en AppState', () {
    late AppState estado;

    setUp(() => estado = AppState()..darConsentimiento(TipoConsentimiento.datosMedicos));

    test('sin ficha no hay QR', () {
      expect(estado.codigoQr, isNull);
      expect(estado.regenerarCodigoQr, throwsStateError);
    });

    test('al guardar la ficha se crea el QR, y editarla no lo cambia', () {
      estado.guardarFichaMedica(ficha);
      final token = estado.codigoQr!.token;

      estado.guardarFichaMedica(FichaMedica(
        tipoSangre: TipoSangre.aNegativo,
        celularContactoEmergencia: '3001234567',
      ));

      expect(estado.codigoQr!.token, token);
    });

    test('regenerar crea un token distinto', () {
      estado.guardarFichaMedica(ficha);
      final viejo = estado.codigoQr!.token;

      estado.regenerarCodigoQr();

      expect(estado.codigoQr!.token, isNot(viejo));
    });

    test('retirar el consentimiento de datos médicos borra el QR', () {
      estado.guardarFichaMedica(ficha);
      estado.retirarConsentimiento(TipoConsentimiento.datosMedicos);
      expect(estado.codigoQr, isNull);
    });

    test('cerrar sesión borra el QR', () {
      estado.guardarFichaMedica(ficha);
      estado.cerrarSesion();
      expect(estado.codigoQr, isNull);
    });
  });

  group('guardado', () {
    test('el token se guarda con la ficha (cifrada) y no con los demás datos', () async {
      final almacen = AlmacenMemoria();
      final estado = AppState(almacen: almacen)
        ..darConsentimiento(TipoConsentimiento.datosMedicos)
        ..guardarFichaMedica(ficha);
      await estado.guardadoPendiente;
      final token = estado.codigoQr!.token;

      expect(almacen.ficha.toString(), contains(token));
      expect(almacen.datos.toString(), isNot(contains(token)));
      expect((await AppState.cargar(almacen)).codigoQr!.token, token);
    });

    test('una ficha guardada antes de que existiera el QR recibe uno nuevo', () async {
      final almacen = AlmacenMemoria()
        ..datos = {
          'consentimientos': {'datosMedicos': '2026-10-19T10:00:00.000'},
        }
        ..ficha = {'tipoSangre': 'oPositivo', 'celularContactoEmergencia': '3001234567'};

      final estado = await AppState.cargar(almacen);

      expect(estado.fichaMedica, isNotNull);
      expect(CodigoQr.tokenValido(estado.codigoQr?.token), isTrue);
    });
  });
}
