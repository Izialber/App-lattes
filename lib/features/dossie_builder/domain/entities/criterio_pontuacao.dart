import 'package:equatable/equatable.dart';

/// Um critério de pontuação da Prova de Títulos, conforme interpretado do
/// edital (ex.: "Doutorado: 10 pontos, máximo 1 título"). `pontosPorUnidade`
/// e `limiteMaximoUnidades` são nulos quando o LLM não conseguiu extrair um
/// valor numérico claro — nesse caso a UI exige preenchimento manual antes
/// de permitir a compilação do dossiê.
class CriterioPontuacao extends Equatable {
  final String id;
  final String descricao;
  final double? pontosPorUnidade;
  final int? limiteMaximoUnidades;

  const CriterioPontuacao({
    required this.id,
    required this.descricao,
    this.pontosPorUnidade,
    this.limiteMaximoUnidades,
  });

  @override
  List<Object?> get props => [id, descricao, pontosPorUnidade, limiteMaximoUnidades];
}
