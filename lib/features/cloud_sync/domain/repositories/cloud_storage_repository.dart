import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/upload_task.dart';

abstract class CloudStorageRepository {
  /// Garante que a pasta dedicada (`AppConstants.cloudFolderName`) existe no
  /// Drive/OneDrive do usuário, criando-a se necessário. Idempotente.
  Future<Either<Failure, String>> garantirPastaDedicada(UploadTask task);

  /// Envia o PDF via upload resumível, retomando de `bytesEnviados` se a
  /// tarefa já tinha uma sessão de upload aberta (sobrevive a queda de 4G).
  Future<Either<Failure, UploadTask>> enviarArquivo(UploadTask task);

  Future<Either<Failure, String>> obterIdArquivoPorNome(String nomeArquivo);
}
