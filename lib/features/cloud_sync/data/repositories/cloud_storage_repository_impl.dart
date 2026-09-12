import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/upload_task.dart';
import '../../domain/repositories/cloud_storage_repository.dart';
import '../datasources/google_drive_datasource.dart';
import '../datasources/onedrive_graph_datasource.dart';
import '../local/upload_queue_local_store.dart';

/// Roteia para [GoogleDriveDatasource] ou [OneDriveGraphDatasource] conforme
/// `UploadTask.provider`. PENDENTE (fora do escopo do entregável 5):
/// implementação real, incluindo o mapeamento de exceções HTTP para
/// [CloudStorageFailure] com `isTransient` correto (5xx/timeout = true,
/// 4xx de permissão = false).
class CloudStorageRepositoryImpl implements CloudStorageRepository {
  final GoogleDriveDatasource _googleDrive;
  final OneDriveGraphDatasource _oneDrive;
  final UploadQueueLocalStore _localStore;

  const CloudStorageRepositoryImpl(this._googleDrive, this._oneDrive, this._localStore);

  @override
  Future<Either<Failure, String>> garantirPastaDedicada(UploadTask task) {
    throw UnimplementedError('CloudStorageRepositoryImpl.garantirPastaDedicada: pendente');
  }

  @override
  Future<Either<Failure, UploadTask>> enviarArquivo(UploadTask task) {
    throw UnimplementedError('CloudStorageRepositoryImpl.enviarArquivo: pendente');
  }

  @override
  Future<Either<Failure, String>> obterIdArquivoPorNome(String nomeArquivo) {
    throw UnimplementedError('CloudStorageRepositoryImpl.obterIdArquivoPorNome: pendente');
  }
}
