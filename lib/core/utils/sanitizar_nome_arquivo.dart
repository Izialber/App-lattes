/// Remove caracteres que não são seguros em nome de arquivo em
/// Drive/OneDrive/sistemas de arquivo em geral, e limita o tamanho — texto
/// de origem (título extraído por LLM, ou de uma entrada do Lattes) pode
/// ser bem mais longo que um nome de arquivo razoável. Compartilhado entre
/// `CloudSyncController` (módulo antigo) e `ComprovantesSyncController`
/// (módulo de comprovantes) — ver DECISOES.md.
String sanitizarParaNomeDeArquivo(String texto) {
  final semCaracteresInvalidos = texto.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim();
  final comHifen = semCaracteresInvalidos.replaceAll(RegExp(r'\s+'), '-');
  return comHifen.length > 60 ? comHifen.substring(0, 60) : comHifen;
}
