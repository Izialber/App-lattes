import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/platform/heic/heic_converter.dart';
import '../../../../core/platform/task_runner/task_runner.dart';
import '../../domain/entities/certificado_capturado.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../datasources/llm_extraction_datasource.dart';
import '../local/certificate_local_store.dart';

const _uuid = Uuid();

/// Implementação real do módulo 2.
///
/// [CameraCaptureDatasource] (câmera ao vivo) não é usado diretamente aqui:
/// tanto a câmera quanto o upload/drag&drop convergem para bytes+mimeType
/// ANTES de chegar em [registrarCaptura] — a unificação das duas fontes
/// acontece na presentation layer (ver docstring de `CapturarCertificado`),
/// então o repositório não precisa saber de onde os bytes vieram.
class CertificateRepositoryImpl implements CertificateRepository {
  final LlmExtractionDatasource _llmDatasource;
  final CertificateLocalStore _localStore;
  final HeicConverter _heicConverter;
  final TaskRunner _taskRunner;

  const CertificateRepositoryImpl(
    this._llmDatasource,
    this._localStore,
    this._heicConverter,
    this._taskRunner,
  );

  @override
  Future<Either<Failure, CertificadoCapturado>> registrarCaptura({
    required List<int> imagemBytes,
    required String mimeType,
  }) async {
    final id = _uuid.v4();

    try {
      await _localStore.salvarImagem(id, imagemBytes);
    } catch (e) {
      return Left(LocalStorageFailure('Não foi possível salvar a imagem localmente: $e'));
    }

    final certificado = CertificadoCapturado(
      id: id,
      caminhoImagemLocal: id,
      mimeType: mimeType,
      status: StatusCertificado.capturado,
    );

    try {
      await _localStore.salvar(certificado);
    } catch (e) {
      return Left(LocalStorageFailure('Não foi possível salvar o certificado localmente: $e'));
    }

    return Right(certificado);
  }

  @override
  Future<Either<Failure, CertificadoCapturado>> normalizarFormatoImagem(
    String certificadoId,
  ) async {
    final certificado = _localStore.buscar(certificadoId);
    if (certificado == null) {
      return Left(LocalStorageFailure('Certificado $certificadoId não encontrado.'));
    }

    final bytes = _localStore.lerImagem(certificadoId);
    if (bytes == null) {
      return Left(LocalStorageFailure('Imagem do certificado $certificadoId não encontrada.'));
    }

    if (!_heicConverter.pareceHeic(bytes)) {
      return Right(certificado); // já não é HEIC: idempotente, sem mudança
    }

    try {
      final convertida = await _taskRunner.run(
        task: () => _heicConverter.converterParaJpeg(bytes),
        estimatedInputBytes: bytes.length,
        debugLabel: 'converter-heic-$certificadoId',
      );
      await _localStore.salvarImagem(certificadoId, convertida.bytes);
      final atualizado = certificado.copyWith(mimeType: convertida.mimeType);
      await _localStore.salvar(atualizado);
      return Right(atualizado);
    } on HeicConversionUnsupportedException catch (e) {
      await _localStore.salvar(
        certificado.copyWith(status: StatusCertificado.falhaExtracao, mensagemErro: e.message),
      );
      return Left(CaptureFailure(e.message));
    } catch (e) {
      return Left(CaptureFailure('Falha ao converter HEIC: $e'));
    }
  }

  @override
  Future<Either<Failure, CertificadoCapturado>> extrairDados(String certificadoId) async {
    final certificado = _localStore.buscar(certificadoId);
    if (certificado == null) {
      return Left(LocalStorageFailure('Certificado $certificadoId não encontrado.'));
    }

    final bytesOriginais = _localStore.lerImagem(certificadoId);
    if (bytesOriginais == null) {
      return Left(LocalStorageFailure('Imagem do certificado $certificadoId não encontrada.'));
    }

    await _localStore.salvar(certificado.copyWith(status: StatusCertificado.extraindoDados));

    ({List<int> bytes, String mimeType}) paraEnvio;
    try {
      paraEnvio = await _taskRunner.run(
        task: () async => _comprimir(bytesOriginais, certificado.mimeType),
        estimatedInputBytes: bytesOriginais.length,
        debugLabel: 'comprimir-certificado-$certificadoId',
      );
    } catch (_) {
      // Compressão é só otimização de payload antes do envio ao LLM — se
      // falhar (ex.: formato que o decoder puro Dart não reconhece), segue
      // com a imagem original em vez de bloquear a extração inteira.
      paraEnvio = (bytes: bytesOriginais, mimeType: certificado.mimeType);
    }

    final resultado = await _llmDatasource.extrair(
      imagemBytes: paraEnvio.bytes,
      mimeType: paraEnvio.mimeType,
    );

    return resultado.match(
      (falha) async {
        await _localStore.salvar(
          certificado.copyWith(status: StatusCertificado.falhaExtracao, mensagemErro: falha.message),
        );
        return Left(falha);
      },
      (json) async {
        final atualizado = certificado.copyWith(
          status: StatusCertificado.pendenteRevisao,
          tituloExtraido: json['titulo'] as String?,
          instituicaoExtraida: json['instituicao'] as String?,
          cargaHorariaExtraidaHoras: (json['cargaHorariaHoras'] as num?)?.round(),
          dataExtraida: _parseDataOpcional(json['data']),
        );
        await _localStore.salvar(atualizado);
        return Right(atualizado);
      },
    );
  }

  @override
  Future<List<CertificadoCapturado>> listarTodos() async => _localStore.listarTodos();

  @override
  Future<Either<Failure, Unit>> atualizarStatus(
    String certificadoId,
    StatusCertificado status,
  ) async {
    final certificado = _localStore.buscar(certificadoId);
    if (certificado == null) {
      return Left(LocalStorageFailure('Certificado $certificadoId não encontrado.'));
    }
    await _localStore.salvar(certificado.copyWith(status: status));
    return const Right(unit);
  }

  /// Reduz resolução/qualidade antes do envio ao LLM (ver ARQUITETURA.md,
  /// fluxo do módulo 2) — fotos de celular modernas passam facilmente de
  /// 4000px de largura, muito além do que qualquer modelo multimodal
  /// precisa para ler texto de um certificado, e o excesso só aumenta
  /// tempo de upload e custo de tokens. PDF não passa por `package:image`
  /// (não é um formato raster — o decoder retornaria null de qualquer
  /// forma) e vai para o LLM como está: a Gemini API lê PDF nativamente via
  /// `inline_data`, sem precisar convertê-lo para imagem antes.
  ({List<int> bytes, String mimeType}) _comprimir(
    List<int> bytes,
    String mimeTypeOriginal, {
    int larguraMaxima = 1600,
  }) {
    if (mimeTypeOriginal == 'application/pdf') {
      return (bytes: bytes, mimeType: mimeTypeOriginal);
    }

    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return (bytes: bytes, mimeType: mimeTypeOriginal);

    final redimensionada =
        decoded.width > larguraMaxima ? img.copyResize(decoded, width: larguraMaxima) : decoded;
    return (bytes: img.encodeJpg(redimensionada, quality: 85), mimeType: 'image/jpeg');
  }

  DateTime? _parseDataOpcional(dynamic valor) {
    if (valor is! String || valor.isEmpty) return null;
    return DateTime.tryParse(valor);
  }
}
