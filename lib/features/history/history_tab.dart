import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/evento.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';

/// Pestaña Historial: lo que ha pasado con la ronda, por días y del más
/// reciente al más antiguo. Se puede filtrar por alertas o medicamentos.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  FiltroHistorial _filtro = FiltroHistorial.todo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final eventos = context.watch<AppState>().eventos;
    final grupos = agruparPorDia([
      for (final evento in eventos)
        if (_filtro.incluye(evento.tipo)) evento,
    ]);

    return TabPage(
      title: 'Historial',
      subtitle: 'Lo que ha pasado con tu ronda.',
      blobs: BlobBackground.codigo,
      children: [
        if (eventos.isEmpty)
          const _SinEventos()
        else ...[
          Glass(
            padding: const EdgeInsets.all(6),
            child: _SelectorFiltro(
              actual: _filtro,
              onChanged: (filtro) => setState(() => _filtro = filtro),
            ),
          ),
          const SizedBox(height: 18),
          if (grupos.isEmpty)
            _SinResultados(filtro: _filtro)
          else
            for (final grupo in grupos) ...[
              SectionLabel(diaRelativo(grupo.dia)),
              Glass(
                blur: false, // Puede haber muchos días: sin desenfoque
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < grupo.eventos.length; i++) ...[
                      if (i > 0) const GlassDivider(indent: 74),
                      _FilaEvento(evento: grupo.eventos[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
        ],
        const SizedBox(height: 14),
        Text(
          'Aquí quedan tus alertas, tus confirmaciones de "Estoy bien", tus tomas de medicamentos y cuándo pausas la ronda.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
      ],
    );
  }
}

/// Tres opciones en fila: Todo · Alertas · Medicamentos.
class _SelectorFiltro extends StatelessWidget {
  const _SelectorFiltro({required this.actual, required this.onChanged});

  final FiltroHistorial actual;
  final ValueChanged<FiltroHistorial> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Row(
      children: [
        for (final filtro in FiltroHistorial.values)
          Expanded(
            // "Medicamentos" es más largo: le toca más ancho.
            flex: filtro == FiltroHistorial.medicamentos ? 3 : 2,
            child: Semantics(
              selected: filtro == actual,
              inMutuallyExclusiveGroup: true,
              button: true,
              label: filtro.etiqueta,
              excludeSemantics: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onChanged(filtro),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: filtro == actual ? c.accentSoft : null,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      // Con letra grande se encoge en vez de desbordarse.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          filtro.etiqueta,
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                                fontWeight: filtro == actual ? FontWeight.w700 : FontWeight.w500,
                                color: filtro == actual ? c.accentLink : c.textSecondary,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

    // Color del ícono: turquesa (normal), neutro (pausa) o ámbar (alerta enviada).
    final (icono, titulo, fondo, color) = switch (evento.tipo) {
      TipoEvento.rondaActivada => (Icons.shield_rounded, 'Ronda activada', c.accentSoft, c.accent),
      TipoEvento.rondaPausada => (Icons.pause_rounded, 'Ronda en pausa', c.neutralSoft, c.textSecondary),
      TipoEvento.rondaReanudada => (Icons.play_arrow_rounded, 'Ronda reanudada', c.accentSoft, c.accent),
      TipoEvento.alertaCancelada => (Icons.check_rounded, 'Posible caída: estabas bien', c.accentSoft, c.accent),
      TipoEvento.estoyBien => (Icons.favorite_rounded, 'Confirmaste que estás bien', c.accentSoft, c.accent),
      TipoEvento.tomaRegistrada => (Icons.medication_rounded, 'Tomaste tu medicamento', c.accentSoft, c.accent),
      TipoEvento.tomaOmitida => (Icons.medication_outlined, 'No tomaste tu medicamento', c.neutralSoft, c.textSecondary),
      TipoEvento.alertaEnviada => (
          Icons.notifications_active_rounded,
          'Alerta enviada',
          c.alert.withValues(alpha: 0.18),
          c.alertText,
        ),
    };
    // El día ya está en el título del grupo.
    final cuando = horaCorta(evento.fecha);

    return Semantics(
      label: '$titulo, ${diaRelativo(evento.fecha)} a las ${horaCorta(evento.fecha)}'
          '${evento.detalle != null ? '. ${evento.detalle}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(14),
              ),
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
                    evento.detalle == null ? cuando : '$cuando · ${evento.detalle}',
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

/// Hay eventos, pero ninguno del filtro elegido.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.filtro});

  final FiltroHistorial filtro;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final (icono, titulo, texto) = switch (filtro) {
      FiltroHistorial.medicamentos => (
          Icons.medication_outlined,
          'Sin tomas registradas',
          'Cuando marques una toma de tus medicamentos, la verás aquí.',
        ),
      _ => (
          Icons.shield_outlined,
          'Sin alertas',
          'Si alguna vez detectamos una posible caída, la verás aquí.',
        ),
    };

    return Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icono, size: 32, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(titulo, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(texto, textAlign: TextAlign.center, style: t.bodyMedium),
        ],
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
            'Cuando actives o pauses tu ronda, o haya una alerta, lo verás en esta lista.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}
