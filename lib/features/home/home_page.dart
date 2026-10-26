import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/status_ring.dart';
import '../medicamentos/medicamentos_page.dart';

/// 05 · Inicio (pestaña 1): estado de la ronda (activa o en pausa).
/// La barra de pestañas la pone [MainShell]; esta pantalla solo es el contenido.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onVerContactos, required this.onVerAjustes});

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
          estado.rondaEnPausa ? 'Ronda en pausa. Nadie recibirá alertas.' : 'Ronda activa de nuevo.',
        ),
      ),
    );
  }

  /// RF-12: confirma que está sin novedad.
  void _estoyBien(BuildContext context) {
    final estado = context.read<AppState>();
    estado.confirmarEstoyBien();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Listo. Quedó registrado que estás bien (${horaCorta(DateTime.now())}).'),
      ),
    );
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
                      Text('Hola, ${primerNombre(estado.nombre)}', style: t.headlineLarge),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Perfil y ajustes',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onVerAjustes,
                    child: RondoAvatar(iniciales: inicialesDe(estado.nombre), size: 44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- Tarjeta héroe: estado de la ronda ----------
            Glass(
              radius: 32,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                children: [
                  StatusRing(activa: !enPausa),
                  const SizedBox(height: 18),
                  StatusChip(
                    label: enPausa ? 'En pausa' : 'Ronda activa',
                    variant: enPausa ? StatusChipVariant.pausa : StatusChipVariant.activa,
                  ),
                  const SizedBox(height: 10),
                  Text(enPausa ? 'Ronda en pausa' : 'Todo en orden', style: t.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    enPausa
                        ? 'Nadie recibirá alertas hasta que la reanudes.'
                        : 'Desde las ${horaCorta(activaDesde)} · sin novedades',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Atajos ----------
            // IntrinsicHeight + stretch: las dos tarjetas miden lo mismo aunque
            // "Estoy bien" tenga una línea más.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Atajo(
                      icono: enPausa ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      etiqueta: enPausa ? 'Reanudar ronda' : 'Pausar ronda',
                      onTap: () => _alternarPausa(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Atajo(
                      icono: Icons.favorite_rounded,
                      etiqueta: 'Estoy bien',
                      detalle: ultimoEstoyBien == null
                          ? null
                          : '${diaRelativo(ultimoEstoyBien)}, ${horaCorta(ultimoEstoyBien)}',
                      onTap: () => _estoyBien(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Quiénes te cuidan ----------
            Glass(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onVerContactos,
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _AvataresApilados(contactos: contactos),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cuantos == 1 ? 'Te cuida 1 persona' : 'Te cuidan $cuantos personas',
                            style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ---------- Medicamentos (solo quien se cuida a sí mismo) ----------
            if (estado.usaFichaMedica) ...[
              const SizedBox(height: 12),
              const _TarjetaMedicamentos(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón cuadrado de vidrio con ícono y texto ("Pausar ronda", "Estoy bien").
class _Atajo extends StatelessWidget {
  const _Atajo({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.detalle,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  /// Texto pequeño debajo, por ejemplo "Hoy, 3:45 p. m.".
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Glass(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, size: 22, color: c.accent),
                ),
                const SizedBox(height: 12),
                Text(etiqueta, style: Theme.of(context).textTheme.titleMedium),
                if (detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle!,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                  ),
                ],
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
    final acabandose = estado.medicamentos.where((m) => m.seEstaAcabando).toList();

    final resumen = proxima == null
        ? 'Agrega tus medicamentos'
        : 'Próxima: ${proxima.medicamento.nombre}, '
            '${diaRelativo(proxima.hora).toLowerCase()} a las ${horaCorta(proxima.hora)}';

    return Glass(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MedicamentosPage()),
          ),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.medication_rounded, color: c.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicamentos',
                        style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(resumen, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
                      if (acabandose.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(acabandose.first.avisoReponer, style: t.labelLarge!.copyWith(color: c.text)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
