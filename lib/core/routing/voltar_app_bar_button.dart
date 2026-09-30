import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Botão de voltar explícito pra `AppBar.leading`. Necessário porque o app
/// navega inteiramente via `context.go()` (substitui a rota atual em vez de
/// empilhar, ver `app_router.dart`) — o Navigator nunca acumula uma pilha
/// real, então o botão de voltar automático do Flutter (que só aparece
/// quando `Navigator.canPop()` é verdadeiro) nunca apareceria sozinho.
/// `rotaPai` é o destino lógico da tela (definido por quem link a ela), não
/// o histórico real do navegador.
class VoltarAppBarButton extends StatelessWidget {
  final String rotaPai;

  const VoltarAppBarButton({super.key, required this.rotaPai});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go(rotaPai),
    );
  }
}
