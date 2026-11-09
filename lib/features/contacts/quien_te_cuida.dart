import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/servicio_vinculos.dart';
import '../../core/vinculos/vinculo.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';
import '../cuidador/abrir_enlace.dart';

/// Contactos → "Quién te cuida" (RF-05, RF-27): invitar a un contacto a
/// cuidarte, ver si ya aceptó y dejar de compartir cuando quieras.
/// Solo aparece si hay servidor de vínculos.
class QuienTeCuida extends StatelessWidget {
  const QuienTeCuida({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final contactos = context.watch<AppState>().contactos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Quién te cuida'),
        Glass(
          // Sin desenfoque: la pestaña ya tiene otras tarjetas (máximo 6).
          blur: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < contactos.length; i++) ...[
                if (i > 0) const GlassDivider(indent: 68),
                _FilaCuidador(contacto: contactos[i], orden: i),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quien acepte tu invitación verá si tu ronda está activa, cuándo dijiste '
          '"Estoy bien" y cómo vas con tus medicamentos. Puedes dejar de compartir cuando quieras.',
          style: t.bodySmall,
        ),
      ],
    );
  }
}

class _FilaCuidador extends StatefulWidget {
  const _FilaCuidador({required this.contacto, required this.orden});

  final Contacto contacto;
  final int orden;

  @override
  State<_FilaCuidador> createState() => _FilaCuidadorState();
}

class _FilaCuidadorState extends State<_FilaCuidador> {
  bool _ocupado = false;

  /// Hace la acción mostrando que está en curso; los errores salen abajo.
  Future<void> _hacer(Future<void> Function() accion) async {
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    try {
      await accion();
    } on ErrorVinculo catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _invitar(Vinculos vinculos) => _hacer(() async {
        final invitacion = await vinculos.invitar(widget.contacto);
        if (mounted) await enviarInvitacion(context, invitacion);
      });

  Future<void> _dejarDeCompartir(Vinculos vinculos, Vinculo vinculo) async {
    final nombre = primerNombre(widget.contacto.nombre);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Dejar de compartir con $nombre?'),
        content: Text('Desde ya, $nombre no verá tu estado. Si cambias de opinión, puedes invitarlo otra vez.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Dejar de compartir')),
        ],
      ),
    );
    if (confirmar == true) await _hacer(() => vinculos.dejarDeCompartir(vinculo));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final vinculos = context.watch<Vinculos>();
    final contacto = widget.contacto;
    final vinculo = vinculos.vinculoCon(contacto.celular);
    final invitacion = vinculo == null ? vinculos.invitacionPendiente(contacto.celular) : null;

    final (estado, color) = switch ((vinculo, invitacion)) {
      (Vinculo(), _) => ('Te cuida', c.accentLink),
      (_, Invitacion(:final codigo)) => ('Invitación enviada · código $codigo', c.textSecondary),
      _ => ('Sin invitar', c.textSecondary),
    };

    final acciones = <Widget>[
      if (vinculo != null)
        TextButton(onPressed: () => _dejarDeCompartir(vinculos, vinculo), child: const Text('Dejar de compartir'))
      else if (invitacion != null) ...[
        TextButton(onPressed: () => enviarInvitacion(context, invitacion), child: const Text('Reenviar SMS')),
        TextButton(
          onPressed: () => _hacer(() => vinculos.cancelarInvitacion(invitacion)),
          child: const Text('Cancelar invitación'),
        ),
      ] else
        TextButton(onPressed: () => _invitar(vinculos), child: const Text('Invitar a cuidarme')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RondoAvatar(iniciales: contacto.iniciales, variante: widget.orden),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contacto.nombre,
                  style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(estado, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400, color: color)),
                if (_ocupado)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  // Los botones bajan de línea si no caben (texto grande).
                  Wrap(children: acciones),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
