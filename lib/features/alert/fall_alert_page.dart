import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/aviso_alerta.dart';
import '../../core/models/contacto.dart';
import '../../core/permisos/permisos_sistema.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/alert_button.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/countdown_ring.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../cuidador/abrir_enlace.dart';

/// 06 · Alerta de caída (RF-13, RF-14, RF-15).
///
/// Pantalla completa con cuenta regresiva, alarma sonora y vibración.
/// - "Estoy bien" cancela la alerta (RF-14; por ahora solo con botón).
/// - Si el tiempo se acaba, o la persona toca "Pedir ayuda ahora", se avisa
///   a los contactos (RF-15): SMS a cada uno con la ubicación (RF-16) y la
///   alerta en el servidor para los cuidadores con Rondó. Si nada sale, suena
///   la alarma local (RF-17).
/// - Sin [AvisoDeAlerta] (web, Windows, pruebas) es una simulación: solo queda
///   en el Historial.
class FallAlertPage extends StatefulWidget {
  const FallAlertPage({super.key, required this.detectadaA});

  /// Hora en que se detectó la posible caída.
  final DateTime detectadaA;

  /// Duración de la cuenta regresiva (RF-13: 10 s).
  static const segundos = 10;

  @override
  State<FallAlertPage> createState() => _FallAlertPageState();
}

enum _Fase { contando, avisando, enviada }

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

  /// `null` en la simulación (sin [AvisoDeAlerta]).
  ResultadoAviso? _resultado;
  bool _simulada = true;

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
    if (_fase != _Fase.contando) return;
    _detener();
    setState(() => _fase = _Fase.avisando);
    _enviar();
  }

  Future<void> _enviar() async {
    final estado = context.read<AppState>();
    final aviso = context.read<AvisoDeAlerta?>();
    final vinculos = context.read<Vinculos?>();
    final contactos = estado.contactos;

    final resultado = aviso == null
        ? null
        : await aviso.avisar(
            nombre: estado.nombre,
            contactos: contactos,
            fecha: widget.detectadaA,
            usarUbicacion: estado.permisoUbicacion,
            usarSms: estado.tienePermiso(PermisoSistema.sms),
            alServidor: vinculos?.publicarAlerta,
          );

    // Queda en el Historial aunque la persona ya haya salido de la pantalla.
    estado.registrarAlerta(enviada: true, detalle: _detalle(resultado, contactos));
    if (!mounted) return;

    // RF-17: no salió ni un SMS ni la alerta al servidor → que suene aquí.
    if (resultado != null && resultado.nadieAvisado) _iniciarAlarma();
    HapticFeedback.mediumImpact();
    setState(() {
      _resultado = resultado;
      _simulada = aviso == null;
      _fase = _Fase.enviada;
    });
  }

  /// Lo que queda en el Historial: "Avisamos a Ana y Luis".
  String _detalle(ResultadoAviso? r, List<Contacto> contactos) {
    if (r == null) return 'Avisamos a ${_nombres(contactos)}';
    if (r.nadieAvisado) return 'No se pudo avisar a nadie';
    final partes = [
      for (final k in r.conSms) primerNombre(k.nombre),
      if (r.llegoACuidadores) 'tus cuidadores en Rondó',
    ];
    return 'Avisamos a ${listaNatural(partes)}';
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
                    child: switch (_fase) {
                      _Fase.contando => _cuentaRegresiva(contactos),
                      _Fase.avisando => _avisando(),
                      _Fase.enviada => _avisoEnviado(contactos),
                    },
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

  Widget _avisando() {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text('Avisando a tus contactos…', textAlign: TextAlign.center, style: t.headlineLarge),
        ),
        const SizedBox(height: 10),
        Text('Buscando tu ubicación y enviando los mensajes.', textAlign: TextAlign.center, style: t.bodyLarge),
      ],
    );
  }

  Widget _avisoEnviado(List<Contacto> contactos) {
    final r = _resultado;
    if (r != null && r.nadieAvisado) return _nadieAvisado(r);

    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    // En la simulación se muestran todos; en la real, solo a quienes les llegó.
    final avisados = r == null ? contactos : r.conSms;
    final problemas = r == null ? const <String>[] : _problemas(r);

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
          r != null && r.posicion == null
              ? 'Les llegó tu alerta con la hora. Pronto se comunicarán contigo.'
              : 'Les llegó tu alerta con tu ubicación y la hora. Pronto se comunicarán contigo.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 22),
        if (avisados.isNotEmpty)
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < avisados.length; i++) ...[
                  if (i > 0) const GlassDivider(indent: 68),
                  ContactRow(contacto: avisados[i], orden: i + 1),
                ],
              ],
            ),
          ),
        if (r != null && r.llegoACuidadores) ...[
          const SizedBox(height: 12),
          Text(
            'Tus cuidadores también la ven en Rondó.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
        for (final problema in problemas) ...[
          const SizedBox(height: 12),
          Text(
            problema,
            textAlign: TextAlign.center,
            style: t.labelLarge!.copyWith(color: c.errorText),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Volver al inicio',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        Text(
          _simulada
              ? 'Simulación: en este dispositivo no se envían mensajes. En una emergencia, llama al 123.'
              : 'En una emergencia, llama al 123.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Lo que salió mal, con los mensajes de RF-15 y RF-16.
  List<String> _problemas(ResultadoAviso r) => [
        if (r.posicion == null) 'No se pudo obtener tu ubicación. Se avisó a tus contactos sin ella.',
        if (r.faltaPermisoSms)
          'La app no tiene permiso para enviar SMS. Actívalo en ajustes.'
        else if (r.sinSms.isNotEmpty)
          'No se pudo enviar el SMS a ${_nombres(r.sinSms)}. Verifica tu señal y tu saldo.',
      ];

  /// RF-17: no salió nada. La alarma sigue sonando para que alguien cerca la oiga.
  Widget _nadieAvisado(ResultadoAviso r) {
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
            decoration: BoxDecoration(color: c.alert.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(Icons.campaign_rounded, size: 44, color: c.alertText),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text('No pudimos avisar a nadie', textAlign: TextAlign.center, style: t.headlineLarge),
        ),
        const SizedBox(height: 10),
        Text(
          'Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        if (r.faltaPermisoSms) ...[
          const SizedBox(height: 12),
          Text(
            'La app no tiene permiso para enviar SMS. Actívalo en ajustes.',
            textAlign: TextAlign.center,
            style: t.labelLarge!.copyWith(color: c.errorText),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 24),
        AlertButton(
          label: 'Llamar al 123',
          icon: Icons.local_hospital_rounded,
          onPressed: () => llamarAl123(context),
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Apagar la alarma y volver',
          icon: Icons.volume_off_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
