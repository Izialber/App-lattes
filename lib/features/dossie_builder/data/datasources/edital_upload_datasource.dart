import 'package:file_picker/file_picker.dart';

/// Um edital de concurso selecionado pelo usuário, já com bytes em mãos —
/// mesmo padrão de `LattesFileDatasourceWeb`/`CertificateUploadDatasourceWeb`.
class EditalSelecionado {
  final List<int> bytes;
  final String nomeArquivo;

  const EditalSelecionado({required this.bytes, required this.nomeArquivo});
}

abstract class EditalUploadDatasource {
  /// `null` quando o usuário fecha o seletor sem escolher nada — não é
  /// tratado como erro.
  Future<EditalSelecionado?> selecionarEdital();
}

class EditalUploadDatasourceWeb implements EditalUploadDatasource {
  @override
  Future<EditalSelecionado?> selecionarEdital() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
      allowMultiple: false,
    );

    if (resultado == null || resultado.files.isEmpty) return null;

    final arquivo = resultado.files.single;
    final bytes = arquivo.bytes;
    if (bytes == null) {
      throw StateError(
        'O seletor de arquivo não retornou os bytes de "${arquivo.name}". '
        'Tente selecionar o arquivo novamente.',
      );
    }

    return EditalSelecionado(bytes: bytes, nomeArquivo: arquivo.name);
  }
}
