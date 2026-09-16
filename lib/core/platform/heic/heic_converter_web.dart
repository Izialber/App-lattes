import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'heic_converter.dart';

const double _jpegQuality = 0.9;

/// Implementação Web: `<img>`/`<canvas>` via `package:web`. Safari (desktop
/// e iOS) decodifica HEIC nativamente num `<img>`; Chrome/Firefox não —
/// nesses casos o `onerror` do `<img>` dispara e a conversão falha com
/// [HeicConversionUnsupportedException], que a UI traduz no fallback
/// documentado (pedir exportação manual como JPEG). Ver ARQUITETURA.md,
/// "HeicConverter".
class HeicConverterWeb extends HeicConverter {
  @override
  Future<ConvertedImage> converterParaJpeg(List<int> bytes) async {
    final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS);
    final objectUrl = web.URL.createObjectURL(blob);

    try {
      final image = web.HTMLImageElement()..src = objectUrl;
      await _aguardarCarregamento(image);

      final canvas = web.HTMLCanvasElement()
        ..width = image.naturalWidth
        ..height = image.naturalHeight;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      context.drawImage(image, 0, 0);

      final dataUrl = canvas.toDataURL('image/jpeg', _jpegQuality.toJS);
      final base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
      return ConvertedImage(bytes: base64Decode(base64), mimeType: 'image/jpeg');
    } finally {
      web.URL.revokeObjectURL(objectUrl);
    }
  }

  Future<void> _aguardarCarregamento(web.HTMLImageElement image) {
    final completer = Completer<void>();
    image.onload = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    image.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const HeicConversionUnsupportedException(
            'Este navegador não consegue decodificar HEIC. Exporte o certificado '
            'como JPEG (ex.: no app Fotos do iPhone, "Compartilhar" -> "Copiar foto") '
            'e envie novamente.',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }
}
