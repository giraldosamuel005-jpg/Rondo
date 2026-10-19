import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/permission_row.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/step_pill.dart';
import '../home/home_page.dart';

/// 03 · ¿A quién avisamos? — Paso 2 de 2.
/// RF-04 (contactos de emergencia) y RF-30 (permisos con su razón).
/// Los contactos y permisos viven en [AppState]; esta pantalla solo los muestra.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  Future<void> _agregarContacto(BuildContext context) async {
    final estado = context.read<AppState>();

    // El formulario se abre desde abajo y devuelve el contacto nuevo (o null).
    final nuevo = await showModalBottomSheet<Contacto>(
      context: context,
      isScrollControlled: true, // Para que suba con el teclado
      builder: (_) => _NuevoContactoSheet(
        celularesRegistrados: estado.contactos.map((k) => k.celular).toList(),
      ),
    );
    if (nuevo != null) estado.agregarContacto(nuevo);
  }

  Future<void> _quitarContacto(BuildContext context, Contacto contacto) async {
    final estado = context.read<AppState>();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar a ${contacto.nombre}?'),
        content: const Text('Dejará de recibir tus alertas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.rondo.errorText),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar == true) estado.quitarContacto(contacto);
  }

  void _activarRonda(BuildContext context) {
    context.read<AppState>().activarRonda();

    // Entra a Inicio y borra todo el registro del historial:
    // "atrás" ya no vuelve a estas pantallas.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
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
                      // Por ahora solo visuales: más adelante cada interruptor
                      // pedirá el permiso real de Android.
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Lo que Rondó necesita',
                          style: t.bodySmall!.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PermissionRow(
                              title: 'Ubicación siempre',
                              reason: 'Solo se envía dentro de una alerta.',
                              value: estado.permisoUbicacion,
                              onChanged: estado.cambiarPermisoUbicacion,
                            ),
                            const GlassDivider(indent: 18),
                            PermissionRow(
                              title: 'Sensores de movimiento',
                              reason: 'Detectan la caída en el teléfono.',
                              value: estado.permisoSensores,
                              onChanged: estado.cambiarPermisoSensores,
                            ),
                          ],
                        ),
                      ),

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

/// Formulario para agregar un contacto (se abre desde abajo).
class _NuevoContactoSheet extends StatefulWidget {
  const _NuevoContactoSheet({required this.celularesRegistrados});

  final List<String> celularesRegistrados;

  @override
  State<_NuevoContactoSheet> createState() => _NuevoContactoSheetState();
}

class _NuevoContactoSheetState extends State<_NuevoContactoSheet> {
  final _nombreController = TextEditingController();
  final _relacionController = TextEditingController();
  final _celularController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _relacionController.dispose();
    _celularController.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombreController.text.trim();
    final celular = _celularController.text;

    if (nombre.isEmpty || celular.length != 10) {
      setState(() => _error = 'Ingresa un nombre y un número de celular válidos.');
      return;
    }
    if (widget.celularesRegistrados.contains(celular)) {
      setState(() => _error = 'Este contacto ya está registrado.');
      return;
    }

    // Cierra el formulario y le entrega el contacto a la pantalla anterior.
    Navigator.of(context).pop(
      Contacto(
        nombre: nombre,
        relacion: _relacionController.text.trim(),
        celular: celular,
      ),
    );
  }

  void _limpiarError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    // Espacio del teclado, para que no tape el botón.
    final teclado = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + teclado),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar contacto', style: t.titleLarge),
            const SizedBox(height: 6),
            Text('Recibirá tus alertas si algo te pasa.', style: t.bodyMedium),
            const SizedBox(height: 18),
            Glass(
              blur: false,
              shadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassField(
                    label: 'Nombre',
                    controller: _nombreController,
                    hint: 'Ej. Ana Gómez',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: _limpiarError,
                  ),
                  const GlassDivider(indent: 18),
                  GlassField(
                    label: 'Relación (opcional)',
                    controller: _relacionController,
                    hint: 'Ej. Hija',
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const GlassDivider(indent: 18),
                  GlassField(
                    label: 'Celular',
                    controller: _celularController,
                    hint: '300 123 4567',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: _limpiarError,
                    onSubmitted: (_) => _guardar(),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: t.labelLarge!.copyWith(color: c.errorText)),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(label: 'Guardar contacto', onPressed: _guardar),
          ],
        ),
      ),
    );
  }
}
