import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/biometria/servicio_biometria.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/persistencia/almacen.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/auth/bloqueo_page.dart';
import 'package:rondo/features/settings/huella.dart';
import 'package:rondo/features/shell/main_shell.dart';

/// Huella de mentira: responde lo que le digamos y cuenta cuántas veces se la pidieron.
class BiometriaFalsa implements ServicioBiometria {
  BiometriaFalsa(this.resultado, {this.hayHuella = true});

  final ResultadoBiometria resultado;
  final bool hayHuella;
  int pedidas = 0;

  @override
  Future<bool> get disponible async => hayHuella;

  @override
  Future<ResultadoBiometria> autenticar(String motivo) async {
    pedidas++;
    return resultado;
  }
}

void main() {
  AppState cuentaRegistrada() => AppState()
    ..iniciarSesion('3206523232')
    ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador)
    ..cambiarHuellaActivada(true);

  Future<void> abrir(WidgetTester tester, AppState estado, ServicioBiometria biometria, Widget pantalla) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: estado),
          Provider<ServicioBiometria>.value(value: biometria),
        ],
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: pantalla,
        ),
      ),
    );
    await tester.pump(); // primer cuadro
    await tester.pump(); // la huella que se pide sola al abrir
  }

  group('pantalla de huella al abrir la app', () {
    testWidgets('pide la huella sola y, si es válida, entra a la app', (tester) async {
      final biometria = BiometriaFalsa(ResultadoBiometria.valido);
      await abrir(tester, cuentaRegistrada(), biometria, const BloqueoPage());
      await tester.pump(const Duration(milliseconds: 500));

      expect(biometria.pedidas, 1);
      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets('si no la reconoce, lo dice y se puede intentar otra vez', (tester) async {
      final biometria = BiometriaFalsa(ResultadoBiometria.noValido);
      await abrir(tester, cuentaRegistrada(), biometria, const BloqueoPage());

      expect(find.text(MensajesBiometria.noValido), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);

      await tester.tap(find.text('Usar mi huella'));
      await tester.pump();
      await tester.pump();
      expect(biometria.pedidas, 2);
    });

    testWidgets('sin huella guardada en el celular, manda al código SMS', (tester) async {
      final biometria = BiometriaFalsa(ResultadoBiometria.noDisponible);
      await abrir(tester, cuentaRegistrada(), biometria, const BloqueoPage());

      expect(find.text(MensajesBiometria.noDisponible), findsOneWidget);
      expect(find.text('Entrar con mi código SMS'), findsOneWidget);
    });

    testWidgets('con demasiados intentos, el sistema la bloquea y se avisa', (tester) async {
      final biometria = BiometriaFalsa(ResultadoBiometria.bloqueado);
      await abrir(tester, cuentaRegistrada(), biometria, const BloqueoPage());

      expect(find.text(MensajesBiometria.bloqueado), findsOneWidget);
    });
  });

  group('activar la huella', () {
    Widget conBoton() => Builder(
          builder: (context) => TextButton(
            onPressed: () => activarHuella(context),
            child: const Text('activar'),
          ),
        );

    testWidgets('con una huella válida queda activada', (tester) async {
      final estado = AppState()
        ..iniciarSesion('3206523232')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      await abrir(tester, estado, BiometriaFalsa(ResultadoBiometria.valido), Scaffold(body: conBoton()));

      await tester.tap(find.text('activar'));
      await tester.pump();
      await tester.pump();

      expect(estado.huellaActivada, isTrue);
    });

    testWidgets('si no la reconoce, no se activa y lo dice', (tester) async {
      final estado = AppState()
        ..iniciarSesion('3206523232')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      await abrir(tester, estado, BiometriaFalsa(ResultadoBiometria.noValido), Scaffold(body: conBoton()));

      await tester.tap(find.text('activar'));
      await tester.pump();
      await tester.pump();

      expect(estado.huellaActivada, isFalse);
      expect(find.text(MensajesBiometria.noValido), findsOneWidget);
    });

    testWidgets('en un celular sin huella configurada, lo dice y no pide nada', (tester) async {
      final estado = AppState()
        ..iniciarSesion('3206523232')
        ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.cuidador);
      final biometria = BiometriaFalsa(ResultadoBiometria.valido, hayHuella: false);
      await abrir(tester, estado, biometria, Scaffold(body: conBoton()));

      await tester.tap(find.text('activar'));
      await tester.pump();
      await tester.pump();

      expect(estado.huellaActivada, isFalse);
      expect(biometria.pedidas, 0);
      expect(find.text(MensajesBiometria.noDisponible), findsOneWidget);
    });
  });

  group('la preferencia', () {
    test('se guarda y vuelve al abrir la app', () async {
      final almacen = AlmacenMemoria();
      final estado = await AppState.cargar(almacen)
        ..iniciarSesion('3206523232')
        ..cambiarHuellaActivada(true)
        ..marcarHuellaOfrecida();
      await estado.guardadoPendiente;

      final nuevo = await AppState.cargar(almacen);
      expect(nuevo.huellaActivada, isTrue);
      expect(nuevo.huellaOfrecida, isTrue);
    });

    test('al cerrar sesión se borra: la huella era de esa cuenta', () {
      final estado = cuentaRegistrada()..marcarHuellaOfrecida();
      estado.cerrarSesion();

      expect(estado.huellaActivada, isFalse);
      expect(estado.huellaOfrecida, isFalse);
    });
  });
}
