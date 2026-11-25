import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/alertas/control_alerta.dart';
import '../../core/deteccion/vigilante_caidas.dart';
import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/status_mark.dart';
import '../cuidador/abrir_enlace.dart';
import '../medicamentos/medicamentos_page.dart';
import 'proteccion.dart';

/// 05 · Inicio (pestaña 1): estado de la ronda (activa o en pausa).
/// La barra de pestañas la pone [MainShell]; esta pantalla solo es el contenido.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onVerContactos,
    required this.onVerAjustes,
  });

  /// Lleva a la pestaña Contactos ("Te cuidan N personas").
  final VoidCallback onVerContactos;

  /// Lleva a la pestaña Ajustes (avatar de perfil).
  final VoidCallback onVerAjustes;

  void _alternarPausa(BuildContext context) {
    final estado = context.read<AppState>();
    estado.alternarPausa();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          estado.rondaEnPausa
              ? 'Ronda en pausa. Nadie recibirá alertas.'
              : 'Ronda activa de nuevo.',
        ),
      ),
    );
  }

  /// RF-12: confirma que está sin novedad.
  void _estoyBien(BuildContext context) {
    final estado = context.read<AppState>();
    final vinculos = context.read<Vinculos?>();
    final control = context.read<ControlAlerta?>();
    // Si hay una alerta abierta, esto también les avisa a quienes la recibieron.
    if (estado.alertaAbierta != null && control != null) {
      control.yaEstoyBien();
    } else {
      estado.confirmarEstoyBien();
    }
    final sinConexion =
        vinculos != null &&
        vinculos.sinConexion &&
        vinculos.cuidadoresActivos.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sinConexion
              ? 'No se pudo registrar tu confirmación. Se reintentará cuando haya conexión.'
              : 'Listo. Quedó registrado que estás bien (${horaCorta(DateTime.now())}).',
        ),
      ),
    );
  }

  /// "las 8:29 p. m." si fue hoy; si no, también el día.
  static String _desde(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy =
        fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;
    return hoy
        ? 'las ${horaCorta(fecha)}'
        : '${diaRelativo(fecha).toLowerCase()}, ${horaCorta(fecha)}';
  }

  /// "Avisamos a 2 contactos · 1 te cuida en Rondó". Un contacto recibe el
  /// SMS; solo quien aceptó la invitación cuida desde la app.
  static String _quienes(int contactos, int? cuidadores) {
    final avisamos = contactos == 1
        ? 'Avisamos a 1 contacto'
        : 'Avisamos a $contactos contactos';
    if (cuidadores == null || cuidadores == 0) return avisamos;
    return cuidadores == 1
        ? '$avisamos · 1 te cuida en Rondó'
        : '$avisamos · $cuidadores te cuidan en Rondó';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final abajo = MediaQuery.paddingOf(context).bottom;

    // Lee del cerebro y se redibuja cuando algo cambia.
    final estado = context.watch<AppState>();
    final enPausa = estado.rondaEnPausa;
    final contactos = estado.contactos;
    final cuantos = contactos.length;
    final activaDesde = estado.rondaActivaDesde ?? DateTime.now();
    final ultimoEstoyBien = estado.ultimoEstoyBien;
    // No hay en web, Windows ni en pruebas: ahí no se detectan caídas.
    final vigilante = context.watch<VigilanteCaidas?>();
    final conAlertas = context.watch<ControlAlerta?>() != null;
    final abierta = estado.alertaAbierta;
    final cuidadores = context.watch<Vinculos?>()?.cuidadoresActivos.length;

    return BlobBackground(
      blobs: BlobBackground.inicio,
      child: SafeArea(
        bottom: false,
        child: ListView(
          // "abajo" ya incluye la altura de la barra de pestañas (extendBody).
          padding: EdgeInsets.fromLTRB(20, 12, 20, abajo + 16),
          children: [
            // Saludo + perfil
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fechaLarga(DateTime.now()), style: t.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Hola, ${primerNombre(estado.nombre)}',
                        style: t.headlineLarge,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Perfil y ajustes',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onVerAjustes,
                    child: RondoAvatar(
                      iniciales: inicialesDe(estado.nombre),
                      size: 44,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (abierta != null && conAlertas) ...[
              AlertaAbierta(fecha: abierta.fecha),
              const SizedBox(height: 12),
            ],

            // ---------- Estado de la ronda ----------
            // Marca a la izquierda y texto a la derecha: así ocupa un tercio de
            // la pantalla y Medicamentos se ve sin tener que desplazarse.
            Glass(
              radius: 32,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      EstadoMarca(activa: !enPausa),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusChip(
                              label: enPausa ? 'En pausa' : 'Ronda activa',
                              variant: enPausa
                                  ? StatusChipVariant.pausa
                                  : StatusChipVariant.activa,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              enPausa
                                  ? 'Ronda en pausa'
                                  : abierta != null
                                  ? 'Alerta enviada'
                                  : 'Todo en orden',
                              style: t.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    enPausa
                        ? 'Nadie recibirá alertas hasta que la reanudes.'
                        : 'Activa desde ${_desde(activaDesde)}${abierta == null ? ' · sin novedades' : ''}',
                    style: t.bodyMedium,
                  ),
                  if (!enPausa && vigilante != null) ...[
                    const SizedBox(height: 8),
                    _EstadoDeteccion(vigilante),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            AvisosProteccion(
              onVerAjustes: onVerAjustes,
              onVerContactos: onVerContactos,
            ),

            if (conAlertas) ...[
              const BotonPedirAyuda(),
              const SizedBox(height: 12),
            ],

            // ---------- Bloques: uno grande y dos pequeños ----------
            // "Estoy bien" es la acción que más se usa: ocupa el bloque alto.
            // IntrinsicHeight + stretch: el bloque alto mide lo que miden los dos pequeños.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _Atajo(
                      grande: true,
                      icono: Icons.favorite_rounded,
                      etiqueta: 'Estoy bien',
                      detalle: ultimoEstoyBien == null
                          ? null
                          : '${diaRelativo(ultimoEstoyBien)}, ${horaCorta(ultimoEstoyBien)}',
                      onTap: () => _estoyBien(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Atajo(
                            icono: enPausa
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            etiqueta: enPausa ? 'Reanudar' : 'Pausar',
                            onTap: () => _alternarPausa(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Emergencias (RF-34): abre el marcador con el 123.
                        Expanded(
                          child: _Atajo(
                            icono: Icons.phone_rounded,
                            etiqueta: 'Llamar al 123',
                            onTap: () => llamarAl123(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Quiénes te cuidan + medicamentos: una sola tarjeta ----------
            // Dos filas en el mismo vidrio (un solo desenfoque) en vez de dos
            // tarjetas iguales apiladas.
            Glass(
              child: Column(
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onVerContactos,
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            _AvataresApilados(contactos: contactos),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _quienes(cuantos, cuidadores),
                                style: t.titleMedium,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Medicamentos: solo quien se cuida a sí mismo.
                  if (estado.usaFichaMedica) ...[
                    const GlassDivider(),
                    const _TarjetaMedicamentos(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// RF-06 / RF-32: dice si la detección de caídas está funcionando, o por qué
/// no, en vez de fallar en silencio.
class _EstadoDeteccion extends StatelessWidget {
  const _EstadoDeteccion(this.vigilante);

  final VigilanteCaidas vigilante;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final aviso = vigilante.aviso;

    return Semantics(
      liveRegion: aviso != null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aviso == null ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            size: 18,
            color: aviso == null ? c.accent : c.errorText,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              aviso ?? 'Detección de caídas activa',
              textAlign: TextAlign.start,
              style: t.labelLarge!.copyWith(
                fontWeight: FontWeight.w400,
                color: aviso == null ? null : c.errorText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque de vidrio con ícono y texto ("Estoy bien", "Pausar", "Llamar al 123").
/// [grande]: el bloque alto de Inicio (ícono grande, texto abajo, con desenfoque).
/// Los pequeños van sin desenfoque: Inicio ya usa 4 de los 6 permitidos.
class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.detalle,
    this.grande = false,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final bool grande;

  /// Texto pequeño debajo, por ejemplo "Hoy, 3:45 p. m.".
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    final icon = Container(
      width: grande ? 56 : 44,
      height: grande ? 56 : 44,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(grande ? 18 : 14),
      ),
      child: Icon(icono, size: grande ? 28 : 22, color: c.accent),
    );

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: grande ? t.titleLarge : t.titleMedium),
        if (detalle != null) ...[
          const SizedBox(height: 2),
          Text(
            detalle!,
            style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ],
    );

    return Glass(
      blur: grande,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: EdgeInsets.all(grande ? 18 : 14),
            child: grande
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [icon, textos],
                  )
                : Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: textos),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Hasta 3 avatares superpuestos.
class _AvataresApilados extends StatelessWidget {
  const _AvataresApilados({required this.contactos});

  final List<Contacto> contactos;

  @override
  Widget build(BuildContext context) {
    const tamano = 34.0;
    const solape = 22.0; // Cuánto avanza cada avatar
    final visibles = contactos.take(3).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: tamano + solape * (visibles.length - 1),
      height: tamano,
      child: Stack(
        children: [
          for (var i = 0; i < visibles.length; i++)
            Positioned(
              left: solape * i,
              child: RondoAvatar(
                iniciales: visibles[i].iniciales,
                size: tamano,
                variante: i,
                borderColor: context.rondo.bg,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Medicamentos · Próxima: Losartán, hoy a las 8:00 p. m." → abre la lista.
class _TarjetaMedicamentos extends StatelessWidget {
  const _TarjetaMedicamentos();

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final proxima = estado.proximaToma(DateTime.now());
    final acabandose = estado.medicamentos
        .where((m) => m.seEstaAcabando)
        .toList();

    final resumen = proxima == null
        ? 'Agrega tus medicamentos'
        : 'Próxima: ${proxima.medicamento.nombre}, '
              '${diaRelativo(proxima.hora).toLowerCase()} a las ${horaCorta(proxima.hora)}';

    // Va dentro de la tarjeta de vidrio de Inicio (sin su propio vidrio).
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MedicamentosPage.abrir()),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.medication_rounded, color: c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medicamentos', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      resumen,
                      style: t.labelLarge!.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (acabandose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        acabandose.first.avisoReponer,
                        style: t.labelLarge!.copyWith(color: c.text),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
