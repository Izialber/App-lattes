import 'package:equatable/equatable.dart';

enum DecisaoVinculo { aprovado, alterado, excluido }

/// Resultado da revisão humana obrigatória sobre uma sugestão de vínculo
/// entre um comprovante e um critério do edital. Nenhum [VinculoAprovado]
/// existe sem uma [DecisaoVinculo] explícita do usuário — não há caminho de
/// código que gere isto automaticamente a partir da sugestão heurística.
class VinculoAprovado extends Equatable {
  final String comprovanteId;
  final String criterioId;
  final DecisaoVinculo decisao;
  final String? observacaoUsuario;

  const VinculoAprovado({
    required this.comprovanteId,
    required this.criterioId,
    required this.decisao,
    this.observacaoUsuario,
  });

  @override
  List<Object?> get props => [comprovanteId, criterioId, decisao, observacaoUsuario];
}
