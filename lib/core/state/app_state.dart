import 'package:flutter/material.dart' show ChangeNotifier, ThemeMode;

import '../models/consentimiento.dart';
import '../models/contacto.dart';
import '../models/evento.dart';
import '../models/ficha_medica.dart';
import '../models/medicamento.dart';
import '../models/persona_a_cargo.dart';
import '../models/tipo_cuenta.dart';
import '../permisos/permisos_sistema.dart';
import '../persistencia/almacen.dart';
import '../persistencia/serializacion.dart';

/// "Cerebro" de la app: guarda los datos de la persona y avisa a las
/// pantallas cuando algo cambia.
///
/// Si recibe un [Almacen], se guarda solo cada vez que algo cambia (en el
/// celular con `AlmacenLocal`). Sin almacén (como en las pruebas) vive solo
/// en memoria. Con Firebase se cambia el almacén; las pantallas siguen igual.
///
/// En `build()` se lee con `context.watch<AppState>()` (se redibuja al cambiar);
/// en acciones (botones) se usa `context.read<AppState>()`.
class AppState extends ChangeNotifier {
  AppState({this._almacen});

  /// Crea el estado con lo que había guardado en [almacen].
  static Future<AppState> cargar(Almacen almacen) async {
    final estado = AppState(almacen: almacen);
    final datos = await almacen.leerDatos();
    final ficha = await almacen.leerFicha();
    if (datos != null) estado._cargarDesde(datos, ficha);
    return estado;
  }

  final Almacen? _almacen;

  /// Cadena de guardados: cada uno espera al anterior, así nunca se pisan.
  Future<void> _guardado = Future.value();

  /// Espera a que termine de guardar (útil en pruebas).
  Future<void> get guardadoPendiente => _guardado;

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

  final List<Medicamento> _medicamentos = [];
  final List<TomaMedicamento> _tomas = [];

  /// Solo en cuentas de cuidador: quienes lo invitaron (RF-26).
  final List<PersonaACargo> _personas = [];

  DateTime? _rondaActivaDesde;
  bool _rondaEnPausa = false;
  final List<Evento> _eventos = [];

  /// Preferencia de la persona; no se borra al cerrar sesión.
  ThemeMode _modoTema = ThemeMode.system;

  // ---------- Lectura (las pantallas leen por aquí) ----------

  /// Ya terminó el registro: al abrir la app va a Inicio. Quien se cuida
  /// termina al activar su ronda; el cuidador, al elegir su tipo de cuenta.
  bool get registroCompleto =>
      _celular != null && _tipo != null && (esCuidador || _rondaActivaDesde != null);

  bool get esCuidador => _tipo == TipoCuenta.cuidador;

  // ---------- Cuidador (RF-26) ----------
  List<PersonaACargo> get personasACargo => List.unmodifiable(_personas);

  PersonaACargo? personaACargo(String id) {
    for (final p in _personas) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Todas las alertas de las personas a cargo, de la más nueva a la más vieja.
  List<({PersonaACargo persona, AlertaPersona alerta})> get alertasDePersonas {
    final todas = [
      for (final p in _personas)
        for (final a in p.alertas) (persona: p, alerta: a),
    ];
    todas.sort((x, y) => y.alerta.fecha.compareTo(x.alerta.fecha));
    return todas;
  }

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

  // ---------- Medicamentos (RF-20 a RF-22) ----------
  List<Medicamento> get medicamentos => List.unmodifiable(_medicamentos);

  Medicamento? medicamento(String id) {
    for (final m in _medicamentos) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Registros de tomas, del más reciente al más antiguo.
  List<TomaMedicamento> get tomas => List.unmodifiable(_tomas.reversed);

  /// Porcentaje de tomas cumplidas (0 a 100). `null` si aún no hay registros.
  int? get cumplimiento {
    if (_tomas.isEmpty) return null;
    final tomadas = _tomas.where((t) => t.tomada).length;
    return (tomadas * 100 / _tomas.length).round();
  }

  /// Próxima toma de un medicamento que todavía no se ha registrado: si ya
  /// marcó la de las 4:00, la próxima es la siguiente.
  DateTime proximaPendiente(Medicamento m, DateTime ahora) {
    var hora = m.proximaToma(ahora);
    while (tomaYaRegistrada(m.id, hora)) {
      hora = hora.add(Duration(hours: m.frecuenciaHoras));
    }
    return hora;
  }

  /// La toma pendiente más cercana de todos los medicamentos, o `null` si no hay.
  ({Medicamento medicamento, DateTime hora})? proximaToma(DateTime ahora) {
    ({Medicamento medicamento, DateTime hora})? mejor;
    for (final m in _medicamentos) {
      final hora = proximaPendiente(m, ahora);
      if (mejor == null || hora.isBefore(mejor.hora)) mejor = (medicamento: m, hora: hora);
    }
    return mejor;
  }

  /// ¿Ya se registró (tomada o no) la dosis de esa hora?
  bool tomaYaRegistrada(String medicamentoId, DateTime horaProgramada) =>
      _tomas.any((t) => t.medicamentoId == medicamentoId && t.horaProgramada == horaProgramada);

  /// Última vez que tocó "Estoy bien" en Inicio (RF-12). `null` si nunca.
  DateTime? get ultimoEstoyBien {
    for (final evento in _eventos.reversed) {
      if (evento.tipo == TipoEvento.estoyBien) return evento.fecha;
    }
    return null;
  }

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

  /// RF-12: la persona confirma que está sin novedad. Queda con su hora en
  /// el Historial; más adelante también la verá su cuidador.
  void confirmarEstoyBien() {
    _registrar(TipoEvento.estoyBien);
    notifyListeners();
  }

  // ---------- Cuidador ----------

  /// Modo de pruebas: carga personas de ejemplo (mientras no hay servidor).
  void cargarPersonasDeEjemplo() {
    _personas
      ..clear()
      ..addAll(PersonaACargo.ejemplos(DateTime.now()));
    notifyListeners();
  }

  /// Modo de pruebas: a esa persona "se le detecta una caída" (llega la alerta).
  void simularAlertaDe(String id) {
    final i = _personas.indexWhere((p) => p.id == id);
    if (i == -1) return;
    final p = _personas[i];
    _personas[i] = p.copyWith(
      estado: EstadoPersona.alerta,
      alertas: [AlertaPersona(fecha: DateTime.now(), atendida: false), ...p.alertas],
    );
    notifyListeners();
  }

  /// El cuidador marca que ya atendió la alerta de esa persona.
  void marcarAlertaAtendida(String id) {
    final i = _personas.indexWhere((p) => p.id == id);
    if (i == -1) return;
    final p = _personas[i];
    _personas[i] = p.copyWith(
      estado: EstadoPersona.activa,
      alertas: [
        for (final a in p.alertas)
          a.atendida ? a : AlertaPersona(fecha: a.fecha, atendida: true, estabaBien: a.estabaBien),
      ],
    );
    notifyListeners();
  }

  // ---------- Medicamentos ----------

  /// Crea un identificador local único (más adelante lo dará Firebase).
  String nuevoIdMedicamento() => 'med-${DateTime.now().microsecondsSinceEpoch}';

  void agregarMedicamento(Medicamento medicamento) {
    _medicamentos.add(medicamento);
    notifyListeners();
  }

  void actualizarMedicamento(Medicamento medicamento) {
    final i = _medicamentos.indexWhere((m) => m.id == medicamento.id);
    if (i == -1) return;
    _medicamentos[i] = medicamento;
    notifyListeners();
  }

  /// Quita el medicamento y sus registros de tomas.
  void eliminarMedicamento(String id) {
    _medicamentos.removeWhere((m) => m.id == id);
    _tomas.removeWhere((t) => t.medicamentoId == id);
    notifyListeners();
  }

  /// RF-22: registra la dosis que toca ahora. Si la tomó, descuenta las
  /// unidades (RF-21). Devuelve `false` si esa dosis ya estaba registrada.
  bool registrarToma(String medicamentoId, {required bool tomada, DateTime? ahora}) {
    final m = medicamento(medicamentoId);
    if (m == null) return false;
    final momento = ahora ?? DateTime.now();
    final hora = m.dosisActual(momento);
    if (tomaYaRegistrada(m.id, hora)) return false;

    _tomas.add(TomaMedicamento(
      medicamentoId: m.id,
      horaProgramada: hora,
      tomada: tomada,
      horaReal: tomada ? momento : null,
    ));
    if (tomada) {
      final quedan = (m.unidadesDisponibles - m.unidadesPorToma).clamp(0, m.unidadesDisponibles);
      _reemplazarSinAviso(m.copyWith(unidadesDisponibles: quedan));
    }
    _registrar(
      tomada ? TipoEvento.tomaRegistrada : TipoEvento.tomaOmitida,
      detalle: '${m.nombre} ${m.dosis}',
    );
    notifyListeners();
    return true;
  }

  void _reemplazarSinAviso(Medicamento medicamento) {
    final i = _medicamentos.indexWhere((m) => m.id == medicamento.id);
    if (i != -1) _medicamentos[i] = medicamento;
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
    _medicamentos.clear();
    _tomas.clear();
    _personas.clear();
    _rondaActivaDesde = null;
    _rondaEnPausa = false;
    _eventos.clear();
    notifyListeners();
  }

  // ---------- Guardar y cargar ----------

  /// Cada cambio avisa a las pantallas y, además, se guarda.
  @override
  void notifyListeners() {
    super.notifyListeners();
    final almacen = _almacen;
    if (almacen == null) return;
    final datos = aJson();
    final ficha = _fichaMedica == null ? null : fichaAJson(_fichaMedica!);
    _guardado = _guardado.then((_) async {
      await almacen.guardarDatos(datos);
      await almacen.guardarFicha(ficha);
    });
  }

  /// Todo menos la ficha médica (que va aparte y cifrada).
  Map<String, Object?> aJson() => {
        'version': 1,
        'celular': _celular,
        'nombre': _nombre,
        'tipo': _tipo?.name,
        'contactos': [for (final c in _contactos) contactoAJson(c)],
        'permisoUbicacion': _permisoUbicacion,
        'permisoSensores': _permisoSensores,
        'consentimientos': {
          for (final e in _consentimientos.entries) e.key.name: e.value.toIso8601String(),
        },
        'avisoAceptadoEn': _avisoAceptadoEn?.toIso8601String(),
        'medicamentos': [for (final m in _medicamentos) medicamentoAJson(m)],
        'tomas': [for (final t in _tomas) tomaAJson(t)],
        'personasACargo': [for (final p in _personas) personaAJson(p)],
        'rondaActivaDesde': _rondaActivaDesde?.toIso8601String(),
        'rondaEnPausa': _rondaEnPausa,
        'eventos': [for (final e in _eventos) eventoAJson(e)],
        'modoTema': _modoTema.name,
      };

  void _cargarDesde(Map<String, Object?> j, Map<String, Object?>? ficha) {
    _celular = j['celular'] as String?;
    _nombre = j['nombre'] as String? ?? '';
    _tipo = enumPorNombre(TipoCuenta.values, j['tipo']);
    _contactos.addAll(listaDe(j['contactos'], contactoDeJson));
    _permisoUbicacion = j['permisoUbicacion'] as bool? ?? false;
    _permisoSensores = j['permisoSensores'] as bool? ?? false;
    final consentimientos = j['consentimientos'];
    if (consentimientos is Map) {
      for (final e in consentimientos.entries) {
        final tipo = enumPorNombre(TipoConsentimiento.values, e.key);
        final fecha = fechaDe(e.value);
        if (tipo != null && fecha != null) _consentimientos[tipo] = fecha;
      }
    }
    _avisoAceptadoEn = fechaDe(j['avisoAceptadoEn']);
    _medicamentos.addAll(listaDe(j['medicamentos'], medicamentoDeJson));
    _tomas.addAll(listaDe(j['tomas'], tomaDeJson));
    _personas.addAll(listaDe(j['personasACargo'], personaDeJson));
    _rondaActivaDesde = fechaDe(j['rondaActivaDesde']);
    _rondaEnPausa = j['rondaEnPausa'] as bool? ?? false;
    _eventos.addAll(listaDe(j['eventos'], eventoDeJson));
    _modoTema = enumPorNombre(ThemeMode.values, j['modoTema']) ?? ThemeMode.system;
    // La ficha solo se carga si sigue el consentimiento de datos médicos.
    if (ficha != null && tieneConsentimiento(TipoConsentimiento.datosMedicos)) {
      _fichaMedica = fichaDeJson(ficha);
    }
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
