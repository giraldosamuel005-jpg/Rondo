import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/persona_a_cargo.dart';

/// Abre el marcador del teléfono con el número ya escrito (la persona solo
/// toca "llamar"). No necesita el permiso CALL_PHONE.
Future<void> llamarA(BuildContext context, PersonaACargo persona) =>
    _abrir(context, persona.enlaceLlamada, 'No se pudo abrir el marcador del teléfono.');

/// Marcador con el 123 (línea de emergencias de Colombia).
Future<void> llamarAl123(BuildContext context) =>
    _abrir(context, Uri(scheme: 'tel', path: '123'), 'No se pudo abrir el marcador del teléfono.');

/// Abre la ubicación en Google Maps (o en el navegador si no está instalada).
Future<void> verEnMapa(BuildContext context, Ubicacion ubicacion) =>
    _abrir(context, ubicacion.enlaceMapa, 'No se pudo abrir el mapa. Intenta de nuevo.');

Future<void> _abrir(BuildContext context, Uri enlace, String error) async {
  final mensajero = ScaffoldMessenger.of(context);
  var abrio = false;
  try {
    abrio = await launchUrl(enlace, mode: LaunchMode.externalApplication);
  } catch (_) {
    abrio = false;
  }
  if (!abrio) mensajero.showSnackBar(SnackBar(content: Text(error)));
}
