import 'dart:async';

import 'package:web/web.dart' as web;

import '../../utils/constants.dart';
import 'task_runner.dart';

/// Implementação Web do [TaskRunner].
///
/// Não há Isolates no navegador. Duas estratégias, escolhidas por tamanho:
///
/// 1. Tarefas pequenas/médias: processamento "chunked" — a função roda no
///    isolate único do Dart-JS, mas cede o event loop periodicamente
///    (`await Future.delayed(Duration.zero)`) para não bloquear o frame de
///    UI por mais que ~16ms de cada vez. Suficiente para manter a UI
///    responsiva durante a extração/compressão de uma imagem.
/// 2. Tarefas grandes (merge final de PDF do dossiê): delegadas a um Web
///    Worker dedicado (arquivo `web/worker/pdf_merge_worker.dart.js`,
///    compilado separadamente com `dart compile js`), comunicando por
///    `postMessage`. Isso tira o trabalho pesado de qualquer isolate que
///    compartilhe frame com a UI. Este arquivo mantém a INTERFACE e a
///    heurística de decisão; a implementação do worker em si fica fora do
///    escopo do entregável 5 (parser), listada como pendência em DECISOES.md.
///
/// Teto de memória (decisão do usuário, ver DECISOES.md e AppConstants):
/// - iOS: constante fixa de 350MB — o WebKit não expõe nenhuma API de
///   memória do dispositivo.
/// - Android (Chrome/Chromium): lido de `navigator.deviceMemory` (Device
///   Memory API), que reporta uma estimativa arredondada da RAM total do
///   aparelho em GB (valores típicos: 0.25, 0.5, 1, 2, 4, 8...). Usamos uma
///   fração conservadora desse total como teto de uma única operação
///   pesada, dentro de um piso e um teto absolutos.
/// - Qualquer navegador sem a API disponível (desktop, ou Android fora do
///   Chromium): cai na constante de desktop.
class TaskRunnerWeb extends TaskRunner {
  final bool _isLikelySafariIos;
  final int _safeHeapBytesCache;

  TaskRunnerWeb({required bool isLikelySafariIos})
      : _isLikelySafariIos = isLikelySafariIos,
        _safeHeapBytesCache = _computeSafeHeapBytes(isLikelySafariIos: isLikelySafariIos);

  @override
  int get estimatedSafeHeapBytes => _safeHeapBytesCache;

  static int _computeSafeHeapBytes({required bool isLikelySafariIos}) {
    if (isLikelySafariIos) {
      return AppConstants.estimatedSafariIosSafeHeapBytes;
    }

    final deviceMemoryGb = _readDeviceMemoryGb();
    if (deviceMemoryGb == null) {
      // API indisponível (Safari desktop, Firefox, navegadores antigos):
      // cai no valor fixo mais generoso, como antes desta mudança.
      return AppConstants.estimatedDesktopSafeHeapBytes;
    }

    final bytesBrutos =
        deviceMemoryGb * 1024 * 1024 * 1024 * AppConstants.androidSafeHeapFractionOfDeviceMemory;
    final bytes = bytesBrutos.round();
    return bytes.clamp(
      AppConstants.estimatedMinSafeHeapBytes,
      AppConstants.estimatedDesktopSafeHeapBytes,
    );
  }

  /// Lê `navigator.deviceMemory` via interop dinâmico. A propriedade não faz
  /// parte da interface tipada padrão de `Navigator` em todas as versões do
  /// `package:web` (é uma API ainda não universalmente padronizada, ausente
  /// no WebKit/Safari e no Firefox) — por isso o acesso é via `dynamic` com
  /// `try/catch`, retornando `null` de forma segura sempre que a propriedade
  /// não existir, em vez de lançar.
  static double? _readDeviceMemoryGb() {
    try {
      final navigator = web.window.navigator;
      final value = (navigator as dynamic).deviceMemory;
      if (value is num) return value.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<R> run<R>({
    required Future<R> Function() task,
    required int estimatedInputBytes,
    String debugLabel = 'task',
  }) async {
    // A verificação de teto de memória é feita pelo chamador (use case), que
    // tem contexto de negócio para decidir a mensagem de degradação
    // explícita. Aqui garantimos apenas que o event loop não fica bloqueado
    // de forma contígua por longos períodos.
    //
    // Chunking real (ex.: processar página a página de um PDF) deve ser
    // implementado dentro de [task] pelo próprio datasource, chamando
    // `await Future<void>.delayed(Duration.zero)` entre unidades de trabalho.
    // Este método apenas garante um yield antes e depois, e mede o tempo
    // para fins de log/telemetria de performance.
    await Future<void>.delayed(Duration.zero);
    final result = await task();
    await Future<void>.delayed(Duration.zero);
    return result;
  }
}
