import 'package:xml/xml.dart';

import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/experiencia_profissional.dart';
import '../../domain/entities/idioma.dart';
import '../../domain/entities/orientacao.dart';
import '../../domain/entities/participacao_evento.dart';
import '../../domain/entities/producao_tecnica.dart';
import '../../domain/entities/projeto_pesquisa.dart';
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
///   - Produção técnica: software, produto tecnológico, apresentação de
///     trabalho, programa de rádio/TV, mídia social/website/blog — seção
///     `PRODUCAO-TECNICA` (filha direta da raiz do XML, não de
///     `OUTRA-PRODUCAO` apesar do nome — confirmado contra XML real de
///     usuário; ver DECISOES.md).
///   - Participação em eventos/congressos (congresso, oficina, exposição,
///     outras) — seção `DADOS-COMPLEMENTARES/PARTICIPACAO-EM-EVENTOS-CONGRESSOS`.
///   - Projetos de pesquisa em que o usuário participou — seção
///     `PARTICIPACAO-EM-PROJETO`, aninhada em cada vínculo de
///     `ATUACOES-PROFISSIONAIS`.
///   - Áreas de atuação e idiomas — seções `DADOS-GERAIS/AREAS-DE-ATUACAO` e
///     `DADOS-GERAIS/IDIOMAS`.
///
/// O schema real do Lattes tem outras seções ainda não cobertas (prêmios,
/// participação em bancas, patentes/registros, inovação). Elas simplesmente
/// não geram itens na saída desta versão — a AUSÊNCIA de uma seção no XML e
/// a ausência de SUPORTE a uma seção têm o mesmo efeito observável (nenhum
/// item), o que é intencional e documentado, nunca um erro silencioso.
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
    final dadosComplementares = findChild(raiz, 'DADOS-COMPLEMENTARES');

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
      cursos: _parseCursos(dadosGerais, dadosComplementares),
      experienciasProfissionais: _parseExperiencias(dadosGerais),
      publicacoes: _parsePublicacoes(raiz),
      orientacoes: _parseOrientacoes(raiz),
      producoesTecnicas: _parseProducoesTecnicas(raiz),
      participacoesEventos: _parseParticipacoesEventos(dadosComplementares),
      projetos: _parseProjetos(dadosGerais),
      areasDeAtuacao: _parseAreasDeAtuacao(dadosGerais),
      idiomas: _parseIdiomas(dadosGerais),
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

  List<Curso> _parseCursos(XmlElement? dadosGerais, XmlElement? dadosComplementares) {
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

    // Formação complementar vive em DADOS-COMPLEMENTARES (não DADOS-GERAIS)
    // e o item é FORMACAO-COMPLEMENTAR-CURSO-DE-CURTA-DURACAO (não
    // CURSO-DE-CURTA-DURACAO) — confirmado contra XML real de usuário, ver
    // DECISOES.md.
    final formacaoComplementar = findChild(dadosComplementares, 'FORMACAO-COMPLEMENTAR');
    for (final el in findChildren(formacaoComplementar, 'FORMACAO-COMPLEMENTAR-CURSO-DE-CURTA-DURACAO')) {
      cursos.add(Curso(
        nivel: NivelCurso.cursoCurta,
        // O nome do curso vem em NOME-CURSO (mesmo atributo usado em
        // GRADUACAO/MESTRADO/etc.), não TITULO-DO-CURSO — confirmado contra
        // XML real de usuário.
        nomeCurso: attrOrNull(el, 'NOME-CURSO') ?? 'Curso sem título informado',
        instituicao: attrOrNull(el, 'NOME-INSTITUICAO'),
        anoInicio: intAttrOrNull(el, 'ANO-DE-INICIO'),
        anoConclusao: intAttrOrNull(el, 'ANO-DE-CONCLUSAO'),
        // Aqui carga horária É um campo padrão do schema, mas pode não ter
        // sido preenchido pelo usuário — tratamos ausência como null, nunca
        // como zero (zero horas seria uma afirmação factual incorreta).
        cargaHorariaHoras: intAttrOrNull(el, 'CARGA-HORARIA'),
        situacao: attrOrNull(el, 'STATUS-DO-CURSO'),
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
        // Atenção: os atributos de data em VINCULOS são ANO-INICIO/MES-INICIO/
        // ANO-FIM/MES-FIM — SEM "-DE-" no meio — diferente do padrão usado em
        // outras seções do schema (ex.: FORMACAO-ACADEMICA-TITULACAO usa
        // ANO-DE-INICIO/ANO-DE-CONCLUSAO). Confirmado contra XML real de
        // usuário; usar os nomes com "-DE-" aqui faz TODO vínculo parecer sem
        // data de fim, mesmo quando o Lattes já tem a data preenchida (ver
        // DECISOES.md).
        final anoFim = intAttrOrNull(vinculo, 'ANO-FIM');

        // ENQUADRAMENTO-FUNCIONAL é uma categoria fixa do Lattes (ex.:
        // "LIVRE") — não é o cargo em si. Quando o usuário descreve o cargo
        // em texto livre, isso fica em OUTRO-ENQUADRAMENTO-FUNCIONAL-INFORMADO,
        // que é o que de fato queremos mostrar; ENQUADRAMENTO-FUNCIONAL só
        // serve como cargo quando não há nada mais específico.
        final cargo = attrOrNull(vinculo, 'OUTRO-ENQUADRAMENTO-FUNCIONAL-INFORMADO') ??
            attrOrNull(vinculo, 'ENQUADRAMENTO-FUNCIONAL');

        // Ausência de ANO-FIM é como o schema do CNPq representa "vínculo em
        // andamento" — indistinguível de "usuário não preencheu a data de
        // fim". Por decisão explícita do usuário (ver DECISOES.md), essa
        // ambiguidade NÃO é resolvida silenciosamente: assumimos
        // `vinculoAtual: true` como leitura mais provável, mas marcamos
        // `precisaConfirmacaoVinculoAtual: true` para a tela de importação
        // perguntar ao usuário antes deste vínculo entrar num dossiê. Quando
        // ANO-FIM está presente, não há ambiguidade nenhuma.
        experiencias.add(ExperienciaProfissional(
          instituicao: instituicao,
          cargo: cargo,
          dataInicio: dateFromMonthYearAttrs(
            vinculo,
            anoAttr: 'ANO-INICIO',
            mesAttr: 'MES-INICIO',
          ),
          dataFim: dateFromMonthYearAttrs(
            vinculo,
            anoAttr: 'ANO-FIM',
            mesAttr: 'MES-FIM',
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

    final textosJornaisRevistas = findChild(producao, 'TEXTOS-EM-JORNAIS-OU-REVISTAS');
    for (final texto in findChildren(textosJornaisRevistas, 'TEXTO-EM-JORNAL-OU-REVISTA')) {
      final basicos = findChild(texto, 'DADOS-BASICOS-DO-TEXTO');
      final detalhamento = findChild(texto, 'DETALHAMENTO-DO-TEXTO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.textoJornalOuRevista,
        titulo: attrOrNull(basicos, 'TITULO-DO-TEXTO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO-DO-TEXTO'),
        doi: null,
        nomeVeiculo: attrOrNull(detalhamento, 'TITULO-DO-JORNAL-OU-REVISTA'),
        autores: _parseAutores(texto),
      ));
    }

    final demaisTipos = findChild(producao, 'DEMAIS-TIPOS-DE-PRODUCAO-BIBLIOGRAFICA');
    for (final outra in findChildren(demaisTipos, 'OUTRA-PRODUCAO-BIBLIOGRAFICA')) {
      final basicos = findChild(outra, 'DADOS-BASICOS-DE-OUTRA-PRODUCAO');
      final detalhamento = findChild(outra, 'DETALHAMENTO-DE-OUTRA-PRODUCAO');
      publicacoes.add(Publicacao(
        tipo: TipoPublicacao.outro,
        titulo: attrOrNull(basicos, 'TITULO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        doi: null,
        nomeVeiculo: attrOrNull(detalhamento, 'EDITORA'),
        autores: _parseAutores(outra),
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

  /// `PRODUCAO-TECNICA` é filha DIRETA da raiz do XML — irmã de
  /// `OUTRA-PRODUCAO`, não filha dela, apesar do nome da seção sugerir o
  /// contrário. Confirmado contra XML real de usuário (ver DECISOES.md);
  /// buscar dentro de `OUTRA-PRODUCAO` nunca encontrava nada.
  List<ProducaoTecnica> _parseProducoesTecnicas(XmlElement raiz) {
    final producaoTecnica = findChild(raiz, 'PRODUCAO-TECNICA');
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

    final demaisTipos = findChild(producaoTecnica, 'DEMAIS-TIPOS-DE-PRODUCAO-TECNICA');

    for (final apresentacao in findChildren(demaisTipos, 'APRESENTACAO-DE-TRABALHO')) {
      final basicos = findChild(apresentacao, 'DADOS-BASICOS-DA-APRESENTACAO-DE-TRABALHO');
      final detalhamento = findChild(apresentacao, 'DETALHAMENTO-DA-APRESENTACAO-DE-TRABALHO');
      producoes.add(ProducaoTecnica(
        tipo: TipoProducaoTecnica.apresentacaoDeTrabalho,
        titulo: attrOrNull(basicos, 'TITULO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        finalidadeOuNatureza: attrOrNull(detalhamento, 'NOME-DO-EVENTO'),
      ));
    }

    for (final programa in findChildren(demaisTipos, 'PROGRAMA-DE-RADIO-OU-TV')) {
      final basicos = findChild(programa, 'DADOS-BASICOS-DO-PROGRAMA-DE-RADIO-OU-TV');
      final detalhamento = findChild(programa, 'DETALHAMENTO-DO-PROGRAMA-DE-RADIO-OU-TV');
      producoes.add(ProducaoTecnica(
        tipo: TipoProducaoTecnica.programaDeRadioOuTv,
        titulo: attrOrNull(basicos, 'TITULO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        finalidadeOuNatureza: attrOrNull(detalhamento, 'EMISSORA'),
      ));
    }

    for (final midia in findChildren(demaisTipos, 'MIDIA-SOCIAL-WEBSITE-BLOG')) {
      final basicos = findChild(midia, 'DADOS-BASICOS-DA-MIDIA-SOCIAL-WEBSITE-BLOG');
      producoes.add(ProducaoTecnica(
        tipo: TipoProducaoTecnica.midiaSocialWebsiteBlog,
        titulo: attrOrNull(basicos, 'TITULO') ?? 'Título não informado',
        ano: intAttrOrNull(basicos, 'ANO'),
        finalidadeOuNatureza: attrOrNull(basicos, 'NATUREZA'),
      ));
    }

    return producoes;
  }

  // ---------------------------------------------------------------------
  // Participação em eventos/congressos (expansão de escopo pedida pelo
  // usuário após conferir o XML real do seu próprio currículo)
  // ---------------------------------------------------------------------

  static const Map<String, TipoParticipacaoEvento> _tagsParticipacaoEvento = {
    'PARTICIPACAO-EM-CONGRESSO': TipoParticipacaoEvento.congresso,
    'PARTICIPACAO-EM-OFICINA': TipoParticipacaoEvento.oficina,
    'PARTICIPACAO-EM-EXPOSICAO': TipoParticipacaoEvento.exposicao,
    'OUTRAS-PARTICIPACOES-EM-EVENTOS-CONGRESSOS': TipoParticipacaoEvento.outra,
  };

  List<ParticipacaoEvento> _parseParticipacoesEventos(XmlElement? dadosComplementares) {
    final container = findChild(dadosComplementares, 'PARTICIPACAO-EM-EVENTOS-CONGRESSOS');
    final participacoes = <ParticipacaoEvento>[];

    for (final entry in _tagsParticipacaoEvento.entries) {
      final sufixo = entry.key == 'PARTICIPACAO-EM-CONGRESSO'
          ? 'DA-PARTICIPACAO-EM-CONGRESSO'
          : entry.key == 'PARTICIPACAO-EM-OFICINA'
              ? 'DA-PARTICIPACAO-EM-OFICINA'
              : entry.key == 'PARTICIPACAO-EM-EXPOSICAO'
                  ? 'DA-PARTICIPACAO-EM-EXPOSICAO'
                  : 'DE-OUTRAS-PARTICIPACOES-EM-EVENTOS-CONGRESSOS';

      for (final item in findChildren(container, entry.key)) {
        final basicos = findChild(item, 'DADOS-BASICOS-$sufixo');
        final detalhamento = findChild(item, 'DETALHAMENTO-$sufixo');
        final nomeEvento = attrOrNull(detalhamento, 'NOME-DO-EVENTO');
        // No Lattes, TITULO vem vazio quando é participação simples (não
        // apresentação de trabalho) — cai para o nome do evento como título
        // de exibição em vez de mostrar um item sem nenhum texto.
        final titulo = attrOrNull(basicos, 'TITULO') ?? nomeEvento ?? 'Participação sem título informado';

        participacoes.add(ParticipacaoEvento(
          tipo: entry.value,
          titulo: titulo,
          nomeEvento: nomeEvento,
          ano: intAttrOrNull(basicos, 'ANO'),
        ));
      }
    }

    return participacoes;
  }

  // ---------------------------------------------------------------------
  // Projetos de pesquisa (expansão de escopo pedida pelo usuário)
  // ---------------------------------------------------------------------

  /// Projetos não são uma lista solta no XML — cada um vive aninhado dentro
  /// do vínculo institucional (`ATUACAO-PROFISSIONAL`) em que o usuário
  /// participou dele, então é preciso iterar todas as atuações. Além disso,
  /// `PARTICIPACAO-EM-PROJETO` é só um wrapper com dados da função exercida
  /// (SEQUENCIA-FUNCAO-ATIVIDADE, FLAG-PERIODO) — os dados do projeto em si
  /// (nome, situação, anos) ficam num filho `PROJETO-DE-PESQUISA`. Confirmado
  /// contra XML real de usuário; ler direto do wrapper sempre dava nome/
  /// situação/anos nulos, mesmo com o projeto preenchido no Lattes.
  List<ProjetoPesquisa> _parseProjetos(XmlElement? dadosGerais) {
    final atuacoes = findChild(dadosGerais, 'ATUACOES-PROFISSIONAIS');
    final projetos = <ProjetoPesquisa>[];

    for (final atuacao in findChildren(atuacoes, 'ATUACAO-PROFISSIONAL')) {
      final atividades = findChild(atuacao, 'ATIVIDADES-DE-PARTICIPACAO-EM-PROJETO');
      for (final participacao in findChildren(atividades, 'PARTICIPACAO-EM-PROJETO')) {
        final projeto = findChild(participacao, 'PROJETO-DE-PESQUISA');
        if (projeto == null) continue;
        projetos.add(ProjetoPesquisa(
          nome: attrOrNull(projeto, 'NOME-DO-PROJETO') ?? 'Projeto sem título informado',
          situacao: attrOrNull(projeto, 'SITUACAO'),
          anoInicio: intAttrOrNull(projeto, 'ANO-INICIO'),
          anoFim: intAttrOrNull(projeto, 'ANO-FIM'),
        ));
      }
    }

    return projetos;
  }

  // ---------------------------------------------------------------------
  // Áreas de atuação e idiomas (expansão de escopo pedida pelo usuário)
  // ---------------------------------------------------------------------

  List<String> _parseAreasDeAtuacao(XmlElement? dadosGerais) {
    final container = findChild(dadosGerais, 'AREAS-DE-ATUACAO');
    return findChildren(container, 'AREA-DE-ATUACAO')
        .map((el) => attrOrNull(el, 'NOME-DA-AREA-DO-CONHECIMENTO'))
        .whereType<String>()
        .toList(growable: false);
  }

  List<Idioma> _parseIdiomas(XmlElement? dadosGerais) {
    final container = findChild(dadosGerais, 'IDIOMAS');
    return findChildren(container, 'IDIOMA').map((el) {
      return Idioma(
        descricao: attrOrNull(el, 'DESCRICAO-DO-IDIOMA') ?? 'Idioma não informado',
        proficienciaLeitura: attrOrNull(el, 'PROFICIENCIA-DE-LEITURA'),
        proficienciaFala: attrOrNull(el, 'PROFICIENCIA-DE-FALA'),
        proficienciaEscrita: attrOrNull(el, 'PROFICIENCIA-DE-ESCRITA'),
        proficienciaCompreensao: attrOrNull(el, 'PROFICIENCIA-DE-COMPREENSAO'),
      );
    }).toList(growable: false);
  }
}
