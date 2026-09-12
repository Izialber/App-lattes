import '../../domain/entities/upload_task.dart';

/// Persistência da fila offline-first em Hive (IndexedDB no web). Todo
/// método deve gravar de forma síncrona com a mudança de estado do use case
/// correspondente — a fila nunca deve existir só em memória, senão um
/// reload de aba (comum no Safari iOS sob pressão de memória) perde o
/// progresso do usuário, o que é uma das falhas críticas listadas no
/// contexto do projeto.
///
/// PENDENTE (fora do escopo do entregável 5): abrir a Hive box
/// `upload_queue` em `core/di/injection.dart` na inicialização do app,
/// antes de qualquer tela ser exibida (para poder restaurar estado ANTES do
/// primeiro frame).
class UploadQueueLocalStore {
  Future<void> salvar(UploadTask task) {
    throw UnimplementedError('UploadQueueLocalStore.salvar: pendente');
  }

  Future<List<UploadTask>> listarTodas() {
    throw UnimplementedError('UploadQueueLocalStore.listarTodas: pendente');
  }

  Future<void> remover(String taskId) {
    throw UnimplementedError('UploadQueueLocalStore.remover: pendente');
  }
}
