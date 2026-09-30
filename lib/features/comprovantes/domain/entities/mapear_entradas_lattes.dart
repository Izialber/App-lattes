import '../../../lattes_parser/domain/entities/curriculo_lattes.dart';
import '../../../lattes_parser/domain/entities/curso.dart';
import 'categoria_entrada_lattes.dart';
import 'entrada_lattes_ref.dart';

/// `curriculo.cursos` junta todo nível de formação (técnico, graduação,
/// pós lato/stricto sensu, formação complementar) num único campo — reflete
/// como o parser lê o XML do Lattes, que também mistura essas seções.
/// Achado ao vivo, em duas rodadas: primeiro formação complementar
/// aparecendo junto da acadêmica (separada por `nivel == cursoCurta`);
/// depois pedido explícito do usuário pra discriminar também dentro da
/// formação acadêmica em si — técnico, graduação, pós lato sensu
/// (especialização) e pós stricto sensu (mestrado/doutorado/pós-doutorado)
/// são coisas diferentes pra quem está montando uma Prova de Títulos.
CategoriaEntradaLattes _categoriaDoCurso(Curso c) => switch (c.nivel) {
      NivelCurso.tecnico => CategoriaEntradaLattes.tecnico,
      NivelCurso.graduacao => CategoriaEntradaLattes.curso,
      NivelCurso.especializacao => CategoriaEntradaLattes.posLatoSensu,
      NivelCurso.mestrado ||
      NivelCurso.doutorado ||
      NivelCurso.posDoutorado =>
        CategoriaEntradaLattes.posStrictoSensu,
      NivelCurso.cursoCurta => CategoriaEntradaLattes.formacaoComplementar,
      // `outro` não tem seção própria no Lattes real (nunca emitido pelo
      // parser hoje) — cai em formação complementar como fallback mais
      // seguro em vez de se perder ou quebrar.
      NivelCurso.outro => CategoriaEntradaLattes.formacaoComplementar,
    };

EntradaLattesRef _entradaDoCurso(Curso c) {
  final categoria = _categoriaDoCurso(c);
  return EntradaLattesRef(
    id: gerarIdEntrada(categoria, [c.nivel.name, c.nomeCurso, c.instituicao, c.anoConclusao]),
    categoria: categoria,
    titulo: c.nomeCurso,
    subtitulo: [
      if (c.instituicao != null) c.instituicao!,
      if (c.anoInicio != null || c.anoConclusao != null)
        '${c.anoInicio ?? '?'}–${c.anoConclusao ?? 'atual'}',
      if (c.cargaHorariaHoras != null) '${c.cargaHorariaHoras}h',
    ].join(' · '),
  );
}

/// Converte o currículo importado (Módulo 1) numa lista achatada de
/// [EntradaLattesRef], na MESMA ORDEM em que cada seção e cada item aparecem
/// no XML original (nenhuma reordenação/ordenação alfabética — `CurriculoLattes`
/// já preserva a ordem de parsing dentro de cada lista, e este mapeamento não
/// altera isso). A ordem das SEÇÕES segue a mesma de `CurriculoListView`
/// (`lattes_parser/presentation/widgets/curriculo_list_view.dart`), pelo
/// mesmo motivo: é a ordem que o usuário já está acostumado a ver na tela de
/// importação. `areasDeAtuacao` fica de fora (ver `CategoriaEntradaLattes`).
List<EntradaLattesRef> gerarEntradasLattes(CurriculoLattes curriculo) {
  return [
    for (final categoria in [
      CategoriaEntradaLattes.tecnico,
      CategoriaEntradaLattes.curso,
      CategoriaEntradaLattes.posLatoSensu,
      CategoriaEntradaLattes.posStrictoSensu,
      CategoriaEntradaLattes.formacaoComplementar,
    ])
      ...curriculo.cursos.where((c) => _categoriaDoCurso(c) == categoria).map(_entradaDoCurso),
    ...curriculo.experienciasProfissionais.map((e) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.experienciaProfissional,
            [e.instituicao, e.cargo, e.dataInicio?.toIso8601String()],
          ),
          categoria: CategoriaEntradaLattes.experienciaProfissional,
          titulo: e.instituicao,
          subtitulo: e.cargo ?? '',
        )),
    ...curriculo.publicacoes.map((p) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.publicacao,
            [p.tipo.name, p.titulo, p.ano, p.nomeVeiculo],
          ),
          categoria: CategoriaEntradaLattes.publicacao,
          titulo: p.titulo,
          subtitulo: [
            if (p.nomeVeiculo != null) p.nomeVeiculo!,
            if (p.ano != null) '${p.ano}',
          ].join(' · '),
        )),
    ...curriculo.orientacoes.map((o) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.orientacao,
            [o.tituloTrabalho, o.nomeOrientado, o.ano],
          ),
          categoria: CategoriaEntradaLattes.orientacao,
          titulo: o.tituloTrabalho,
          subtitulo: [
            if (o.nomeOrientado != null) 'Orientado(a): ${o.nomeOrientado}',
            o.situacao.name,
          ].join(' · '),
        )),
    ...curriculo.producoesTecnicas.map((p) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.producaoTecnica,
            [p.tipo.name, p.titulo, p.ano],
          ),
          categoria: CategoriaEntradaLattes.producaoTecnica,
          titulo: p.titulo,
          subtitulo: [
            if (p.finalidadeOuNatureza != null) p.finalidadeOuNatureza!,
            if (p.ano != null) '${p.ano}',
          ].join(' · '),
        )),
    ...curriculo.participacoesEventos.map((p) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.participacaoEvento,
            [p.tipo.name, p.titulo, p.nomeEvento, p.ano],
          ),
          categoria: CategoriaEntradaLattes.participacaoEvento,
          titulo: p.titulo,
          subtitulo: [
            if (p.nomeEvento != null && p.nomeEvento != p.titulo) p.nomeEvento!,
            if (p.ano != null) '${p.ano}',
          ].join(' · '),
        )),
    ...curriculo.projetos.map((p) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.projetoPesquisa,
            [p.nome, p.anoInicio],
          ),
          categoria: CategoriaEntradaLattes.projetoPesquisa,
          titulo: p.nome,
          subtitulo: [
            if (p.situacao != null) p.situacao!,
            if (p.anoInicio != null || p.anoFim != null)
              '${p.anoInicio ?? '?'}–${p.anoFim ?? 'atual'}',
          ].join(' · '),
        )),
    ...curriculo.idiomas.map((i) => EntradaLattesRef(
          id: gerarIdEntrada(CategoriaEntradaLattes.idioma, [i.descricao]),
          categoria: CategoriaEntradaLattes.idioma,
          titulo: i.descricao,
          subtitulo: [
            if (i.proficienciaLeitura != null) 'Leitura: ${i.proficienciaLeitura}',
            if (i.proficienciaFala != null) 'Fala: ${i.proficienciaFala}',
          ].join(' · '),
        )),
  ];
}
