import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/persona_a_cargo.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';
import 'alerta_entrante_page.dart';
import 'persona_detalle_page.dart';

/// Pestaña Alertas (cuidador, RF-26): las alertas de todas las personas que
/// cuida, de la más reciente a la más antigua.
class AlertasTab extends StatelessWidget {
  const AlertasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final alertas = context.watch<AppState>().alertasDePersonas;

    return TabPage(
      title: 'Alertas',
      subtitle: 'Las alertas de las personas que cuidas.',
      blobs: BlobBackground.codigo,
      children: [
        if (alertas.isEmpty)
          const _SinAlertas()
        else
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < alertas.length; i++) ...[
                  if (i > 0) const GlassDivider(indent: 74),
                  FilaAlertaPersona(
                    persona: alertas[i].persona,
                    alerta: alertas[i].alerta,
                    mostrarNombre: true,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Si alguien que cuidas no responde a una posible caída, te avisamos al instante.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
      ],
    );
  }
}

/// Una alerta en una lista. Si está sin atender, se toca para abrirla.
class FilaAlertaPersona extends StatelessWidget {
  const FilaAlertaPersona({
    super.key,
    required this.persona,
    required this.alerta,
    this.mostrarNombre = false,
  });

  final PersonaACargo persona;
  final AlertaPersona alerta;

  /// En la pestaña Alertas se dice de quién es; en el detalle no hace falta.
  final bool mostrarNombre;

  void _abrir(BuildContext context) {
    if (!alerta.atendida) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlertaEntrantePage(personaId: persona.id),
        ),
      );
    } else if (mostrarNombre) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PersonaDetallePage(personaId: persona.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    // Ámbar: sin atender. Turquesa: estaba bien. Neutro: ya se atendió.
    final (icono, fondo, color, estadoTexto) = !alerta.atendida
        ? (Icons.notifications_active_rounded, c.alert.withValues(alpha: 0.18), c.alertText, 'Sin atender')
        : alerta.estabaBien
            ? (Icons.check_rounded, c.accentSoft, c.accent, 'Respondió que estaba bien')
            : (Icons.done_all_rounded, c.neutralSoft, c.textSecondary, 'Atendida');
    final titulo = mostrarNombre ? 'Posible caída de ${primerNombre(persona.nombre)}' : 'Posible caída';
    final detalle = '${diaRelativo(alerta.fecha)} · ${horaCorta(alerta.fecha)} · $estadoTexto';
    final sePuedeAbrir = !alerta.atendida || mostrarNombre;

    return Semantics(
      button: sePuedeAbrir,
      label: '$titulo. $detalle',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: sePuedeAbrir ? () => _abrir(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icono, size: 22, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: t.labelLarge!.copyWith(
                          fontWeight: alerta.atendida ? FontWeight.w400 : FontWeight.w600,
                          color: alerta.atendida ? null : c.alertText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (sePuedeAbrir) Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinAlertas extends StatelessWidget {
  const _SinAlertas();

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 32, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('No hay alertas', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cuando alguien que cuidas tenga una posible caída, la verás en esta lista.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}
