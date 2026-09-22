import 'package:file_picker/file_picker.dart';

/// Um arquivo de comprovante selecionado pelo usuário, já com bytes em mãos
/// (`withData: true` é essencial no web — o `path` do `file_picker` não é
/// utilizável no navegador).
class ArquivoComprovanteSelecionado {
  final List<int> bytes;
  final String mimeType;
  final String nomeArquivo;

  const ArquivoComprovanteSelecionado({
    required this.bytes,
    required this.mimeType,
    required this.nomeArquivo,
  });
}

/// Extensões aceitas — mesma lista do Módulo 2 antigo
/// (`certificate_capture/data/datasources/certificate_upload_datasource.dart`),
/// duplicada de propósito em vez de importada: este módulo não depende do
/// antigo, que pode vir a ser removido depois (ver DECISOES.md).
const _extensoesAceitas = ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'pdf'];

String _mimeTypePorExtensao(String? extensao) {
  switch (extensao?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'heic':
    case 'heif':
      return 'image/heic';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

/// Seleção de UM único arquivo — cada entrada do Lattes tem seu próprio
/// botão de upload, então não há seleção múltipla aqui (ao contrário do
/// Módulo 2 antigo). `null` quando o usuário fecha o seletor sem escolher
/// nada (não é erro).
abstract class ComprovanteUploadDatasource {
  Future<ArquivoComprovanteSelecionado?> selecionarArquivo();
}

class ComprovanteUploadDatasourceWeb implements ComprovanteUploadDatasource {
  @override
  Future<ArquivoComprovanteSelecionado?> selecionarArquivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensoesAceitas,
      withData: true,
      allowMultiple: false,
    );

    if (resultado == null || resultado.files.isEmpty) return null;
    final arquivo = resultado.files.single;
    if (arquivo.bytes == null) return null;

    return ArquivoComprovanteSelecionado(
      bytes: arquivo.bytes!,
      mimeType: _mimeTypePorExtensao(arquivo.extension),
      nomeArquivo: arquivo.name,
    );
  }
}
