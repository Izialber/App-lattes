/// Resultado de uma normalização de formato: bytes já garantidamente em
/// JPEG, prontos para envio ao LLM ou conversão para PDF.
class ConvertedImage {
  final List<int> bytes;
  final String mimeType; // sempre 'image/jpeg' após conversão bem-sucedida

  const ConvertedImage({required this.bytes, required this.mimeType});
}

/// O navegador/SO não conseguiu decodificar o HEIC (ex.: Chrome/Firefox no
/// desktop, que não decodificam HEIC nativamente via `<img>`). Fallback
/// esperado pela UI: pedir para o usuário exportar/converter manualmente
/// antes de enviar — ver ARQUITETURA.md, "HeicConverter".
class HeicConversionUnsupportedException implements Exception {
  final String message;
  const HeicConversionUnsupportedException(this.message);

  @override
  String toString() => message;
}

/// Abstração de conversão HEIC -> JPEG (ver ARQUITETURA.md, tabela de
/// abstrações de plataforma). HEIC é formato proprietário da Apple sem
/// decoder confiável 100% em Dart puro para web — por isso esta abstração
/// de plataforma, no mesmo padrão de `CameraService`/`SecureStorageService`.
abstract class HeicConverter {
  /// Detecta HEIC pelos magic bytes do container ISOBMFF (box `ftyp` com uma
  /// das "major brands" de HEIF/HEIC) — NUNCA confia no mimetype reportado
  /// pelo navegador/SO, que no Safari iOS costuma vir genérico mesmo para
  /// HEIC (ver RISCOS.md, "Upload iOS com nome/mimetype genéricos"). Lógica
  /// pura de bytes, idêntica em toda plataforma — por isso concreta aqui, em
  /// vez de duplicada em cada implementação.
  bool pareceHeic(List<int> bytes) {
    if (bytes.length < 12) return false;
    if (String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') return false;

    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return _majorBrandsHeic.contains(brand);
  }

  static const _majorBrandsHeic = {
    'heic',
    'heix',
    'hevc',
    'hevx',
    'heim',
    'heis',
    'hevm',
    'hevs',
    'mif1',
    'msf1',
  };

  /// Converte para JPEG. Idempotente pelo contrato do chamador
  /// (`ConverterHeicParaJpeg`/`CertificateRepositoryImpl`): só é chamado
  /// depois de [pareceHeic] confirmar que a imagem realmente é HEIC.
  /// Lança [HeicConversionUnsupportedException] quando a decodificação falha.
  Future<ConvertedImage> converterParaJpeg(List<int> bytes);
}
