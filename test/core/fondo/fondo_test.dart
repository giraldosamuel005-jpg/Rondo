import 'package:flutter_test/flutter_test.dart';
import 'package:rondo/core/fondo/fondo.dart';
import 'package:rondo/core/models/persona_a_cargo.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';

import '../../support/alertas_falsas.dart';

void main() {
  late FondoFalso celular;

  setUp(() => celular = FondoFalso());

  ControlFondo crear(AppState estado) {
    final control = ControlFondo(estado, celular);
    addTearDown(control.dispose);
    return control;
  }

  AppState persona() => AppState()
    ..iniciarSesion('3104567890')
    ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
    ..cambiarPermiso(PermisoSistema.sensores, true)
    ..activarRonda();

  AppState cuidador() => AppState()
    ..iniciarSesion('3001234567')
    ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);

  const rosa = PersonaACargo(
    id: 'uid-rosa',
    nombre: 'Rosa Gómez',
    celular: '3104567890',
    estado: EstadoPersona.activa,
  );

  test('la persona: encendido con la ronda activa, apagado en pausa', () async {
    final estado = persona();
    crear(estado);
    expect(celular.titulo, 'Tu ronda está activa');
    expect(celular.despierto, isTrue); // Lee sensores con la pantalla apagada

    estado.alternarPausa();
    expect(celular.titulo, isNull);

    estado.alternarPausa();
    expect(celular.titulo, isNotNull);

    estado.cerrarSesion();
    expect(celular.titulo, isNull);
  });

  test('sin permiso de sensores no mantiene despierto el celular', () {
    crear(persona()..cambiarPermiso(PermisoSistema.sensores, false));
    expect(celular.despierto, isFalse);
  });

  test('el cuidador: encendido mientras cuide a alguien de verdad', () {
    final estado = cuidador();
    crear(estado);
    expect(celular.titulo, isNull);

    estado.cargarPersonasDeEjemplo();
    expect(celular.titulo, isNull);

    estado.ponerPersonasVinculadas([rosa]);
    expect(celular.titulo, 'Pendiente de Rosa');

    estado.ponerPersonasVinculadas([]);
    expect(celular.titulo, isNull);
  });

  test('no molesta al celular si nada cambió', () {
    final estado = persona();
    crear(estado);
    final veces = celular.veces;
    estado.confirmarEstoyBien();
    expect(celular.veces, veces);
  });

  test('si Android no lo dejó, al volver a la app se intenta otra vez', () async {
    celular.falla = true;
    final control = crear(persona());
    await pumpEventQueue();
    expect(celular.titulo, isNull);

    celular.falla = false;
    control.asegurar();
    expect(celular.titulo, 'Tu ronda está activa');
  });
}
