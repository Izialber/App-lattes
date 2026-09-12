import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../entities/edital.dart';
import '../repositories/dossie_repository.dart';

/// Resultado é sempre consumido pela tela de checklist (human-in-the-loop);
/// nenhum caminho de código leva de [SugerirVinculos] direto para
/// [CompilarDossie] sem passar por [RegistrarDecisaoVinculo] para cada item.
class SugerirVinculos {
  final DossieRepository _repository;

  const SugerirVinculos(this._repository);

  Future<Either<Failure, Edital>> call({
    required Edital edital,
    required List<CertificadoCapturado> certificadosSincronizados,
  }) {
    return _repository.sugerirVinculos(
      edital: edital,
      certificadosSincronizados: certificadosSincronizados,
    );
  }
}
