import 'package:equatable/equatable.dart';

/// Sugestão do LLM de qual item do currículo Lattes (publicação, curso ou
/// experiência) este certificado comprova. `confianca` é heurística (0..1)
/// vinda do próprio LLM ou calculada por similaridade de texto — NUNCA usada
/// para aprovar automaticamente (requisito de human-in-the-loop, módulo 4).
class VinculoSugerido extends Equatable {
  final String idItemLattesReferenciado;
  final String descricaoItemLattes;
  final double confianca;

  const VinculoSugerido({
    required this.idItemLattesReferenciado,
    required this.descricaoItemLattes,
    required this.confianca,
  });

  @override
  List<Object?> get props => [idItemLattesReferenciado, descricaoItemLattes, confianca];
}
