import 'package:equatable/equatable.dart';

enum DecisaoVinculo { aprovado, alterado, excluido }

/// Resultado da revisão humana obrigatória sobre uma sugestão de vínculo
/// entre um certificado e um critério do edital. Nenhum [VinculoAprovado]
/// existe sem uma [DecisaoVinculo] explícita do usuário — não há caminho de
/// código que gere isto automaticamente a partir da sugestão do LLM.
class VinculoAprovado extends Equatable {
  final String certificadoId;
  final String criterioId;
  final DecisaoVinculo decisao;
  final String? observacaoUsuario;

  const VinculoAprovado({
    required this.certificadoId,
    required this.criterioId,
    required this.decisao,
    this.observacaoUsuario,
  });

  @override
  List<Object?> get props => [certificadoId, criterioId, decisao, observacaoUsuario];
}
