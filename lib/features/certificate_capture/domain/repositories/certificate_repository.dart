import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/certificado_capturado.dart';

abstract class CertificateRepository {
  /// Registra um certificado recém-capturado (câmera ou upload) e retorna a
  /// entidade com status inicial [StatusCertificado.capturado].
  Future<Either<Failure, CertificadoCapturado>> registrarCaptura({
    required List<int> imagemBytes,
    required String mimeType,
  });

  /// Envia a imagem ao LLM configurado (BYOK) e retorna o certificado
  /// atualizado com os dados extraídos e a sugestão de vínculo.
  Future<Either<Failure, CertificadoCapturado>> extrairDados(String certificadoId);

  /// Converte HEIC para JPEG quando necessário. Idempotente: se a imagem já
  /// não for HEIC, retorna o certificado sem alteração.
  Future<Either<Failure, CertificadoCapturado>> normalizarFormatoImagem(String certificadoId);

  Future<List<CertificadoCapturado>> listarTodos();

  Future<Either<Failure, Unit>> atualizarStatus(
    String certificadoId,
    StatusCertificado status, {
    String? mensagemErro,
  });
}
