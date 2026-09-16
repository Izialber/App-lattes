import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/certificate_capture/data/datasources/certificate_upload_datasource.dart';

/// Só a parte pura e testável sem navegador: o fallback de
/// `caminhoRelativo`. A seleção em si (`selecionarImagens`/
/// `selecionarPasta`) depende de `file_picker`/`package:web`, então fica de
/// fora de teste unitário (mesmo padrão já adotado para os outros
/// datasources `_web.dart` do projeto).
void main() {
  test('caminhoRelativo usa nomeArquivo quando não informado (seleção de arquivo avulso)', () {
    const arquivo = ArquivoSelecionado(
      bytes: [1, 2, 3],
      mimeType: 'image/jpeg',
      nomeArquivo: 'certificado.jpg',
    );

    expect(arquivo.caminhoRelativo, 'certificado.jpg');
  });

  test('caminhoRelativo preserva a subpasta quando informado (seleção de pasta)', () {
    const arquivo = ArquivoSelecionado(
      bytes: [1, 2, 3],
      mimeType: 'image/jpeg',
      nomeArquivo: 'certificado.jpg',
      caminhoRelativo: 'Diplomas/2023/certificado.jpg',
    );

    expect(arquivo.caminhoRelativo, 'Diplomas/2023/certificado.jpg');
  });
}
