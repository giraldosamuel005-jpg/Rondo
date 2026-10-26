import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/persona_a_cargo.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/tab_page.dart';
import 'abrir_enlace.dart';
import 'alertas_tab.dart';
import 'personas_tab.dart';

/// Detalle de una persona a cargo (RF-26): estado, última ubicación,
/// "Estoy bien", medicamentos y alertas recientes. Solo lectura (RF-27).
class PersonaDetallePage extends StatelessWidget {
  const PersonaDetallePage({super.key, required this.personaId});

  final String personaId;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final persona = context.watch<AppState>().personaACargo(personaId);
    if (persona == null) return const Scaffold(); // Se cerró la sesión

    final ubicacion = persona.ubicacion;
    final estoyBien = persona.ultimoEstoyBien;
    final nombre = primerNombre(persona.nombre);

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso,
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
                      const SizedBox(height: 18),

                      // ---------- Encabezado ----------
                      Row(
                        children: [
                          RondoAvatar(iniciales: inicialesDe(persona.nombre), size: 64),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(persona.nombre, style: t.headlineLarge!.copyWith(fontSize: 28)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (persona.relacion.isNotEmpty) persona.relacion,
                                    formatearCelular(persona.celular),
                                  ].join(' · '),
                                  style: t.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: EstadoPersonaChip(estado: persona.estado),
                      ),
                      const SizedBox(height: 22),

                      if (persona.estado == EstadoPersona.alerta) ...[
                        AvisoAlertaPersona(persona: persona),
                        const SizedBox(height: 22),
                      ],

                      // ---------- Última ubicación ----------
                      const SectionLabel('Última ubicación'),
                      Glass(
                        padding: const EdgeInsets.all(16),
                        child: ubicacion == null
                            ? Text('Todavía no conocemos su ubicación.', style: t.bodyMedium)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.place_rounded, size: 22, color: c.accent),
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
                                              'Actualizada ${haceCuanto(ubicacion.fecha)}',
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
                                    onPressed: () => verEnMapa(context, ubicacion),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Cómo está ----------
                      const SectionLabel('Cómo está'),
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Fila(
                              icono: Icons.favorite_rounded,
                              titulo: 'Estoy bien',
                              detalle: estoyBien == null
                                  ? 'Aún no lo ha confirmado'
                                  : 'Lo confirmó ${haceCuanto(estoyBien)}',
                            ),
                            if (persona.cumplimiento != null) ...[
                              const GlassDivider(indent: 74),
                              _Fila(
                                icono: Icons.medication_rounded,
                                titulo: 'Medicamentos',
                                detalle: '${persona.cumplimiento} % de tomas cumplidas',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Alertas recientes ----------
                      const SectionLabel('Alertas recientes'),
                      Glass(
                        child: persona.alertas.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('Sin alertas recientes.', style: t.bodyMedium),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < persona.alertas.length; i++) ...[
                                    if (i > 0) const GlassDivider(indent: 74),
                                    FilaAlertaPersona(persona: persona, alerta: persona.alertas[i]),
                                  ],
                                ],
                              ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Llamar a $nombre',
                        icon: Icons.phone_rounded,
                        onPressed: () => llamarA(context, persona),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se abre el teléfono con su número listo para llamar.',
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

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.detalle});

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(icono, size: 22, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detalle, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
