import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/state/app_state.dart';
import 'package:rondo/core/theme/rondo_colors.dart';
import 'package:rondo/core/widgets/permisos_card.dart';

/// Responde siempre lo mismo, sin tocar Android.
class _SistemaFalso implements PermisosSistema {
  _SistemaFalso(this.respuesta);

  final EstadoPermiso respuesta;
  final pedidos = <PermisoSistema>[];
  var ajustesAbiertos = 0;

  @override
  Future<EstadoPermiso> pedir(PermisoSistema permiso) async {
    pedidos.add(permiso);
    return respuesta;
  }

  @override
  Future<EstadoPermiso> consultar(PermisoSistema permiso) async => respuesta;

  @override
  Future<bool> abrirAjustes() async {
    ajustesAbiertos++;
    return true;
  }
}

void main() {
  late AppState estado;

  // Sin el tema completo de Rondó: sus fuentes se descargan de internet.
  Future<void> montar(WidgetTester tester, _SistemaFalso sistema) => tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: estado,
          child: MaterialApp(
            theme: ThemeData(extensions: [RondoColors.light]),
            home: Scaffold(body: PermisosCard(permisos: sistema)),
          ),
        ),
      );

  setUp(() => estado = AppState());

  testWidgets('si el sistema concede, el interruptor queda encendido', (tester) async {
    final sistema = _SistemaFalso(EstadoPermiso.concedido);
    await montar(tester, sistema);

    await tester.tap(find.text('Ubicación siempre'));
    await tester.pumpAndSettle();

    expect(sistema.pedidos, [PermisoSistema.ubicacion]);
    expect(estado.permisoUbicacion, isTrue);
    expect(find.textContaining('Necesitamos tu permiso'), findsNothing);
  });

  testWidgets('si el sistema niega, queda apagado y se muestra el error', (tester) async {
    final sistema = _SistemaFalso(EstadoPermiso.denegado);
    await montar(tester, sistema);

    await tester.tap(find.text('Sensores de movimiento'));
    await tester.pumpAndSettle();

    expect(estado.permisoSensores, isFalse);
    expect(
      find.text('Activa el permiso de sensores de movimiento para usar la detección de caídas.'),
      findsOneWidget,
    );
    expect(find.text('Abrir ajustes'), findsNothing);
  });

  testWidgets('si está bloqueado, ofrece abrir los ajustes del celular', (tester) async {
    final sistema = _SistemaFalso(EstadoPermiso.bloqueado);
    await montar(tester, sistema);

    await tester.tap(find.text('Ubicación siempre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();

    expect(estado.permisoUbicacion, isFalse);
    expect(sistema.ajustesAbiertos, 1);
  });

  testWidgets('apagar no le pregunta nada al sistema', (tester) async {
    final sistema = _SistemaFalso(EstadoPermiso.concedido);
    estado.cambiarPermisoUbicacion(true);
    await montar(tester, sistema);

    await tester.tap(find.text('Ubicación siempre'));
    await tester.pumpAndSettle();

    expect(sistema.pedidos, isEmpty);
    expect(estado.permisoUbicacion, isFalse);
  });
}
