import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'camera_service.dart';

const double _jpegQuality = 0.9;

/// Implementação Web via `getUserMedia`.
///
/// - `start()` DEVE ser chamado a partir do `onTap` do botão "Abrir câmera"
///   — nunca de forma automática — porque Safari iOS bloqueia
///   `getUserMedia` fora de um gesto do usuário e exige contexto HTTPS.
/// - `captureFrame()` desenha o frame atual do `<video>` em um `<canvas>`
///   oculto e exporta via `toDataURL('image/jpeg', quality)`.
/// - Erros de permissão negada, câmera ocupada por outra aba, ou ausência de
///   câmera viram [StateError] com mensagem amigável, traduzidos para
///   [CaptureFailure] pelo repositório que consome esta classe
///   (`certificate_capture/data/repositories`).
///
/// [stream] expõe o `MediaStream` ao vivo para a presentation layer exibir
/// via `HtmlElementView.fromTagName` (ver `_CameraPreview` em
/// `certificate_capture_page.dart`) — um `<video>` próprio da UI, distinto
/// do `<video>` interno usado por [captureFrame]. Um mesmo `MediaStream`
/// pode alimentar vários elementos `<video>` simultaneamente (cada um com
/// seu próprio decodificador), então não há conflito entre os dois.
class CameraServiceWeb implements CameraService {
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;

  @override
  bool get isAvailable => _stream != null;

  web.MediaStream? get stream => _stream;

  @override
  Future<void> start() async {
    final web.MediaStream stream;
    try {
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: web.MediaTrackConstraints(facingMode: 'environment'.toJS),
              audio: false.toJS,
            ),
          )
          .toDart;
    } catch (e) {
      throw StateError(
        'Não foi possível acessar a câmera. Verifique se a permissão foi concedida '
        'e se nenhuma outra aba está usando a câmera. ($e)',
      );
    }

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..srcObject = stream;
    await video.play().toDart;

    _stream = stream;
    _video = video;
  }

  @override
  Future<CapturedFrame> captureFrame() async {
    final video = _video;
    if (_stream == null || video == null) {
      throw StateError('Câmera não iniciada — chame start() antes de captureFrame().');
    }

    final canvas = web.HTMLCanvasElement()
      ..width = video.videoWidth
      ..height = video.videoHeight;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(video, 0, 0);

    final dataUrl = canvas.toDataURL('image/jpeg', _jpegQuality.toJS);
    final base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);

    return CapturedFrame(
      bytes: base64Decode(base64),
      mimeType: 'image/jpeg',
      capturedAt: DateTime.now(),
    );
  }

  @override
  Future<void> stop() async {
    for (final track in _stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _video = null;
  }
}
