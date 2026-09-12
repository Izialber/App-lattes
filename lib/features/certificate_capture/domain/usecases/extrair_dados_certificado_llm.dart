import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/certificado_capturado.dart';
import '../repositories/certificate_repository.dart';

/// Dispara a extração via LLM. Deve ser chamado somente após
/// [ConverterHeicParaJpeg] garantir um formato suportado pela API de LLM.
class ExtrairDadosCertificadoLlm {
  final CertificateRepository _repository;

  const ExtrairDadosCertificadoLlm(this._repository);

  Future<Either<Failure, CertificadoCapturado>> call(String certificadoId) {
    return _repository.extrairDados(certificadoId);
  }
}
