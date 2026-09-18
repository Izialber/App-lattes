import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/dossie.dart';
import '../entities/vinculo_aprovado.dart';
import '../repositories/dossie_repository.dart';

/// Persiste a decisão humana (aprovar/alterar/excluir) sobre um vínculo
/// sugerido — chamado a cada interação no checklist, não só ao final, para
/// que o progresso da revisão sobreviva a reload de aba. Referenciado desde
/// a docstring original de [SugerirVinculos], mas nunca tinha sido criado
/// como classe de use case até esta rodada.
class RegistrarDecisaoVinculo {
  final DossieRepository _repository;

  const RegistrarDecisaoVinculo(this._repository);

  Future<Either<Failure, Dossie>> call({
    required String dossieId,
    required VinculoAprovado decisao,
  }) {
    return _repository.registrarDecisaoVinculo(dossieId: dossieId, decisao: decisao);
  }
}
