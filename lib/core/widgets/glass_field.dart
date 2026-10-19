import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rondo_colors.dart';
import '../theme/rondo_text.dart';

/// Campo de formulario para usar dentro de una tarjeta de vidrio:
/// etiqueta pequeña arriba y el valor debajo.
///
/// Si se pasa `value`, el campo es de solo lectura (muestra un dato ya conocido).
/// Con `errorText`, se pinta en coral con la ayuda debajo.
/// Tocar cualquier parte de la caja (también la etiqueta) activa el campo.
class GlassField extends StatefulWidget {
  const GlassField({
    super.key,
    required this.label,
    this.controller,
    this.value,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<GlassField> {
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final hayError = widget.errorText != null;
    final soloLectura = widget.value != null;

    final contenido = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: soloLectura ? null : _foco.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: t.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: hayError ? c.errorText : c.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            if (soloLectura)
              Text(widget.value!, style: t.bodyLarge)
            else
              TextField(
                controller: widget.controller,
                focusNode: _foco,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                textCapitalization: widget.textCapitalization,
                textInputAction: widget.textInputAction,
                autofillHints: widget.autofillHints,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: t.bodyLarge,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: t.bodyLarge!.copyWith(
                    color: c.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (hayError) ...[
              const SizedBox(height: 6),
              Text(widget.errorText!, style: t.labelLarge!.copyWith(color: c.errorText)),
            ],
          ],
        ),
      ),
    );

    if (!hayError) return contenido;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.errorSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.error, width: 1.5),
      ),
      child: contenido,
    );
  }
}

/// Campo del celular de la pantalla Entrar: "+57 | 300 123 4567".
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;
    final hayError = errorText != null;
    final estiloNumero = RondoText.phone(c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Número de celular',
          style: t.bodySmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: hayError ? c.errorText : c.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hayError ? c.errorSurface : c.neutralSoft,
            borderRadius: BorderRadius.circular(16),
            border: hayError ? Border.all(color: c.error, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Text('+57', style: estiloNumero.copyWith(color: c.textSecondary)),
              const SizedBox(width: 12),
              Container(width: 1, height: 22, color: c.hairline),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.phone, // Teclado numérico
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Solo números
                    LengthLimitingTextInputFormatter(10), // Máximo 10
                  ],
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: estiloNumero,
                  decoration: InputDecoration.collapsed(
                    hintText: '300 123 4567',
                    hintStyle: estiloNumero.copyWith(
                      color: c.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hayError) ...[
          const SizedBox(height: 8),
          Text(errorText!, style: t.labelLarge!.copyWith(color: c.errorText)),
        ],
      ],
    );
  }
}
