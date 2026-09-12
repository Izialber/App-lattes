import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/camera/camera_service.dart';
import '../platform/camera/camera_service_native.dart';
import '../platform/camera/camera_service_web.dart';
import '../platform/secure_storage/secure_storage_service.dart';
import '../platform/secure_storage/secure_storage_service_native.dart';
import '../platform/secure_storage/secure_storage_service_web.dart';
import '../platform/task_runner/task_runner.dart';
import '../platform/task_runner/task_runner_native.dart';
import '../platform/task_runner/task_runner_web.dart';

// ---------------------------------------------------------------------------
// Injeção de dependência via Riverpod (Provider simples para singletons de
// infraestrutura). Este é o ÚNICO arquivo do app que decide qual
// implementação de plataforma é usada (kIsWeb) — nenhuma feature faz essa
// checagem por conta própria. Trocar para a fase 2 nativa é editar só os
// três providers `*Provider` abaixo, nunca os providers de feature.
// ---------------------------------------------------------------------------

/// Heurística simples de detecção de Safari iOS via user agent, usada só
/// para calibrar o teto de memória do [TaskRunner]. Não é usada para
/// nenhuma decisão de segurança — apenas UX (evitar tentar e travar).
bool _isLikelySafariIos() {
  if (!kIsWeb) return false;
  // PENDENTE: ler `window.navigator.userAgent` via package:web e checar
  // "iPhone|iPad|iPod" + "Safari" sem "CriOS"/"FxiOS" (que são Chrome/Firefox
  // rodando sobre WebKit, mas com o mesmo teto de memória do Safari real —
  // por isso, na prática, basta checar iOS, o motor é sempre WebKit lá).
  return false;
}

final taskRunnerProvider = Provider<TaskRunner>((ref) {
  return kIsWeb
      ? TaskRunnerWeb(isLikelySafariIos: _isLikelySafariIos())
      : TaskRunnerNative();
});

final cameraServiceProvider = Provider<CameraService>((ref) {
  return kIsWeb ? CameraServiceWeb() : CameraServiceNative();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return kIsWeb ? SecureStorageServiceWeb() : SecureStorageServiceNative();
});

// Os providers de repositório/datasource de cada feature (que dependem dos
// providers acima) ficam em
// `lib/features/<feature>/presentation/providers/<feature>_providers.dart`,
// para manter a regra feature-first — este arquivo central só resolve as
// abstrações de plataforma, que são verdadeiramente transversais.
