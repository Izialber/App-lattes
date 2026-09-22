import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/experiencia_profissional.dart';
import '../../domain/entities/idioma.dart';
import '../../domain/entities/orientacao.dart';
import '../../domain/entities/participacao_evento.dart';
import '../../domain/entities/producao_tecnica.dart';
import '../../domain/entities/projeto_pesquisa.dart';
import '../../domain/entities/publicacao.dart';

/// Persiste o currículo Lattes importado — sem isso, um reload de aba perdia
/// o currículo inteiro (era estado só em memória, achado ao desenhar o
/// módulo de comprovantes: anexar arquivo a cada entrada é tarefa de vários
/// dias, não de uma sessão só — ver DECISOES.md). Só existe UM currículo por
/// usuário, então a chave no Hive é fixa (`_chave`), ao contrário dos outros
/// local stores do projeto que são listas com id por item.
class CurriculoLocalStore {
  const CurriculoLocalStore();

  static const boxName = 'curriculo_lattes';
  static const _chave = 'atual';

  Box<Map> get _box => Hive.box<Map>(boxName);

  Future<void> salvar(CurriculoLattes curriculo) {
    return _box.put(_chave, _paraMapa(curriculo));
  }

  CurriculoLattes? buscar() {
    final mapa = _box.get(_chave);
    return mapa == null ? null : _daMapa(mapa);
  }

  Future<void> limpar() => _box.delete(_chave);

  Map<String, dynamic> _paraMapa(CurriculoLattes c) => {
        'nomeCompleto': c.nomeCompleto,
        'nomeEmCitacoesBibliograficas': c.nomeEmCitacoesBibliograficas,
        'idLattes': c.idLattes,
        'dataAtualizacaoCv': c.dataAtualizacaoCv?.toIso8601String(),
        'publicacoes': c.publicacoes.map(_publicacaoParaMapa).toList(),
        'cursos': c.cursos.map(_cursoParaMapa).toList(),
        'experienciasProfissionais':
            c.experienciasProfissionais.map(_experienciaParaMapa).toList(),
        'orientacoes': c.orientacoes.map(_orientacaoParaMapa).toList(),
        'producoesTecnicas': c.producoesTecnicas.map(_producaoTecnicaParaMapa).toList(),
        'participacoesEventos': c.participacoesEventos.map(_participacaoParaMapa).toList(),
        'projetos': c.projetos.map(_projetoParaMapa).toList(),
        'areasDeAtuacao': c.areasDeAtuacao,
        'idiomas': c.idiomas.map(_idiomaParaMapa).toList(),
      };

  CurriculoLattes _daMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    return CurriculoLattes(
      nomeCompleto: mapa['nomeCompleto'] as String,
      nomeEmCitacoesBibliograficas: mapa['nomeEmCitacoesBibliograficas'] as String?,
      idLattes: mapa['idLattes'] as String?,
      dataAtualizacaoCv: mapa['dataAtualizacaoCv'] == null
          ? null
          : DateTime.parse(mapa['dataAtualizacaoCv'] as String),
      publicacoes: _lista(mapa['publicacoes']).map(_publicacaoDaMapa).toList(),
      cursos: _lista(mapa['cursos']).map(_cursoDaMapa).toList(),
      experienciasProfissionais:
          _lista(mapa['experienciasProfissionais']).map(_experienciaDaMapa).toList(),
      orientacoes: _lista(mapa['orientacoes']).map(_orientacaoDaMapa).toList(),
      producoesTecnicas: _lista(mapa['producoesTecnicas']).map(_producaoTecnicaDaMapa).toList(),
      participacoesEventos:
          _lista(mapa['participacoesEventos']).map(_participacaoDaMapa).toList(),
      projetos: _lista(mapa['projetos']).map(_projetoDaMapa).toList(),
      areasDeAtuacao: (mapa['areasDeAtuacao'] as List?)?.cast<String>() ?? const [],
      idiomas: _lista(mapa['idiomas']).map(_idiomaDaMapa).toList(),
    );
  }

  List<Map> _lista(dynamic bruto) => (bruto as List?)?.cast<Map>() ?? const [];

  // --- Curso ---------------------------------------------------------------

  Map<String, dynamic> _cursoParaMapa(Curso c) => {
        'nivel': c.nivel.name,
        'nomeCurso': c.nomeCurso,
        'instituicao': c.instituicao,
        'anoInicio': c.anoInicio,
        'anoConclusao': c.anoConclusao,
        'cargaHorariaHoras': c.cargaHorariaHoras,
        'situacao': c.situacao,
      };

  Curso _cursoDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return Curso(
      nivel: NivelCurso.values.byName(m['nivel'] as String),
      nomeCurso: m['nomeCurso'] as String,
      instituicao: m['instituicao'] as String?,
      anoInicio: m['anoInicio'] as int?,
      anoConclusao: m['anoConclusao'] as int?,
      cargaHorariaHoras: m['cargaHorariaHoras'] as int?,
      situacao: m['situacao'] as String?,
    );
  }

  // --- Publicacao ------------------------------------------------------------

  Map<String, dynamic> _publicacaoParaMapa(Publicacao p) => {
        'tipo': p.tipo.name,
        'titulo': p.titulo,
        'ano': p.ano,
        'doi': p.doi,
        'nomeVeiculo': p.nomeVeiculo,
        'autores': p.autores,
      };

  Publicacao _publicacaoDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return Publicacao(
      tipo: TipoPublicacao.values.byName(m['tipo'] as String),
      titulo: m['titulo'] as String,
      ano: m['ano'] as int?,
      doi: m['doi'] as String?,
      nomeVeiculo: m['nomeVeiculo'] as String?,
      autores: (m['autores'] as List?)?.cast<String>() ?? const [],
    );
  }

  // --- ExperienciaProfissional -----------------------------------------------

  Map<String, dynamic> _experienciaParaMapa(ExperienciaProfissional e) => {
        'instituicao': e.instituicao,
        'cargo': e.cargo,
        'dataInicio': e.dataInicio?.toIso8601String(),
        'dataFim': e.dataFim?.toIso8601String(),
        'vinculoAtual': e.vinculoAtual,
        'precisaConfirmacaoVinculoAtual': e.precisaConfirmacaoVinculoAtual,
      };

  ExperienciaProfissional _experienciaDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return ExperienciaProfissional(
      instituicao: m['instituicao'] as String,
      cargo: m['cargo'] as String?,
      dataInicio: m['dataInicio'] == null ? null : DateTime.parse(m['dataInicio'] as String),
      dataFim: m['dataFim'] == null ? null : DateTime.parse(m['dataFim'] as String),
      vinculoAtual: m['vinculoAtual'] as bool? ?? false,
      precisaConfirmacaoVinculoAtual: m['precisaConfirmacaoVinculoAtual'] as bool? ?? false,
    );
  }

  // --- Orientacao ------------------------------------------------------------

  Map<String, dynamic> _orientacaoParaMapa(Orientacao o) => {
        'nivel': o.nivel.name,
        'situacao': o.situacao.name,
        'tituloTrabalho': o.tituloTrabalho,
        'nomeOrientado': o.nomeOrientado,
        'ano': o.ano,
        'instituicao': o.instituicao,
      };

  Orientacao _orientacaoDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return Orientacao(
      nivel: NivelOrientacao.values.byName(m['nivel'] as String),
      situacao: SituacaoOrientacao.values.byName(m['situacao'] as String),
      tituloTrabalho: m['tituloTrabalho'] as String,
      nomeOrientado: m['nomeOrientado'] as String?,
      ano: m['ano'] as int?,
      instituicao: m['instituicao'] as String?,
    );
  }

  // --- ProducaoTecnica ---------------------------------------------------------

  Map<String, dynamic> _producaoTecnicaParaMapa(ProducaoTecnica p) => {
        'tipo': p.tipo.name,
        'titulo': p.titulo,
        'ano': p.ano,
        'finalidadeOuNatureza': p.finalidadeOuNatureza,
      };

  ProducaoTecnica _producaoTecnicaDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return ProducaoTecnica(
      tipo: TipoProducaoTecnica.values.byName(m['tipo'] as String),
      titulo: m['titulo'] as String,
      ano: m['ano'] as int?,
      finalidadeOuNatureza: m['finalidadeOuNatureza'] as String?,
    );
  }

  // --- ParticipacaoEvento -----------------------------------------------------

  Map<String, dynamic> _participacaoParaMapa(ParticipacaoEvento p) => {
        'tipo': p.tipo.name,
        'titulo': p.titulo,
        'nomeEvento': p.nomeEvento,
        'ano': p.ano,
      };

  ParticipacaoEvento _participacaoDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return ParticipacaoEvento(
      tipo: TipoParticipacaoEvento.values.byName(m['tipo'] as String),
      titulo: m['titulo'] as String,
      nomeEvento: m['nomeEvento'] as String?,
      ano: m['ano'] as int?,
    );
  }

  // --- ProjetoPesquisa ---------------------------------------------------------

  Map<String, dynamic> _projetoParaMapa(ProjetoPesquisa p) => {
        'nome': p.nome,
        'situacao': p.situacao,
        'anoInicio': p.anoInicio,
        'anoFim': p.anoFim,
      };

  ProjetoPesquisa _projetoDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return ProjetoPesquisa(
      nome: m['nome'] as String,
      situacao: m['situacao'] as String?,
      anoInicio: m['anoInicio'] as int?,
      anoFim: m['anoFim'] as int?,
    );
  }

  // --- Idioma ------------------------------------------------------------------

  Map<String, dynamic> _idiomaParaMapa(Idioma i) => {
        'descricao': i.descricao,
        'proficienciaLeitura': i.proficienciaLeitura,
        'proficienciaFala': i.proficienciaFala,
        'proficienciaEscrita': i.proficienciaEscrita,
        'proficienciaCompreensao': i.proficienciaCompreensao,
      };

  Idioma _idiomaDaMapa(Map mapaBruto) {
    final m = Map<String, dynamic>.from(mapaBruto);
    return Idioma(
      descricao: m['descricao'] as String,
      proficienciaLeitura: m['proficienciaLeitura'] as String?,
      proficienciaFala: m['proficienciaFala'] as String?,
      proficienciaEscrita: m['proficienciaEscrita'] as String?,
      proficienciaCompreensao: m['proficienciaCompreensao'] as String?,
    );
  }
}
