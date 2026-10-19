import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/rondo_colors.dart';
import '../theme/rondo_text.dart';
import 'glass.dart';

/// Las 4 casillas del código SMS.
///
/// Truco: un campo de texto INVISIBLE encima de 4 cajas de vidrio.
/// La persona escribe en el campo (borrar retrocede solo, y Android puede
/// autocompletar el código del SMS); las cajas solo muestran los dígitos.
class CodeInput extends StatelessWidget {
  const CodeInput({
    super.key,
    required this.controller,
    this.hasError = false,
    this.onChanged,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  static const largo = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Código de $largo dígitos',
      child: Stack(
        children: [
          // Se redibuja cada vez que cambia el texto del campo.
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final codigo = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < largo; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _Casilla(indice: i, codigo: codigo, hasError: hasError)),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                autofocus: autofocus, // Abre el teclado al entrar
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(largo),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: onChanged,
                decoration: const InputDecoration.collapsed(hintText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.indice, required this.codigo, required this.hasError});

  final int indice;
  final String codigo;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final tieneNumero = indice < codigo.length;
    final esLaActual = indice == codigo.length; // La siguiente por llenar

    final Color? borde;
    if (hasError) {
      borde = c.error;
    } else if (esLaActual) {
      borde = c.accent;
    } else {
      borde = null; // Borde normal del vidrio
    }

    return Glass(
      radius: 22,
      blur: false, // 4 desenfoques seguidos serían muy costosos
      shadow: false,
      borderColor: borde,
      borderWidth: borde != null ? 1.5 : 1,
      child: SizedBox(
        height: 76,
        child: Center(
          child: Text(
            tieneNumero ? codigo[indice] : '',
            style: RondoText.codeDigit(c).copyWith(
              color: hasError ? c.errorText : c.text,
            ),
          ),
        ),
      ),
    );
  }
}
