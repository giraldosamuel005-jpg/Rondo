import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/persona_a_cargo.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/tab_page.dart';
import 'alerta_entrante_page.dart';
import 'persona_detalle_page.dart';

/// Pestaña Personas (cuidador, RF-26): quienes lo invitaron, con su estado,
/// su última ubicación, su último "Estoy bien" y cómo van con los medicamentos.
class PersonasTab extends StatelessWidget {
  const PersonasTab({super.key, required this.onVerAjustes});

  /// Lleva a la pestaña Ajustes (avatar de perfil).
  final VoidCallback onVerAjustes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final abajo = MediaQuery.paddingOf(context).bottom;
    final estado = context.watch<AppState>();
    final personas = estado.personasACargo;
    final conAlerta = [for (final p in personas) if (p.estado == EstadoPersona.alerta) p];

    return BlobBackground(
      blobs: BlobBackground.inicio,
      child: SafeArea(
        bottom: false,
        child: ListView(
          // "abajo" ya incluye la altura de la barra de pestañas (extendBody).
          padding: EdgeInsets.fromLTRB(20, 12, 20, abajo + 16),
          children: [
            // Saludo + perfil (igual que en Inicio)
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

            // ---------- Alertas sin atender: lo primero que se ve ----------
            for (final p in conAlerta) ...[
              AvisoAlertaPersona(persona: p),
              const SizedBox(height: 12),
            ],

            if (personas.isEmpty)
              const _SinPersonas()
            else ...[
              const SectionLabel('Personas que cuidas'),
              for (var i = 0; i < personas.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                // Máximo 6 desenfoques por pantalla: a partir de la 3.ª, sin blur.
                _TarjetaPersona(persona: personas[i], orden: i, blur: i < 2),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de una persona: nombre, estado y un resumen. Al tocarla, el detalle.
class _TarjetaPersona extends StatelessWidget {
  const _TarjetaPersona({required this.persona, required this.orden, required this.blur});

  final PersonaACargo persona;
  final int orden;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final ubicacion = persona.ubicacion;
    final estoyBien = persona.ultimoEstoyBien;

    return Glass(
      blur: blur,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PersonaDetallePage(personaId: persona.id)),
          ),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RondoAvatar(iniciales: inicialesDe(persona.nombre), size: 44, variante: orden),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(persona.nombre, style: t.titleMedium),
                          if (persona.relacion.isNotEmpty)
                            Text(
                              persona.relacion,
                              style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: EstadoPersonaChip(estado: persona.estado)),
                const SizedBox(height: 12),
                if (ubicacion != null)
                  _Dato(
                    icono: Icons.place_rounded,
                    texto: '${ubicacion.descripcion} · ${haceCuanto(ubicacion.fecha)}',
                  ),
                _Dato(
                  icono: Icons.favorite_rounded,
                  texto: estoyBien == null
                      ? 'Aún no ha confirmado que está bien'
                      : 'Dijo "Estoy bien" ${haceCuanto(estoyBien)}',
                ),
                if (persona.cumplimiento != null)
                  _Dato(
                    icono: Icons.medication_rounded,
                    texto: 'Medicamentos: ${persona.cumplimiento} % de tomas cumplidas',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de estado de una persona: "Ronda activa", "En pausa" o "Alerta".
class EstadoPersonaChip extends StatelessWidget {
  const EstadoPersonaChip({super.key, required this.estado});

  final EstadoPersona estado;

  @override
  Widget build(BuildContext context) {
    return switch (estado) {
      EstadoPersona.activa => const StatusChip(label: 'Ronda activa', variant: StatusChipVariant.activa),
      EstadoPersona.enPausa => const StatusChip(label: 'En pausa', variant: StatusChipVariant.pausa),
      EstadoPersona.alerta => const StatusChip(label: 'Alerta', variant: StatusChipVariant.alerta),
    };
  }
}

/// Una línea con ícono pequeño: "Casa · hace 15 min".
class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: c.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner ámbar arriba de la lista cuando alguien tiene una alerta sin atender.
class AvisoAlertaPersona extends StatelessWidget {
  const AvisoAlertaPersona({super.key, required this.persona});

  final PersonaACargo persona;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final alerta = persona.alertas.isEmpty ? null : persona.alertas.first;

    return Semantics(
      button: true,
      liveRegion: true,
      child: Glass(
        fill: c.alert.withValues(alpha: 0.14),
        borderColor: c.alert,
        borderWidth: 1.5,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => AlertaEntrantePage(personaId: persona.id),
              ),
            ),
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.alert.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: c.alertText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${primerNombre(persona.nombre)} podría haberse caído',
                          style: t.titleMedium!.copyWith(color: c.alertText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alerta == null
                              ? 'Toca para ver qué hacer.'
                              : 'Alerta ${haceCuanto(alerta.fecha)} · Toca para ver qué hacer.',
                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.alertText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// RF-26: "Aún no tienes personas a tu cargo." + cómo llegan.
class _SinPersonas extends StatelessWidget {
  const _SinPersonas();

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.volunteer_activism_rounded, size: 30, color: c.accent),
              ),
              const SizedBox(height: 14),
              Text(
                'Aún no tienes personas a tu cargo.',
                textAlign: TextAlign.center,
                style: t.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Cuando alguien te agregue como contacto en su Rondó, te llegará un SMS '
                'con una invitación. Al aceptarla, verás aquí su estado y su ubicación.',
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
            ],
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Cargar personas de ejemplo',
            icon: Icons.group_add_rounded,
            onPressed: () => context.read<AppState>().cargarPersonasDeEjemplo(),
          ),
          const SizedBox(height: 6),
          Text(
            'Modo de pruebas: mientras no hay servidor.',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ],
      ],
    );
  }
}
