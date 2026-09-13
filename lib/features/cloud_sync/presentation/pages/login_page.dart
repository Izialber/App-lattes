import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/oauth_config.dart';
import '../../domain/entities/cloud_provider.dart';
import '../providers/auth_providers.dart';

/// Primeira tela do app. Login = entrar com a própria conta Google (ou,
/// mais adiante, Microsoft) — não existe conta própria do app nem backend
/// compartilhado entre usuários (ver DECISOES.md, "Confirmação explícita do
/// modelo multiusuário"). Cada pessoa autentica e usa a própria nuvem.
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final carregando = authState.isLoading;
    final erro = authState.valueOrNull is AuthUnauthenticated
        ? (authState.valueOrNull as AuthUnauthenticated).erro
        : null;

    final googleConfigurado = OAuthConfig.forProvider(CloudProvider.googleDrive).isConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Certificados Lattes',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Entre com sua conta para organizar seus comprovantes e montar '
                    'o dossiê de Prova de Títulos. Seus arquivos ficam salvos na sua '
                    'própria conta — nunca em um servidor compartilhado.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (erro != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        erro,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    onPressed: (!googleConfigurado || carregando)
                        ? null
                        : () => ref.read(authControllerProvider.notifier).loginComGoogle(),
                    icon: carregando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(googleConfigurado ? 'Continuar com Google' : 'Continuar com Google (em breve)'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.login),
                    label: const Text('Continuar com Microsoft (em breve)'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
