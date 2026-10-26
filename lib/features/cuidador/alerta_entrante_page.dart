import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/alert_button.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'abrir_enlace.dart';

/// Alerta que le llega al cuidador cuando alguien que cuida no respondió a
/// una posible caída (RF-15 visto desde el otro lado, RF-26).
///
/// TODAVÍA ES SIMULADA: se abre desde Ajustes → Modo de pruebas. Con el
/// servidor llegará como notificación push.
class AlertaEntrantePage extends StatefulWidget {
  const AlertaEntrantePage({super.key, required this.personaId});

  final String personaId;

  @override
  State<AlertaEntrantePage> createState() => _AlertaEntrantePageState();
}

class _AlertaEntrantePageState extends State<AlertaEntrantePage> {
  final _alarma = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Solo suena si la alerta sigue sin atender (al reabrirla desde la lista, no).
    final persona = context.read<AppState>().personaACargo(widget.personaId);
    final pendiente = persona != null && persona.alertas.any((a) => !a.atendida);
    if (!pendiente) return;

    _iniciarAlarma();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${persona.nombre} podría haberse caído y no respondió.',
        TextDirection.ltr,
        assertiveness: Assertiveness.assertive,
      );
    });
  }

  @override
  void dispose() {
    _alarma.dispose();
    super.dispose();
  }

  Future<void> _iniciarAlarma() async {
    try {
      // Mismo canal de alarma que la alerta de caída.
      await _alarma.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.gainTransient,
            stayAwake: true,
          ),
        ),
      );
      await _alarma.setReleaseMode(ReleaseMode.loop);
      await _alarma.play(AssetSource('sounds/alarma.wav'), volume: 1);
    } catch (_) {
      // Si no suena, la pantalla igual muestra la alerta.
    }
  }

  /// Apenas el cuidador hace algo (llamar, ver el mapa), deja de sonar.
  void _silenciar() => _alarma.stop();

  void _marcarAtendida(String nombre) {
    _silenciar();
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
    if (persona == null) return const Scaffold(); // Se cerró la sesión

    final nombre = primerNombre(persona.nombre);
    final ubicacion = persona.ubicacion;
    final alerta = persona.alertas.isEmpty ? null : persona.alertas.first;
    final hora = alerta?.fecha ?? DateTime.now();

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
                          label: 'Posible caída · ${horaCorta(hora)}',
                          variant: StatusChipVariant.alerta,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$nombre podría haberse caído',
                        textAlign: TextAlign.center,
                        style: t.headlineLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No respondió a la alerta de su celular. Llama ahora o revisa dónde está.',
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
                            child: SecondaryButton(
                              label: 'Ya la atendí',
                              icon: Icons.check_rounded,
                              blur: false,
                              onPressed: () => _marcarAtendida(nombre),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Simulación: con el servidor, esta alerta te llegará como notificación.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall,
                      ),
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
