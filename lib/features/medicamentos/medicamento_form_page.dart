import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/medicamento.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/utils/formato.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_back_button.dart';
import '../../core/widgets/tab_page.dart';

/// Agregar o editar un medicamento (RF-20).
/// Se escribe lo mínimo: la frecuencia se elige con un toque y las unidades
/// por toma con botones − / +.
class MedicamentoFormPage extends StatefulWidget {
  const MedicamentoFormPage({super.key, this.medicamento});

  /// `null` = medicamento nuevo.
  final Medicamento? medicamento;

  @override
  State<MedicamentoFormPage> createState() => _MedicamentoFormPageState();
}

class _MedicamentoFormPageState extends State<MedicamentoFormPage> {
  final _nombre = TextEditingController();
  final _dosis = TextEditingController();
  final _disponibles = TextEditingController();
  int? _frecuencia;
  int _porToma = 1;
  late DateTime _primeraToma;
  String? _error;

  bool get _editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicamento;
    if (m != null) {
      _nombre.text = m.nombre;
      _dosis.text = m.dosis;
      _disponibles.text = '${m.unidadesDisponibles}';
      _frecuencia = m.frecuenciaHoras;
      _porToma = m.unidadesPorToma;
      _primeraToma = m.primeraToma;
    } else {
      // Por defecto: la próxima hora en punto.
      final ahora = DateTime.now();
      _primeraToma = DateTime(ahora.year, ahora.month, ahora.day, ahora.hour + 1);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _dosis.dispose();
    _disponibles.dispose();
    super.dispose();
  }

  void _limpiarError([Object? _]) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_primeraToma),
      helpText: 'Hora de la primera toma',
    );
    if (hora == null) return;
    setState(() {
      _primeraToma = DateTime(
        _primeraToma.year,
        _primeraToma.month,
        _primeraToma.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  void _guardar() {
    final estado = context.read<AppState>();
    final disponibles = int.tryParse(_disponibles.text);

    final error = Medicamento.validar(
      nombre: _nombre.text,
      dosis: _dosis.text,
      frecuenciaHoras: _frecuencia,
      unidadesPorToma: _porToma,
      unidadesDisponibles: disponibles,
      otros: estado.medicamentos,
      idEditando: widget.medicamento?.id,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final medicamento = Medicamento(
      id: widget.medicamento?.id ?? estado.nuevoIdMedicamento(),
      nombre: _nombre.text.trim(),
      dosis: _dosis.text.trim(),
      unidadesPorToma: _porToma,
      frecuenciaHoras: _frecuencia!,
      unidadesDisponibles: disponibles!,
      primeraToma: _primeraToma,
    );
    if (_editando) {
      estado.actualizarMedicamento(medicamento);
    } else {
      estado.agregarMedicamento(medicamento);
    }

    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          medicamento.seEstaAcabando
              ? medicamento.avisoReponer
              : (_editando ? 'Cambios guardados.' : 'Agregamos ${medicamento.nombre}.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

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
                      const SizedBox(height: 22),
                      Text(_editando ? 'Editar medicamento' : 'Nuevo medicamento', style: t.headlineLarge),
                      const SizedBox(height: 22),

                      // ---------- Nombre y dosis ----------
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassField(
                              label: 'Nombre',
                              controller: _nombre,
                              hint: 'Ej. Losartán',
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              onChanged: _limpiarError,
                            ),
                            const GlassDivider(indent: 18),
                            GlassField(
                              label: 'Dosis',
                              controller: _dosis,
                              hint: 'Ej. 50 mg',
                              textInputAction: TextInputAction.done,
                              onChanged: _limpiarError,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Frecuencia ----------
                      const SectionLabel('¿Cada cuánto lo tomas?'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final horas in Medicamento.frecuencias)
                            _Opcion(
                              texto: horas == 24 ? '1 vez al día' : 'Cada $horas h',
                              seleccionada: _frecuencia == horas,
                              onTap: () => setState(() {
                                _frecuencia = horas;
                                _error = null;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // ---------- Primera toma ----------
                      const SectionLabel('Primera toma'),
                      Glass(
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: _elegirHora,
                            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, color: c.accent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${diaRelativo(_primeraToma)} a las ${horaCorta(_primeraToma)}',
                                      style: t.bodyLarge,
                                    ),
                                  ),
                                  Text('Cambiar', style: t.labelLarge!.copyWith(color: c.accentLink)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ---------- Cantidades ----------
                      const SectionLabel('Cantidad'),
                      Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unidades por toma',
                                          style: t.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Pastillas, gotas o cápsulas cada vez',
                                          style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _Contador(
                                    valor: _porToma,
                                    onCambio: (v) => setState(() {
                                      _porToma = v;
                                      _error = null;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            const GlassDivider(indent: 18),
                            GlassField(
                              label: '¿Cuántas unidades tienes?',
                              controller: _disponibles,
                              hint: 'Ej. 30',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              textInputAction: TextInputAction.done,
                              onChanged: _limpiarError,
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

                      const Spacer(),
                      const SizedBox(height: 24),
                      PrimaryButton(label: 'Guardar', onPressed: _guardar),
                      const SizedBox(height: 16),
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

/// Opción seleccionable en forma de cápsula ("Cada 8 h").
class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.seleccionada, required this.onTap});

  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Semantics(
      selected: seleccionada,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: seleccionada ? c.accentSoft : c.glassTop,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: seleccionada ? c.accent : c.glassBorder,
                width: seleccionada ? 1.5 : 1,
              ),
            ),
            // widthFactor: 1 → centra el texto sin estirar la cápsula a todo el ancho.
            child: Center(
              widthFactor: 1,
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w600,
                      color: seleccionada ? c.accentLink : c.text,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// − 1 + para las unidades por toma (de 1 a 20).
class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.onCambio});

  final int valor;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotonRedondo(
          icono: Icons.remove_rounded,
          etiqueta: 'Una unidad menos',
          onTap: valor > 1 ? () => onCambio(valor - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$valor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _BotonRedondo(
          icono: Icons.add_rounded,
          etiqueta: 'Una unidad más',
          onTap: valor < 20 ? () => onCambio(valor + 1) : null,
        ),
      ],
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.icono, required this.etiqueta, required this.onTap});

  final IconData icono;
  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: etiqueta,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.neutralSoft, shape: BoxShape.circle),
            child: Icon(icono, color: onTap != null ? c.text : c.textSecondary.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
