import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/biometria/servicio_biometria.dart';
import '../../core/state/app_state.dart';

/// Activa la huella para reingresar (RF-02). Antes de guardarla pide la huella
/// una vez: así sabemos que funciona y no dejamos a nadie fuera de su cuenta.
/// Devuelve `true` si quedó activada. Si algo falla, lo dice con los mensajes
/// de requisitos.md.
Future<bool> activarHuella(BuildContext context) async {
  // Sin servicio (pruebas) se comporta como un celular sin huella.
  final servicio =
      context.read<ServicioBiometria?>() ??
      const ServicioBiometriaNoDisponible();
  final estado = context.read<AppState>();
  final mensajero = ScaffoldMessenger.of(context);

  if (!await servicio.disponible) {
    mensajero.showSnackBar(
      const SnackBar(content: Text(MensajesBiometria.noDisponible)),
    );
    return false;
  }

  final resultado = await servicio.autenticar(
    'Confirma tu huella para activarla.',
  );
  if (resultado != ResultadoBiometria.valido) {
    mensajero.showSnackBar(
      SnackBar(content: Text(MensajesBiometria.de(resultado)!)),
    );
    return false;
  }

  estado.cambiarHuellaActivada(true);
  mensajero.showSnackBar(
    const SnackBar(
      content: Text(
        'Listo. La próxima vez que abras Rondó te pediremos tu huella.',
      ),
    ),
  );
  return true;
}

/// Oferta única después del primer ingreso (RF-02). Solo aparece si el celular
/// tiene huella guardada; se muestra una sola vez, la acepte o no.
Future<void> ofrecerHuella(BuildContext context) async {
  final estado = context.read<AppState>();
  final servicio = context.read<ServicioBiometria?>();
  if (servicio == null || estado.huellaOfrecida || estado.huellaActivada)
    return;
  if (!await servicio.disponible) return;
  if (!context.mounted) return;

  estado.marcarHuellaOfrecida();
  final acepto = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Entrar con tu huella?'),
      content: const Text(
        'La próxima vez que abras Rondó usa tu huella en vez de escribir un código. '
        'Si no funciona, entras con tu código SMS.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          child: const Text('Activar'),
        ),
      ],
    ),
  );
  if (acepto == true && context.mounted) await activarHuella(context);
}
