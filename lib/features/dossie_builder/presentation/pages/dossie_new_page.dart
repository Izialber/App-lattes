import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/dossie_builder_providers.dart';

/// Primeira tela do módulo 4: seleciona o PDF do edital, extrai os
/// critérios de pontuação via LLM, e cria o dossiê — depois navega direto
/// para o checklist de revisão. Rota sem `dossieId` na URL de propósito
/// (`/dossie/novo`): o id só existe depois que a extração termina com
/// sucesso.
class DossieNewPage extends ConsumerWidget {
  const DossieNewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(dossieBuilderControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Montar dossiê')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Selecione o PDF do edital do concurso. A gente lê o texto e sugere os '
                  'critérios de pontuação da Prova de Títulos automaticamente — você revisa '
                  'e ajusta tudo na próxima tela.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (estado.erro != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      estado.erro!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: estado.carregando ? null : () => _selecionarEIniciar(context, ref),
                  icon: estado.carregando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(estado.carregando ? 'Lendo o edital…' : 'Selecionar edital (PDF)'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selecionarEIniciar(BuildContext context, WidgetRef ref) async {
    final dossieId = await ref.read(dossieBuilderControllerProvider.notifier).criarNovoDossie();
    if (dossieId != null && context.mounted) {
      context.go('/dossie/$dossieId/checklist');
    }
  }
}
