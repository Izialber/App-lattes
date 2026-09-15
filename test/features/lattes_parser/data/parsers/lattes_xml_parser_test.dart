import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/lattes_parser/data/parsers/lattes_xml_parser.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/curso.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/orientacao.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/participacao_evento.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/producao_tecnica.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/publicacao.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/usecases/confirmar_vinculo_atual.dart';

/// Testes do parser 100% local do XML do Lattes. Cada teste corresponde a um
/// dos cenários exigidos: XML válido completo, campos opcionais ausentes,
/// nó vazio, lista com item único, e acentuação/caracteres especiais — além
/// de casos de erro irrecuperável (XML malformado, XML que não é um
/// currículo Lattes, conteúdo vazio).
///
/// Executar com `flutter test` a partir da raiz do pacote — os caminhos de
/// fixture abaixo são relativos à raiz do projeto, convenção padrão do
/// `package:test`/`flutter_test`.
void main() {
  const parser = LattesXmlParser();

  String lerFixture(String nomeArquivo) {
    return File('test/fixtures/$nomeArquivo').readAsStringSync();
  }

  group('XML válido e completo (lattes_valido.xml)', () {
    late final curriculo = parser.parse(lerFixture('lattes_valido.xml'));

    test('lê dados gerais corretamente', () {
      expect(curriculo.nomeCompleto, 'Izialber Alves da Silva');
      expect(curriculo.nomeEmCitacoesBibliograficas, 'SILVA, I. A.');
      expect(curriculo.idLattes, '1234567890123456');
      expect(curriculo.dataAtualizacaoCv, DateTime(2026, 9, 7));
    });

    test('lê os três níveis de formação acadêmica + curso de curta duração', () {
      expect(curriculo.cursos, hasLength(5));

      final graduacao = curriculo.cursos.firstWhere((c) => c.nivel == NivelCurso.graduacao);
      expect(graduacao.nomeCurso, 'Engenharia Elétrica');
      expect(graduacao.anoConclusao, 2010);

      final doutorado = curriculo.cursos.firstWhere((c) => c.nivel == NivelCurso.doutorado);
      expect(doutorado.situacao, 'Em andamento');
      expect(doutorado.anoConclusao, isNull); // doutorado em andamento, sem ano de conclusão

      final cursoCurta = curriculo.cursos
          .where((c) => c.nivel == NivelCurso.cursoCurta)
          .firstWhere((c) => c.nomeCurso.contains('62443'));
      expect(cursoCurta.cargaHorariaHoras, 40);
      expect(cursoCurta.instituicao, 'ISA');
    });

    test('lê experiências profissionais e infere vínculo atual pela ausência de ANO-FIM', () {
      expect(curriculo.experienciasProfissionais, hasLength(2));

      final shell = curriculo.experienciasProfissionais.firstWhere(
        (e) => e.instituicao == 'Shell Brasil',
      );
      expect(shell.vinculoAtual, isTrue);
      expect(shell.dataFim, isNull);
      expect(shell.cargo, 'IT Site Operations Lead');
      expect(shell.dataInicio, DateTime(2018, 3));
      // ANO-FIM ausente: vínculo ambíguo, precisa de confirmação explícita
      // do usuário antes de entrar num dossiê (ver DECISOES.md).
      expect(shell.precisaConfirmacaoVinculoAtual, isTrue);

      final dunamis = curriculo.experienciasProfissionais.firstWhere(
        (e) => e.instituicao == 'Faculdade Dunamis',
      );
      expect(dunamis.vinculoAtual, isFalse);
      expect(dunamis.dataFim, DateTime(2023, 12));
      // ANO-FIM presente: sem ambiguidade, não precisa de confirmação.
      expect(dunamis.precisaConfirmacaoVinculoAtual, isFalse);

      expect(curriculo.temVinculosPendentesDeConfirmacao, isTrue);
    });

    test('lê orientações concluídas e em andamento', () {
      expect(curriculo.orientacoes, hasLength(2));

      final mestrado = curriculo.orientacoes.firstWhere(
        (o) => o.nivel == NivelOrientacao.mestrado,
      );
      expect(mestrado.situacao, SituacaoOrientacao.concluida);
      expect(mestrado.tituloTrabalho, 'IoT Aplicado a Automação Predial');
      expect(mestrado.nomeOrientado, 'Fernanda Lima');
      expect(mestrado.ano, 2021);

      final doutorado = curriculo.orientacoes.firstWhere(
        (o) => o.nivel == NivelOrientacao.doutorado,
      );
      expect(doutorado.situacao, SituacaoOrientacao.emAndamento);
      expect(doutorado.nomeOrientado, 'Rafael Nogueira');
    });

    test('lê produção técnica (software, produto tecnológico e os 3 tipos novos)', () {
      expect(curriculo.producoesTecnicas, hasLength(5));

      final software = curriculo.producoesTecnicas.firstWhere(
        (p) => p.tipo == TipoProducaoTecnica.software,
      );
      expect(software.titulo, 'Painel de Monitoramento IACS');
      expect(software.finalidadeOuNatureza, 'Uso interno');

      final produto = curriculo.producoesTecnicas.firstWhere(
        (p) => p.tipo == TipoProducaoTecnica.produtoTecnologico,
      );
      expect(produto.titulo, 'Guia de Hardening ISA/IEC 62443');

      final apresentacao = curriculo.producoesTecnicas.firstWhere(
        (p) => p.tipo == TipoProducaoTecnica.apresentacaoDeTrabalho,
      );
      expect(apresentacao.titulo, 'Simulação de Eventos Discretos Aplicada à Evasão');
      expect(apresentacao.finalidadeOuNatureza, 'COBENGE 2023');

      final programa = curriculo.producoesTecnicas.firstWhere(
        (p) => p.tipo == TipoProducaoTecnica.programaDeRadioOuTv,
      );
      expect(programa.titulo, 'Proteção da sua base de TO');
      expect(programa.finalidadeOuNatureza, 'Youtube');

      final midia = curriculo.producoesTecnicas.firstWhere(
        (p) => p.tipo == TipoProducaoTecnica.midiaSocialWebsiteBlog,
      );
      expect(midia.titulo, 'Site Pessoal');
      expect(midia.finalidadeOuNatureza, 'SITE');
    });

    test('lê publicações dos cinco tipos suportados', () {
      expect(curriculo.publicacoes, hasLength(5));

      final artigo = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.artigoPeriodico,
      );
      expect(artigo.titulo, 'IoT Adoption in South America: A Review');
      expect(artigo.doi, '10.1000/xyz123');
      expect(artigo.nomeVeiculo, 'Journal of Industrial Technology');
      expect(artigo.autores, ['Izialber Alves da Silva', 'Sandro Costa Pereira']);

      final trabalho = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.trabalhoEvento,
      );
      expect(trabalho.nomeVeiculo, 'International Conference on Engineering Education');

      final capitulo = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.capituloLivro,
      );
      expect(capitulo.nomeVeiculo, 'Tópicos em Automação Industrial');

      final texto = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.textoJornalOuRevista,
      );
      expect(texto.titulo, 'Informação guardada a 7 chaves');
      expect(texto.nomeVeiculo, 'FM Connection');

      final outra = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.outro,
      );
      expect(outra.titulo, 'Dataset de Adoção de IoT na América do Sul');
      expect(outra.nomeVeiculo, 'IEEE');
    });

    test('lê participação em eventos, caindo para o nome do evento quando TITULO vem vazio', () {
      expect(curriculo.participacoesEventos, hasLength(2));

      final congresso = curriculo.participacoesEventos.firstWhere(
        (p) => p.tipo == TipoParticipacaoEvento.congresso,
      );
      // TITULO="" no XML (participação simples, não apresentação) — cai
      // para NOME-DO-EVENTO como título de exibição.
      expect(congresso.titulo, '7º Congresso Nacional FENEP');
      expect(congresso.ano, 2022);

      final outra = curriculo.participacoesEventos.firstWhere(
        (p) => p.tipo == TipoParticipacaoEvento.outra,
      );
      expect(outra.titulo, 'Como está a proteção da sua base de TO?');
      expect(outra.nomeEvento, 'Mês da Inovação do IBP');
    });

    test('lê projeto de pesquisa aninhado dentro do vínculo institucional', () {
      final projeto = curriculo.projetos.single;
      expect(projeto.nome, 'Modernização do Sistema de Controle de Pressão');
      expect(projeto.situacao, 'CONCLUIDO');
      expect(projeto.anoInicio, 2019);
      expect(projeto.anoFim, 2021);
    });

    test('lê áreas de atuação e idiomas', () {
      expect(curriculo.areasDeAtuacao, ['Engenharia Elétrica', 'Engenharia de Produção']);

      final idioma = curriculo.idiomas.single;
      expect(idioma.descricao, 'Inglês');
      expect(idioma.proficienciaLeitura, 'BEM');
    });
  });

  group('Campos opcionais ausentes (lattes_campos_opcionais_ausentes.xml)', () {
    late final curriculo = parser.parse(lerFixture('lattes_campos_opcionais_ausentes.xml'));

    test('não lança exceção e preserva o que está presente', () {
      expect(curriculo.nomeCompleto, 'Maria Oliveira');
      expect(curriculo.nomeEmCitacoesBibliograficas, isNull);
      expect(curriculo.idLattes, isNull);
      expect(curriculo.dataAtualizacaoCv, isNull);
    });

    test('curso sem ano de conclusão nem status fica com esses campos nulos, não zerados', () {
      final graduacao = curriculo.cursos.firstWhere((c) => c.nivel == NivelCurso.graduacao);
      expect(graduacao.anoConclusao, isNull);
      expect(graduacao.situacao, isNull);
      expect(graduacao.anoInicio, 2010);
    });

    test('curso de curta duração sem instituição/carga horária/anos: tudo nulo, sem exceção', () {
      final cursoCurta = curriculo.cursos.firstWhere((c) => c.nivel == NivelCurso.cursoCurta);
      expect(cursoCurta.nomeCurso, 'Excel Avançado');
      expect(cursoCurta.instituicao, isNull);
      expect(cursoCurta.cargaHorariaHoras, isNull);
      expect(cursoCurta.anoInicio, isNull);
    });

    test('experiência sem MES-INICIO assume mês 1 e fica marcada para confirmação', () {
      final experiencia = curriculo.experienciasProfissionais.single;
      expect(experiencia.dataInicio, DateTime(2015, 1));
      expect(experiencia.vinculoAtual, isTrue);
      expect(experiencia.precisaConfirmacaoVinculoAtual, isTrue);
    });

    test('artigo sem DOI, sem periódico e sem autores: campos nulos/lista vazia, sem exceção', () {
      final artigo = curriculo.publicacoes.single;
      expect(artigo.titulo, 'Estudo sobre Produtividade');
      expect(artigo.doi, isNull);
      expect(artigo.nomeVeiculo, isNull);
      expect(artigo.autores, isEmpty);
    });
  });

  group('Nó vazio (lattes_no_vazio.xml)', () {
    late final curriculo = parser.parse(lerFixture('lattes_no_vazio.xml'));

    test('seções presentes mas vazias (self-closing ou sem filhos) não quebram o parser', () {
      expect(curriculo.nomeCompleto, 'João Sem Currículo Preenchido');
      expect(curriculo.cursos, isEmpty);
      expect(curriculo.publicacoes, isEmpty);
    });

    test('OUTRA-PRODUCAO ausente do XML: orientações e produção técnica vazias, sem exceção', () {
      expect(curriculo.orientacoes, isEmpty);
      expect(curriculo.producoesTecnicas, isEmpty);
    });

    test('atuação profissional sem nenhum VINCULOS ainda gera uma experiência (sem detalhes)', () {
      final experiencia = curriculo.experienciasProfissionais.single;
      expect(experiencia.instituicao, 'Instituição Sem Vínculos Detalhados');
      expect(experiencia.cargo, isNull);
      expect(experiencia.dataInicio, isNull);
      expect(experiencia.vinculoAtual, isFalse);
      // Sem VINCULOS nenhum, não há ambiguidade de "vínculo em andamento" a
      // resolver — a confirmação só se aplica quando há um vínculo cujo
      // ANO-FIM está ausente.
      expect(experiencia.precisaConfirmacaoVinculoAtual, isFalse);
      expect(curriculo.temVinculosPendentesDeConfirmacao, isFalse);
    });
  });

  group('Lista com item único (lattes_lista_item_unico.xml)', () {
    late final curriculo = parser.parse(lerFixture('lattes_lista_item_unico.xml'));

    test('uma única formação, uma única experiência, uma única publicação', () {
      expect(curriculo.cursos, hasLength(1));
      expect(curriculo.experienciasProfissionais, hasLength(1));
      expect(curriculo.publicacoes, hasLength(1));
      expect(curriculo.publicacoes.single.autores, hasLength(1));
    });

    test('dataAtualizacaoCv no formato DDMMAAAA é convertida corretamente', () {
      expect(curriculo.dataAtualizacaoCv, DateTime(2026, 1, 15));
    });
  });

  group('Acentuação e caracteres especiais (lattes_acentuacao.xml)', () {
    late final curriculo = parser.parse(lerFixture('lattes_acentuacao.xml'));

    test('preserva acentuação, cedilha, til e caracteres compostos no nome', () {
      expect(curriculo.nomeCompleto, 'José André Ñuñez-Müller');
      expect(curriculo.nomeEmCitacoesBibliograficas, 'ÑUÑEZ-MÜLLER, J. A.');
    });

    test('preserva apóstrofo em nome de instituição', () {
      final experiencia = curriculo.experienciasProfissionais.single;
      expect(experiencia.instituicao, "Instituição São João D'Alí");
    });

    test('decodifica entidade XML &amp; corretamente em título e veículo', () {
      final artigo = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.artigoPeriodico,
      );
      expect(artigo.nomeVeiculo, 'Revista Brasileira de Educação & Inovação');

      final trabalho = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.trabalhoEvento,
      );
      expect(trabalho.titulo, 'A Curricularização da Competência 4.0: Questões & Respostas');
    });

    test('lista de autores com acentuação mantém ordem e grafia exatas', () {
      final artigo = curriculo.publicacoes.firstWhere(
        (p) => p.tipo == TipoPublicacao.artigoPeriodico,
      );
      expect(artigo.autores, ['José André Ñuñez-Müller', 'Conceição Araújo']);
    });
  });

  group('ConfirmarVinculoAtual (resolução da ambiguidade de vínculo em andamento)', () {
    const confirmar = ConfirmarVinculoAtual();
    final experienciaAmbigua = parser
        .parse(lerFixture('lattes_valido.xml'))
        .experienciasProfissionais
        .firstWhere((e) => e.instituicao == 'Shell Brasil');

    test('confirmar como ainda ativo mantém vinculoAtual e encerra a pendência', () {
      final resultado = confirmar(experienciaAmbigua, aindaAtivo: true);
      expect(resultado.vinculoAtual, isTrue);
      expect(resultado.dataFim, isNull);
      expect(resultado.precisaConfirmacaoVinculoAtual, isFalse);
    });

    test('confirmar como não mais ativo zera vinculoAtual e encerra a pendência', () {
      final resultado = confirmar(experienciaAmbigua, aindaAtivo: false);
      expect(resultado.vinculoAtual, isFalse);
      expect(resultado.precisaConfirmacaoVinculoAtual, isFalse);
    });

    test('não altera instituição, cargo ou data de início', () {
      final resultado = confirmar(experienciaAmbigua, aindaAtivo: false);
      expect(resultado.instituicao, experienciaAmbigua.instituicao);
      expect(resultado.cargo, experienciaAmbigua.cargo);
      expect(resultado.dataInicio, experienciaAmbigua.dataInicio);
    });
  });

  group('Erros irrecuperáveis', () {
    test('XML malformado lança LattesXmlParseException, não uma exceção genérica', () {
      const xmlQuebrado = '<CURRICULO-VITAE><DADOS-GERAIS NOME-COMPLETO="Sem Fechar">';
      expect(
        () => parser.parse(xmlQuebrado),
        throwsA(isA<LattesXmlParseException>()),
      );
    });

    test('XML válido mas sem elemento raiz CURRICULO-VITAE lança LattesXmlParseException', () {
      const xmlOutraCoisa = '<?xml version="1.0"?><OUTRA-COISA><A/></OUTRA-COISA>';
      expect(
        () => parser.parse(xmlOutraCoisa),
        throwsA(isA<LattesXmlParseException>()),
      );
    });

    test('conteúdo totalmente vazio lança LattesXmlParseException', () {
      expect(() => parser.parse(''), throwsA(isA<LattesXmlParseException>()));
    });
  });
}
