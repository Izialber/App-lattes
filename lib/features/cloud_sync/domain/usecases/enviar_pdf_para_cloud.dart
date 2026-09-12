import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/upload_task.dart';
import '../repositories/cloud_storage_repository.dart';
import 'renovar_token.dart';

class EnviarPdfParaCloud {
  final CloudStorageRepository _storageRepository;
  final RenovarToken _renovarToken;

  const EnviarPdfParaCloud(this._storageRepository, this._renovarToken);

  Future<Either<Failure, UploadTask>> call(UploadTask task) async {
    final tokenOuFalha = await _renovarToken(task.provider);
    return tokenOuFalha.match(
      (falha) => Future.value(Either<Failure, UploadTask>.left(falha)),
      (_) => _storageRepository.enviarArquivo(task),
    );
  }
}
