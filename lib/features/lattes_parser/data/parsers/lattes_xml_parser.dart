import 'package:xml/xml.dart';

import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/experiencia_profissional.dart';
import '../../domain/entities/orientacao.dart';
import '../../domain/entities/producao_tecnica.dart';
import '../../domain/entities/publicacao.dart';
import 'lattes_xml_defensive_utils.dart';

/// Lançada apenas para os poucos casos em que o arquivo é irrecuperável
/// (não é XML válido, ou não é um XML de currículo Lattes reconhecível —
/// elemento raiz `CURRICULO-VITAE` ausente). Todo o resto — nós ausentes,
/// atributos vazios, listas com um único item, seções inteiras não
/// preenchidas pelo usuário — é tratado como dado ausente, não como erro,
/// e resolvido pelas utilidades em `lattes_xml_defensive_utils.dart`.
class LattesXmlParseException implements Exception {
  final String message;
  const LattesXmlParseException(this.message);

  @override
  String toString() => 'LattesXmlParseException: $message';
}

/// Parser 100% local do currículo Lattes (formato XML do CNPq/Plataforma
/// Lattes) — nenhuma chamada de rede, nenhuma IA envolvida neste módulo.
///
/// Cobertura desta implementação (ver DECISOES.md para o que foi
/// conscientemente deixado de fora nesta primeira versão):
///   - Dados gerais: nome completo, nome em citações, ID Lattes, data de
///     atualização do currículo.
///   - Formação acadêmica: graduação, especialização, mestrado, doutorado,
///     pós-doutorado, e cursos de curta duração (formação complementar).
///   - Atuações profissionais / vínculos institucionais.
///   - Produção bibliográfica: artigos publicados em periódicos, trabalhos
///     em eventos, capítulos de livro e livros publicados/organizados.
///   - Orientações (dissertação de mestrado, tese de doutorado, iniciação
///     científica, outra natureza), concluídas e em andamento — seção
///     `OUTRA-PRODUCAO/ORIENTACOES-*`, adicionada por decisão explícita do
///     usuário de expandir o escopo original (ver DECISOES.md).
///   - Produção técnica: software e produto tecnológico — seção
///     `OUTRA-PRODUCAO/PRODUCAO-TECNICA`, mesma expansão.
///
/// O schema real do Lattes tem outras seções ainda não cobertas (projetos
/// de pesquisa, prêmios, participação em bancas, demais tipos de produção
/// técnica). Elas simplesmente não geram itens na saída desta versão — a
/// AUSÊNCIA de uma seção no XML e a ausência de SUPORTE a uma seção têm o
/// mesmo efeito observável (nenhum item), o que é intencional e
/// documentado, nunca um erro silencioso.
class LattesXmlParser {
  const LattesXmlParser();

  CurriculoLattes parse(String xmlContent) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlContent);
    } on XmlException catch (e) {
      throw LattesXmlParseException('O arquivo não é um XML válido: ${e.message}');
    } on FormatException catch (e) {
      throw LattesXmlParseException('O arquivo não é um XML válido: ${e.message}');
    }

    final raizCandidatos = document.findAllElements('CURRICULO-VITAE');
    if (raizCandidatos.isEmpty) {
      throw const LattesXmlParseException(
        'O arquivo não parece ser um currículo Lattes: elemento raiz '
        '<CURRICULO-VITAE> não encontrado.',
      );
    }
    final raiz = raizCandidatos.first;

    final dadosGerais = findChild(raiz, 'DADOS-GERAIS');

    // NOME-COMPLETO é o único campo que tratamos como obrigatório para
    // considerar o currículo "legível" — mesmo assim, se estiver ausente,
    // preferimos um valor sentinela explícito a lançar exceção, porque o
    // restante do currículo (publicações, cursos) ainda pode ser útil ao
    // usuário mesmo sem o nome.
    final nomeCompleto = attrOrNull(dadosGerais, 'NOME-COMPLETO') ??
        attrOrNull(raiz, 'NOME-COMPLETO') ??
        'Nome não informado no XML';

    return CurriculoLattes(
      nomeCompleto: nomeCompleto,
      nomeEmCitacoesBibliograficas: attrOrNull(dadosGerais, 'NOME-EM-CITACOES-BIBLIOGRAFICAS'),
      idLattes: attrOrNull(raiz, 'NUMERO-IDENTIFICADOR'),
      dataAtualizacaoCv: parseDataAtualizacaoCv(attrOrNull(raiz, 'DATA-ATUALIZACAO')),
      cursos: _parseCursos(dadosGerais),
      experienciasProfissionais: _parseExperiencias(dadosGerais),
      publicacoes: _parsePublicacoes(raiz),
      orientacoes: _parseOrientacoes(raiz),
      producoesTecnicas: _parseProducoesTecnicas(raiz),
    );
  }

  // ---------------------------------------------------------------------
  // Formação acadêmica
  // ---------------------------------------------------------------------

  static const Map<String, NivelCurso> _tagsNivelFormacao = {
    'GRADUACAO': NivelCurso.graduacao,
    'ESPECIALIZACAO': NivelCurso.especializacao,
    'MESTRADO': NivelCurso.mestrado,
    'DOUTORADO': NivelCurso.doutorado,
    'POS-DOUTORADO': NivelCurso.posDoutorado,
  };

  List<Curso> _parseCursos(XmlElement? dadosGerais) {
    final formacao = findChild(dadosGerais, 'FORMACAO-ACADEMICA-TITULACAO');
    final cursos = <Curso>[];

    for (final entry in _tagsNivelFormacao.entries) {
      for (final el in findChildren(formacao, entry.key)) {
        cursos.add(Curso(
          nivel: entry.value,
          nomeCurso: attrOrNull(el, 'NOME-CURSO') ?? 'Curso sem título informado',
          instituicao: attrOrNull(el, 'NOME-INSTITUICAO'),
          anoInicio: intAttrOrNull(el, 'ANO-DE-INICIO'),
          anoConclusao: intAttrOrNull(el, 'ANO-DE-CONCLUSAO'),
          // Carga horária não é um campo padrão do schema do CNPq para
          // estes níveis (graduação/pós) — permanece null intencionalmente.
          cargaHorariaHoras: null,
          situacao: attrOrNull(el, 'STATUS-DO-CURSO'),
        ));
      }
    }

    final formacaoComplementar = findChild(dadosGerais, 'FORMACAO-COMPLEMENTAR');
    for (final el in findChildren(formacaoComplementar, 'CURSO-DE-CURTA-DURACAO')) {
      cursos.add(Curso(
        nivel: NivelCurso.cursoCurta,
        nomeCurso: attrOrNull(el, 'TITULO-DO-CURSO') ?? 'Curso sem título informado',
        instituicao: attrOrNull(el, 'NOME-INSTITUICAO'),
        anoInicio: intAttrOrNull(el, 'ANO-DE-INICIO'),
        anoConclusao: intAttrOrNull(el, 'ANO-DE-CONCLUSAO'),
        // Aqui carga horária É um campo padrão do schema, mas pode não ter
        // sido preenchido pelo usuário — tratamos ausência como null, nunca
        // como zero (zero horas seria uma afirmação factual incorreta).
        cargaHorariaHoras: intAttrOrNull(el, 'CARGA-HORARIA'),
        situacao: null,
      ));
    }

    return cursos;
  }

  // ---------------------------------------------------------------------
  // Experiência profissional
  // ---------------------------------------------------------------------

  List<ExperienciaProfissional> _parseExperiencias(XmlElement? dadosGerais) {
    final atuacoes = findChild(dadosGerais, 'ATUACOES-PROFISSIONAIS');
    final experiencias = <ExperienciaProfissional>[];

    for (final atuacao in findChildren(atuacoes, 'ATUACAO-PROFISSIONAL')) {
      final instituicao = attrOrNull(atuacao, 'NOME-INSTITUICAO') ?? 'Instituição não informada';
      final vinculos = findChildren(atuacao, 'VINCULOS');

      if (vinculos.isEmpty) {
        // Atuação registrada sem nenhum vínculo detalhado ainda é um dado
        // válido a preservar (ex.: usuário só informou a instituição).
        experiencias.add(ExperienciaProfissional(instituicao: instituicao));
        continue;
      }

      for (final vinculo in vinculos) {
        final anoFim = intAttrOrNull(vinculo, 'ANO-DE-FIM');
        // Ausência de ANO-DE-FIM é como o schema do CNPq representa "vínculo
        // em andamento" — indistinguível de "usuário não preencheu a data
        // de fim". Por decisão explícita do usuário (ver DECISOES.md), essa
        // ambiguidade NÃO é resolvida silenciosamente: assumimos
        // `vinculoAtual: true` como leitura mais provável, mas marcamos
        // `precisaConfirmacaoVinculoAtual: true` para a tela de importação
        // perguntar ao usuário antes deste vínculo entrar em um dossiê.
        // Quando ANO-DE-FIM está presente, não há ambiguidade nenhuma.
        experiencias.add(ExperienciaProfissional(
          instituicao: instituicao,
          cargo: attrOrNull(vinculo, 'ENQUADRAMENTO-FUNCIONAL') ??
              attrOrNull(vinculo, 'OUTRO-ENQUADRAMENTO-FUNCIONAL-INFORMADO'),
          dataInicio: dateFromMonthYearAttrs(
            vinculo,
            anoAttr: 'ANO-DE-INICIO',
            mesAttr: 'MES-DE-INICIO',
          ),
          dataFim: dateFromMonthYearAttrs(
            vinculo,
            anoAttr: 'ANO-DE-FIM',
            mesAttr: 'MES-DE-FIM',
          ),
          vinculoAtual: anoFim == null,
          precisaConfirmacaoVinculoAtual: anoFim == null,
        ));
      }
    }

    return experiencias;
  }

  // ---------------------------------------------------------------------
  // Produção bibliográfica
  // ---------------------------------------------------------------------

  List<Publicacao> _parsePublicacoes(XmlElement raiz) {
    final producao = findChild(raiz, 'PRODUCAO-BIBLIOGRAFICA');
    final publicacoes = <Publicacao>[];

    final artigos = findChild(producao, 'ARTIGOS-PUBLICADOS');
    for (final artigo in findChildren(artigos, 'ARTIGO-PUBLICADO')) {
      final basicos = findChild(artigo, 'DADOS-BASICOS-DO-ARTIGO');
      final detalhamento = findChild(artigo, 'DETALHAMENTO-DO-ARTIGO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.artigoPeriodico,
        titulo: attrOrNull(basicos, 'TITULO-DO-ARTIGO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO-DO-ARTIGO'),
        doi: attrOrNull(basicos, 'DOI'),
        nomeVeiculo: attrOrNull(detalhamento, 'TITULO-DO-PERIODICO-OU-REVISTA'),
        autores: _parseAutores(artigo),
      ));
    }

    final trabalhosEventos = findChild(producao, 'TRABALHOS-EM-EVENTOS');
    for (final trabalho in findChildren(trabalhosEventos, 'TRABALHO-EM-EVENTOS')) {
      final basicos = findChild(trabalho, 'DADOS-BASICOS-DO-TRABALHO');
      final detalhamento = findChild(trabalho, 'DETALHAMENTO-DO-TRABALHO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.trabalhoEvento,
        titulo: attrOrNull(basicos, 'TITULO-DO-TRABALHO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO-DO-TRABALHO'),
        doi: attrOrNull(basicos, 'DOI'),
        nomeVeiculo: attrOrNull(detalhamento, 'NOME-DO-EVENTO'),
        autores: _parseAutores(trabalho),
      ));
    }

    final livrosECapitulos = findChild(producao, 'LIVROS-E-CAPITULOS');

    final capitulos = findChild(livrosECapitulos, 'CAPITULOS-DE-LIVROS-PUBLICADOS');
    for (final capitulo in findChildren(capitulos, 'CAPITULO-DE-LIVRO-PUBLICADO')) {
      final basicos = findChild(capitulo, 'DADOS-BASICOS-DO-CAPITULO');
      final detalhamento = findChild(capitulo, 'DETALHAMENTO-DO-CAPITULO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.capituloLivro,
        titulo: attrOrNull(basicos, 'TITULO-DO-CAPITULO-DO-LIVRO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        doi: attrOrNull(basicos, 'DOI'),
        nomeVeiculo: attrOrNull(detalhamento, 'TITULO-DO-LIVRO'),
        autores: _parseAutores(capitulo),
      ));
    }

    final livros = findChild(livrosECapitulos, 'LIVROS-PUBLICADOS-OU-ORGANIZADOS');
    for (final livro in findChildren(livros, 'LIVRO-PUBLICADO-OU-ORGANIZADO')) {
      final basicos = findChild(livro, 'DADOS-BASICOS-DO-LIVRO');
      final detalhamento = findChild(livro, 'DETALHAMENTO-DO-LIVRO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.livroPublicado,
        titulo: attrOrNull(basicos, 'TITULO-DO-LIVRO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        doi: attrOrNull(basicos, 'DOI'),
        nomeVeiculo: attrOrNull(detalhamento, 'NOME-DA-EDITORA'),
        autores: _parseAutores(livro),
      ));
    }

    return publicacoes;
  }

  /// Cada item de produção bibliográfica tem zero ou mais elementos
  /// `<AUTORES NOME-COMPLETO-DO-AUTOR="..."/>` como filhos diretos (schema
  /// do CNPq). Nomes vazios/ausentes são filtrados, nunca viram string
  /// vazia na lista final.
  List<String> _parseAutores(XmlElement itemProducao) {
    return findChildren(itemProducao, 'AUTORES')
        .map((autor) => attrOrNull(autor, 'NOME-COMPLETO-DO-AUTOR'))
        .whereType<String>()
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // Orientações (expansão de escopo decidida pelo usuário)
  // ---------------------------------------------------------------------

  static const Map<String, NivelOrientacao> _tagsNivelOrientacao = {
    'INICIACAO-CIENTIFICA': NivelOrientacao.iniciacaoCientifica,
    'MONOGRAFIA-DE-CONCLUSAO-DE-CURSO-APERFEICOAMENTO-E-ESPECIALIZACAO':
        NivelOrientacao.especializacao,
    'DISSERTACAO-DE-MESTRADO': NivelOrientacao.mestrado,
    'TESE-DE-DOUTORADO': NivelOrientacao.doutorado,
    'SUPERVISAO-DE-POS-DOUTORADO': NivelOrientacao.posDoutorado,
    'ORIENTACAO-DE-OUTRA-NATUREZA': NivelOrientacao.outraNatureza,
  };

  List<Orientacao> _parseOrientacoes(XmlElement raiz) {
    final outraProducao = findChild(raiz, 'OUTRA-PRODUCAO');
    final orientacoes = <Orientacao>[];

    // Cada nível (DISSERTACAO-DE-MESTRADO, TESE-DE-DOUTORADO etc.) tem seus
    // dados em `DADOS-BASICOS-DE-ORIENTACOES-CONCLUIDAS`/
    // `-EM-ANDAMENTO` conforme o container em que está — passamos o nome
    // exato esperado para não depender de tentativa-e-erro.
    void parseContainer(
      String tagContainer,
      SituacaoOrientacao situacao,
      String tagDadosBasicos,
      String tagDetalhamento,
    ) {
      final container = findChild(outraProducao, tagContainer);
      for (final entry in _tagsNivelOrientacao.entries) {
        for (final item in findChildren(container, entry.key)) {
          final basicos = findChild(item, tagDadosBasicos);
          final detalhamento = findChild(item, tagDetalhamento);

          orientacoes.add(Orientacao(
            nivel: entry.value,
            situacao: situacao,
            tituloTrabalho: attrOrNull(basicos, 'TITULO') ?? 'Título não informado',
            ano: intAttrOrNull(basicos, 'ANO'),
            nomeOrientado: attrOrNull(detalhamento, 'NOME-DO-ORIENTADO'),
            instituicao: attrOrNull(detalhamento, 'NOME-DA-INSTITUICAO'),
          ));
        }
      }
    }

    parseContainer(
      'ORIENTACOES-CONCLUIDAS',
      SituacaoOrientacao.concluida,
      'DADOS-BASICOS-DE-ORIENTACOES-CONCLUIDAS',
      'DETALHAMENTO-DE-ORIENTACOES-CONCLUIDAS',
    );
    parseContainer(
      'ORIENTACOES-EM-ANDAMENTO',
      SituacaoOrientacao.emAndamento,
      'DADOS-BASICOS-DE-ORIENTACOES-EM-ANDAMENTO',
      'DETALHAMENTO-DE-ORIENTACOES-EM-ANDAMENTO',
    );

    return orientacoes;
  }

  // ---------------------------------------------------------------------
  // Produção técnica (expansão de escopo decidida pelo usuário)
  // ---------------------------------------------------------------------

  List<ProducaoTecnica> _parseProducoesTecnicas(XmlElement raiz) {
    final outraProducao = findChild(raiz, 'OUTRA-PRODUCAO');
    final producaoTecnica = findChild(outraProducao, 'PRODUCAO-TECNICA');
    final producoes = <ProducaoTecnica>[];

    for (final software in findChildren(producaoTecnica, 'SOFTWARE')) {
      final basicos = findChild(software, 'DADOS-BASICOS-DO-SOFTWARE');
      final detalhamento = findChild(software, 'DETALHAMENTO-DO-SOFTWARE');
      producoes.add(ProducaoTecnica(
        tipo: TipoProducaoTecnica.software,
        titulo: attrOrNull(basicos, 'TITULO-DO-SOFTWARE') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        finalidadeOuNatureza: attrOrNull(detalhamento, 'FINALIDADE'),
      ));
    }

    for (final produto in findChildren(producaoTecnica, 'PRODUTO-TECNOLOGICO')) {
      final basicos = findChild(produto, 'DADOS-BASICOS-DO-PRODUTO-TECNOLOGICO');
      final detalhamento = findChild(produto, 'DETALHAMENTO-DO-PRODUTO-TECNOLOGICO');
      producoes.add(ProducaoTecnica(
        tipo: TipoProducaoTecnica.produtoTecnologico,
        titulo: attrOrNull(basicos, 'TITULO-DO-PRODUTO-TECNOLOGICO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        finalidadeOuNatureza: attrOrNull(detalhamento, 'NATUREZA'),
      ));
    }

    return producoes;
  }
}
