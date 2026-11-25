import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/contacto.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/vinculos/vinculos.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/contact_row.dart';
import '../../core/widgets/contact_sheets.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/tab_page.dart';
import '../cuidador/abrir_enlace.dart';
import 'quien_te_cuida.dart';

/// Pestaña Contactos (RF-04, RF-31): ver, agregar y quitar contactos de emergencia.
class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  Future<void> _agregar(BuildContext context) async {
    final estado = context.read<AppState>();
    final nuevo = await mostrarFormularioContacto(
      context,
      celularesRegistrados: estado.contactos.map((k) => k.celular).toList(),
      celularPropio: estado.celular,
    );
    if (nuevo != null) estado.agregarContacto(nuevo);
  }

  Future<void> _tocar(BuildContext context, Contacto contacto) async {
    final accion = await mostrarAccionesContacto(context, contacto);
    if (!context.mounted) return;
    switch (accion) {
      case AccionContacto.editar:
        await _editar(context, contacto);
      case AccionContacto.quitar:
        await _quitar(context, contacto);
      case null:
    }
  }

  /// RF-31. Con otro celular ya es otra persona para el servidor: si lo
  /// cuidaba, ese vínculo se corta y hay que invitarlo otra vez.
  Future<void> _editar(BuildContext context, Contacto contacto) async {
    final estado = context.read<AppState>();
    final vinculos = context.read<Vinculos?>();
    final mensajero = ScaffoldMessenger.of(context);
    final nuevo = await mostrarFormularioContacto(
      context,
      celularesRegistrados: estado.contactos.map((k) => k.celular).toList(),
      celularPropio: estado.celular,
      editando: contacto,
    );
    if (nuevo == null) return;
    estado.editarContacto(contacto, nuevo);
    if (nuevo.celular == contacto.celular) return;
    final teniaVinculo = vinculos?.vinculoCon(contacto.celular) != null;
    await vinculos?.olvidarContacto(contacto.celular);
    if (teniaVinculo) {
      mensajero.showSnackBar(
        SnackBar(content: Text('Cambió su número: invita otra vez a ${nuevo.nombre} a cuidarte.')),
      );
    }
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

    final vinculos = context.read<Vinculos?>();
    if (await confirmarQuitarContacto(context, contacto)) {
      estado.quitarContacto(contacto);
      // Si lo cuidaba, deja de ver sus datos (RF-27).
      await vinculos?.olvidarContacto(contacto.celular);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final contactos = context.watch<AppState>().contactos;
    // Sin servidor (pruebas, o plataformas sin Firebase) no hay invitaciones.
    final hayVinculos = context.watch<Vinculos?>() != null;

    return TabPage(
      title: 'Contactos',
      subtitle: 'Reciben tus alertas si algo te pasa. Toca el teléfono para llamar, o el nombre para editarlo o quitarlo.',
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
                  onTap: () => _tocar(context, contactos[i]),
                  onLlamar: () => llamarAContacto(context, contactos[i]),
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
                  'Les avisamos a todos a la vez por SMS. Funciona sin internet.',
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (hayVinculos && contactos.isNotEmpty) ...[
          const SizedBox(height: 22),
          const QuienTeCuida(),
        ],
      ],
    );
  }
}
