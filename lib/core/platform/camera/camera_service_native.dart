import 'camera_service.dart';

/// Stub documentado da fase 2: usa o plugin `camera` (já listado no
/// pubspec, marcado "[só nativo, fase 2]"), com `CameraController` do
/// pacote oficial. Pós-processamento do frame (compressão) passa pelo
/// `TaskRunnerNative` (Isolate), nunca na UI thread.
class CameraServiceNative implements CameraService {
  @override
  bool get isAvailable => throw UnimplementedError('fase 2: plugin camera');

  @override
  Future<void> start() => throw UnimplementedError('fase 2: plugin camera');

  @override
  Future<CapturedFrame> captureFrame() => throw UnimplementedError('fase 2: plugin camera');

  @override
  Future<void> stop() => throw UnimplementedError('fase 2: plugin camera');
}
