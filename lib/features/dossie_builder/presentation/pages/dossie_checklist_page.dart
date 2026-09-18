import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';
import '../../domain/entities/vinculo_sugerido_dossie.dart';
import '../providers/dossie_builder_providers.dart';

/// Checklist interativo human-in-the-loop: para cada certificado já
/// sincronizado, o usuário escolhe/confirma qual critério do edital ele
/// comprova e aprova ou exclui o vínculo. Nenhum vínculo entra na
/// compilação final sem uma decisão explícita daqui — ver
/// `DossieRepository.registrarDecisaoVinculo`.
///
/// Edição manual dos critérios extraídos (renomear/adicionar/remover) não
/// está implementada nesta tela ainda — só a lista somente-leitura e a
/// aprovação de vínculo. Ver DECISOES.md.
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
      appBar: AppBar(title: const Text('Revisar dossiê')),
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
              'digitalizado (imagem escaneada), sem texto legível.')
        else
          for (final criterio in edital.criterios)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  ${criterio.descricao}'
                '${criterio.pontosPorUnidade != null ? " — ${criterio.pontosPorUnidade} pts" : ""}'
                '${criterio.limiteMaximoUnidades != null ? " (máx. ${criterio.limiteMaximoUnidades})" : ""}',
              ),
            ),
        const Divider(height: 32),
        Text(
          'Certificados sincronizados (${estado.certificadosSincronizados.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (estado.certificadosSincronizados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum certificado sincronizado com o Drive ainda. Volte para a tela de '
              'certificados, sincronize os que quiser incluir, e depois recarregue esta página.',
            ),
          )
        else
          for (final certificado in estado.certificadosSincronizados)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CertificadoVinculoTile(
                certificado: certificado,
                edital: edital,
                sugestao: _primeiraOuNulo(
                  estado.sugestoes.where((s) => s.certificadoId == certificado.id),
                ),
                decisaoAtual: _primeiraOuNulo(
                  estado.dossie?.vinculosRevisados.where((v) => v.certificadoId == certificado.id) ??
                      const [],
                ),
              ),
            ),
        const SizedBox(height: 80), // espaço para o FAB não cobrir o último item
      ],
    );
  }

  T? _primeiraOuNulo<T>(Iterable<T> iteravel) {
    for (final item in iteravel) {
      return item;
    }
    return null;
  }
}

class _CertificadoVinculoTile extends ConsumerStatefulWidget {
  final CertificadoCapturado certificado;
  final Edital edital;
  final VinculoSugeridoDossie? sugestao;
  final VinculoAprovado? decisaoAtual;

  const _CertificadoVinculoTile({
    required this.certificado,
    required this.edital,
    required this.sugestao,
    required this.decisaoAtual,
  });

  @override
  ConsumerState<_CertificadoVinculoTile> createState() => _CertificadoVinculoTileState();
}

class _CertificadoVinculoTileState extends ConsumerState<_CertificadoVinculoTile> {
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
              widget.certificado.tituloExtraido ?? 'Certificado',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (widget.certificado.instituicaoExtraida != null)
              Text(
                widget.certificado.instituicaoExtraida!,
                style: Theme.of(context).textTheme.bodySmall,
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
            certificadoId: widget.certificado.id,
            criterioId: criterioId,
            decisao: decisao,
          ),
        );
  }
}
