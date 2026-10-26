/// Convierte los modelos a JSON (para guardarlos) y de vuelta.
///
/// Las fechas se guardan en texto ISO 8601 ("2026-10-25T08:00:00.000") y los
/// enum por su nombre. Si al leer algo no se reconoce (por ejemplo, un dato de
/// una versión vieja de la app), ese elemento se ignora en vez de fallar.
library;

import '../models/contacto.dart';
import '../models/evento.dart';
import '../models/ficha_medica.dart';
import '../models/medicamento.dart';
import '../models/persona_a_cargo.dart';

/// Busca un valor de un enum por su nombre; `null` si no existe.
T? enumPorNombre<T extends Enum>(List<T> valores, Object? nombre) {
  for (final v in valores) {
    if (v.name == nombre) return v;
  }
  return null;
}

DateTime? fechaDe(Object? texto) => texto is String ? DateTime.tryParse(texto) : null;

// ---------- Contacto ----------

Map<String, Object?> contactoAJson(Contacto c) => {
      'nombre': c.nombre,
      'celular': c.celular,
      'relacion': c.relacion,
      'esCuidador': c.esCuidador,
    };

Contacto? contactoDeJson(Map<String, Object?> j) {
  final nombre = j['nombre'], celular = j['celular'];
  if (nombre is! String || celular is! String) return null;
  return Contacto(
    nombre: nombre,
    celular: celular,
    relacion: j['relacion'] as String? ?? '',
    esCuidador: j['esCuidador'] as bool? ?? false,
  );
}

// ---------- Evento ----------

Map<String, Object?> eventoAJson(Evento e) => {
      'tipo': e.tipo.name,
      'fecha': e.fecha.toIso8601String(),
      'detalle': e.detalle,
    };

Evento? eventoDeJson(Map<String, Object?> j) {
  final tipo = enumPorNombre(TipoEvento.values, j['tipo']);
  final fecha = fechaDe(j['fecha']);
  if (tipo == null || fecha == null) return null;
  return Evento(tipo: tipo, fecha: fecha, detalle: j['detalle'] as String?);
}

// ---------- Medicamentos ----------

Map<String, Object?> medicamentoAJson(Medicamento m) => {
      'id': m.id,
      'nombre': m.nombre,
      'dosis': m.dosis,
      'unidadesPorToma': m.unidadesPorToma,
      'frecuenciaHoras': m.frecuenciaHoras,
      'unidadesDisponibles': m.unidadesDisponibles,
      'primeraToma': m.primeraToma.toIso8601String(),
    };

Medicamento? medicamentoDeJson(Map<String, Object?> j) {
  final primera = fechaDe(j['primeraToma']);
  final porToma = j['unidadesPorToma'], frecuencia = j['frecuenciaHoras'];
  if (j['id'] is! String || j['nombre'] is! String || primera == null) return null;
  if (porToma is! int || porToma <= 0 || frecuencia is! int || frecuencia <= 0) return null;
  return Medicamento(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    dosis: j['dosis'] as String? ?? '',
    unidadesPorToma: porToma,
    frecuenciaHoras: frecuencia,
    unidadesDisponibles: j['unidadesDisponibles'] as int? ?? 0,
    primeraToma: primera,
  );
}

Map<String, Object?> tomaAJson(TomaMedicamento t) => {
      'medicamentoId': t.medicamentoId,
      'horaProgramada': t.horaProgramada.toIso8601String(),
      'tomada': t.tomada,
      'horaReal': t.horaReal?.toIso8601String(),
    };

TomaMedicamento? tomaDeJson(Map<String, Object?> j) {
  final hora = fechaDe(j['horaProgramada']);
  if (j['medicamentoId'] is! String || hora == null) return null;
  return TomaMedicamento(
    medicamentoId: j['medicamentoId'] as String,
    horaProgramada: hora,
    tomada: j['tomada'] as bool? ?? false,
    horaReal: fechaDe(j['horaReal']),
  );
}

// ---------- Ficha médica (se guarda aparte y cifrada) ----------

Map<String, Object?> fichaAJson(FichaMedica f) => {
      'tipoSangre': f.tipoSangre.name,
      'alergias': f.alergias,
      'celularContactoEmergencia': f.celularContactoEmergencia,
    };

FichaMedica? fichaDeJson(Map<String, Object?> j) {
  final tipo = enumPorNombre(TipoSangre.values, j['tipoSangre']);
  final celular = j['celularContactoEmergencia'];
  if (tipo == null || celular is! String) return null;
  return FichaMedica(
    tipoSangre: tipo,
    celularContactoEmergencia: celular,
    alergias: [for (final a in (j['alergias'] as List? ?? const [])) if (a is String) a],
  );
}

/// Convierte una lista JSON en modelos, saltándose los que no se entiendan.
List<T> listaDe<T>(Object? json, T? Function(Map<String, Object?>) convertir) => [
      if (json is List)
        for (final item in json)
          if (item is Map) ?convertir(item.cast<String, Object?>()),
    ];

// ---------- Personas a cargo (cuenta de cuidador) ----------

Map<String, Object?> personaAJson(PersonaACargo p) => {
      'id': p.id,
      'nombre': p.nombre,
      'celular': p.celular,
      'relacion': p.relacion,
      'estado': p.estado.name,
      'ubicacion': p.ubicacion == null
          ? null
          : {
              'latitud': p.ubicacion!.latitud,
              'longitud': p.ubicacion!.longitud,
              'descripcion': p.ubicacion!.descripcion,
              'fecha': p.ubicacion!.fecha.toIso8601String(),
            },
      'ultimoEstoyBien': p.ultimoEstoyBien?.toIso8601String(),
      'cumplimiento': p.cumplimiento,
      'alertas': [
        for (final a in p.alertas)
          {'fecha': a.fecha.toIso8601String(), 'atendida': a.atendida, 'estabaBien': a.estabaBien},
      ],
    };

PersonaACargo? personaDeJson(Map<String, Object?> j) {
  final estado = enumPorNombre(EstadoPersona.values, j['estado']);
  if (j['id'] is! String || j['nombre'] is! String || j['celular'] is! String || estado == null) {
    return null;
  }
  Ubicacion? ubicacion;
  final u = j['ubicacion'];
  if (u is Map) {
    final fecha = fechaDe(u['fecha']);
    final lat = u['latitud'], lng = u['longitud'];
    if (fecha != null && lat is num && lng is num) {
      ubicacion = Ubicacion(
        latitud: lat.toDouble(),
        longitud: lng.toDouble(),
        descripcion: u['descripcion'] as String? ?? '',
        fecha: fecha,
      );
    }
  }
  return PersonaACargo(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    celular: j['celular'] as String,
    relacion: j['relacion'] as String? ?? '',
    estado: estado,
    ubicacion: ubicacion,
    ultimoEstoyBien: fechaDe(j['ultimoEstoyBien']),
    cumplimiento: j['cumplimiento'] as int?,
    alertas: listaDe(j['alertas'], (a) {
      final fecha = fechaDe(a['fecha']);
      return fecha == null
          ? null
          : AlertaPersona(
              fecha: fecha,
              atendida: a['atendida'] as bool? ?? true,
              estabaBien: a['estabaBien'] as bool? ?? false,
            );
    }),
  );
}
