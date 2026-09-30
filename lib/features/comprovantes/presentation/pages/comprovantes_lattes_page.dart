import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/download/browser_download_web.dart';
import '../../../../core/routing/app_router.dart';
import '../../../cloud_sync/presentation/providers/comprovantes_sync_providers.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/comprovante_entrada.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../providers/comprovantes_providers.dart';

/// Módulo 2 redesenhado: cada entrada do currículo Lattes (Módulo 1) já
/// pede diretamente seu comprovante, sem LLM e sem tentar adivinhar vínculo
/// nenhum — o vínculo já é certo porque o botão de upload está do lado da
/// própria entrada (ver DECISOES.md). Seções e ordem dos itens seguem
/// exatamente a mesma ordem do XML do Lattes já usada em
/// `CurriculoListView` — nenhuma reordenação.
class ComprovantesLattesPage extends ConsumerWidget {
  const ComprovantesLattesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(comprovantesControllerProvider);
    final estadoSync = ref.watch(comprovantesSyncControllerProvider);
    final temPendentes = estado.comprovantes.values.expand((l) => l).any(
          (c) => c.statusSincronizacao != StatusSincronizacaoComprovante.sincronizado,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprovantes'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com o Google Drive',
            icon: estadoSync.sincronizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            onPressed: (!temPendentes || estadoSync.sincronizando)
                ? null
                : () => ref.read(comprovantesSyncControllerProvider.notifier).sincronizarTodos(),
          ),
          IconButton(
            tooltip: 'Importar XML atualizado do Lattes',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.go(AppRoutes.importarLattes),
          ),
        ],
      ),
      body: Column(
        children: [
          if (estado.erro != null)
            MaterialBanner(
              content: Text(estado.erro!),
              leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(comprovantesControllerProvider.notifier).limparErro(),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          if (estadoSync.erro != null)
            MaterialBanner(
              content: Text(estadoSync.erro!),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(comprovantesSyncControllerProvider.notifier).limparErro(),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          if (estado.entradas.isNotEmpty) _cabecalhoProgresso(context, estado),
          Expanded(
            child: estado.entradas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma entrada encontrada no currículo importado.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final categoria in CategoriaEntradaLattes.values)
                        _secao(context, ref, estado, categoria),
                      _secaoOrfaos(context, ref, estado),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Quantas entradas (de qualquer categoria) já têm pelo menos um
  /// comprovante anexado — usado tanto no cabeçalho geral quanto no título
  /// de cada seção, pra dar visibilidade de progresso num currículo que
  /// pode ter dezenas de entradas (ninguém preenche tudo numa sessão só).
  int _concluidas(ComprovantesState estado, Iterable<EntradaLattesRef> entradas) {
    return entradas.where((e) => estado.comprovantes[e.id]?.isNotEmpty ?? false).length;
  }

  Widget _cabecalhoProgresso(BuildContext context, ComprovantesState estado) {
    final total = estado.entradas.length;
    final concluidas = _concluidas(estado, estado.entradas);
    final fracao = total == 0 ? 0.0 : concluidas / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$concluidas de $total entradas com comprovante (${(fracao * 100).round()}%)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fracao, minHeight: 6),
          ),
        ],
      ),
    );
  }

  /// Seção recolhível (uma por categoria) — currículos grandes têm dezenas
  /// de entradas espalhadas por 8 categorias, ninguém consegue (nem
  /// precisa) ver tudo expandido ao mesmo tempo. Aberta por padrão porque é
  /// o comportamento que a tela já tinha antes disto existir; o usuário
  /// recolhe as seções que já terminou.
  Widget _secao(
    BuildContext context,
    WidgetRef ref,
    ComprovantesState estado,
    CategoriaEntradaLattes categoria,
  ) {
    final entradas = estado.entradas.where((e) => e.categoria == categoria).toList();
    if (entradas.isEmpty) return const SizedBox.shrink();

    final concluidas = _concluidas(estado, entradas);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          '${categoria.rotulo} (${entradas.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('$concluidas de ${entradas.length} com comprovante'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final entrada in entradas) _linhaEntrada(context, ref, estado, entrada),
        ],
      ),
    );
  }

  /// Comprovantes cujo `entradaId` não bate com nenhuma entrada do currículo
  /// atual — acontece quando o Lattes é reimportado e um campo identificador
  /// de alguma entrada mudou (ver docstring de `gerarIdEntrada`, DECISOES.md).
  /// Fica visível em vez de simplesmente sumir, pra não perder o arquivo.
  Widget _secaoOrfaos(BuildContext context, WidgetRef ref, ComprovantesState estado) {
    final idsAtuais = estado.entradas.map((e) => e.id).toSet();
    final orfaos = estado.comprovantes.values
        .expand((lista) => lista)
        .where((c) => !idsAtuais.contains(c.entradaId))
        .toList();
    if (orfaos.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comprovantes sem entrada correspondente (${orfaos.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'O Lattes foi reimportado e alguma dessas entradas mudou — o arquivo '
              'continua aqui, só não está mais ligado a nenhum item da lista acima.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final comprovante in orfaos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: Text(comprovante.nomeArquivo),
                subtitle: Text(comprovante.categoria.rotulo),
                trailing: IconButton(
                  tooltip: 'Remover comprovante',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(comprovantesControllerProvider.notifier)
                      .remover(comprovante.entradaId, comprovante.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Status de sincronização de UM comprovante — nuvem cinza (ainda não
  /// enviado), spinner (enviando agora), nuvem com check verde (já está no
  /// Drive), nuvem com erro que, ao tocar, tenta de novo só esse arquivo.
  Widget _indicadorSincronizacao(
    BuildContext context,
    WidgetRef ref,
    ComprovanteEntrada anexo,
  ) {
    switch (anexo.statusSincronizacao) {
      case StatusSincronizacaoComprovante.sincronizando:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case StatusSincronizacaoComprovante.sincronizado:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.cloud_done_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case StatusSincronizacaoComprovante.falha:
        return IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip:
              anexo.mensagemErroSincronizacao ?? 'Falha ao sincronizar — toque para tentar de novo',
          icon: Icon(Icons.cloud_off_outlined, color: Theme.of(context).colorScheme.error),
          onPressed: () =>
              ref.read(comprovantesSyncControllerProvider.notifier).retentarUm(anexo.id),
        );
      case StatusSincronizacaoComprovante.naoSincronizado:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.cloud_outlined, size: 18, color: Theme.of(context).hintColor),
        );
    }
  }

  Widget _linhaEntrada(
    BuildContext context,
    WidgetRef ref,
    ComprovantesState estado,
    EntradaLattesRef entrada,
  ) {
    final anexos = estado.comprovantes[entrada.id] ?? const [];
    final processando = estado.entradaProcessando == entrada.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              anexos.isEmpty ? Icons.upload_file_outlined : Icons.check_circle,
              color: anexos.isEmpty ? null : Theme.of(context).colorScheme.primary,
            ),
            title: Text(entrada.titulo),
            subtitle: entrada.subtitulo.isEmpty ? null : Text(entrada.subtitulo),
            trailing: processando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: anexos.isEmpty ? 'Anexar comprovante' : 'Anexar mais um comprovante',
                    icon: const Icon(Icons.upload_outlined),
                    onPressed: () => ref
                        .read(comprovantesControllerProvider.notifier)
                        .selecionarEAnexar(entrada),
                  ),
          ),
          for (final anexo in anexos)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 18, color: Theme.of(context).hintColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      anexo.nomeArquivo,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _indicadorSincronizacao(context, ref, anexo),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Baixar',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () {
                      final bytes =
                          ref.read(comprovantesControllerProvider.notifier).lerBytes(anexo.id);
                      if (bytes != null) {
                        baixarArquivoWeb(bytes, anexo.nomeArquivo, mimeType: anexo.mimeType);
                      }
                    },
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(comprovantesControllerProvider.notifier)
                        .remover(entrada.id, anexo.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
