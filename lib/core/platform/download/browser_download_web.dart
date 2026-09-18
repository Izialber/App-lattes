import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dispara o download de [bytes] pelo navegador, com o nome [nomeArquivo] —
/// técnica padrão de Blob + `<a download>` + clique programático. Só faz
/// sentido no web (não há "salvar em disco" equivalente em Fase 2 nativa,
/// que usaria compartilhamento do SO em vez disso — por isso este arquivo
/// não tem par `_native.dart`, ao contrário do resto de `core/platform`).
void baixarArquivoWeb(
  List<int> bytes,
  String nomeArquivo, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = nomeArquivo;
  anchor.style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
