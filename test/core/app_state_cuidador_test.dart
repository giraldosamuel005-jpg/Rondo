import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/models/persona_a_cargo.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/persistencia/almacen.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/utils/formato.dart';

AppState cuidador({Almacen? almacen}) => AppState(almacen: almacen)
  ..iniciarSesion('3206523232')
  ..guardarPerfil(nombre: 'Andrés', tipo: TipoCuenta.cuidador);

void main() {
  test('el cuidador termina el registro sin contactos ni ronda', () {
    final estado = cuidador();
    expect(estado.esCuidador, isTrue);
    expect(estado.registroCompleto, isTrue);
    expect(estado.personasACargo, isEmpty);
  });

  test('quien se cuida todavía necesita activar su ronda', () {
    final estado = AppState()
      ..iniciarSesion('3206523232')
      ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi);
    expect(estado.registroCompleto, isFalse);
  });

  test('simular una alerta la deja sin atender, y atenderla la cierra', () {
    final estado = cuidador()..cargarPersonasDeEjemplo();
    final rosa = estado.personasACargo.first;

    estado.simularAlertaDe(rosa.id);
    var ahora = estado.personaACargo(rosa.id)!;
    expect(ahora.estado, EstadoPersona.alerta);
    expect(ahora.alertas.first.atendida, isFalse);
    expect(estado.alertasDePersonas.first.persona.id, rosa.id);

    estado.marcarAlertaAtendida(rosa.id);
    ahora = estado.personaACargo(rosa.id)!;
    expect(ahora.estado, EstadoPersona.activa);
    expect(ahora.alertas.every((a) => a.atendida), isTrue);
  });

  test('las personas a cargo se guardan y se borran al cerrar sesión', () async {
    final almacen = AlmacenMemoria();
    final estado = cuidador(almacen: almacen)..cargarPersonasDeEjemplo();
    estado.simularAlertaDe('ejemplo-rosa');
    await estado.guardadoPendiente;

    final nuevo = await AppState.cargar(almacen);
    expect(nuevo.registroCompleto, isTrue);
    expect(nuevo.personasACargo, hasLength(2));
    final rosa = nuevo.personaACargo('ejemplo-rosa')!;
    expect(rosa.estado, EstadoPersona.alerta);
    expect(rosa.ubicacion!.descripcion, contains('Calle 5'));
    expect(rosa.alertas, hasLength(2));

    nuevo.cerrarSesion();
    await nuevo.guardadoPendiente;
    expect((await AppState.cargar(almacen)).personasACargo, isEmpty);
  });

  test('haceCuanto', () {
    final ahora = DateTime(2026, 10, 25, 15);
    expect(haceCuanto(ahora, ahora: ahora), 'hace un momento');
    expect(haceCuanto(DateTime(2026, 10, 25, 14, 45), ahora: ahora), 'hace 15 min');
    expect(haceCuanto(DateTime(2026, 10, 25, 13), ahora: ahora), 'hace 2 h');
    expect(haceCuanto(DateTime(2026, 10, 24, 9), ahora: ahora), 'ayer, 9:00 a. m.');
  });
}
