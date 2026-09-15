import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/breakpoints.dart';
import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/entities/experiencia_profissional.dart';
import '../providers/lattes_providers.dart';

/// Exibe o currículo importado. Usa `LayoutBuilder` para adaptar de 1 coluna
/// (compact, celular) a 2 colunas (expanded/large, desktop) — nenhum widget
/// aqui é "o mesmo layout desktop encolhido" (requisito de responsividade
/// real, ver ARQUITETURA.md).
class CurriculoListView extends ConsumerWidget {
  final CurriculoLattes curriculo;

  const CurriculoListView({super.key, required this.curriculo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamanho = screenSizeFor(constraints.maxWidth);
        final duasColunas = tamanho == ScreenSize.expanded || tamanho == ScreenSize.large;

        final secoes = [
          if (curriculo.temVinculosPendentesDeConfirmacao) _bannerConfirmacaoPendente(context),
          _secaoDadosGerais(context),
          _secaoLista(
            context,
            titulo: 'Formação acadêmica (${curriculo.cursos.length})',
            itens: curriculo.cursos
                .map((c) => _ItemTile(
                      titulo: c.nomeCurso,
                      subtitulo: [
                        if (c.instituicao != null) c.instituicao!,
                        if (c.anoInicio != null || c.anoConclusao != null)
                          '${c.anoInicio ?? '?'}–${c.anoConclusao ?? 'atual'}',
                        if (c.cargaHorariaHoras != null) '${c.cargaHorariaHoras}h',
                      ].join(' · '),
                    ))
                .toList(),
          ),
          _secaoExperiencias(context, ref),
          _secaoLista(
            context,
            titulo: 'Produção bibliográfica (${curriculo.publicacoes.length})',
            itens: curriculo.publicacoes
                .map((p) => _ItemTile(
                      titulo: p.titulo,
                      subtitulo: [
                        if (p.nomeVeiculo != null) p.nomeVeiculo!,
                        if (p.ano != null) '${p.ano}',
                      ].join(' · '),
                    ))
                .toList(),
          ),
          if (curriculo.orientacoes.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Orientações (${curriculo.orientacoes.length})',
              itens: curriculo.orientacoes
                  .map((o) => _ItemTile(
                        titulo: o.tituloTrabalho,
                        subtitulo: [
                          if (o.nomeOrientado != null) 'Orientado(a): ${o.nomeOrientado}',
                          o.situacao.name,
                        ].join(' · '),
                      ))
                  .toList(),
            ),
          if (curriculo.producoesTecnicas.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Produção técnica (${curriculo.producoesTecnicas.length})',
              itens: curriculo.producoesTecnicas
                  .map((p) => _ItemTile(
                        titulo: p.titulo,
                        subtitulo: [
                          if (p.finalidadeOuNatureza != null) p.finalidadeOuNatureza!,
                          if (p.ano != null) '${p.ano}',
                        ].join(' · '),
                      ))
                  .toList(),
            ),
          if (curriculo.participacoesEventos.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Participação em eventos (${curriculo.participacoesEventos.length})',
              itens: curriculo.participacoesEventos
                  .map((p) => _ItemTile(
                        titulo: p.titulo,
                        subtitulo: [
                          if (p.nomeEvento != null && p.nomeEvento != p.titulo) p.nomeEvento!,
                          if (p.ano != null) '${p.ano}',
                        ].join(' · '),
                      ))
                  .toList(),
            ),
          if (curriculo.projetos.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Projetos de pesquisa (${curriculo.projetos.length})',
              itens: curriculo.projetos
                  .map((p) => _ItemTile(
                        titulo: p.nome,
                        subtitulo: [
                          if (p.situacao != null) p.situacao!,
                          if (p.anoInicio != null || p.anoFim != null)
                            '${p.anoInicio ?? '?'}–${p.anoFim ?? 'atual'}',
                        ].join(' · '),
                      ))
                  .toList(),
            ),
          if (curriculo.areasDeAtuacao.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Áreas de atuação (${curriculo.areasDeAtuacao.length})',
              itens: curriculo.areasDeAtuacao
                  .map((area) => _ItemTile(titulo: area, subtitulo: ''))
                  .toList(),
            ),
          if (curriculo.idiomas.isNotEmpty)
            _secaoLista(
              context,
              titulo: 'Idiomas (${curriculo.idiomas.length})',
              itens: curriculo.idiomas
                  .map((idioma) => _ItemTile(
                        titulo: idioma.descricao,
                        subtitulo: [
                          if (idioma.proficienciaLeitura != null) 'Leitura: ${idioma.proficienciaLeitura}',
                          if (idioma.proficienciaFala != null) 'Fala: ${idioma.proficienciaFala}',
                        ].join(' · '),
                      ))
                  .toList(),
            ),
        ];

        if (!duasColunas) {
          return ListView(padding: const EdgeInsets.all(16), children: secoes);
        }

        // Layout de 2 colunas: divide as seções em duas listas alternadas,
        // não é o mesmo ListView do celular só "esticado".
        final coluna1 = <Widget>[];
        final coluna2 = <Widget>[];
        for (var i = 0; i < secoes.length; i++) {
          (i.isEven ? coluna1 : coluna2).add(secoes[i]);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: coluna1)),
              const SizedBox(width: 24),
              Expanded(child: Column(children: coluna2)),
            ],
          ),
        );
      },
    );
  }

  Widget _bannerConfirmacaoPendente(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Alguns vínculos profissionais não têm data de término no XML do Lattes. '
                'Confirme abaixo se ainda estão ativos antes de usá-los em um dossiê.',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoDadosGerais(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(curriculo.nomeCompleto, style: Theme.of(context).textTheme.titleLarge),
            if (curriculo.nomeEmCitacoesBibliograficas != null)
              Text('Citações: ${curriculo.nomeEmCitacoesBibliograficas}'),
            if (curriculo.dataAtualizacaoCv != null)
              Text(
                'Currículo atualizado em ${DateFormat('dd/MM/yyyy').format(curriculo.dataAtualizacaoCv!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _secaoExperiencias(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Experiência profissional (${curriculo.experienciasProfissionais.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final experiencia in curriculo.experienciasProfissionais)
              _ExperienciaTile(experiencia: experiencia, ref: ref),
          ],
        ),
      ),
    );
  }

  Widget _secaoLista(BuildContext context, {required String titulo, required List<_ItemTile> itens}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (itens.isEmpty)
              Text(
                'Nada encontrado nesta seção do currículo.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...itens,
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const _ItemTile({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
          if (subtitulo.isNotEmpty)
            Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Uma experiência profissional, com os botões de confirmação de "ainda
/// ativo?" quando ambígua. Alvos de toque >=48dp mesmo aqui (requisito de
/// UI usável com o polegar, ver ARQUITETURA.md/RISCOS.md).
class _ExperienciaTile extends StatelessWidget {
  final ExperienciaProfissional experiencia;
  final WidgetRef ref;

  const _ExperienciaTile({required this.experiencia, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(experiencia.instituicao, style: Theme.of(context).textTheme.bodyLarge),
          if (experiencia.cargo != null) Text(experiencia.cargo!),
          if (experiencia.precisaConfirmacaoVinculoAtual)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Este vínculo ainda está ativo?'),
                  SizedBox(
                    height: Breakpoints.minTouchTarget,
                    child: FilledButton(
                      onPressed: () => ref
                          .read(lattesImportControllerProvider.notifier)
                          .confirmarVinculo(experiencia, aindaAtivo: true),
                      child: const Text('Sim'),
                    ),
                  ),
                  SizedBox(
                    height: Breakpoints.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () => ref
                          .read(lattesImportControllerProvider.notifier)
                          .confirmarVinculo(experiencia, aindaAtivo: false),
                      child: const Text('Não'),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              experiencia.vinculoAtual ? 'Ativo' : 'Encerrado',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
