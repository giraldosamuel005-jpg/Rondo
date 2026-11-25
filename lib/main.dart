import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/alertas/alertas_cuidador.dart';
import 'core/alertas/aviso_alerta.dart';
import 'core/alertas/control_alerta.dart';
import 'core/biometria/servicio_biometria.dart';
import 'core/deteccion/vigilante_caidas.dart';
import 'core/fondo/fondo.dart';
import 'core/notificaciones/notificaciones.dart';
import 'core/permisos/vigilante_permisos.dart';
import 'core/persistencia/almacen_local.dart';
import 'core/recordatorios/recordatorios.dart';
import 'core/state/app_state.dart';
import 'core/theme/rondo_theme.dart';
import 'core/widgets/glass.dart';
import 'core/vinculos/servicio_vinculos_firebase.dart';
import 'core/vinculos/vinculos.dart';
import 'features/auth/bloqueo_page.dart';
import 'features/auth/login_page.dart';
import 'features/shell/coordinador.dart';
import 'features/shell/main_shell.dart';
import 'firebase_options.dart';

/// Para probar contra un Firebase local en vez del real, sin tocar sus datos:
/// `flutter run --dart-define=FIREBASE_LOCAL=10.0.2.2` (10.0.2.2 es el
/// computador, visto desde el emulador).
const _firebaseLocal = String.fromEnvironment('FIREBASE_LOCAL');

/// Con esta llave se abren pantallas (alertas) desde fuera de ellas.
final _navegador = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Necesario para leer lo guardado antes de mostrar la app.
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (proyecto rondo-fb405) solo está configurado para Android. En
  // otras plataformas la app abre igual, sin vincular cuidadores, sin alertas
  // reales y sin detección de caídas.
  final conFirebase = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (conFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (_firebaseLocal.isNotEmpty) {
      await FirebaseAuth.instance.useAuthEmulator(_firebaseLocal, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(_firebaseLocal, 8080);
    }
  }

  final estado = await AppState.cargar(AlmacenLocal());
  RondoPerf.reducir.value = estado.vidrioReducido;

  // Lo que trabaja aunque no haya pantallas (con la app cerrada, el servicio
  // en primer plano mantiene vivo todo esto).
  const gps = LectorUbicacionGps();
  final vinculos = conFirebase ? Vinculos(ServicioVinculosFirebase(), estado, ubicacion: gps) : null;
  final notificaciones = conFirebase ? NotificacionesAndroid() : null;
  final vigilante = conFirebase ? VigilanteCaidas(estado, const SensoresDelCelular()) : null;
  final fondo = conFirebase ? const ServicioFondoAndroid() : null;
  final control = ControlAlerta(
    estado,
    // En web y Windows no se envía nada: la alerta es una simulación.
    ubicacion: conFirebase ? gps : null,
    sms: conFirebase ? const EnviadorSmsAndroid() : null,
    servidor: vinculos,
    alarma: AlarmaSonora(),
  );
  vigilante?.caidas.listen((caida) => control.iniciar(detectadaA: caida.fecha));

  runApp(
    MultiProvider(
      providers: [
        // UN solo AppState para todas las pantallas, ya con los datos guardados.
        ChangeNotifierProvider.value(value: estado),
        // Huella para reingresar (RF-02).
        Provider<ServicioBiometria>.value(value: servicioBiometriaDeLaPlataforma()),
        // La alerta de la persona: cuenta regresiva, SMS y servidor (RF-13 a RF-17).
        ChangeNotifierProvider.value(value: control),
        // Cuidador ↔ persona (RF-05, RF-26, RF-27).
        if (vinculos != null) ChangeNotifierProvider.value(value: vinculos),
        // Detección de caídas con los sensores (RF-06, RF-09, RF-10).
        if (vigilante != null) ChangeNotifierProvider.value(value: vigilante),
        if (notificaciones != null) ...[
          Provider<Notificaciones>.value(value: notificaciones),
          // Alertas que le llegan al cuidador (RF-15).
          ChangeNotifierProvider(
            lazy: false,
            create: (_) =>
                AlertasCuidador(estado, vinculos!, alarma: AlarmaSonora(), notificaciones: notificaciones),
          ),
          // Avisos de toma de medicamentos (RF-22).
          ChangeNotifierProvider(
            lazy: false,
            create: (_) => Recordatorios(estado, ProgramadorAndroid(notificaciones)),
          ),
        ],
        // Seguir pendiente con la app cerrada.
        if (fondo != null) ...[
          Provider<ServicioFondo>.value(value: fondo),
          Provider(lazy: false, create: (_) => ControlFondo(estado, fondo), dispose: (_, c) => c.dispose()),
        ],
      ],
      child: RondoApp(registrado: estado.registroCompleto, conHuella: estado.huellaActivada),
    ),
  );
}

class RondoApp extends StatelessWidget {
  const RondoApp({super.key, required this.registrado, this.conHuella = false});

  /// Si ya terminó el registro, la app abre directo en Inicio.
  final bool registrado;

  /// Activó la huella (RF-02): al abrir se la pedimos antes de mostrar Inicio.
  final bool conHuella;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rondó',
      navigatorKey: _navegador,
      // Textos de Flutter (selector de hora, diálogos...) en español de Colombia.
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false, // Quita la cinta roja "DEBUG"
      theme: RondoTheme.light(),
      darkTheme: RondoTheme.dark(),
      // Automático (según el celular), claro u oscuro: se elige en Ajustes.
      themeMode: context.watch<AppState>().modoTema,
      home: !registrado
          ? const LoginPage()
          : (conHuella ? const BloqueoPage() : const MainShell()),
      // En todas las pantallas: revisa si quitaron un permiso (RF-32) y abre
      // las alertas.
      builder: (context, child) => VigilantePermisos(
        child: Coordinador(navegador: _navegador, child: child!),
      ),
    );
  }
}
