import 'heic_converter.dart';

/// Stub documentado da fase 2: usa `heic_to_jpg` (já listado no pubspec,
/// marcado "[só nativo, fase 2]"), decodificação sempre confiável — ver
/// ROADMAP_MOBILE.md.
class HeicConverterNative extends HeicConverter {
  @override
  Future<ConvertedImage> converterParaJpeg(List<int> bytes) =>
      throw UnimplementedError('fase 2: heic_to_jpg');
}
