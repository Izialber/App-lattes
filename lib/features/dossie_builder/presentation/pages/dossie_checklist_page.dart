import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/routing/voltar_app_bar_button.dart';
import '../../../comprovantes/domain/entities/comprovante_entrada.dart';
import '../../../comprovantes/domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/criterio_pontuacao.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';
import '../../domain/entities/vinculo_sugerido_dossie.dart';
import '../providers/dossie_builder_providers.dart';

const _uuid = Uuid();

/// Checklist interativo human-in-the-loop: para cada certificado já
/// sincronizado, o usuário escolhe/confirma qual critério do edital ele
/// comprova e aprova ou exclui o vínculo. Nenhum vínculo entra na
/// compilação final sem uma decisão explícita daqui — ver
/// `DossieRepository.registrarDecisaoVinculo`. Critérios extraídos podem
/// ser removidos e novos podem ser adicionados manualmente (só edição
/// inline da descrição de um critério existente que ainda não existe).
class DossieChecklistPage extends ConsumerStatefulWidget {
  final String dossieId;
  const DossieChecklistPage({super.key, required this.dossieId});

  @override
  ConsumerState<DossieChecklistPage> createState() => _DossieChecklistPageState();
}

class _DossieChecklistPageState extends ConsumerState<DossieChecklistPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(dossieBuilderControllerProvider.notifier).carregarChecklist(widget.dossieId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(dossieBuilderControllerProvider);
    final edital = estado.edital;
    final temAprovado =
        estado.dossie?.vinculosRevisados.any((v) => v.decisao == DecisaoVinculo.aprovado) ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const VoltarAppBarButton(rotaPai: AppRoutes.dossieNovo),
        title: const Text('Revisar dossiê'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: temAprovado ? () => context.go('/dossie/${widget.dossieId}/compilar') : null,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Compilar dossiê'),
      ),
      body: estado.carregando && edital == null
          ? const Center(child: CircularProgressIndicator())
          : edital == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(estado.erro ?? 'Dossiê não encontrado.'),
                  ),
                )
              : _corpo(context, estado, edital),
    );
  }

  Widget _corpo(BuildContext context, DossieBuilderState estado, Edital edital) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (estado.erro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                estado.erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ),
        Text('Critérios do edital', style: Theme.of(context).textTheme.titleMedium),
        Text(
          edital.orgaoOuBanca ?? edital.nomeArquivoOriginal,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (edital.criterios.isEmpty)
          const Text('Nenhum critério identificado automaticamente — o edital pode ser um PDF '
              'digitalizado (imagem escaneada), sem texto legível. Adicione manualmente abaixo.')
        else
          for (final criterio in edital.criterios)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '•  ${criterio.descricao}'
                      '${criterio.pontosPorUnidade != null ? " — ${criterio.pontosPorUnidade} pts" : ""}'
                      '${criterio.limiteMaximoUnidades != null ? " (máx. ${criterio.limiteMaximoUnidades})" : ""}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover critério',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => ref
                        .read(dossieBuilderControllerProvider.notifier)
                        .removerCriterio(criterio.id),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _abrirDialogoNovoCriterio(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar critério manualmente'),
          ),
        ),
        const Divider(height: 32),
        Text(
          'Comprovantes sincronizados (${estado.comprovantesSincronizados.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (estado.comprovantesSincronizados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum comprovante sincronizado com o Drive ainda. Volte para a tela de '
              'Comprovantes, sincronize os que quiser incluir, e depois recarregue esta página.',
            ),
          )
        else
          for (final comprovante in estado.comprovantesSincronizados)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ComprovanteVinculoTile(
                comprovante: comprovante,
                entrada: estado.entradas
                    .where((e) => e.id == comprovante.entradaId)
                    .firstOrNull,
                edital: edital,
                sugestao: estado.sugestoes
                    .where((s) => s.comprovanteId == comprovante.id)
                    .firstOrNull,
                decisaoAtual: estado.dossie?.vinculosRevisados
                    .where((v) => v.comprovanteId == comprovante.id)
                    .firstOrNull,
              ),
            ),
        const SizedBox(height: 80), // espaço para o FAB não cobrir o último item
      ],
    );
  }

  Future<void> _abrirDialogoNovoCriterio(BuildContext context, WidgetRef ref) async {
    final controladorDescricao = TextEditingController();
    final controladorPontos = TextEditingController();
    final controladorLimite = TextEditingController();

    final criterio = await showDialog<CriterioPontuacao>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo critério'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controladorDescricao,
              decoration: const InputDecoration(labelText: 'Descrição'),
              autofocus: true,
            ),
            TextField(
              controller: controladorPontos,
              decoration: const InputDecoration(labelText: 'Pontos por unidade (opcional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: controladorLimite,
              decoration: const InputDecoration(labelText: 'Limite máximo de unidades (opcional)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final descricao = controladorDescricao.text.trim();
              if (descricao.isEmpty) return;
              Navigator.of(context).pop(
                CriterioPontuacao(
                  id: _uuid.v4(),
                  descricao: descricao,
                  pontosPorUnidade: double.tryParse(controladorPontos.text.replaceAll(',', '.')),
                  limiteMaximoUnidades: int.tryParse(controladorLimite.text),
                ),
              );
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (criterio != null) {
      await ref.read(dossieBuilderControllerProvider.notifier).adicionarCriterioManual(criterio);
    }
  }
}

class _ComprovanteVinculoTile extends ConsumerStatefulWidget {
  final ComprovanteEntrada comprovante;
  final EntradaLattesRef? entrada;
  final Edital edital;
  final VinculoSugeridoDossie? sugestao;
  final VinculoAprovado? decisaoAtual;

  const _ComprovanteVinculoTile({
    required this.comprovante,
    required this.entrada,
    required this.edital,
    required this.sugestao,
    required this.decisaoAtual,
  });

  @override
  ConsumerState<_ComprovanteVinculoTile> createState() => _ComprovanteVinculoTileState();
}

class _ComprovanteVinculoTileState extends ConsumerState<_ComprovanteVinculoTile> {
  String? _criterioSelecionadoId;

  @override
  void initState() {
    super.initState();
    _criterioSelecionadoId = widget.decisaoAtual?.criterioId ?? widget.sugestao?.criterioId;
  }

  @override
  Widget build(BuildContext context) {
    final decisao = widget.decisaoAtual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entrada?.titulo ?? widget.comprovante.nomeArquivo,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.entrada != null && widget.entrada!.subtitulo.isNotEmpty)
              Text(
                widget.entrada!.subtitulo,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (widget.comprovante.mimeType == 'application/pdf')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'PDF de origem — não entra na mesclagem automática do dossiê ainda.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _criterioSelecionadoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Critério do edital',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final criterio in widget.edital.criterios)
                  DropdownMenuItem(
                    value: criterio.id,
                    child: Text(criterio.descricao, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _criterioSelecionadoId = id),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (decisao?.decisao == DecisaoVinculo.aprovado)
                  const Chip(
                    label: Text('Aprovado'),
                    avatar: Icon(Icons.check, size: 16),
                    visualDensity: VisualDensity.compact,
                  )
                else if (decisao?.decisao == DecisaoVinculo.excluido)
                  const Chip(
                    label: Text('Excluído'),
                    avatar: Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _criterioSelecionadoId == null
                      ? null
                      : () => _registrar(DecisaoVinculo.excluido),
                  child: const Text('Excluir'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _criterioSelecionadoId == null
                      ? null
                      : () => _registrar(DecisaoVinculo.aprovado),
                  child: const Text('Aprovar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _registrar(DecisaoVinculo decisao) {
    final criterioId = _criterioSelecionadoId;
    if (criterioId == null) return;
    ref.read(dossieBuilderControllerProvider.notifier).registrarDecisao(
          VinculoAprovado(
            comprovanteId: widget.comprovante.id,
            criterioId: criterioId,
            decisao: decisao,
          ),
        );
  }
}
