import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'lattes_file_datasource.dart';

/// Lançada quando o usuário fecha o seletor de arquivo sem escolher nada.
/// Distinta de um erro real — a camada de apresentação trata isso como
/// "usuário desistiu", não como falha a ser exibida.
class LattesFileNotSelectedException implements Exception {
  const LattesFileNotSelectedException();
}

/// Implementação Web de [LattesFileDatasource] usando `file_picker`.
///
/// `withData: true` é essencial no web: sem ele, o `file_picker` só entrega
/// o `path` do arquivo, que não existe de forma utilizável no navegador
/// (não há filesystem real acessível por caminho) — os bytes precisam vir
/// diretamente no resultado do picker.
///
/// Encoding: currículos exportados pelo Lattes normalmente vêm em UTF-8,
/// mas exportações antigas podem vir em ISO-8859-1 (Latin-1). Tentamos UTF-8
/// primeiro (decodificação estrita, `allowMalformed: false`, para não
/// mascarar corrupção real de acentuação) e caímos para Latin-1 apenas se o
/// UTF-8 falhar — Latin-1 decodifica QUALQUER sequência de bytes sem
/// lançar, então nunca é a primeira tentativa (senão XML em UTF-8 legítimo
/// com acentos correria o risco de ser lido errado sem nenhum aviso).
class LattesFileDatasourceWeb implements LattesFileDatasource {
  @override
  Future<String> lerConteudoComoTexto() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xml'],
      withData: true,
      allowMultiple: false,
    );

    if (resultado == null || resultado.files.isEmpty) {
      throw const LattesFileNotSelectedException();
    }

    final arquivo = resultado.files.single;
    final bytes = arquivo.bytes;
    if (bytes == null) {
      // Não deveria acontecer com withData: true, mas é uma dependência de
      // uma API externa — nunca assumimos silenciosamente que bytes não-nulo
      // é garantido.
      throw StateError(
        'O seletor de arquivo não retornou os bytes de "${arquivo.name}". '
        'Tente selecionar o arquivo novamente.',
      );
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
