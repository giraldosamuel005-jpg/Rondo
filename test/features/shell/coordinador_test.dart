import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/alertas_cuidador.dart';
import 'package:rondo/core/alertas/control_alerta.dart';
import 'package:rondo/core/biometria/servicio_biometria.dart';
import 'package:rondo/core/fondo/fondo.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/notificaciones/notificaciones.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/core/vinculos/vinculos.dart';
import 'package:rondo/features/alert/fall_alert_page.dart';
import 'package:rondo/features/auth/bloqueo_page.dart';
import 'package:rondo/features/cuidador/alerta_entrante_page.dart';
import 'package:rondo/features/shell/coordinador.dart';

import '../../support/alertas_falsas.dart';
import '../../support/servidor_vinculos_falso.dart';

void main() {
  const ana = Contacto(nombre: 'Ana', celular: '3001234567');
  late NotificacionesFalsas avisos;

  setUp(() => avisos = NotificacionesFalsas());

  AppState persona() => AppState()
    ..iniciarSesion('3104567890')
    ..guardarPerfil(nombre: 'Rosa', tipo: TipoCuenta.paraMi)
    ..agregarContacto(ana)
    ..cambiarPermiso(PermisoSistema.sms, true)
    ..activarRonda();

  Future<ControlAlerta> montar(
    WidgetTester tester,
    AppState estado, {
    AlertasCuidador? cuidador,
    Vinculos? vinculos,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final control = ControlAlerta(
      estado,
      sms: SmsFalso(),
      servidor: ServidorAlertasFalso(),
      alarma: AlarmaFalsa(),
      reloj: tester.binding.clock.now,
    );
    addTearDown(control.dispose);
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: estado),
          ChangeNotifierProvider.value(value: control),
          if (vinculos != null) ChangeNotifierProvider.value(value: vinculos),
          if (cuidador != null) ChangeNotifierProvider.value(value: cuidador),
          Provider<Notificaciones>.value(value: avisos),
          Provider<ServicioFondo>.value(value: FondoFalso()),
          Provider<ServicioBiometria>.value(value: const ServicioBiometriaNoDisponible()),
        ],
        child: MaterialApp(
          navigatorKey: navegador,
          theme: ThemeData(extensions: [RondoColors.light]),
          builder: (context, child) => Coordinador(
            navegador: navegador,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
              child: child!,
            ),
          ),
          home: const Scaffold(body: Text('Inicio de mentiras')),
        ),
      ),
    );
    await tester.pump();
    return control;
  }

  Future<void> irA(WidgetTester tester, List<AppLifecycleState> estados) async {
    for (final e in estados) {
      tester.binding.handleAppLifecycleStateChanged(e);
    }
    await tester.pump();
  }

  const alFondo = [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused];
  const alFrente = [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed];

  testWidgets('una caída abre la alerta sobre cualquier pantalla y "Estoy bien" la cierra', (tester) async {
    final control = await montar(tester, persona());

    control.iniciar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FallAlertPage), findsOneWidget);
    expect(avisos.caidas, 0); // Ya la está viendo: no hace falta notificación

    await tester.tap(find.text('Estoy bien'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FallAlertPage), findsNothing);
    expect(find.text('Inicio de mentiras'), findsOneWidget);
  });

  testWidgets('con la app fuera de la vista sale la notificación, y sus botones sirven', (tester) async {
    final control = await montar(tester, persona());
    await irA(tester, alFondo);

    control.iniciar();
    await tester.pump();
    expect(avisos.caidas, 1);

    avisos.toques.add(
      const RespuestaNotificacion(RespuestaNotificacion.caida, accion: RespuestaNotificacion.accionEstoyBien),
    );
    expect(control.activa, isFalse);
    await irA(tester, alFrente);
  });

  testWidgets('si sale de la app a mitad de la cuenta, aparece la notificación', (tester) async {
    final control = await montar(tester, persona());
    control.iniciar();
    await tester.pump();
    expect(avisos.caidas, 0);

    await irA(tester, alFondo);
    expect(avisos.caidas, 1);
    control.estoyBien();
    await irA(tester, alFrente);
  });

  testWidgets('al volver después de quitarla de las recientes pide otra vez la huella (RF-02)', (tester) async {
    await montar(tester, persona()..cambiarHuellaActivada(true));

    await irA(tester, [...alFondo, ...alFrente]); // Solo salió y volvió
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BloqueoPage), findsNothing);

    await irA(tester, [...alFondo, AppLifecycleState.detached, AppLifecycleState.resumed]);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BloqueoPage), findsOneWidget);
  });

  testWidgets('con una alerta en curso no se pide la huella: primero la emergencia', (tester) async {
    final control = await montar(tester, persona()..cambiarHuellaActivada(true));
    await irA(tester, [...alFondo, AppLifecycleState.detached]);
    control.iniciar();
    await irA(tester, [AppLifecycleState.resumed]);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BloqueoPage), findsNothing);
    expect(find.byType(FallAlertPage), findsOneWidget);
    control.estoyBien();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('cuidador: la alerta abre su pantalla una sola vez y suena', (tester) async {
    final servidor = ServidorFalso();
    final rosa = persona();
    final estado = AppState()
      ..iniciarSesion('3001234567')
      ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
    final deRosa = Vinculos(servidor.celular('rosa'), rosa);
    final deAna = Vinculos(servidor.celular('ana'), estado);
    final alarma = AlarmaFalsa();
    final cuidador = AlertasCuidador(estado, deAna, alarma: alarma, notificaciones: avisos);
    for (final cerrar in [deRosa.dispose, deAna.dispose, cuidador.dispose]) {
      addTearDown(cerrar);
    }
    await montar(tester, estado, cuidador: cuidador, vinculos: deAna);
    final invitacion = await deRosa.invitar(ana);
    await deAna.aceptar(invitacion.codigo);
    await tester.pump();

    await deRosa.publicarAlerta(AlertaCompartida(id: 'a1', fecha: DateTime.now()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertaEntrantePage), findsOneWidget);
    expect(alarma.sonando, isTrue);

    // Tocar además la notificación no abre otra encima.
    avisos.toques.add(const RespuestaNotificacion('${RespuestaNotificacion.alerta}rosa'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertaEntrantePage), findsOneWidget);

    await tester.tap(find.text('Ya la atendí'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertaEntrantePage), findsNothing);
    expect(alarma.sonando, isFalse);
    expect(servidor.alertas['rosa']!.single.atendida, isTrue);
    cuidador.silenciar();
    await tester.pump();
  });
}
