import 'package:flutter/material.dart' show ChangeNotifier, ThemeMode;

import '../models/contacto.dart';
import '../models/evento.dart';
import '../models/tipo_cuenta.dart';

/// "Cerebro" de la app: guarda los datos de la persona y avisa a las
/// pantallas cuando algo cambia.
///
/// Por ahora todo vive en memoria (se pierde al cerrar la app). Cuando
/// conectemos Firebase, solo cambia lo de adentro de esta clase; las
/// pantallas siguen igual.
///
/// En `build()` se lee con `context.watch<AppState>()` (se redibuja al cambiar);
/// en acciones (botones) se usa `context.read<AppState>()`.
class AppState extends ChangeNotifier {
  // ---------- Datos (privados: solo esta clase los cambia) ----------
  String? _celular;
  String _nombre = '';
  TipoCuenta? _tipo;
  final List<Contacto> _contactos = [];
  bool _permisoUbicacion = false;
  bool _permisoSensores = false;
  DateTime? _rondaActivaDesde;
  bool _rondaEnPausa = false;
  final List<Evento> _eventos = [];

  /// Preferencia de la persona; no se borra al cerrar sesión.
  ThemeMode _modoTema = ThemeMode.system;

  // ---------- Lectura (las pantallas leen por aquí) ----------
  String? get celular => _celular;
  String get nombre => _nombre;
  TipoCuenta? get tipo => _tipo;
  List<Contacto> get contactos => List.unmodifiable(_contactos);
  bool get permisoUbicacion => _permisoUbicacion;
  bool get permisoSensores => _permisoSensores;
  DateTime? get rondaActivaDesde => _rondaActivaDesde;
  bool get rondaEnPausa => _rondaEnPausa;
  ThemeMode get modoTema => _modoTema;

  /// Del más reciente al más antiguo.
  List<Evento> get eventos => List.unmodifiable(_eventos.reversed);

  // ---------- Acciones (las pantallas cambian datos por aquí) ----------

  /// Después de escribir bien el código SMS.
  void iniciarSesion(String celular) {
    _celular = celular;
    notifyListeners();
  }

  /// Paso 1 del registro.
  void guardarPerfil({required String nombre, required TipoCuenta tipo}) {
    _nombre = nombre;
    _tipo = tipo;
    notifyListeners();
  }

  void agregarContacto(Contacto contacto) {
    _contactos.add(contacto);
    notifyListeners();
  }

  void quitarContacto(Contacto contacto) {
    _contactos.remove(contacto);
    notifyListeners();
  }

  void cambiarPermisoUbicacion(bool valor) {
    _permisoUbicacion = valor;
    notifyListeners();
  }

  void cambiarPermisoSensores(bool valor) {
    _permisoSensores = valor;
    notifyListeners();
  }

  /// Botón "Activar mi ronda".
  void activarRonda() {
    _rondaActivaDesde = DateTime.now();
    _rondaEnPausa = false;
    _registrar(TipoEvento.rondaActivada);
    notifyListeners();
  }

  void alternarPausa() {
    _rondaEnPausa = !_rondaEnPausa;
    _registrar(_rondaEnPausa ? TipoEvento.rondaPausada : TipoEvento.rondaReanudada);
    notifyListeners();
  }

  /// Ajustes → Apariencia: automático, claro u oscuro.
  void cambiarModoTema(ThemeMode modo) {
    _modoTema = modo;
    notifyListeners();
  }

  /// Borra los datos de la cuenta y vuelve al estado inicial.
  /// La preferencia de apariencia se conserva.
  void cerrarSesion() {
    _celular = null;
    _nombre = '';
    _tipo = null;
    _contactos.clear();
    _permisoUbicacion = false;
    _permisoSensores = false;
    _rondaActivaDesde = null;
    _rondaEnPausa = false;
    _eventos.clear();
    notifyListeners();
  }

  void _registrar(TipoEvento tipo) {
    _eventos.add(Evento(tipo: tipo, fecha: DateTime.now()));
  }
}
