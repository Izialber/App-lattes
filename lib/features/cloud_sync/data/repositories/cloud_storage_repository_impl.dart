import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;

import '../../../../core/error/failures.dart';
import '../../../../core/utils/constants.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/upload_task.dart';
import '../../domain/repositories/cloud_storage_repository.dart';
import '../datasources/google_drive_datasource.dart';
import '../datasources/onedrive_graph_datasource.dart';
import '../local/upload_queue_local_store.dart';

/// Roteia para [GoogleDriveDatasource] ou [OneDriveGraphDatasource] conforme
/// `UploadTask.provider`. OneDrive continua fora de escopo (decisão do
/// usuário: Google primeiro — ver DECISOES.md) — `_oneDrive` fica
/// injetado, mas todo método retorna [CloudStorageFailure] explícita para
/// esse provedor em vez de deixar o stub lançar `UnimplementedError`.
class CloudStorageRepositoryImpl implements CloudStorageRepository {
  final GoogleDriveDatasource _googleDrive;
  // ignore: unused_field
  final OneDriveGraphDatasource _oneDrive;
  final UploadQueueLocalStore _localStore;

  const CloudStorageRepositoryImpl(this._googleDrive, this._oneDrive, this._localStore);

  static const _falhaOneDrive = CloudStorageFailure(
    'OneDrive ainda não é suportado neste app — use o Google Drive.',
    isTransient: false,
  );

  @override
  Future<Either<Failure, String>> garantirPastaDedicada(UploadTask task) async {
    if (task.provider == CloudProvider.oneDrive) return const Left(_falhaOneDrive);

    try {
      return Right(await _googleDrive.criarPastaSeNaoExistir(AppConstants.cloudFolderName));
    } on DioException catch (e) {
      return Left(_falhaDeDioException(e));
    } catch (e) {
      return Left(CloudStorageFailure('Falha ao preparar a pasta no Drive: $e'));
    }
  }

  @override
  Future<Either<Failure, UploadTask>> enviarArquivo(UploadTask task) async {
    if (task.provider == CloudProvider.oneDrive) return const Left(_falhaOneDrive);

    final bytes = _localStore.lerPdf(task.caminhoPdfLocal);
    if (bytes == null) {
      return const Left(
        CloudStorageFailure('PDF do certificado não encontrado localmente.', isTransient: false),
      );
    }

    try {
      final pastaId = await _googleDrive.criarPastaSeNaoExistir(AppConstants.cloudFolderName);

      // Retoma a sessão já aberta (reload de aba no meio do upload) em vez
      // de começar de novo — requisito do contrato de `enviarArquivo` (ver
      // domain/repositories/cloud_storage_repository.dart).
      final sessionUrl = task.uploadSessionUrl ??
          await _googleDrive.iniciarSessaoUploadResumivel(
            pastaId: pastaId,
            nomeArquivo: task.nomeArquivoDeterministico,
            tamanhoBytes: bytes.length,
          );

      final restante = bytes.sublist(task.bytesEnviados);
      final resultadoEnvio = await _googleDrive.enviarChunk(
        sessionUrl: sessionUrl,
        bytes: restante,
        offset: task.bytesEnviados,
      );

      final concluido = resultadoEnvio.bytesConfirmados >= bytes.length;
      final atualizada = task.copyWith(
        status: concluido ? UploadStatus.concluido : UploadStatus.falhaTemporaria,
        uploadSessionUrl: sessionUrl,
        bytesEnviados: resultadoEnvio.bytesConfirmados,
        idArquivoCloud: resultadoEnvio.idArquivo,
      );
      await _localStore.salvar(atualizada);

      if (!concluido) {
        return const Left(
          CloudStorageFailure('Upload não concluiu numa única tentativa — tente novamente.'),
        );
      }
      return Right(atualizada);
    } on DioException catch (e) {
      final falha = _falhaDeDioException(e);
      await _localStore.salvar(
        task.copyWith(
          status: falha.isTransient ? UploadStatus.falhaTemporaria : UploadStatus.falhaPermanente,
          mensagemErro: falha.message,
        ),
      );
      return Left(falha);
    } catch (e) {
      return Left(CloudStorageFailure('Falha ao enviar o arquivo para o Drive: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> obterIdArquivoPorNome(String nomeArquivo) async {
    try {
      final id = await _googleDrive.buscarArquivoPorNome(nomeArquivo);
      if (id == null) {
        return const Left(
          CloudStorageFailure('Nenhum arquivo com esse nome no Drive.', isTransient: false),
        );
      }
      return Right(id);
    } on DioException catch (e) {
      return Left(_falhaDeDioException(e));
    } catch (e) {
      return Left(CloudStorageFailure('Falha ao buscar o arquivo no Drive: $e'));
    }
  }

  /// 5xx, 429 (quota) e timeout são transitórios (a fila deve tentar de
  /// novo automaticamente); 4xx de permissão/validação não são — exigem
  /// intervenção do usuário (reautenticar, revisar o arquivo).
  /// `type: cancel` é o sinal específico que o interceptor de
  /// `GoogleDriveDatasource` usa para "sessão inválida" (sem token válido
  /// para renovar) — nunca transitório: tentar de novo sem o usuário
  /// reautenticar só repetiria a mesma falha.
  CloudStorageFailure _falhaDeDioException(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return CloudStorageFailure(e.message ?? 'Sessão do Google Drive inválida.', isTransient: false);
    }

    final status = e.response?.statusCode;
    final isTransient = status == null || status >= 500 || status == 429;
    final mensagemApi = _mensagemDoCorpoDeErro(e.response?.data) ?? e.message;
    return CloudStorageFailure(
      'Falha ao comunicar com o Google Drive: $mensagemApi',
      isTransient: isTransient,
    );
  }

  String? _mensagemDoCorpoDeErro(dynamic corpo) {
    try {
      final mensagem = (corpo as Map)['error']['message'];
      return mensagem is String && mensagem.isNotEmpty ? mensagem : null;
    } catch (_) {
      return null;
    }
  }
}
