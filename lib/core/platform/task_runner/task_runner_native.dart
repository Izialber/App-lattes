import 'task_runner.dart';

/// Stub documentado da implementação nativa (fase 2). NÃO importa
/// `dart:isolate` ainda porque este pacote hoje compila apenas para web
/// (ver pubspec.yaml) — importar `dart:isolate` aqui quebraria o build web
/// caso este arquivo seja acidentalmente incluído fora de uma condicional
/// de import. Quando a fase 2 começar, este arquivo passa a:
///
/// 1. Importar `dart:isolate`.
/// 2. Implementar `run` com `Isolate.run(task)` (Dart 2.19+), que já cuida
///    de spawnar, executar e encerrar o isolate, retornando o resultado
///    via `SendPort` internamente.
/// 3. Calcular `estimatedSafeHeapBytes` a partir de memória real do
///    dispositivo quando disponível (ex.: via `device_info_plus`), com
///    fallback para as constantes atuais.
///
/// A troca de `TaskRunnerWeb` por `TaskRunnerNative` acontece SOMENTE em
/// `core/di/injection.dart`, via `kIsWeb` — nenhum código de feature muda.
class TaskRunnerNative extends TaskRunner {
  @override
  int get estimatedSafeHeapBytes =>
      throw UnimplementedError('TaskRunnerNative: implementar na fase 2 com Isolate.run');

  @override
  Future<R> run<R>({
    required Future<R> Function() task,
    required int estimatedInputBytes,
    String debugLabel = 'task',
  }) {
    throw UnimplementedError('TaskRunnerNative: implementar na fase 2 com Isolate.run');
  }
}
