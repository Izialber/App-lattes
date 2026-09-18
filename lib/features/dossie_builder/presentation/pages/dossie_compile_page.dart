import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/download/browser_download_web.dart';
import '../../domain/entities/dossie.dart';
import '../providers/dossie_builder_providers.dart';

/// Tela final de compilação: dispara `CompilarDossie` e trata os desfechos
/// possíveis — sucesso (com botão de download do PDF final), falha, ou
/// degradação explícita por memória insuficiente (orientando o usuário a
/// concluir num desktop).
class DossieCompilePage extends ConsumerStatefulWidget {
  final String dossieId;
  const DossieCompilePage({super.key, required this.dossieId});

  @override
  ConsumerState<DossieCompilePage> createState() => _DossieCompilePageState();
}

class _DossieCompilePageState extends ConsumerState<DossieCompilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_carregarECompilar);
  }

  Future<void> _carregarECompilar() async {
    final notifier = ref.read(dossieBuilderControllerProvider.notifier);
    final estadoAtual = ref.read(dossieBuilderControllerProvider);

    // Se o usuário chegou aqui direto pela URL (reload de aba), o estado
    // (edital/certificados) ainda não foi carregado — carrega antes de
    // compilar, senão `Dossie.vinculosRevisados` estaria vazio na tela
    // (o repositório lê de novo do Hive de qualquer forma, mas a UI
    // também precisa do edital/certificados para mostrar contexto).
    if (estadoAtual.dossie?.id != widget.dossieId) {
      await notifier.carregarChecklist(widget.dossieId);
    }

    // Sem essa checagem, voltar para o checklist e reabrir esta tela (ou só
    // recarregar a URL /dossie/:id/compilar) refazia a mesclagem inteira do
    // zero mesmo com o dossiê já compilado com sucesso — achado da 2ª
    // revisão de código. `falhaCompilacao`/`degradadoAguardandoDesktop`
    // continuam recompilando ao entrar na tela (é o comportamento que o
    // botão "Tentar novamente" já espera).
    final jaCompilado = ref.read(dossieBuilderControllerProvider).dossie?.status ==
        StatusDossie.compilado;
    if (jaCompilado) return;

    await notifier.compilar(widget.dossieId);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(dossieBuilderControllerProvider);
    final dossie = estado.dossie;

    return Scaffold(
      appBar: AppBar(title: const Text('Compilar dossiê')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _corpo(context, estado, dossie),
          ),
        ),
      ),
    );
  }

  Widget _corpo(BuildContext context, DossieBuilderState estado, Dossie? dossie) {
    if (estado.carregando || dossie == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Compilando o dossiê…'),
        ],
      );
    }

    switch (dossie.status) {
      case StatusDossie.compilado:
        return _resultado(
          context,
          icone: Icons.check_circle,
          cor: Theme.of(context).colorScheme.primary,
          titulo: 'Dossiê compilado com sucesso!',
          subtitulo: dossie.notaCompilacao,
          acao: FilledButton.icon(
            onPressed: () {
              final bytes = ref.read(dossieBuilderControllerProvider.notifier).lerPdfFinal(dossie.id);
              if (bytes != null) {
                baixarArquivoWeb(bytes, 'dossie_${dossie.id}.pdf', mimeType: 'application/pdf');
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Baixar PDF'),
          ),
        );

      case StatusDossie.degradadoAguardandoDesktop:
        return _resultado(
          context,
          icone: Icons.desktop_windows_outlined,
          cor: Theme.of(context).colorScheme.error,
          titulo: dossie.mensagemDegradacao ??
              'Este dispositivo não tem memória suficiente para compilar este dossiê.',
        );

      case StatusDossie.falhaCompilacao:
        return _resultado(
          context,
          icone: Icons.error_outline,
          cor: Theme.of(context).colorScheme.error,
          titulo: estado.erro ?? 'Falha ao compilar o dossiê.',
          acao: OutlinedButton(
            onPressed: _carregarECompilar,
            child: const Text('Tentar novamente'),
          ),
        );

      case StatusDossie.aguardandoRevisaoHumana:
      case StatusDossie.prontoParaCompilar:
      case StatusDossie.compilando:
      case StatusDossie.compilandoEmPartes:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Compilando o dossiê…'),
          ],
        );
    }
  }

  Widget _resultado(
    BuildContext context, {
    required IconData icone,
    required Color cor,
    required String titulo,
    String? subtitulo,
    Widget? acao,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 64, color: cor),
        const SizedBox(height: 16),
        Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (subtitulo != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        if (acao != null) ...[
          const SizedBox(height: 24),
          acao,
        ],
      ],
    );
  }
}
