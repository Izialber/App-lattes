import '../../../../core/error/failures.dart';
import '../entities/upload_task.dart';
import 'enviar_pdf_para_cloud.dart';

/// Percorre a fila persistida (todas as [UploadTask] com status pendente ou
/// falha temporária) e tenta reenviar, com backoff exponencial aplicado pela
/// implementação de `data/` via package:retry. Disparado: (1) ao detectar
/// retorno de conectividade via `ConnectivityGate`, (2) periodicamente
/// enquanto a aba está aberta, (3) ao reabrir o app após reload.
///
/// A classificação "vale a pena tentar de novo?" usa
/// `CloudStorageFailure.isTransient` (ver core/error/failures.dart): falhas
/// transitórias (rede, 5xx, quota momentânea) voltam para
/// [UploadStatus.falhaTemporaria] e permanecem na fila; falhas não
/// transitórias (ex.: 403 de permissão) viram [UploadStatus.falhaPermanente]
/// e exigem intervenção do usuário (reautenticar, escolher outra pasta).
class ProcessarFilaOffline {
  final EnviarPdfParaCloud _enviarPdfParaCloud;

  const ProcessarFilaOffline(this._enviarPdfParaCloud);

  Future<List<UploadTask>> call(List<UploadTask> filaPendente) async {
    final resultados = <UploadTask>[];
    for (final task in filaPendente) {
      final resultado = await _enviarPdfParaCloud(task);
      resultados.add(
        resultado.match(
          (falha) {
            final transitoria = falha is! CloudStorageFailure || falha.isTransient;
            return task.copyWith(
              status: transitoria ? UploadStatus.falhaTemporaria : UploadStatus.falhaPermanente,
              tentativas: task.tentativas + 1,
              mensagemErro: falha.message,
            );
          },
          (sucesso) => sucesso,
        ),
      );
    }
    return resultados;
  }
}
