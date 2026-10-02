import 'package:equatable/equatable.dart';

/// Sugestão de qual critério do edital um comprovante já sincronizado
/// comprova — NUNCA aprovada automaticamente (vira [VinculoAprovado] só
/// depois de uma decisão humana explícita no checklist, ver
/// `DossieRepository.registrarDecisaoVinculo`).
///
/// Não confundir com `VinculoSugerido` (em `certificate_capture`, módulo
/// antigo desconectado): aquele é a ligação certificado <-> item do
/// currículo Lattes (nunca implementada — ver DECISOES.md), enquanto este é
/// comprovante <-> critério do EDITAL, que é o que o módulo 4 de fato usa.
class VinculoSugeridoDossie extends Equatable {
  final String comprovanteId;
  final String criterioId;
  final double confianca;

  const VinculoSugeridoDossie({
    required this.comprovanteId,
    required this.criterioId,
    required this.confianca,
  });

  @override
  List<Object?> get props => [comprovanteId, criterioId, confianca];
}
