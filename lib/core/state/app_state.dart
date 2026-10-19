import 'package:flutter/material.dart' show ChangeNotifier, ThemeMode;

import '../models/consentimiento.dart';
import '../models/contacto.dart';
import '../models/evento.dart';
import '../models/ficha_medica.dart';
import '../models/tipo_cuenta.dart';
import '../permisos/permisos_sistema.dart';

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

  /// Cada consentimiento dado, con la fecha en que se dio (RF-30).
  final Map<TipoConsentimiento, DateTime> _consentimientos = {};

  /// Cuándo aceptó el aviso "no reemplaza al 123" (RF-34).
  DateTime? _avisoAceptadoEn;

  /// RF-23. Por ahora en memoria; al guardarla en el celular, cifrada (7.1).
  FichaMedica? _fichaMedica;

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
  bool tienePermiso(PermisoSistema permiso) => switch (permiso) {
        PermisoSistema.ubicacion => _permisoUbicacion,
        PermisoSistema.sensores => _permisoSensores,
      };
  bool tieneConsentimiento(TipoConsentimiento tipo) => _consentimientos.containsKey(tipo);

  /// `null` si no lo ha dado.
  DateTime? fechaConsentimiento(TipoConsentimiento tipo) => _consentimientos[tipo];
  DateTime? get avisoAceptadoEn => _avisoAceptadoEn;

  /// `null` si todavía no la ha llenado.
  FichaMedica? get fichaMedica => _fichaMedica;

  /// La ficha es de quien se cuida, no del cuidador.
  bool get usaFichaMedica => _tipo == TipoCuenta.paraMi;
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

  /// Paso 1 del registro. Solo se llega aquí con el aviso del 123 aceptado.
  void guardarPerfil({required String nombre, required TipoCuenta tipo}) {
    _nombre = nombre;
    _tipo = tipo;
    _avisoAceptadoEn ??= DateTime.now();
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

  /// El interruptor de ubicación, con su razón al lado, es el consentimiento
  /// explícito de ubicación (RF-30).
  void cambiarPermisoUbicacion(bool valor) {
    _permisoUbicacion = valor;
    _marcarConsentimiento(TipoConsentimiento.ubicacion, valor);
    notifyListeners();
  }

  /// Lo que la persona decide con el interruptor.
  void cambiarPermiso(PermisoSistema permiso, bool valor) => switch (permiso) {
        PermisoSistema.ubicacion => cambiarPermisoUbicacion(valor),
        PermisoSistema.sensores => cambiarPermisoSensores(valor),
      };

  /// La persona quitó el permiso desde los ajustes del celular (RF-32).
  /// Se apaga el interruptor, pero el consentimiento que dio en Rondó se
  /// conserva: no lo retiró aquí, y si vuelve a activar el permiso sigue
  /// valiendo la fecha original.
  void permisoRevocadoPorSistema(PermisoSistema permiso) {
    switch (permiso) {
      case PermisoSistema.ubicacion:
        _permisoUbicacion = false;
      case PermisoSistema.sensores:
        _permisoSensores = false;
    }
    notifyListeners();
  }

  void darConsentimiento(TipoConsentimiento tipo) {
    _marcarConsentimiento(tipo, true);
    notifyListeners();
  }

  /// Retirar el consentimiento de datos médicos borra la ficha (Ley 1581).
  void retirarConsentimiento(TipoConsentimiento tipo) {
    _marcarConsentimiento(tipo, false);
    if (tipo == TipoConsentimiento.datosMedicos) _fichaMedica = null;
    notifyListeners();
  }

  /// Sin consentimiento de datos médicos no se guarda nada (RF-30): la
  /// pantalla debe pedirlo antes.
  void guardarFichaMedica(FichaMedica ficha) {
    if (!tieneConsentimiento(TipoConsentimiento.datosMedicos)) {
      throw StateError('Falta el consentimiento de datos médicos.');
    }
    _fichaMedica = ficha;
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

  /// Resultado de una alerta de caída (RF-13 a RF-15).
  /// `enviada`: se avisó a los contactos; si no, la persona dijo "Estoy bien".
  void registrarAlerta({required bool enviada, String? detalle}) {
    _registrar(
      enviada ? TipoEvento.alertaEnviada : TipoEvento.alertaCancelada,
      detalle: detalle,
    );
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
    _consentimientos.clear();
    _avisoAceptadoEn = null;
    _fichaMedica = null;
    _rondaActivaDesde = null;
    _rondaEnPausa = false;
    _eventos.clear();
    notifyListeners();
  }

  /// Guarda la fecha solo la primera vez que se da; al retirarlo se borra.
  void _marcarConsentimiento(TipoConsentimiento tipo, bool dado) {
    if (dado) {
      _consentimientos.putIfAbsent(tipo, DateTime.now);
    } else {
      _consentimientos.remove(tipo);
    }
  }

  void _registrar(TipoEvento tipo, {String? detalle}) {
    _eventos.add(Evento(tipo: tipo, fecha: DateTime.now(), detalle: detalle));
  }
}
