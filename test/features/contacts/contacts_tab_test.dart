import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/contacto.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/features/contacts/contacts_tab.dart';

void main() {
  const canal = MethodChannel('plugins.flutter.io/url_launcher');
  late AppState estado;
  String? abierto;

  Future<void> mostrar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    abierto = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, (llamada) async {
      abierto = (llamada.arguments as Map)['url'] as String?;
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null));

    estado = AppState()
      ..agregarContacto(const Contacto(nombre: 'Ana', celular: '3001234567'))
      ..agregarContacto(const Contacto(nombre: 'Luis', celular: '3104445566'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
          theme: ThemeData(extensions: [RondoColors.light]),
          home: const Scaffold(body: ContactsTab()),
        ),
      ),
    );
  }

  testWidgets('el botón de teléfono llama a ese contacto, con el +57', (tester) async {
    await mostrar(tester);

    await tester.tap(find.byTooltip('Llamar a Luis'));
    await tester.pump();

    expect(abierto, 'tel:+573104445566');
  });

  testWidgets('llamar no abre la confirmación de quitar ni quita al contacto', (tester) async {
    await mostrar(tester);

    await tester.tap(find.byTooltip('Llamar a Ana'));
    await tester.pumpAndSettle();

    expect(find.textContaining('¿Quitar'), findsNothing);
    expect(estado.contactos, hasLength(2));
  });

  testWidgets('tocar el nombre no llama: sigue siendo para quitarlo', (tester) async {
    await mostrar(tester);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(abierto, isNull);
    expect(find.textContaining('¿Quitar'), findsOneWidget);
  });
}
