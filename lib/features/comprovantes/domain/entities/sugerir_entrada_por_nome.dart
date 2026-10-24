import 'entrada_lattes_ref.dart';

/// Palavras que aparecem em quase todo nome de arquivo de certificado (ou em
/// quase todo título do Lattes) e não ajudam a distinguir uma entrada da
/// outra.
const _palavrasIgnoradas = {
  'de', 'da', 'do', 'das', 'dos', 'em', 'e', 'a', 'o', 'as', 'os', 'para', 'por', 'com', 'no',
  'na', 'nos', 'nas', 'the', 'of', 'and', 'to', 'in', 'for', 'on',
  'pdf', 'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp',
  'certificado', 'certificate', 'comprovante', 'diploma', 'historico',
  'escolar', 'curso', 'evento', 'completion', 'certificateofcompletion', 'conclusao',
  'certificadodeconclusao', 'participacao', 'frente', 'verso', 'assinado', 'copia',
};

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
  'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o',
  'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas, sem acento, quebrado em palavras de 3+ caracteres (ou
/// números), sem as palavras de [_palavrasIgnoradas]. Exposto só pros testes.
Set<String> palavrasSignificativas(String texto) {
  final semAcento = texto.toLowerCase().split('').map((c) => _acentos[c] ?? c).join();
  return semAcento
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.length >= 3 || RegExp(r'^\d+$').hasMatch(p))
      .where((p) => !_palavrasIgnoradas.contains(p))
      .toSet();
}

/// Fallback local, sem LLM, do anexo em lote: liga um arquivo à entrada do
/// Lattes cujo TÍTULO tem mais palavras em comum com o caminho do arquivo.
/// Conservador de propósito — na dúvida devolve null ("sem entrada") em vez
/// de chutar, porque um vínculo errado aceito sem querer na revisão é pior
/// que uma linha a mais pro usuário escolher à mão:
/// - pelo menos 2 palavras do título em comum (ou 1, se o título só tem uma
///   palavra significativa);
/// - empate entre entradas diferentes no melhor placar = ambíguo = null.
/// A instituição (subtítulo) só desempata, nunca decide sozinha — "IFRJ"
/// num nome de arquivo bate com toda entrada do IFRJ.
String? sugerirEntradaPorNome(String caminhoArquivo, List<EntradaLattesRef> entradas) {
  final palavrasArquivo = palavrasSignificativas(caminhoArquivo);
  if (palavrasArquivo.isEmpty) return null;

  String? melhorId;
  var melhorPlacar = (0, 0.0, 0);
  var empatado = false;

  for (final entrada in entradas) {
    final palavrasTitulo = palavrasSignificativas(entrada.titulo);
    if (palavrasTitulo.isEmpty) continue;

    final emComum = palavrasTitulo.intersection(palavrasArquivo).length;
    final minimo = palavrasTitulo.length == 1 ? 1 : 2;
    if (emComum < minimo) continue;

    final desempate = palavrasSignificativas(entrada.subtitulo)
        .difference(palavrasTitulo)
        .intersection(palavrasArquivo)
        .length;
    final placar = (emComum, emComum / palavrasTitulo.length, desempate);

    final comparacao = _comparar(placar, melhorPlacar);
    if (comparacao > 0) {
      melhorId = entrada.id;
      melhorPlacar = placar;
      empatado = false;
    } else if (comparacao == 0) {
      empatado = true;
    }
  }

  return empatado ? null : melhorId;
}

int _comparar((int, double, int) a, (int, double, int) b) {
  if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
  if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
  return a.$3.compareTo(b.$3);
}
