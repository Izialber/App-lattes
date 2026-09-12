/// Frame de imagem capturado, já como bytes crus (JPEG/PNG). O domínio nunca
/// vê `dart:html`/`package:web`/plugin `camera` — apenas estes bytes.
class CapturedFrame {
  final List<int> bytes;
  final String mimeType; // 'image/jpeg' | 'image/png' | 'image/heic'
  final DateTime capturedAt;

  const CapturedFrame({
    required this.bytes,
    required this.mimeType,
    required this.capturedAt,
  });
}

/// Abstração de captura de câmera. Requisito de plataforma: no navegador,
/// `getUserMedia` exige HTTPS e um gesto explícito do usuário (não pode ser
/// disparado automaticamente) — por isso `start()` deve ser chamado a partir
/// de um handler de tap/click, nunca de `initState`/efeito automático.
abstract class CameraService {
  /// Solicita permissão e inicia o stream de vídeo ao vivo. Deve ser chamado
  /// em resposta direta a um gesto do usuário (ver nota de classe).
  Future<void> start();

  /// Captura o frame atual do stream ativo como imagem estática.
  Future<CapturedFrame> captureFrame();

  /// Encerra o stream e libera a câmera.
  Future<void> stop();

  /// Indica se há uma câmera disponível e permissão já concedida nesta
  /// sessão (usado pela UI para decidir entre mostrar preview ao vivo ou
  /// cair direto no fallback de upload de arquivo).
  bool get isAvailable;
}
