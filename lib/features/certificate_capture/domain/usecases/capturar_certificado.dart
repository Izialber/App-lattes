import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/certificado_capturado.dart';
import '../repositories/certificate_repository.dart';

/// Recebe bytes de imagem já obtidos (seja de `CameraService.captureFrame`
/// no mobile, seja de `file_picker`/drag&drop no desktop — a unificação das
/// duas fontes acontece na camada de apresentação, que converte ambas para
/// bytes antes de chamar este use case, conforme exigido pelo módulo 2).
class CapturarCertificado {
  final CertificateRepository _repository;

  const CapturarCertificado(this._repository);

  Future<Either<Failure, CertificadoCapturado>> call({
    required List<int> imagemBytes,
    required String mimeType,
  }) {
    return _repository.registrarCaptura(imagemBytes: imagemBytes, mimeType: mimeType);
  }
}
