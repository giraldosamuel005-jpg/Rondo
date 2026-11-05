import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/tipo_cuenta.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/home/home_page.dart';

void main() {
  const canal = MethodChannel('plugins.flutter.io/url_launcher');

  Future<void> mostrarInicio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final estado = AppState()
      ..iniciarSesion('3206523232')
      ..guardarPerfil(nombre: 'Ana', tipo: TipoCuenta.paraMi)
      ..activarRonda();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: Scaffold(body: HomePage(onVerContactos: () {}, onVerAjustes: () {})),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('el botón abre el marcador con el 123', (tester) async {
    String? abierto;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (llamada) async {
      abierto = (llamada.arguments as Map)['url'] as String?;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));

    await mostrarInicio(tester);
    await tester.tap(find.text('Llamar al 123'));
    await tester.pump();

    expect(abierto, 'tel:123');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('si no se puede abrir el marcador, lo avisa', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));

    await mostrarInicio(tester);
    await tester.tap(find.text('Llamar al 123'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No se pudo abrir el marcador del teléfono.'), findsOneWidget);
  });
}
