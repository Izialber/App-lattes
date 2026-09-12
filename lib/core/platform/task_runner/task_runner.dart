/// Abstração de execução de trabalho pesado fora da thread de UI.
///
/// `dart:isolate` NÃO existe no Flutter Web — por isso esta interface, e não
/// `Isolate` diretamente, é o que todo o resto do app (mesclagem de PDF,
/// compressão de imagem, parsing de XML muito grande) deve chamar.
///
/// - Implementação Web (fase 1): processamento em chunks cedendo o event
///   loop, ou Web Worker para as tarefas mais pesadas (merge de PDF).
///   Ver `task_runner_web.dart`.
/// - Implementação Nativa (fase 2): `Isolate.run`. Ver `task_runner_native.dart`
///   (hoje um stub documentado, sem código Flutter/Isolate real ainda).
abstract class TaskRunner {
  /// Executa [task] fora da UI thread (ou em chunks que cedem o event loop
  /// no web) e retorna o resultado. [estimatedInputBytes] é usado pela
  /// implementação para decidir, ANTES de começar, se o processamento cabe
  /// no teto de memória estimado da plataforma atual — se não couber, deve
  /// lançar [InsufficientDeviceMemoryFailure] (ver core/error/failures.dart)
  /// em vez de tentar e travar a aba.
  Future<R> run<R>({
    required Future<R> Function() task,
    required int estimatedInputBytes,
    String debugLabel = 'task',
  });

  /// Teto de memória estimado (em bytes) que esta implementação considera
  /// seguro para UMA ÚNICA operação pesada de uma vez, na plataforma/
  /// navegador atual. Por decisão do usuário (ver DECISOES.md), este valor
  /// não é mais uma única constante universal:
  /// - iOS: constante fixa e conservadora (`AppConstants.
  ///   estimatedSafariIosSafeHeapBytes`), porque o WebKit não expõe nenhuma
  ///   API de memória do dispositivo.
  /// - Android (Chrome): calculado a partir de `navigator.deviceMemory`
  ///   quando disponível, para aproveitar mais memória em aparelhos com
  ///   mais RAM em vez de aplicar o mesmo teto conservador a todos.
  /// - Desktop / navegadores sem a API: constante fixa mais generosa.
  ///
  /// Usado pelos use cases de `dossie_builder` como o primeiro critério da
  /// estratégia de 3 níveis (mesclar direto / mesclar em partes / degradar
  /// explicitamente) — ver [batchSizeBytesHint] e RISCOS.md, "Memória no
  /// Safari iOS".
  int get estimatedSafeHeapBytes;

  /// Tamanho de lote (em bytes) recomendado quando uma operação NÃO cabe
  /// inteira em [estimatedSafeHeapBytes] de uma vez, mas pode ser dividida
  /// em partes processadas sequencialmente (ex.: mesclar o dossiê em blocos
  /// de N certificados, gerando PDFs intermediários, e só depois mesclar os
  /// intermediários — bem menores — no arquivo final). Por padrão, uma
  /// fração do teto principal, para deixar folga de manipulação temporária
  /// durante o processamento de cada lote.
  int get batchSizeBytesHint => (estimatedSafeHeapBytes * 0.6).round();
}
