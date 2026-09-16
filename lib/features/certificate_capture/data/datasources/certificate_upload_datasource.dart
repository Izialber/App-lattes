import 'package:file_picker/file_picker.dart';

/// Um arquivo de imagem selecionado pelo usuário, já com bytes em mãos —
/// igual ao padrão de `LattesFileDatasourceWeb`, `withData: true` é
/// essencial no web (o `path` do `file_picker` não é utilizável no
/// navegador).
class ArquivoSelecionado {
  final List<int> bytes;
  final String mimeType;
  final String nomeArquivo;

  const ArquivoSelecionado({
    required this.bytes,
    required this.mimeType,
    required this.nomeArquivo,
  });
}

abstract class CertificateUploadDatasource {
  /// Seleção múltipla de imagens de certificado. Lista vazia quando o
  /// usuário fecha o seletor sem escolher nada — não é tratado como erro.
  Future<List<ArquivoSelecionado>> selecionarImagens();
}

/// Implementação Web via `file_picker`.
///
/// O mimetype reportado pelo navegador NÃO é confiável (ver RISCOS.md,
/// "Upload iOS com nome/mimetype genéricos") — por isso o mimetype usado
/// pelo resto do pipeline vem da EXTENSÃO do arquivo, não de
/// `PlatformFile.bytes`/metadata do picker. Isso é só uma primeira
/// aproximação: a detecção real de HEIC (que é o único formato onde a
/// diferença importa de verdade) acontece por magic bytes em
/// `HeicConverter.pareceHeic`, não por este mimetype.
class CertificateUploadDatasourceWeb implements CertificateUploadDatasource {
  @override
  Future<List<ArquivoSelecionado>> selecionarImagens() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'],
      withData: true,
      allowMultiple: true,
    );

    if (resultado == null) return const [];

    return resultado.files
        .where((arquivo) => arquivo.bytes != null)
        .map(
          (arquivo) => ArquivoSelecionado(
            bytes: arquivo.bytes!,
            mimeType: _mimeTypePorExtensao(arquivo.extension),
            nomeArquivo: arquivo.name,
          ),
        )
        .toList(growable: false);
  }

  String _mimeTypePorExtensao(String? extensao) {
    switch (extensao?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
