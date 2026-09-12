import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../../domain/entities/certificado_capturado.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/camera_capture_datasource.dart';
import '../datasources/llm_extraction_datasource.dart';

/// Implementação real do módulo 2. PENDENTE (fora do escopo do entregável 5):
/// - registrarCaptura: gera id (uuid), persiste bytes em IndexedDB via Hive,
///   cria CertificadoCapturado com status inicial.
/// - extrairDados: chama LlmExtractionDatasource, mapeia JSON -> entidade,
///   captura qualquer exceção de rede/parsing como LlmFailure.
/// - normalizarFormatoImagem: detecta HEIC pelos magic bytes (não confia no
///   mimetype do navegador, ver RISCOS.md) e converte via HeicConverter.
class CertificateRepositoryImpl implements CertificateRepository {
  final CameraCaptureDatasource _cameraDatasource;
  final LlmExtractionDatasource _llmDatasource;

  const CertificateRepositoryImpl(this._cameraDatasource, this._llmDatasource);

  @override
  Future<Either<Failure, CertificadoCapturado>> registrarCaptura({
    required List<int> imagemBytes,
    required String mimeType,
  }) {
    throw UnimplementedError('CertificateRepositoryImpl.registrarCaptura: pendente');
  }

  @override
  Future<Either<Failure, CertificadoCapturado>> extrairDados(String certificadoId) {
    throw UnimplementedError('CertificateRepositoryImpl.extrairDados: pendente');
  }

  @override
  Future<Either<Failure, CertificadoCapturado>> normalizarFormatoImagem(String certificadoId) {
    throw UnimplementedError('CertificateRepositoryImpl.normalizarFormatoImagem: pendente');
  }

  @override
  Future<List<CertificadoCapturado>> listarTodos() {
    throw UnimplementedError('CertificateRepositoryImpl.listarTodos: pendente');
  }

  @override
  Future<Either<Failure, Unit>> atualizarStatus(String certificadoId, StatusCertificado status) {
    throw UnimplementedError('CertificateRepositoryImpl.atualizarStatus: pendente');
  }
}
