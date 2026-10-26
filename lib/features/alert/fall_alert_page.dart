import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/alert_button.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';

/// 06 · Alerta de caída (RF-13, RF-14, RF-15).
///
/// Pantalla completa con cuenta regresiva, alarma sonora y vibración.
/// - "Estoy bien" cancela la alerta (RF-14; por ahora solo con botón).
/// - Si el tiempo se acaba, o la persona toca "Pedir ayuda ahora", se avisa
///   a los contactos (RF-15). TODAVÍA ES SIMULADO: no se envía nada real.
class FallAlertPage extends StatefulWidget {
  const FallAlertPage({super.key, required this.detectadaA});

  /// Hora en que se detectó la posible caída.
  final DateTime detectadaA;

  /// Duración de la cuenta regresiva (RF-13: 10 s).
  static const segundos = 10;

  @override
  State<FallAlertPage> createState() => _FallAlertPageState();
}

enum _Fase { contando, enviada }

class _FallAlertPageState extends State<FallAlertPage> with SingleTickerProviderStateMixin {
  // Va de 1.0 a 0.0 en 10 s; con él se dibuja el anillo de forma continua.
  late final AnimationController _reloj = AnimationController(
    vsync: this,
    duration: const Duration(seconds: FallAlertPage.segundos),
    value: 1,
  );
  final _alarma = AudioPlayer();

  _Fase _fase = _Fase.contando;
  int _ultimoSegundo = FallAlertPage.segundos;
  String? _errorSonido;

  int get _segundosRestantes => (_reloj.value * FallAlertPage.segundos).ceil();

  @override
  void initState() {
    super.initState();
    _reloj.addListener(_alPasarSegundo);
    _reloj.addStatusListener((estado) {
      if (estado == AnimationStatus.dismissed) _avisarContactos(); // Llegó a 0
    });
    _reloj.reverse(); // Arranca la cuenta regresiva (de 1 a 0)

    _iniciarAlarma();
    HapticFeedback.heavyImpact();
    // El lector de pantalla lo anuncia en voz alta apenas aparece.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Posible caída detectada. Avisaremos en ${FallAlertPage.segundos} segundos.',
        TextDirection.ltr,
        assertiveness: Assertiveness.assertive,
      );
    });
  }

  @override
  void dispose() {
    _reloj.dispose();
    _alarma.dispose();
    super.dispose();
  }

  Future<void> _iniciarAlarma() async {
    try {
      // Canal de ALARMA (no de música): suena con el volumen de alarmas,
      // aunque la persona tenga la música en silencio.
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
      await _alarma.setReleaseMode(ReleaseMode.loop); // Suena en bucle
      await _alarma.play(AssetSource('sounds/alarma.wav'), volume: 1);
    } catch (_) {
      if (mounted) {
        setState(() => _errorSonido =
            'No se pudo reproducir la alarma sonora. Revisa el volumen de tu celular.');
      }
    }
  }

  /// Vibra una vez por cada segundo que pasa.
  void _alPasarSegundo() {
    final segundo = _segundosRestantes;
    if (segundo != _ultimoSegundo) {
      _ultimoSegundo = segundo;
      HapticFeedback.heavyImpact();
    }
  }

  void _detener() {
    _reloj.stop();
    _alarma.stop();
  }

  /// RF-14: la persona confirma que está bien → no se avisa a nadie.
  void _estoyBien() {
    _detener();
    context.read<AppState>().registrarAlerta(enviada: false);

    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    mensajero.showSnackBar(
      const SnackBar(content: Text('Qué bueno que estás bien. No avisamos a nadie.')),
    );
  }

  /// RF-15: se acabó el tiempo o pidió ayuda → se avisa a los contactos.
  void _avisarContactos() {
    if (_fase == _Fase.enviada) return;
    _detener();

    final estado = context.read<AppState>();
    final nombres = _nombres(estado.contactos);
    estado.registrarAlerta(enviada: true, detalle: 'Avisamos a $nombres');

    HapticFeedback.mediumImpact();
    setState(() => _fase = _Fase.enviada);
  }

  String _nombres(List<Contacto> contactos) {
    if (contactos.isEmpty) return 'tus contactos';
    return listaNatural([for (final k in contactos) primerNombre(k.nombre)]);
  }

  @override
  Widget build(BuildContext context) {
    final contactos = context.watch<AppState>().contactos;

    // Durante la cuenta regresiva, el botón atrás no la cierra por accidente.
    return PopScope(
      canPop: _fase == _Fase.enviada,
      child: Scaffold(
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
                    child: _fase == _Fase.contando
                        ? _cuentaRegresiva(contactos)
                        : _avisoEnviado(contactos),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cuentaRegresiva(List<Contacto> contactos) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final primero = contactos.isEmpty ? 'tus contactos' : primerNombre(contactos.first.nombre);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: StatusChip(
            label: 'Posible caída · ${horaCorta(widget.detectadaA)}',
            variant: StatusChipVariant.alerta,
          ),
        ),
        const SizedBox(height: 18),
        Text('¿Estás bien?', textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: 10),
        Text(
          'Si no respondes, avisamos a $primero con tu ubicación.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        Center(
          child: AnimatedBuilder(
            animation: _reloj,
            builder: (context, _) => CountdownRing(
              restante: _reloj.value,
              segundos: _segundosRestantes,
            ),
          ),
        ),
        if (_errorSonido != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorSonido!,
            textAlign: TextAlign.center,
            style: t.labelLarge!.copyWith(color: c.errorText),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 24),
        SecondaryButton(
          label: 'Estoy bien',
          icon: Icons.check_rounded,
          height: 64,
          onPressed: _estoyBien,
        ),
        const SizedBox(height: 12),
        AlertButton(
          label: 'Pedir ayuda ahora',
          icon: Icons.phone_in_talk_rounded,
          onPressed: _avisarContactos,
        ),
        const SizedBox(height: 12),
        Text(
          'Se enviará un SMS a ${_nombres(contactos)}.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _avisoEnviado(List<Contacto> contactos) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.alert.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_rounded, size: 44, color: c.alertText),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            'Avisamos a tus contactos',
            textAlign: TextAlign.center,
            style: t.headlineLarge,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Les llegó tu alerta con tu ubicación y la hora. Pronto se comunicarán contigo.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 22),
        if (contactos.isNotEmpty)
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < contactos.length; i++) ...[
                  if (i > 0) const GlassDivider(indent: 68),
                  ContactRow(contacto: contactos[i], orden: i + 1),
                ],
              ],
            ),
          ),
        const Spacer(),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Volver al inicio',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        Text(
          'Simulación: todavía no se envían mensajes reales. En una emergencia, llama al 123.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
