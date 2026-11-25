import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/contacto.dart';
import '../theme/rondo_colors.dart';
import '../utils/formato.dart';
import 'glass.dart';
import 'glass_field.dart';
import 'primary_button.dart';

/// Abre el formulario de contacto desde abajo: para agregar, o para editar
/// [editando]. Devuelve el contacto, o null si la persona lo cerró sin guardar.
/// [celularPropio]: nadie puede ser su propio contacto de emergencia.
Future<Contacto?> mostrarFormularioContacto(
  BuildContext context, {
  required List<String> celularesRegistrados,
  String? celularPropio,
  Contacto? editando,
}) {
  return showModalBottomSheet<Contacto>(
    context: context,
    isScrollControlled: true, // Para que suba con el teclado
    builder: (_) => _FormularioContacto(
      celularesRegistrados: celularesRegistrados,
      celularPropio: celularPropio,
      editando: editando,
    ),
  );
}

enum AccionContacto { editar, quitar }

/// Al tocar un contacto: editarlo o quitarlo (RF-31).
Future<AccionContacto?> mostrarAccionesContacto(BuildContext context, Contacto contacto) {
  final c = context.rondo;
  final t = Theme.of(context).textTheme;
  return showModalBottomSheet<AccionContacto>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(contacto.nombre, style: t.titleLarge),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.edit_outlined, color: c.accent),
            title: Text('Editar', style: t.bodyLarge),
            onTap: () => Navigator.of(context).pop(AccionContacto.editar),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.person_remove_outlined, color: c.errorText),
            title: Text('Quitar', style: t.bodyLarge!.copyWith(color: c.errorText)),
            onTap: () => Navigator.of(context).pop(AccionContacto.quitar),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
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
  const _FormularioContacto({required this.celularesRegistrados, this.celularPropio, this.editando});

  final List<String> celularesRegistrados;
  final String? celularPropio;

  /// `null` = contacto nuevo.
  final Contacto? editando;

  @override
  State<_FormularioContacto> createState() => _FormularioContactoState();
}

class _FormularioContactoState extends State<_FormularioContacto> {
  late final _nombreController = TextEditingController(text: widget.editando?.nombre);
  late final _relacionController = TextEditingController(text: widget.editando?.relacion);
  late final _celularController = TextEditingController(text: widget.editando?.celular);
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

    if (nombre.isEmpty || !celularValido(celular)) {
      setState(() => _error = 'Ingresa un nombre y un número de celular válidos.');
      return;
    }
    if (celular == widget.celularPropio) {
      setState(() => _error = 'Ese es tu propio número. Escribe el de otra persona.');
      return;
    }
    if (celular != widget.editando?.celular && widget.celularesRegistrados.contains(celular)) {
      setState(() => _error = 'Este contacto ya está registrado.');
      return;
    }

    // Cierra el formulario y le entrega el contacto a quien lo abrió.
    Navigator.of(context).pop(
      Contacto(
        nombre: nombre,
        relacion: _relacionController.text.trim(),
        celular: celular,
        esCuidador: widget.editando?.esCuidador ?? false,
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
            Text(widget.editando == null ? 'Agregar contacto' : 'Editar contacto', style: t.titleLarge),
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
