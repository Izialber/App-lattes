import 'dart:async';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Um arquivo de comprovante selecionado pelo usuário, já com bytes em mãos
/// (`withData: true` é essencial no web — o `path` do `file_picker` não é
/// utilizável no navegador). [caminhoRelativo] só difere de [nomeArquivo]
/// quando veio de [ComprovanteUploadDatasource.selecionarPasta] (ex.:
/// "Diplomas/Matematica/Diploma.pdf") — o anexo em lote manda esse caminho
/// pro LLM, porque o nome da subpasta costuma ser uma boa pista.
class ArquivoComprovanteSelecionado {
  final List<int> bytes;
  final String mimeType;
  final String nomeArquivo;
  final String caminhoRelativo;

  const ArquivoComprovanteSelecionado({
    required this.bytes,
    required this.mimeType,
    required this.nomeArquivo,
    String? caminhoRelativo,
  }) : caminhoRelativo = caminhoRelativo ?? nomeArquivo;
}

/// Resultado de uma seleção do anexo em lote. [ignorados] conta os arquivos
/// de uma pasta com extensão fora de [_extensoesAceitas] (.msg, .docx,
/// .xlsx...) — pastas reais de certificados têm disso, e a tela avisa
/// quantos ficaram de fora em vez de sumir com eles calada.
class SelecaoEmLote {
  final List<ArquivoComprovanteSelecionado> arquivos;
  final int ignorados;

  const SelecaoEmLote({required this.arquivos, this.ignorados = 0});
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

abstract class ComprovanteUploadDatasource {
  /// Seleção de UM único arquivo, pro botão de upload de cada entrada do
  /// Lattes. `null` quando o usuário fecha o seletor sem escolher nada (não
  /// é erro).
  Future<ArquivoComprovanteSelecionado?> selecionarArquivo();

  /// Seleção múltipla de arquivos avulsos, pro anexo em lote. Lista vazia
  /// quando o usuário cancela.
  Future<SelecaoEmLote> selecionarVariosArquivos();

  /// Pasta inteira, recursiva, pro anexo em lote. Lista vazia quando o
  /// usuário cancela.
  Future<SelecaoEmLote> selecionarPasta();
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

  @override
  Future<SelecaoEmLote> selecionarVariosArquivos() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensoesAceitas,
      withData: true,
      allowMultiple: true,
    );
    if (resultado == null) return const SelecaoEmLote(arquivos: []);

    return SelecaoEmLote(
      arquivos: [
        for (final arquivo in resultado.files)
          if (arquivo.bytes != null)
            ArquivoComprovanteSelecionado(
              bytes: arquivo.bytes!,
              mimeType: _mimeTypePorExtensao(arquivo.extension),
              nomeArquivo: arquivo.name,
            ),
      ],
    );
  }

  /// `file_picker` não seleciona pasta no web — mesma implementação própria
  /// via `<input webkitdirectory>` do Módulo 2 antigo
  /// (`CertificateUploadDatasourceWeb.selecionarPasta`, ver lá e DECISOES.md
  /// "Seleção de pasta inteira no Módulo 2"), duplicada pelo mesmo motivo de
  /// [_extensoesAceitas]: este módulo não depende do antigo.
  @override
  Future<SelecaoEmLote> selecionarPasta() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = true;
    input.style.display = 'none';
    input.setAttribute('webkitdirectory', 'true');
    input.setAttribute('directory', 'true');

    web.document.body!.appendChild(input);

    try {
      final completer = Completer<web.FileList?>();
      input.onchange = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(input.files);
      }).toJS;
      input.oncancel = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      // Síncrono em relação ao gesto do usuário — sem `await` antes daqui.
      input.click();

      final arquivos = await completer.future;
      if (arquivos == null) return const SelecaoEmLote(arquivos: []);

      final selecionados = <ArquivoComprovanteSelecionado>[];
      var ignorados = 0;
      for (var i = 0; i < arquivos.length; i++) {
        final arquivo = arquivos.item(i);
        if (arquivo == null) continue;

        final extensao = arquivo.name.contains('.') ? arquivo.name.split('.').last : null;
        if (!_extensoesAceitas.contains(extensao?.toLowerCase())) {
          // Arquivos ocultos do sistema (.DS_Store) não contam como
          // "ignorados" pro usuário — ele nem sabe que existem.
          if (!arquivo.name.startsWith('.')) ignorados++;
          continue;
        }

        final buffer = await arquivo.arrayBuffer().toDart;
        selecionados.add(ArquivoComprovanteSelecionado(
          bytes: buffer.toDart.asUint8List(),
          mimeType: _mimeTypePorExtensao(extensao),
          nomeArquivo: arquivo.name,
          caminhoRelativo:
              arquivo.webkitRelativePath.isNotEmpty ? arquivo.webkitRelativePath : arquivo.name,
        ));
      }
      return SelecaoEmLote(arquivos: selecionados, ignorados: ignorados);
    } finally {
      input.remove();
    }
  }
}
