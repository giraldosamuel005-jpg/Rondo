import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/rondo_back_button.dart';

/// Vista previa de la ficha médica en solo lectura: lo que verá quien escanee
/// el QR (RF-24). La página real vivirá en el servidor; esta muestra a la
/// persona qué datos suyos quedan a la vista.
class FichaVistaPage extends StatelessWidget {
  const FichaVistaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final ficha = estado.fichaMedica;
    final contacto = ficha?.contactoEmergenciaEn(estado.contactos);

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: RondoBackButton()),
              const SizedBox(height: 22),
              Text('Así se ve tu ficha', style: t.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Esto verá quien escanee tu código en una emergencia. Solo puede leerlo, no cambiarlo.',
                style: t.bodyMedium!.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 22),
              if (ficha == null)
                Glass(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aún no tienes ficha médica.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge,
                  ),
                )
              else ...[
                // ---------- De quién es ----------
                Glass(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      RondoAvatar(iniciales: inicialesDe(estado.nombre), size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ficha médica de', style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
                            const SizedBox(height: 2),
                            Text(estado.nombre, style: t.titleLarge),
                            if (ficha.fechaNacimiento != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${ficha.edad(DateTime.now())} años · ${fechaCompleta(ficha.fechaNacimiento!)}',
                                style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---------- Tipo de sangre ----------
                Glass(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    label: 'Tipo de sangre: ${ficha.tipoSangre.etiqueta}',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ficha.tipoSangre.etiqueta,
                            style: t.headlineLarge!.copyWith(color: c.accentLink),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text('Tipo de sangre', style: t.titleMedium)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ---------- Alergias ----------
                Glass(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alergias', style: t.titleMedium),
                      const SizedBox(height: 10),
                      if (ficha.alergias.isEmpty)
                        Text('Sin alergias conocidas.', style: t.bodyLarge)
                      else
                        _Etiquetas(ficha.alergias),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---------- Lo opcional: si está vacío, no se muestra ----------
                // Sin desenfoque: la pantalla no puede pasar de 6.
                if (ficha.enfermedades.isNotEmpty) ...[
                  _SeccionOpcional(
                    titulo: 'Enfermedades',
                    child: _Etiquetas(ficha.enfermedades),
                  ),
                  const SizedBox(height: 12),
                ],
                if (ficha.mostrarMedicamentos && estado.medicamentos.isNotEmpty) ...[
                  _SeccionOpcional(
                    titulo: 'Medicamentos',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final medicamento in estado.medicamentos)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${medicamento.nombre} · ${medicamento.dosis} · ${medicamento.frecuenciaTexto}',
                              style: t.bodyLarge,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (ficha.notas.isNotEmpty) ...[
                  _SeccionOpcional(
                    titulo: 'Notas',
                    child: Text(ficha.notas, style: t.bodyLarge),
                  ),
                  const SizedBox(height: 12),
                ],

                // ---------- Contacto de emergencia ----------
                Glass(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contacto de emergencia', style: t.titleMedium),
                      const SizedBox(height: 10),
                      if (contacto == null)
                        Text('Sin contacto. Elige uno al editar tu ficha.', style: t.bodyLarge)
                      else
                        Row(
                          children: [
                            RondoAvatar(iniciales: contacto.iniciales),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contacto.nombre,
                                    style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    contacto.detalle,
                                    style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionOpcional extends StatelessWidget {
  const _SeccionOpcional({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Etiquetas extends StatelessWidget {
  const _Etiquetas(this.textos);

  final List<String> textos;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final texto in textos)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.rondo.neutralSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(texto, style: Theme.of(context).textTheme.bodyLarge),
          ),
      ],
    );
  }
}
