import 'camera_service.dart';

/// Implementação Web via `getUserMedia`.
///
/// Notas de implementação (corpo real fica fora do escopo do entregável 5 —
/// listado em DECISOES.md como pendência de implementação, esta classe fixa
/// a interface e o contrato de uso):
///
/// - Usa `package:web` (`window.navigator.mediaDevices.getUserMedia`) para
///   obter um `MediaStream`, ligado a um elemento `<video>` registrado via
///   `HtmlElementView`/`platformViewRegistry`.
/// - `captureFrame()` desenha o frame atual do `<video>` em um `<canvas>`
///   oculto e exporta via `canvas.toBlob('image/jpeg', quality)`.
/// - `start()` DEVE ser chamado a partir do `onTap` do botão "Abrir câmera"
///   — nunca de forma automática — porque Safari iOS bloqueia
///   `getUserMedia` fora de um gesto do usuário e exige contexto HTTPS.
/// - Erros de permissão negada, câmera ocupada por outra aba, ou ausência de
///   câmera são todos traduzidos para [CaptureFailure] pelo datasource que
///   consome esta classe (`certificate_capture/data/datasources`).
class CameraServiceWeb implements CameraService {
  bool _started = false;

  @override
  bool get isAvailable => _started;

  @override
  Future<void> start() async {
    // TODO(fase 1, pendente): bind com getUserMedia via package:web.
    // Deve ser chamado só a partir de um gesto do usuário (ver docstring).
    throw UnimplementedError(
      'CameraServiceWeb.start: implementação getUserMedia pendente (ver DECISOES.md)',
    );
  }

  @override
  Future<CapturedFrame> captureFrame() async {
    throw UnimplementedError(
      'CameraServiceWeb.captureFrame: captura via <canvas> pendente (ver DECISOES.md)',
    );
  }

  @override
  Future<void> stop() async {
    _started = false;
  }
}
