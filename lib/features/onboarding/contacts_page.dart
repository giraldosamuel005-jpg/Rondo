import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/contact_sheets.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/permisos_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/step_pill.dart';
import '../../core/widgets/tab_page.dart';
import '../shell/main_shell.dart';

/// 03 · ¿A quién avisamos? — Paso 2 de 2.
/// RF-04 (contactos de emergencia) y RF-30 (permisos con su razón).
/// Los contactos y permisos viven en [AppState]; esta pantalla solo los muestra.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  Future<void> _agregarContacto(BuildContext context) async {
    final estado = context.read<AppState>();
    final nuevo = await mostrarFormularioContacto(
      context,
      celularesRegistrados: estado.contactos.map((k) => k.celular).toList(),
    );
    if (nuevo != null) estado.agregarContacto(nuevo);
  }

  Future<void> _quitarContacto(BuildContext context, Contacto contacto) async {
    final estado = context.read<AppState>();
    if (await confirmarQuitarContacto(context, contacto)) {
      estado.quitarContacto(contacto);
    }
  }

  void _activarRonda(BuildContext context) {
    context.read<AppState>().activarRonda();

    // Entra a la app (pestañas) y borra todo el registro del historial:
    // "atrás" ya no vuelve a estas pantallas.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (ruta) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>(); // Se redibuja si cambia
    final contactos = estado.contactos;
    final sinContactos = contactos.isEmpty;

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
                      const Row(
                        children: [
                          RondoBackButton(),
                          Expanded(child: Center(child: StepPill(actual: 2, total: 2))),
                          SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('¿A quién avisamos?', style: t.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Al menos un contacto. Les llega un SMS, incluso sin datos.',
                        style: t.bodyMedium!.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Contactos (RF-04) ----------
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < contactos.length; i++) ...[
                              if (i > 0) const GlassDivider(indent: 68),
                              ContactRow(
                                contacto: contactos[i],
                                orden: i + 1,
                                onTap: () => _quitarContacto(context, contactos[i]),
                              ),
                            ],
                            if (!sinContactos) const GlassDivider(indent: 68),
                            AddContactRow(onTap: () => _agregarContacto(context)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Permisos (RF-30) ----------
                      const SectionLabel('Lo que Rondó necesita'),
                      const PermisosCard(),

                      const Spacer(),
                      const SizedBox(height: 24),
                      if (sinContactos) ...[
                        Text(
                          'Debes registrar al menos un contacto de emergencia.',
                          textAlign: TextAlign.center,
                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 10),
                      ],
                      PrimaryButton(
                        label: 'Activar mi ronda',
                        onPressed: sinContactos ? null : () => _activarRonda(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Puedes pausarla cuando quieras.',
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
