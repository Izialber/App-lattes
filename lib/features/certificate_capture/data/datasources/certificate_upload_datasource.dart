import 'dart:async';
import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Um arquivo de imagem selecionado pelo usuário, já com bytes em mãos —
/// igual ao padrão de `LattesFileDatasourceWeb`, `withData: true` é
/// essencial no web (o `path` do `file_picker` não é utilizável no
/// navegador). [caminhoRelativo] só vem preenchido em [selecionarPasta]
/// (indica a subpasta original, ex. "Diplomas/2023/curso.jpg") — em
/// [selecionarImagens] fica igual a [nomeArquivo], já que não há pasta.
class ArquivoSelecionado {
  final List<int> bytes;
  final String mimeType;
  final String nomeArquivo;
  final String caminhoRelativo;

  const ArquivoSelecionado({
    required this.bytes,
    required this.mimeType,
    required this.nomeArquivo,
    String? caminhoRelativo,
  }) : caminhoRelativo = caminhoRelativo ?? nomeArquivo;
}

/// Extensões aceitas pelo pipeline de captura — compartilhada entre os dois
/// modos de seleção (arquivos avulsos / pasta) para não divergir. PDF é
/// aceito porque a Gemini API lê PDF nativamente (ver `LlmRepositoryImpl`);
/// a OpenAI ainda não, por isso `OpenAiLlmDatasource` rejeita esse mimetype
/// explicitamente em vez de mandar uma chamada fadada a falhar.
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

abstract class CertificateUploadDatasource {
  /// Seleção múltipla de imagens de certificado (janela nativa do sistema,
  /// sem noção de pasta). Lista vazia quando o usuário fecha o seletor sem
  /// escolher nada — não é tratado como erro.
  Future<List<ArquivoSelecionado>> selecionarImagens();

  /// Seleciona uma pasta inteira — todos os arquivos de imagem dela E de
  /// suas subpastas, recursivamente. Lista vazia quando o usuário cancela.
  Future<List<ArquivoSelecionado>> selecionarPasta();
}

/// Implementação Web.
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
      allowedExtensions: _extensoesAceitas,
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

  /// `file_picker` não tem suporte a seleção de pasta no web (não usa
  /// `webkitdirectory` em nenhuma implementação) — esta é uma implementação
  /// própria, no mesmo padrão de `CameraServiceWeb`/`HeicConverterWeb`
  /// (abstração de plataforma via `package:web` puro). `webkitdirectory` é
  /// um atributo HTML não padronizado mas amplamente suportado (Chrome,
  /// Edge, Safari; Firefox desde a v50) que faz o navegador listar TODOS os
  /// arquivos da pasta escolhida, recursivamente por subpasta, num único
  /// `<input type="file">` — cada `File` carrega `webkitRelativePath` com o
  /// caminho original. Não existe equivalente em mobile: nesses navegadores
  /// o seletor de pasta tende a não aparecer ou cair de volta para seleção
  /// de arquivo avulso, por isso `selecionarImagens` continua sendo o
  /// caminho principal.
  @override
  Future<List<ArquivoSelecionado>> selecionarPasta() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = true;
    input.style.display = 'none';
    input.setAttribute('webkitdirectory', 'true');
    input.setAttribute('directory', 'true'); // fallback de navegadores antigos

    web.document.body!.appendChild(input);

    try {
      final completer = Completer<web.FileList?>();
      input.onchange = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(input.files);
      }).toJS;
      // 'cancel' é suportado em navegadores Chromium recentes quando o
      // usuário fecha o seletor sem escolher nada; em navegadores sem esse
      // evento, o pior caso é idêntico ao de qualquer <input type=file> cru
      // sem biblioteca adicional: a Future só resolve se o usuário concluir
      // a seleção.
      input.oncancel = ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;

      // click() precisa ser chamado de forma síncrona em relação ao gesto
      // do usuário (nenhum `await` entre o tap e aqui) — navegadores
      // recusam abrir o seletor de arquivo fora de um user gesture ativo.
      input.click();

      final arquivos = await completer.future;
      if (arquivos == null) return const [];

      return _lerArquivosAceitos(arquivos);
    } finally {
      input.remove();
    }
  }

  Future<List<ArquivoSelecionado>> _lerArquivosAceitos(web.FileList arquivos) async {
    final selecionados = <ArquivoSelecionado>[];

    for (var i = 0; i < arquivos.length; i++) {
      final arquivo = arquivos.item(i);
      if (arquivo == null) continue;

      final extensao = arquivo.name.contains('.') ? arquivo.name.split('.').last : null;
      if (!_extensoesAceitas.contains(extensao?.toLowerCase())) continue;

      final buffer = await arquivo.arrayBuffer().toDart;
      final caminhoRelativo =
          arquivo.webkitRelativePath.isNotEmpty ? arquivo.webkitRelativePath : arquivo.name;

      selecionados.add(
        ArquivoSelecionado(
          bytes: buffer.toDart.asUint8List(),
          mimeType: _mimeTypePorExtensao(extensao),
          nomeArquivo: arquivo.name,
          caminhoRelativo: caminhoRelativo,
        ),
      );
    }

    return selecionados;
  }
}
