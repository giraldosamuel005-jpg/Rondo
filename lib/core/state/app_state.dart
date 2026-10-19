import 'package:flutter/foundation.dart';

import '../models/contacto.dart';
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

  // ---------- Lectura (las pantallas leen por aquí) ----------
  String? get celular => _celular;
  String get nombre => _nombre;
  TipoCuenta? get tipo => _tipo;
  List<Contacto> get contactos => List.unmodifiable(_contactos);
  bool get permisoUbicacion => _permisoUbicacion;
  bool get permisoSensores => _permisoSensores;
  DateTime? get rondaActivaDesde => _rondaActivaDesde;
  bool get rondaEnPausa => _rondaEnPausa;

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
    notifyListeners();
  }

  void alternarPausa() {
    _rondaEnPausa = !_rondaEnPausa;
    notifyListeners();
  }

  /// Borra todo y vuelve al estado inicial.
  void cerrarSesion() {
    _celular = null;
    _nombre = '';
    _tipo = null;
    _contactos.clear();
    _permisoUbicacion = false;
    _permisoSensores = false;
    _rondaActivaDesde = null;
    _rondaEnPausa = false;
    notifyListeners();
  }
}
