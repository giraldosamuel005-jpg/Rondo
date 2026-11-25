import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/persona_a_cargo.dart';
import '../notificaciones/notificaciones.dart';
import '../state/app_state.dart';
import '../utils/formato.dart';
import '../vinculos/vinculos.dart';
import 'aviso_alerta.dart';

/// Cuidador: qué pasa cuando llega una alerta de alguien que cuida (RF-15).
/// Suena la alarma, sale la notificación y se pide abrir la pantalla.
///
/// Vive aparte de las pantallas: con la app en segundo plano no se dibuja
/// nada, pero la alarma y la notificación igual tienen que salir.
class AlertasCuidador extends ChangeNotifier {
  AlertasCuidador(this._estado, this._vinculos, {this.alarma, this.notificaciones}) {
    _sub = _vinculos.alertasNuevas.listen(_alLlegar);
    _estado.addListener(_revisar);
  }

  final AppState _estado;
  final Vinculos _vinculos;
  final Alarma? alarma;
  final Notificaciones? notificaciones;

  /// Si nadie la toca, la alarma deja de sonar (la alerta sigue sin atender).
  static const maximoSonando = Duration(minutes: 2);

  late final StreamSubscription<String> _sub;
  final _abrir = StreamController<String>.broadcast();
  final Set<String> _pendientes = {};
  String? _sonandoPor;
  Timer? _fin;

  /// El ID de la persona cada vez que hay que abrir su pantalla de alerta.
  Stream<String> get abrir => _abrir.stream;

  /// La persona por la que está sonando la alarma.
  String? get sonandoPor => _sonandoPor;

  Future<void> _alLlegar(String personaId) async {
    final persona = _estado.personaACargo(personaId);
    if (persona == null) return;
    _pendientes.add(personaId);
    _sonandoPor = personaId;
    _fin?.cancel();
    _fin = Timer(maximoSonando, silenciar);
    final alerta = persona.alertas.where((a) => !a.atendida).firstOrNull;
    notificaciones?.alertaDePersona(
      personaId: personaId,
      titulo: titulo(persona, alerta),
      cuerpo: 'Toca para llamar o ver dónde está.',
    );
    _abrir.add(personaId);
    notifyListeners();
    await alarma?.sonar();
    if (_sonandoPor == null) alarma?.parar(); // La silenciaron mientras cargaba
  }

  /// "Rosa necesita ayuda", o que es una prueba.
  static String titulo(PersonaACargo persona, AlertaPersona? alerta) {
    final nombre = primerNombre(persona.nombre);
    return (alerta?.prueba ?? false) ? 'Prueba de alerta de $nombre' : '$nombre necesita ayuda';
  }

  /// Apenas el cuidador hace algo, deja de sonar.
  void silenciar() {
    _fin?.cancel();
    alarma?.parar();
    if (_sonandoPor == null) return;
    _sonandoPor = null;
    notifyListeners();
  }

  /// Si otro cuidador la atendió, o la persona avisó que está bien, aquí
  /// también se calla y se quita la notificación.
  void _revisar() {
    for (final id in _pendientes.toList()) {
      final persona = _estado.personaACargo(id);
      if (persona != null && persona.alertas.any((a) => !a.atendida)) continue;
      _pendientes.remove(id);
      notificaciones?.quitarAlertaDePersona(id);
      if (_sonandoPor == id) silenciar();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _fin?.cancel();
    _estado.removeListener(_revisar);
    alarma?.parar();
    _abrir.close();
    super.dispose();
  }
}
