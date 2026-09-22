import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/download/browser_download_web.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../providers/comprovantes_providers.dart';

const _rotuloCategoria = {
  CategoriaEntradaLattes.curso: 'Formação acadêmica',
  CategoriaEntradaLattes.experienciaProfissional: 'Experiência profissional',
  CategoriaEntradaLattes.publicacao: 'Produção bibliográfica',
  CategoriaEntradaLattes.orientacao: 'Orientações',
  CategoriaEntradaLattes.producaoTecnica: 'Produção técnica',
  CategoriaEntradaLattes.participacaoEvento: 'Participação em eventos',
  CategoriaEntradaLattes.projetoPesquisa: 'Projetos de pesquisa',
  CategoriaEntradaLattes.idioma: 'Idiomas',
};

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

    return Scaffold(
      appBar: AppBar(title: const Text('Comprovantes')),
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

  Widget _secao(
    BuildContext context,
    WidgetRef ref,
    ComprovantesState estado,
    CategoriaEntradaLattes categoria,
  ) {
    final entradas = estado.entradas.where((e) => e.categoria == categoria).toList();
    if (entradas.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_rotuloCategoria[categoria]} (${entradas.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final entrada in entradas) _linhaEntrada(context, ref, estado, entrada),
          ],
        ),
      ),
    );
  }

  /// Comprovantes cujo `entradaId` não bate com nenhuma entrada do currículo
  /// atual — acontece quando o Lattes é reimportado e um campo identificador
  /// de alguma entrada mudou (ver docstring de `gerarIdEntrada`, DECISOES.md).
  /// Fica visível em vez de simplesmente sumir, pra não perder o arquivo.
  Widget _secaoOrfaos(BuildContext context, WidgetRef ref, ComprovantesState estado) {
    final idsAtuais = estado.entradas.map((e) => e.id).toSet();
    final orfaos =
        estado.comprovantes.values.where((c) => !idsAtuais.contains(c.entradaId)).toList();
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
                subtitle: Text(_rotuloCategoria[comprovante.categoria] ?? ''),
                trailing: IconButton(
                  tooltip: 'Remover comprovante',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(comprovantesControllerProvider.notifier)
                      .remover(comprovante.entradaId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linhaEntrada(
    BuildContext context,
    WidgetRef ref,
    ComprovantesState estado,
    EntradaLattesRef entrada,
  ) {
    final comprovante = estado.comprovantes[entrada.id];
    final processando = estado.entradaProcessando == entrada.id;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        comprovante != null ? Icons.check_circle : Icons.upload_file_outlined,
        color: comprovante != null ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(entrada.titulo),
      subtitle: entrada.subtitulo.isEmpty ? null : Text(entrada.subtitulo),
      trailing: processando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (comprovante != null) ...[
                  IconButton(
                    tooltip: 'Baixar comprovante',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () {
                      final bytes =
                          ref.read(comprovantesControllerProvider.notifier).lerBytes(entrada.id);
                      if (bytes != null) {
                        baixarArquivoWeb(
                          bytes,
                          comprovante.nomeArquivo,
                          mimeType: comprovante.mimeType,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Remover comprovante',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(comprovantesControllerProvider.notifier).remover(entrada.id),
                  ),
                ],
                IconButton(
                  tooltip: comprovante == null ? 'Anexar comprovante' : 'Substituir comprovante',
                  icon: const Icon(Icons.upload_outlined),
                  onPressed: () => ref
                      .read(comprovantesControllerProvider.notifier)
                      .selecionarEAnexar(entrada),
                ),
              ],
            ),
    );
  }
}
