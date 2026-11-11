import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/alertas/alerta_compartida.dart';
import 'package:rondo/core/alertas/aviso_alerta.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/models/evento.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/alert/fall_alert_page.dart';

import '../../core/alertas/aviso_alerta_test.dart' show SmsFalso, UbicacionFalsa;

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

  Future<void> mostrar(WidgetTester tester, {AvisoDeAlerta? aviso}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: estado),
          if (aviso != null) Provider.value(value: aviso),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [RondoColors.light]),
          // La letra de las pruebas (cuadros anchos) no cabe en el anillo de la
          // cuenta regresiva; con las fuentes de Rondó sí cabe.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.7)),
            child: child!,
          ),
          home: FallAlertPage(detectadaA: DateTime(2026, 11, 10, 15, 42)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pedirAyuda(WidgetTester tester) async {
    await tester.tap(find.text('Pedir ayuda ahora'));
    await tester.pump(); // "Avisando…"
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('pedir ayuda envía el SMS a cada contacto y lo deja en el Historial', (tester) async {
    final sms = SmsFalso();
    await mostrar(tester, aviso: AvisoDeAlerta(ubicacion: UbicacionFalsa(const Posicion(3.43, -76.52)), sms: sms));

    await pedirAyuda(tester);

    expect(sms.enviados.keys, [ana.celular, luis.celular]);
    expect(find.text('Avisamos a tus contactos'), findsOneWidget);
    expect(find.textContaining('Simulación'), findsNothing);
    final evento = estado.eventos.firstWhere((e) => e.tipo == TipoEvento.alertaEnviada);
    expect(evento.detalle, 'Avisamos a Ana y Luis');
  });

  testWidgets('si algo falla lo dice con el mensaje del requisito', (tester) async {
    await mostrar(
      tester,
      aviso: AvisoDeAlerta(ubicacion: UbicacionFalsa(null), sms: SmsFalso(fallanA: {luis.celular})),
    );

    await pedirAyuda(tester);

    expect(find.text('No se pudo obtener tu ubicación. Se avisó a tus contactos sin ella.'), findsOneWidget);
    expect(find.text('No se pudo enviar el SMS a Luis. Verifica tu señal y tu saldo.'), findsOneWidget);
  });

  testWidgets('si no le llega a nadie, alarma local y botón al 123 (RF-17)', (tester) async {
    await mostrar(tester, aviso: AvisoDeAlerta(ubicacion: UbicacionFalsa(null), sms: SmsFalso(sinPermiso: true)));

    await pedirAyuda(tester);

    expect(find.text('No pudimos avisar a nadie'), findsOneWidget);
    expect(find.text('Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana.'), findsOneWidget);
    expect(find.text('La app no tiene permiso para enviar SMS. Actívalo en ajustes.'), findsOneWidget);
    expect(find.text('Llamar al 123'), findsOneWidget);
  });

  testWidgets('sin el servicio de alertas es una simulación y lo dice', (tester) async {
    await mostrar(tester);

    await pedirAyuda(tester);

    expect(find.text('Avisamos a tus contactos'), findsOneWidget);
    expect(find.textContaining('Simulación'), findsOneWidget);
  });
}
