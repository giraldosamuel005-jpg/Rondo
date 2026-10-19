import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/contact_sheets.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';

/// Pestaña Contactos (RF-04, RF-31): ver, agregar y quitar contactos de emergencia.
class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  Future<void> _agregar(BuildContext context) async {
    final estado = context.read<AppState>();
    final nuevo = await mostrarFormularioContacto(
      context,
      celularesRegistrados: estado.contactos.map((k) => k.celular).toList(),
    );
    if (nuevo != null) estado.agregarContacto(nuevo);
  }

  Future<void> _quitar(BuildContext context, Contacto contacto) async {
    final estado = context.read<AppState>();

    // RF-31: siempre debe quedar al menos un contacto.
    if (estado.contactos.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes mantener al menos un contacto de emergencia.')),
      );
      return;
    }

    if (await confirmarQuitarContacto(context, contacto)) {
      estado.quitarContacto(contacto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final contactos = context.watch<AppState>().contactos;

    return TabPage(
      title: 'Contactos',
      subtitle: 'Reciben tus alertas si algo te pasa. Toca uno para quitarlo.',
      blobs: BlobBackground.paso,
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < contactos.length; i++) ...[
                if (i > 0) const GlassDivider(indent: 68),
                ContactRow(
                  contacto: contactos[i],
                  orden: i + 1,
                  onTap: () => _quitar(context, contactos[i]),
                ),
              ],
              if (contactos.isNotEmpty) const GlassDivider(indent: 68),
              AddContactRow(onTap: () => _agregar(context)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.sms_outlined, size: 22, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Les avisamos a todos a la vez. Si no tienes datos, les llega un SMS.',
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
