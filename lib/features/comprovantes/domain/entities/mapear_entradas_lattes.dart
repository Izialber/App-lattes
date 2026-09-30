import '../../../lattes_parser/domain/entities/curriculo_lattes.dart';
import '../../../lattes_parser/domain/entities/curso.dart';
import 'categoria_entrada_lattes.dart';
import 'entrada_lattes_ref.dart';

/// `curriculo.cursos` mistura formação acadêmica de verdade (graduação,
/// mestrado, doutorado etc.) com formação complementar (cursos de curta
/// duração) num único campo — refletindo como o parser lê o XML do Lattes
/// (`FORMACAO-ACADEMICA-TITULACAO` e `FORMACAO-COMPLEMENTAR` são seções
/// tecnicamente diferentes no schema, mas ambas viram `Curso` com `nivel`
/// distinguindo as duas). Achado ao vivo: as duas apareciam juntas numa
/// seção só de "Formação acadêmica" — errado, são coisas diferentes pra
/// quem está montando uma Prova de Títulos. Separadas aqui por `nivel`.
bool _ehFormacaoComplementar(Curso c) => c.nivel == NivelCurso.cursoCurta;

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
    ...curriculo.cursos.where((c) => !_ehFormacaoComplementar(c)).map((c) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.curso,
            [c.nivel.name, c.nomeCurso, c.instituicao, c.anoConclusao],
          ),
          categoria: CategoriaEntradaLattes.curso,
          titulo: c.nomeCurso,
          subtitulo: [
            if (c.instituicao != null) c.instituicao!,
            if (c.anoInicio != null || c.anoConclusao != null)
              '${c.anoInicio ?? '?'}–${c.anoConclusao ?? 'atual'}',
            if (c.cargaHorariaHoras != null) '${c.cargaHorariaHoras}h',
          ].join(' · '),
        )),
    ...curriculo.cursos.where(_ehFormacaoComplementar).map((c) => EntradaLattesRef(
          id: gerarIdEntrada(
            CategoriaEntradaLattes.formacaoComplementar,
            [c.nivel.name, c.nomeCurso, c.instituicao, c.anoConclusao],
          ),
          categoria: CategoriaEntradaLattes.formacaoComplementar,
          titulo: c.nomeCurso,
          subtitulo: [
            if (c.instituicao != null) c.instituicao!,
            if (c.anoInicio != null || c.anoConclusao != null)
              '${c.anoInicio ?? '?'}–${c.anoConclusao ?? 'atual'}',
            if (c.cargaHorariaHoras != null) '${c.cargaHorariaHoras}h',
          ].join(' · '),
        )),
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
