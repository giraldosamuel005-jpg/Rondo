import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/medicamento.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/secondary_button.dart';
import 'medicamento_form_page.dart';

/// Medicamentos (RF-20 a RF-22): lista con la próxima toma y los días que
/// quedan; al tocar uno se registra la toma.
class MedicamentosPage extends StatelessWidget {
  const MedicamentosPage({super.key});

  void _agregar(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MedicamentoFormPage()));
  }

  void _abrirDetalle(BuildContext context, Medicamento medicamento) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetalleMedicamento(id: medicamento.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final medicamentos = estado.medicamentos;
    final ahora = DateTime.now();
    final abajo = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.paso,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + abajo),
            children: [
              const Align(alignment: Alignment.centerLeft, child: RondoBackButton()),
              const SizedBox(height: 22),
              Text('Medicamentos', style: t.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Toca uno para marcar tu toma. Te decimos cuántos días te quedan.',
                style: t.bodyMedium!.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 22),

              if (estado.cumplimiento != null) ...[
                _Cumplimiento(porcentaje: estado.cumplimiento!, tomas: estado.tomas.length,
                    tomadas: estado.tomas.where((x) => x.tomada).length),
                const SizedBox(height: 12),
              ],

              if (medicamentos.isEmpty)
                const _SinMedicamentos()
              else
                for (final m in medicamentos) ...[
                  _TarjetaMedicamento(
                    medicamento: m,
                    proxima: estado.proximaPendiente(m, ahora),
                    onTap: () => _abrirDetalle(context, m),
                  ),
                  const SizedBox(height: 10),
                ],

              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Agregar medicamento',
                icon: Icons.add_rounded,
                onPressed: () => _agregar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Cumplimiento 86 % · 12 de 14 tomas" (RF-22).
class _Cumplimiento extends StatelessWidget {
  const _Cumplimiento({required this.porcentaje, required this.tomas, required this.tomadas});

  final int porcentaje;
  final int tomas;
  final int tomadas;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Glass(
      padding: const EdgeInsets.all(16),
      child: Semantics(
        label: 'Cumplimiento: $porcentaje por ciento. $tomadas de $tomas tomas.',
        excludeSemantics: true,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.task_alt_rounded, color: c.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cumplimiento', style: t.labelLarge),
                  Text('$porcentaje %', style: t.titleLarge),
                ],
              ),
            ),
            Text('$tomadas de $tomas tomas', style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _TarjetaMedicamento extends StatelessWidget {
  const _TarjetaMedicamento({required this.medicamento, required this.proxima, required this.onTap});

  final Medicamento medicamento;

  /// Próxima toma que falta por registrar.
  final DateTime proxima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final m = medicamento;

    return Glass(
      blur: false, // Puede haber muchas tarjetas: sin desenfoque
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
                Row(
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
                          Text(m.nombre, style: t.titleMedium),
                          Text(
                            '${m.dosis} · ${m.frecuenciaTexto}',
                            style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Próxima: ${diaRelativo(proxima)} a las ${horaCorta(proxima)}',
                        style: t.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.neutralSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(m.diasTexto, style: t.labelLarge!.copyWith(color: c.text)),
                    ),
                  ],
                ),
                if (m.seEstaAcabando) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: c.text),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(m.avisoReponer, style: t.labelLarge!.copyWith(color: c.text)),
                      ),
                    ],
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

class _SinMedicamentos extends StatelessWidget {
  const _SinMedicamentos();

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Glass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 32, color: c.textSecondary),
          const SizedBox(height: 12),
          Text('Aún no tienes medicamentos', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Agrégalos para saber cuándo tomarlos y cuántos días te quedan.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior de un medicamento: registrar la toma, editar o eliminar.
class _DetalleMedicamento extends StatelessWidget {
  const _DetalleMedicamento({required this.id});

  final String id;

  void _registrar(BuildContext context, {required bool tomada}) {
    final estado = context.read<AppState>();
    final mensajero = ScaffoldMessenger.of(context);
    estado.registrarToma(id, tomada: tomada);
    final m = estado.medicamento(id);
    Navigator.of(context).pop();

    final mensaje = !tomada
        ? 'Registramos que no la tomaste.'
        : (m != null && m.seEstaAcabando ? 'Toma registrada. ${m.avisoReponer}' : 'Listo, registramos tu toma.');
    mensajero.showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _editar(BuildContext context, Medicamento m) {
    final navegador = Navigator.of(context);
    navegador.pop();
    navegador.push(MaterialPageRoute(builder: (_) => MedicamentoFormPage(medicamento: m)));
  }

  Future<void> _eliminar(BuildContext context, Medicamento m) async {
    final estado = context.read<AppState>();
    final navegador = Navigator.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar ${m.nombre}?'),
        content: const Text('También se borran sus registros de tomas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    navegador.pop();
    estado.eliminarMedicamento(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final estado = context.watch<AppState>();
    final m = estado.medicamento(id);
    if (m == null) return const SizedBox.shrink();

    final ahora = DateTime.now();
    final toca = m.dosisActual(ahora);
    final yaRegistrada = estado.tomaYaRegistrada(m.id, toca);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(m.nombre, style: t.titleLarge),
            const SizedBox(height: 4),
            Text('${m.dosis} · ${m.frecuenciaTexto}', style: t.bodyMedium),
            const SizedBox(height: 18),
            _Dato(icono: Icons.schedule_rounded, texto: 'Toca: ${diaRelativo(toca)} a las ${horaCorta(toca)}'),
            const SizedBox(height: 8),
            _Dato(
              icono: Icons.inventory_2_outlined,
              texto: 'Te ${m.diasTexto.toLowerCase()} (${m.unidadesDisponibles} unidades)',
            ),
            if (yaRegistrada) ...[
              const SizedBox(height: 8),
              _Dato(icono: Icons.check_rounded, texto: 'Ya registraste esta toma.', color: c.accent),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Tomé mi dosis',
              icon: Icons.check_rounded,
              onPressed: yaRegistrada ? null : () => _registrar(context, tomada: true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'No la tomé',
              blur: false,
              onPressed: yaRegistrada ? null : () => _registrar(context, tomada: false),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _editar(context, m),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _eliminar(context, m),
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto, this.color});

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    return Row(
      children: [
        Icon(icono, size: 20, color: color ?? c.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: color)),
        ),
      ],
    );
  }
}
