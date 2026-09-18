import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/edital.dart';
import '../repositories/dossie_repository.dart';

class ExtrairCriteriosEdital {
  final DossieRepository _repository;

  const ExtrairCriteriosEdital(this._repository);

  Future<Either<Failure, Edital>> call({
    required String editalId,
    required String nomeArquivoOriginal,
    required List<int> editalPdfBytes,
  }) {
    return _repository.extrairCriterios(
      editalId: editalId,
      nomeArquivoOriginal: nomeArquivoOriginal,
      editalPdfBytes: editalPdfBytes,
    );
  }
}
