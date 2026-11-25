import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/control_alerta.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/alert/fall_alert_page.dart';

import '../../support/alertas_falsas.dart';

class PermisosFalsos extends PermisosSistema {
  const PermisosFalsos();

  @override
  Future<EstadoPermiso> pedir(PermisoSistema permiso) async => EstadoPermiso.concedido;
}

void main() {
  const ana = Contacto(nombre: 'Ana', celular: '3001234567');
  const luis = Contacto(nombre: 'Luis', celular: '3009876543');
  late AppState estado;

  setUp(() {
    estado = AppState()
      ..iniciarSesion('3104567890')
      ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
      ..agregarContacto(ana)
      ..agregarContacto(luis)
      ..activarRonda()
      ..cambiarPermiso(PermisoSistema.ubicacion, true)
      ..cambiarPermiso(PermisoSistema.sms, true);
  });

  Future<ControlAlerta> mostrar(
    WidgetTester tester, {
    SmsFalso? sms,
    ServidorAlertasFalso? servidor,
    Posicion? posicion,
    bool simulada = false,
    bool sinAnimaciones = false,
  }) async {
    final control = ControlAlerta(
      estado,
      ubicacion: simulada ? null : UbicacionFalsa(posicion),
      sms: simulada ? null : sms ?? SmsFalso(),
      servidor: simulada ? null : servidor ?? ServidorAlertasFalso(EntregaServidor.sinCuidadores),
      alarma: AlarmaFalsa(),
      reloj: tester.binding.clock.now,
    );
    addTearDown(control.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (sinAnimaciones) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    control.iniciar(detectadaA: DateTime(2026, 11, 10, 15, 42));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: estado),
          ChangeNotifierProvider.value(value: control),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [RondoColors.light]),
          // La letra de las pruebas (cuadros anchos) no cabe en el anillo de la
          // cuenta regresiva; con las fuentes de Rondó sí cabe.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.7)),
            child: child!,
          ),
          home: const FallAlertPage(permisos: PermisosFalsos()),
        ),
      ),
    );
    await tester.pump();
    return control;
  }

  Future<void> pedirAyuda(WidgetTester tester) async {
    await tester.tap(find.text('Pedir ayuda ahora'));
    await tester.pump(); // "Avisando…"
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('pedir ayuda envía el SMS a cada contacto', (tester) async {
    final sms = SmsFalso();
    await mostrar(tester, sms: sms, posicion: const Posicion(3.43, -76.52));

    await pedirAyuda(tester);

    expect(sms.enviados.keys, {ana.celular, luis.celular});
    expect(find.text('Avisamos a tus contactos'), findsOneWidget);
    expect(find.text('Ya estoy bien, avísales'), findsOneWidget);
  });

  testWidgets('con las animaciones apagadas en el celular la cuenta dura los mismos 10 s', (tester) async {
    final control = await mostrar(tester, sinAnimaciones: true);

    await tester.pump(const Duration(seconds: 8));
    expect(control.fase, FaseAlerta.contando);
    expect(find.text('0:02'), findsOneWidget);

    await tester.tap(find.text('Estoy bien'));
    await tester.pump();
    expect(control.activa, isFalse);
  });

  testWidgets('el botón atrás no cierra la cuenta regresiva', (tester) async {
    final control = await mostrar(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(control.fase, FaseAlerta.contando);
    control.estoyBien();
    await tester.pump();
  });

  testWidgets('si algo falla lo dice con el mensaje del requisito', (tester) async {
    final control = await mostrar(tester, sms: SmsFalso(fallanA: {luis.celular}));

    await pedirAyuda(tester);

    expect(find.text('No se pudo obtener tu ubicación. Se avisó a tus contactos sin ella.'), findsOneWidget);
    expect(find.text('No se pudo notificar a Luis. Reintentando…'), findsOneWidget);
    control.yaEstoyBien(); // Para los reintentos
    await tester.pump();
  });

  testWidgets('si no le llega a nadie: alarma local y botón al 123 (RF-17)', (tester) async {
    final control = await mostrar(tester, sms: SmsFalso(fallanA: {ana.celular, luis.celular}));

    await pedirAyuda(tester);

    expect(find.text('No pudimos avisar a nadie'), findsOneWidget);
    expect(find.text('Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana.'), findsOneWidget);
    expect(find.text('Llamar al 123'), findsOneWidget);
    control.yaEstoyBien();
    await tester.pump();
  });

  testWidgets('sin permiso de SMS no culpa a la señal, y se puede dar ahí mismo', (tester) async {
    estado.cambiarPermiso(PermisoSistema.sms, false);
    final sms = SmsFalso();
    await mostrar(tester, sms: sms);

    await pedirAyuda(tester);
    expect(find.text('La app no tiene permiso para enviar SMS. Actívalo en ajustes.'), findsOneWidget);
    expect(find.textContaining('Sin conexión ni señal'), findsNothing);

    await tester.tap(find.text('Permitir SMS y reintentar'));
    await tester.pumpAndSettle();
    expect(sms.enviados.keys, {ana.celular, luis.celular});
    expect(find.text('Avisamos a tus contactos'), findsOneWidget);
  });

  testWidgets('sin SMS ni servidor es una simulación y lo dice', (tester) async {
    await mostrar(tester, simulada: true);

    await pedirAyuda(tester);

    expect(find.text('Simulación'), findsOneWidget);
    expect(find.text('En este dispositivo no se envían mensajes.'), findsOneWidget);
  });
}
