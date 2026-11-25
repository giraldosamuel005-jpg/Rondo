import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/alertas_cuidador.dart';
import '../../core/models/persona_a_cargo.dart';
import '../../core/state/app_state.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/alert_button.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'abrir_enlace.dart';
import 'persona_detalle_page.dart';

/// Alerta que le llega al cuidador cuando alguien que cuida no respondió a
/// una posible caída (RF-15 visto desde el otro lado, RF-26).
///
/// Se abre sola cuando llega una alerta nueva, al tocar su notificación o
/// desde la lista de alertas. La alarma la maneja [AlertasCuidador].
class AlertaEntrantePage extends StatefulWidget {
  const AlertaEntrantePage({super.key, required this.personaId});

  final String personaId;

  @override
  State<AlertaEntrantePage> createState() => _AlertaEntrantePageState();
}

class _AlertaEntrantePageState extends State<AlertaEntrantePage> {
  @override
  void initState() {
    super.initState();
    final persona = context.read<AppState>().personaACargo(widget.personaId);
    if (persona == null || persona.alertas.every((a) => a.atendida)) return;
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${persona.nombre} necesita ayuda.',
        TextDirection.ltr,
        assertiveness: Assertiveness.assertive,
      );
    });
  }

  /// Apenas el cuidador hace algo (llamar, ver el mapa), deja de sonar.
  void _silenciar() => context.read<AlertasCuidador?>()?.silenciar();

  void _marcarAtendida(String nombre) {
    _silenciar();
    // En el servidor primero (lo leen los otros cuidadores), y aquí de una.
    context.read<Vinculos?>()?.atenderAlertas(widget.personaId);
    context.read<AppState>().marcarAlertaAtendida(widget.personaId);

    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    mensajero.showSnackBar(
      SnackBar(content: Text('Listo. Marcamos la alerta de $nombre como atendida.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final persona = context.watch<AppState>().personaACargo(widget.personaId);
    if (persona == null) return const PersonaNoDisponible();

    final nombre = primerNombre(persona.nombre);
    final ubicacion = persona.ubicacion;
    // La más reciente sin atender; si ya no hay, la última.
    final alerta = persona.alertas.where((a) => !a.atendida).firstOrNull ?? persona.alertas.firstOrNull;
    final hora = alerta?.fecha ?? DateTime.now();
    final prueba = alerta?.prueba ?? false;
    final estabaBien = alerta?.estabaBien ?? false;
    final pendiente = alerta != null && !alerta.atendida;

    return Scaffold(
      body: BlobBackground(
        alerta: true,
        blobs: BlobBackground.alertaCaida,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerLeft, child: RondoBackButton()),
                      const SizedBox(height: 12),
                      Center(
                        child: StatusChip(
                          label: '${prueba ? 'Prueba' : 'Alerta'} · ${horaCorta(hora)}',
                          variant: StatusChipVariant.alerta,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        estabaBien
                            ? '$nombre avisó que está bien'
                            : prueba
                                ? '$nombre está probando su alerta'
                                : '$nombre necesita ayuda',
                        textAlign: TextAlign.center,
                        style: t.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        estabaBien
                            ? 'Ya no necesita ayuda.'
                            : prueba
                                ? 'No es una emergencia. Así te llegaría una alerta de verdad.'
                                : 'Puede haberse caído o pidió ayuda. Llama ahora o revisa dónde está.',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge!.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Dónde está ----------
                      if (ubicacion != null)
                        Glass(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.place_rounded, size: 22, color: c.alertText),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ubicacion.descripcion,
                                          style: t.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ubicación ${haceCuanto(ubicacion.fecha)}',
                                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SecondaryButton(
                                label: 'Ver en el mapa',
                                icon: Icons.map_rounded,
                                blur: false,
                                onPressed: () {
                                  _silenciar();
                                  verEnMapa(context, ubicacion);
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'No se pudo obtener su ubicación.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium,
                        ),

                      const Spacer(),
                      const SizedBox(height: 24),
                      AlertButton(
                        label: 'Llamar a $nombre',
                        icon: Icons.phone_in_talk_rounded,
                        onPressed: () {
                          _silenciar();
                          llamarA(context, persona);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Llamar al 123',
                              icon: Icons.local_hospital_rounded,
                              blur: false,
                              onPressed: () {
                                _silenciar();
                                llamarAl123(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: pendiente
                                ? SecondaryButton(
                                    label: 'Ya la atendí',
                                    icon: Icons.check_rounded,
                                    blur: false,
                                    onPressed: () => _marcarAtendida(nombre),
                                  )
                                : SecondaryButton(
                                    label: 'Cerrar',
                                    icon: Icons.close_rounded,
                                    blur: false,
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                          ),
                        ],
                      ),
                      if (persona.id.startsWith(PersonaACargo.prefijoEjemplo)) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Simulación: es una persona de ejemplo.',
                          textAlign: TextAlign.center,
                          style: t.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
