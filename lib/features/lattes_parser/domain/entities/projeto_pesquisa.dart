import 'package:equatable/equatable.dart';

/// Projeto de pesquisa em que o usuário participou (seção
/// `PARTICIPACAO-EM-PROJETO`, aninhada dentro de cada vínculo em
/// `ATUACOES-PROFISSIONAIS/ATUACAO-PROFISSIONAL/
/// ATIVIDADES-DE-PARTICIPACAO-EM-PROJETO` — não é uma lista solta no XML).
class ProjetoPesquisa extends Equatable {
  final String nome;
  final String? situacao;
  final int? anoInicio;
  final int? anoFim;

  const ProjetoPesquisa({
    required this.nome,
    this.situacao,
    this.anoInicio,
    this.anoFim,
  });

  @override
  List<Object?> get props => [nome, situacao, anoInicio, anoFim];
}
