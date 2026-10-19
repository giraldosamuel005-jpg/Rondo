import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rondo/core/models/consentimiento.dart';
import 'package:rondo/core/permisos/permisos_sistema.dart';
import 'package:rondo/core/permisos/vigilante_permisos.dart';
import 'package:rondo/core/state/app_state.dart';

/// Un "celular" donde la prueba decide qué permisos están concedidos.
class _SistemaFalso implements PermisosSistema {
  final concedidos = <PermisoSistema>{};
  final consultados = <PermisoSistema>[];

  @override
  Future<EstadoPermiso> consultar(PermisoSistema permiso) async {
    consultados.add(permiso);
    return concedidos.contains(permiso) ? EstadoPermiso.concedido : EstadoPermiso.denegado;
  }

  @override
  Future<EstadoPermiso> pedir(PermisoSistema permiso) => consultar(permiso);

  @override
  Future<bool> abrirAjustes() async => true;
}

void main() {
  late AppState estado;
  late _SistemaFalso sistema;

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: estado,
        child: MaterialApp(
          builder: (context, child) => VigilantePermisos(permisos: sistema, child: child!),
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle(); // Deja correr la revisión inicial
  }

  Future<void> volverAlFrente(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  setUp(() {
    estado = AppState();
    sistema = _SistemaFalso();
  });

  testWidgets('si el permiso sigue concedido, no cambia nada', (tester) async {
    sistema.concedidos.add(PermisoSistema.ubicacion);
    estado.cambiarPermisoUbicacion(true);

    await montar(tester);

    expect(estado.permisoUbicacion, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('al abrir la app, si quitaron la ubicación, apaga y avisa', (tester) async {
    estado.cambiarPermisoUbicacion(true); // Rondó cree que lo tiene; el sistema no

    await montar(tester);

    expect(estado.permisoUbicacion, isFalse);
    expect(find.textContaining('Desactivaste el permiso de ubicación'), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsOneWidget);
  });

  testWidgets('al volver de los ajustes del celular, detecta el permiso quitado', (tester) async {
    sistema.concedidos.add(PermisoSistema.sensores);
    estado.cambiarPermisoSensores(true);
    await montar(tester);
    expect(estado.permisoSensores, isTrue);

    sistema.concedidos.clear(); // La persona lo quita en los ajustes
    await volverAlFrente(tester);

    expect(estado.permisoSensores, isFalse);
    expect(find.textContaining('Desactivaste el permiso de sensores'), findsOneWidget);
  });

  testWidgets('no pregunta por permisos que la persona tiene apagados', (tester) async {
    await montar(tester);
    await volverAlFrente(tester);

    expect(sistema.consultados, isEmpty);
  });

  testWidgets('el consentimiento de ubicación se conserva aunque quiten el permiso', (tester) async {
    estado.cambiarPermisoUbicacion(true);
    final fecha = estado.fechaConsentimiento(TipoConsentimiento.ubicacion);

    await montar(tester);

    expect(estado.permisoUbicacion, isFalse);
    expect(estado.fechaConsentimiento(TipoConsentimiento.ubicacion), fecha);
  });
}
