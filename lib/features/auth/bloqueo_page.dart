import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/biometria/servicio_biometria.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/rondo_colors.dart';
import '../../core/widgets/blob_background.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rondo_logo.dart';
import '../../core/widgets/secondary_button.dart';
import '../shell/main_shell.dart';
import 'code_page.dart';

/// Reingreso con huella (RF-02): se muestra al abrir la app cuando la persona
/// activó la huella. El sistema valida la huella; Rondó solo recibe
/// "válido" o "no válido". Si falla, queda el código SMS.
class BloqueoPage extends StatefulWidget {
  const BloqueoPage({super.key});

  @override
  State<BloqueoPage> createState() => _BloqueoPageState();
}

class _BloqueoPageState extends State<BloqueoPage> {
  String? _error;
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    // Pide la huella solo al abrir, sin que la persona tenga que tocar nada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pedirHuella());
  }

  Future<void> _pedirHuella() async {
    if (_pidiendo) return;
    setState(() {
      _pidiendo = true;
      _error = null;
    });
    final servicio = context.read<ServicioBiometria>();
    final resultado = await servicio.autenticar(
      'Confirma que eres tú para entrar a Rondó.',
    );
    if (!mounted) return;

    if (resultado == ResultadoBiometria.valido) {
      // Se cambia ESTA pantalla, no la de encima: si mientras tanto se abrió
      // una alerta, la alerta se queda.
      Navigator.of(context).replace(
        oldRoute: ModalRoute.of(context)!,
        newRoute: MaterialPageRoute<void>(builder: (_) => const MainShell()),
      );
      return;
    }
    setState(() {
      _pidiendo = false;
      _error = MensajesBiometria.de(resultado);
    });
  }

  /// Plan B: el código SMS (RF-02). Con el código bien escrito entra directo.
  void _entrarConCodigo() {
    final celular = context.read<AppState>().celular;
    if (celular == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CodePage(celular: celular)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rondo;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: BlobBackground(
        blobs: BlobBackground.entrar,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: RondoLogo()),
                const SizedBox(height: 20),
                Text(
                  'Rondó',
                  textAlign: TextAlign.center,
                  style: t.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirma con tu huella para entrar.',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge!.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  ErrorBanner(
                    title: 'No pudimos confirmar tu huella',
                    message: _error!,
                  ),
                const Spacer(),
                PrimaryButton(
                  label: 'Usar mi huella',
                  icon: Icons.fingerprint_rounded,
                  onPressed: _pidiendo ? null : _pedirHuella,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Entrar con mi código SMS',
                  onPressed: _entrarConCodigo,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
