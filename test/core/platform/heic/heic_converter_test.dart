import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/core/platform/heic/heic_converter_native.dart';

/// `pareceHeic` é lógica pura de bytes, concreta na classe base — testada
/// aqui via `HeicConverterNative` (não instancia nenhuma API de
/// plataforma; só o método herdado é exercitado). NUNCA confia no
/// mimetype/extensão do arquivo, só nos magic bytes do container ISOBMFF —
/// ver RISCOS.md, "Upload iOS com nome/mimetype genéricos".
void main() {
  final converter = HeicConverterNative();

  List<int> _ftypBox(String majorBrand) => [
        0, 0, 0, 24, // box size (irrelevante para a detecção)
        ...'ftyp'.codeUnits,
        ...majorBrand.codeUnits,
      ];

  test('detecta HEIC pela major brand "heic"', () {
    expect(converter.pareceHeic(_ftypBox('heic')), isTrue);
  });

  test('detecta HEIC pela major brand "mif1" (HEIF genérico)', () {
    expect(converter.pareceHeic(_ftypBox('mif1')), isTrue);
  });

  test('não detecta HEIC para um JPEG (magic bytes FFD8FF...)', () {
    expect(converter.pareceHeic([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0]), isFalse);
  });

  test('não detecta HEIC para um PNG (assinatura própria)', () {
    expect(
      converter.pareceHeic([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]),
      isFalse,
    );
  });

  test('não detecta HEIC para um MP4 (mesmo box ftyp, brand diferente)', () {
    expect(converter.pareceHeic(_ftypBox('isom')), isFalse);
  });

  test('não lança e retorna falso para bytes curtos demais', () {
    expect(converter.pareceHeic([1, 2, 3]), isFalse);
    expect(converter.pareceHeic(const []), isFalse);
  });
}
