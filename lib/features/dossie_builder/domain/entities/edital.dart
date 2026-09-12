import 'package:equatable/equatable.dart';

import 'criterio_pontuacao.dart';

/// Edital do concurso, fornecido pelo usuário como PDF. `criterios` é
/// preenchido pelo use case `ExtrairCriteriosEdital` e SEMPRE tratado como
/// sugestão sujeita a erro de interpretação (editais não têm padronização —
/// ver contexto do projeto); por isso a UI de checklist (human-in-the-loop)
/// também permite editar/remover critérios extraídos, não só vínculos.
class Edital extends Equatable {
  final String id;
  final String nomeArquivoOriginal;
  final String? orgaoOuBanca;
  final List<CriterioPontuacao> criterios;

  const Edital({
    required this.id,
    required this.nomeArquivoOriginal,
    this.orgaoOuBanca,
    this.criterios = const [],
  });

  @override
  List<Object?> get props => [id, nomeArquivoOriginal, orgaoOuBanca, criterios];
}
