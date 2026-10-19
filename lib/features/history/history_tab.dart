import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/evento.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';

/// Pestaña Historial: lo que ha pasado con la ronda, del más reciente al más antiguo.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final eventos = context.watch<AppState>().eventos;

    return TabPage(
      title: 'Historial',
      subtitle: 'Lo que ha pasado con tu ronda.',
      blobs: BlobBackground.codigo,
      children: [
        if (eventos.isEmpty)
          const _SinEventos()
        else
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < eventos.length; i++) ...[
                  if (i > 0) const GlassDivider(indent: 74),
                  _FilaEvento(evento: eventos[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        Text(
          'Aquí también aparecerán tus alertas y tus confirmaciones de "Estoy bien".',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
      ],
    );
  }
}

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    final (icono, titulo, destacado) = switch (evento.tipo) {
      TipoEvento.rondaActivada => (Icons.shield_rounded, 'Ronda activada', true),
      TipoEvento.rondaPausada => (Icons.pause_rounded, 'Ronda en pausa', false),
      TipoEvento.rondaReanudada => (Icons.play_arrow_rounded, 'Ronda reanudada', true),
    };

    return Semantics(
      label: '$titulo, ${diaRelativo(evento.fecha)} a las ${horaCorta(evento.fecha)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: destacado ? c.accentSoft : c.neutralSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, size: 22, color: destacado ? c.accent : c.textSecondary),
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
                    '${diaRelativo(evento.fecha)} · ${horaCorta(evento.fecha)}',
                    style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinEventos extends StatelessWidget {
  const _SinEventos();

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 32, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('Aún no hay nada aquí', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cuando actives o pauses tu ronda, lo verás en esta lista.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}
