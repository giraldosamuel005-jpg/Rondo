import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/state/app_state.dart';

void main() {
  late AppState estado;

  setUp(() => estado = AppState());

  test('al empezar no hay consentimientos ni aviso aceptado', () {
    for (final tipo in TipoConsentimiento.values) {
      expect(estado.tieneConsentimiento(tipo), isFalse);
      expect(estado.fechaConsentimiento(tipo), isNull);
    }
    expect(estado.avisoAceptadoEn, isNull);
  });

  test('dar un consentimiento guarda su fecha, y darlo otra vez no la cambia', () async {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    final primera = estado.fechaConsentimiento(TipoConsentimiento.datosMedicos);
    expect(primera, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    expect(estado.fechaConsentimiento(TipoConsentimiento.datosMedicos), primera);
  });

  test('los consentimientos son independientes entre sí', () {
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);
    expect(estado.tieneConsentimiento(TipoConsentimiento.ubicacion), isFalse);
    expect(estado.tieneConsentimiento(TipoConsentimiento.camara), isFalse);
  });

  test('retirar un consentimiento borra su fecha', () {
    estado.darConsentimiento(TipoConsentimiento.camara);
    estado.retirarConsentimiento(TipoConsentimiento.camara);
    expect(estado.tieneConsentimiento(TipoConsentimiento.camara), isFalse);
    expect(estado.fechaConsentimiento(TipoConsentimiento.camara), isNull);
  });

  test('el interruptor de ubicación da y retira el consentimiento de ubicación', () {
    estado.cambiarPermisoUbicacion(true);
    expect(estado.tieneConsentimiento(TipoConsentimiento.ubicacion), isTrue);

    estado.cambiarPermisoUbicacion(false);
    expect(estado.tieneConsentimiento(TipoConsentimiento.ubicacion), isFalse);
  });

  test('guardar el perfil registra la fecha del aviso del 123', () {
    estado.guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.paraMi);
    expect(estado.avisoAceptadoEn, isNotNull);
  });

  test('cerrar sesión borra consentimientos y aviso', () {
    estado.guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.paraMi);
    estado.darConsentimiento(TipoConsentimiento.datosMedicos);

    estado.cerrarSesion();

    expect(estado.tieneConsentimiento(TipoConsentimiento.datosMedicos), isFalse);
    expect(estado.avisoAceptadoEn, isNull);
  });
}
