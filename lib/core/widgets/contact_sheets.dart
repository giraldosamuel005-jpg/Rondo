import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contacto.dart';
import '../theme/rondo_colors.dart';
import 'glass.dart';
import 'glass_field.dart';
import 'primary_button.dart';

/// Abre el formulario "Agregar contacto" desde abajo.
/// Devuelve el contacto nuevo, o null si la persona lo cerró sin guardar.
Future<Contacto?> mostrarFormularioContacto(
  BuildContext context, {
  required List<String> celularesRegistrados,
}) {
  return showModalBottomSheet<Contacto>(
    context: context,
    isScrollControlled: true, // Para que suba con el teclado
    builder: (_) => _FormularioContacto(celularesRegistrados: celularesRegistrados),
  );
}

/// Pregunta "¿Quitar a ...?". Devuelve true si la persona confirma.
Future<bool> confirmarQuitarContacto(BuildContext context, Contacto contacto) async {
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
  return confirmar == true;
}

class _FormularioContacto extends StatefulWidget {
  const _FormularioContacto({required this.celularesRegistrados});

  final List<String> celularesRegistrados;

  @override
  State<_FormularioContacto> createState() => _FormularioContactoState();
}

class _FormularioContactoState extends State<_FormularioContacto> {
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

    // Cierra el formulario y le entrega el contacto a quien lo abrió.
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
