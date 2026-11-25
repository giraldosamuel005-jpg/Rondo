import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/alerta_compartida.dart';
import '../../core/alertas/control_alerta.dart';
import '../../core/models/contacto.dart';
import '../../core/permisos/permisos_sistema.dart';
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
import '../cuidador/abrir_enlace.dart';

/// 06 · Alerta de caída (RF-13 a RF-17). Solo DIBUJA la alerta: la cuenta
/// regresiva, los avisos y los reintentos los lleva [ControlAlerta], que sigue
/// aunque esta pantalla no se vea. La abre y la cierra el Coordinador.
class FallAlertPage extends StatefulWidget {
  const FallAlertPage({super.key, this.permisos = const PermisosSistema()});

  final PermisosSistema permisos;

  @override
  State<FallAlertPage> createState() => _FallAlertPageState();
}

class _FallAlertPageState extends State<FallAlertPage> with SingleTickerProviderStateMixin {
  // Redibuja el anillo en cada cuadro; el tiempo sale del reloj, no de aquí.
  late final Ticker _cuadros = createTicker((_) => setState(() {}));
  int? _ultimoSegundo;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    final control = context.read<ControlAlerta>();
    if (control.fase == FaseAlerta.contando) _cuadros.start();
    // El lector de pantalla lo anuncia en voz alta apenas aparece.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || control.fase != FaseAlerta.contando) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Posible caída detectada. Avisaremos en ${control.segundosRestantes} segundos.',
        TextDirection.ltr,
        assertiveness: Assertiveness.assertive,
      );
    });
  }

  @override
  void dispose() {
    _cuadros.dispose();
    super.dispose();
  }

  void _estoyBien() {
    final mensajero = ScaffoldMessenger.of(context);
    context.read<ControlAlerta>().estoyBien();
    mensajero.showSnackBar(
      const SnackBar(content: Text('Qué bueno que estás bien. No avisamos a nadie.')),
    );
  }

  void _yaEstoyBien() {
    final mensajero = ScaffoldMessenger.of(context);
    context.read<ControlAlerta>().yaEstoyBien();
    mensajero.showSnackBar(
      const SnackBar(content: Text('Qué bueno que estás bien. Les avisamos.')),
    );
  }

  /// Faltaba el permiso de SMS: lo pide aquí mismo y vuelve a intentar.
  Future<void> _permitirSms() async {
    final estado = context.read<AppState>();
    final control = context.read<ControlAlerta>();
    final respuesta = await widget.permisos.pedir(PermisoSistema.sms);
    if (respuesta == EstadoPermiso.bloqueado) {
      await widget.permisos.abrirAjustes();
      return;
    }
    if (respuesta != EstadoPermiso.concedido) return;
    estado.cambiarPermiso(PermisoSistema.sms, true);
    control.reintentarYa();
  }

  static String _nombres(List<Contacto> contactos) =>
      contactos.isEmpty ? 'tus contactos' : listaNatural([for (final k in contactos) primerNombre(k.nombre)]);

  @override
  Widget build(BuildContext context) {
    final control = context.watch<ControlAlerta>();
    final fase = control.fase;

    if (fase != FaseAlerta.contando && _cuadros.isActive) _cuadros.stop();
    // Vibra una vez por cada segundo que pasa.
    if (fase == FaseAlerta.contando && _ultimoSegundo != control.segundosRestantes) {
      _ultimoSegundo = control.segundosRestantes;
      HapticFeedback.heavyImpact();
    }

    // Durante la cuenta regresiva, el botón atrás no la cierra por accidente.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seCerro, _) {
        if (!seCerro) control.cerrar(); // Solo hace algo si ya se envió
      },
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
                    child: switch (fase) {
                      FaseAlerta.contando => _cuentaRegresiva(control),
                      FaseAlerta.avisando => _avisando(control),
                      _ when control.nadieAvisado => _nadieAvisado(control),
                      _ => _avisoEnviado(control),
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

  Widget _cuentaRegresiva(ControlAlerta control) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final contactos = estado.contactos;
    final conUbicacion = estado.permisoUbicacion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: StatusChip(
            label: '${control.prueba ? 'Prueba' : 'Posible caída'} · ${horaCorta(control.detectadaA)}',
            variant: StatusChipVariant.alerta,
          ),
        ),
        const SizedBox(height: 18),
        Text('¿Estás bien?', textAlign: TextAlign.center, style: t.displayMedium),
        const SizedBox(height: 10),
        Text(
          'Si no respondes, avisamos a ${_nombres(contactos)}${conUbicacion ? ' con tu ubicación' : ''}.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        Center(
          child: CountdownRing(
            restante: control.fraccionRestante,
            segundos: control.segundosRestantes,
          ),
        ),
        if (control.sonidoFallo) ...[
          const SizedBox(height: 12),
          Text(
            ControlAlerta.errorSonido,
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
          onPressed: control.pedirAyuda,
        ),
        const SizedBox(height: 12),
        Text(
          estado.tienePermiso(PermisoSistema.sms)
              ? 'Se enviará un SMS a ${_nombres(contactos)}.'
              : 'Sin permiso de SMS: solo les llegará a tus cuidadores con Rondó.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _avisando(ControlAlerta control) {
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
        Text('Enviando los mensajes con tu ubicación.', textAlign: TextAlign.center, style: t.bodyLarge),
      ],
    );
  }

  Widget _icono(IconData icono) {
    final c = context.rondo;
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(color: c.alert.withValues(alpha: 0.18), shape: BoxShape.circle),
        child: Icon(icono, size: 44, color: c.alertText),
      ),
    );
  }

  Widget _avisoEnviado(ControlAlerta control) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    // En la simulación se muestran todos; en la real, solo a quienes les llegó.
    final avisados = control.simulada ? control.contactos : control.conSms;
    final titulo = control.simulada
        ? 'Simulación'
        : avisados.isEmpty
            ? 'Avisamos a tus cuidadores'
            : 'Avisamos a tus contactos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Spacer(),
        _icono(Icons.notifications_active_rounded),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(titulo, textAlign: TextAlign.center, style: t.headlineLarge),
        ),
        const SizedBox(height: 10),
        Text(
          control.simulada
              ? 'En este dispositivo no se envían mensajes.'
              : control.prueba
                  ? 'Les llegó que es una prueba, no una emergencia.'
                  : control.posicion == null
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
        if (control.llegoACuidadores) ...[
          const SizedBox(height: 12),
          Text('Tus cuidadores también la ven en Rondó.', textAlign: TextAlign.center, style: t.bodyMedium),
        ],
        ..._problemas(control),
        const Spacer(),
        const SizedBox(height: 24),
        if (!control.simulada && !control.prueba) ...[
          PrimaryButton(
            label: 'Ya estoy bien, avísales',
            icon: Icons.favorite_rounded,
            onPressed: _yaEstoyBien,
          ),
          const SizedBox(height: 10),
        ],
        SecondaryButton(label: 'Volver al inicio', blur: false, onPressed: control.cerrar),
        const SizedBox(height: 10),
        Text('En una emergencia, llama al 123.', textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Lo que salió mal, con los mensajes de RF-15 y RF-16, y cómo arreglarlo.
  List<Widget> _problemas(ControlAlerta control) {
    if (control.simulada) return const [];
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final textos = [
      if (control.posicion == null) 'No se pudo obtener tu ubicación. Se avisó a tus contactos sin ella.',
      if (control.faltaPermisoSms)
        'La app no tiene permiso para enviar SMS. Actívalo en ajustes.'
      else if (control.sinSms.isNotEmpty)
        control.reintentando
            ? 'No se pudo notificar a ${_nombres(control.sinSms)}. Reintentando…'
            : 'No se pudo enviar el SMS a ${_nombres(control.sinSms)}. Verifica tu señal y tu saldo.',
      ..._problemaServidor(control),
    ];
    return [
      for (final texto in textos) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: t.labelLarge!.copyWith(color: c.errorText),
          ),
        ),
      ],
      if (control.faltaPermisoSms) ...[
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Permitir SMS y reintentar',
          icon: Icons.sms_rounded,
          blur: false,
          onPressed: _permitirSms,
        ),
      ],
    ];
  }

  List<String> _problemaServidor(ControlAlerta control) => switch (control.entregaServidor) {
        EntregaServidor.pendiente => const [
            'Sin conexión: a tus cuidadores les llegará en Rondó cuando vuelva el internet.',
          ],
        EntregaServidor.fallo => [
            control.reintentando
                ? 'No se pudo avisar a tus cuidadores en Rondó. Reintentando…'
                : 'No se pudo avisar a tus cuidadores en Rondó.',
          ],
        _ => const [],
      };

  /// RF-17: no salió nada. La alarma sigue sonando para que alguien cerca la oiga.
  Widget _nadieAvisado(ControlAlerta control) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final sinSenal = !control.faltaPermisoSms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Spacer(),
        _icono(Icons.campaign_rounded),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text('No pudimos avisar a nadie', textAlign: TextAlign.center, style: t.headlineLarge),
        ),
        const SizedBox(height: 10),
        Text(
          sinSenal
              ? 'Sin conexión ni señal. Activando alarma sonora para pedir ayuda cercana.'
              : 'Activando alarma sonora para pedir ayuda cercana.',
          textAlign: TextAlign.center,
          style: t.bodyLarge!.copyWith(color: c.textSecondary),
        ),
        ..._problemas(control),
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
          blur: false,
          onPressed: control.cerrar,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
