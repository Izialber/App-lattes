import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/certificado_capturado.dart';
import '../repositories/certificate_repository.dart';

/// Uploads vindos de iOS podem chegar como HEIC mesmo com extensão/mimetype
/// genérico (ver RISCOS.md). Este use case garante que, antes de qualquer
/// envio ao LLM ou conversão para PDF, a imagem esteja em JPEG.
class ConverterHeicParaJpeg {
  final CertificateRepository _repository;

  const ConverterHeicParaJpeg(this._repository);

  Future<Either<Failure, CertificadoCapturado>> call(String certificadoId) {
    return _repository.normalizarFormatoImagem(certificadoId);
  }
}
