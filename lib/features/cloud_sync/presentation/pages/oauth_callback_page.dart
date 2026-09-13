import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../providers/auth_providers.dart';

/// Destino do redirect OAuth2. Não renderiza UI de verdade — processa
/// `code`/`state` da query string via [AuthController.tratarRetornoDeRedirect]
/// e navega para fora assim que terminar (sucesso -> app; falha -> login,
/// com a mensagem de erro exposta pelo próprio estado global de auth).
class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key});

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processar());
  }

  Future<void> _processar() async {
    await ref.read(authControllerProvider.notifier).tratarRetornoDeRedirect();
    if (!mounted) return;

    final estado = ref.read(authControllerProvider).valueOrNull;
    if (estado is AuthAuthenticated) {
      context.go(AppRoutes.importarLattes);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Concluindo login...'),
          ],
        ),
      ),
    );
  }
}
