import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cloud_sync/presentation/providers/auth_providers.dart';

/// Única tela alcançável enquanto o estado de auth for [AuthPendenteCodigo]
/// (ver `app_router.dart`, DECISOES.md "Códigos de convite") — o login
/// Google já terminou (tokens de Drive válidos), só falta um código de
/// convite pra este e-mail específico.
class CodigoPendentePage extends ConsumerStatefulWidget {
  const CodigoPendentePage({super.key});

  @override
  ConsumerState<CodigoPendentePage> createState() => _CodigoPendentePageState();
}

class _CodigoPendentePageState extends ConsumerState<CodigoPendentePage> {
  final _codigoController = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _resgatar() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      setState(() => _erro = 'Digite o código de convite.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    final erro = await ref.read(authControllerProvider.notifier).resgatarCodigoGoogle(codigo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(authControllerProvider).valueOrNull;
    final email = estado is AuthPendenteCodigo ? estado.email : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_lock_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Código de convite necessário',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email == null
                          ? 'Digite o código de convite que você recebeu para continuar.'
                          : 'Conectado como $email. Digite o código de convite que você recebeu para continuar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_erro != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _erro!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _codigoController,
                      enabled: !_enviando,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código de convite',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _resgatar(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _enviando ? null : _resgatar,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _enviando
                          ? null
                          : () => ref.read(authControllerProvider.notifier).logout(),
                      child: const Text('Sair e tentar com outra conta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
