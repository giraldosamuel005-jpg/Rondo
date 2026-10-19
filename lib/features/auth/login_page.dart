import 'package:flutter/material.dart';

import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/glass_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import 'code_page.dart';

/// 01 · Entrar (RF-01): la persona escribe su número de celular.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _celularController = TextEditingController();
  final _celularFoco = FocusNode();
  String? _error;

  @override
  void dispose() {
    _celularController.dispose();
    _celularFoco.dispose();
    super.dispose();
  }

  void _enviarCodigo() {
    final celular = _celularController.text;

    if (celular.length != 10) {
      setState(() => _error = 'Ingresa un número de celular válido.');
      return;
    }

    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CodePage(celular: celular)),
    );
  }

  void _entrarConHuella() {
    // RF-02: la huella se ofrece DESPUÉS del primer ingreso con código.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Primero entra con tu código. Después podrás activar la huella.'),
      ),
    );
  }

  void _crearCuenta() {
    // Registrarse e ingresar es el mismo camino: celular + código.
    _celularFoco.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Para crear tu cuenta, escribe tu celular.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.entrar,
        child: SafeArea(
          // CustomScrollView + SliverFillRemaining: ocupa toda la pantalla
          // (para usar Spacer) pero permite scroll cuando sale el teclado.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 64),

                      // ---------- Logo y nombre ----------
                      Center(
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(34),
                            boxShadow: [
                              BoxShadow(
                                color: c.glassShadow,
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(34),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              semanticLabel: 'Logo de Rondó',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Rondó', textAlign: TextAlign.center, style: t.displayLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Alguien pendiente, siempre.',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge!.copyWith(color: c.textSecondary),
                      ),

                      const Spacer(),
                      const SizedBox(height: 32),

                      // ---------- Celular + botón principal ----------
                      Glass(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PhoneField(
                              controller: _celularController,
                              focusNode: _celularFoco,
                              errorText: _error,
                              onChanged: (_) {
                                if (_error != null) setState(() => _error = null);
                              },
                              onSubmitted: (_) => _enviarCodigo(),
                            ),
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: 'Enviarme el código',
                              height: 54,
                              onPressed: _enviarCodigo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Te llega un SMS de 4 dígitos. Sin contraseñas.',
                        textAlign: TextAlign.center,
                        style: t.labelLarge!.copyWith(fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 20),

                      // ---------- Opciones secundarias ----------
                      SecondaryButton(
                        label: 'Entrar con huella',
                        icon: Icons.fingerprint_rounded,
                        onPressed: _entrarConHuella,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('¿Primera vez?', style: t.bodyMedium),
                          TextButton(
                            onPressed: _crearCuenta,
                            child: const Text('Crear cuenta'),
                          ),
                        ],
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
