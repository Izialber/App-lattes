import 'package:equatable/equatable.dart';

import 'curso.dart';
import 'experiencia_profissional.dart';
import 'idioma.dart';
import 'orientacao.dart';
import 'participacao_evento.dart';
import 'producao_tecnica.dart';
import 'projeto_pesquisa.dart';
import 'publicacao.dart';

/// Entidade raiz do currículo Lattes importado. Representa apenas os dados
/// já normalizados — nenhum campo aqui é opcional "por acidente": campos que
/// o XML do CNPq pode legitimamente omitir são `String?`/listas vazias, e
/// isso é uma decisão de modelagem, não uma falha de parsing.
class CurriculoLattes extends Equatable {
  final String nomeCompleto;
  final String? nomeEmCitacoesBibliograficas;
  final String? idLattes;
  final DateTime? dataAtualizacaoCv;
  final List<Publicacao> publicacoes;
  final List<Curso> cursos;
  final List<ExperienciaProfissional> experienciasProfissionais;
  final List<Orientacao> orientacoes;
  final List<ProducaoTecnica> producoesTecnicas;
  final List<ParticipacaoEvento> participacoesEventos;
  final List<ProjetoPesquisa> projetos;
  final List<String> areasDeAtuacao;
  final List<Idioma> idiomas;

  const CurriculoLattes({
    required this.nomeCompleto,
    this.nomeEmCitacoesBibliograficas,
    this.idLattes,
    this.dataAtualizacaoCv,
    this.publicacoes = const [],
    this.cursos = const [],
    this.experienciasProfissionais = const [],
    this.orientacoes = const [],
    this.producoesTecnicas = const [],
    this.participacoesEventos = const [],
    this.projetos = const [],
    this.areasDeAtuacao = const [],
    this.idiomas = const [],
  });

  /// `true` quando há pelo menos um vínculo profissional cuja natureza
  /// ("ainda ativo?") precisa de confirmação explícita do usuário antes de
  /// entrar em um dossiê (ver DECISOES.md, "Ambiguidade vínculo em
  /// andamento"). A tela de importação usa isso para decidir se mostra o
  /// passo extra de confirmação antes de liberar o currículo para uso.
  bool get temVinculosPendentesDeConfirmacao =>
      experienciasProfissionais.any((e) => e.precisaConfirmacaoVinculoAtual);

  /// Substitui a lista de experiências (usado após `ConfirmarVinculoAtual`
  /// resolver uma ou mais pendências).
  CurriculoLattes copyWithExperiencias(List<ExperienciaProfissional> novasExperiencias) {
    return CurriculoLattes(
      nomeCompleto: nomeCompleto,
      nomeEmCitacoesBibliograficas: nomeEmCitacoesBibliograficas,
      idLattes: idLattes,
      dataAtualizacaoCv: dataAtualizacaoCv,
      publicacoes: publicacoes,
      cursos: cursos,
      experienciasProfissionais: novasExperiencias,
      orientacoes: orientacoes,
      producoesTecnicas: producoesTecnicas,
      participacoesEventos: participacoesEventos,
      projetos: projetos,
      areasDeAtuacao: areasDeAtuacao,
      idiomas: idiomas,
    );
  }

  @override
  List<Object?> get props => [
        nomeCompleto,
        nomeEmCitacoesBibliograficas,
        idLattes,
        dataAtualizacaoCv,
        publicacoes,
        cursos,
        experienciasProfissionais,
        orientacoes,
        producoesTecnicas,
        participacoesEventos,
        projetos,
        areasDeAtuacao,
        idiomas,
      ];
}
