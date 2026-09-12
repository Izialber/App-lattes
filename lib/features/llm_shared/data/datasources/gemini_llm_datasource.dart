/// Chamada HTTP direta à API do Gemini (`generativelanguage.googleapis.com`)
/// a partir do navegador, com a chave BYOK no header/query param. CORS: a
/// API do Gemini permite chamadas de origem arbitrária com API key (ver
/// RISCOS.md, "CORS nas chamadas ao LLM"); caso isso mude, o ponto de troca
/// é este datasource, sem impacto em `domain`.
///
/// PENDENTE (fora do escopo do entregável 5): implementação real via Dio,
/// incluindo o parsing da resposta multimodal do Gemini Flash.
class GeminiLlmDatasource {
  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) {
    throw UnimplementedError('GeminiLlmDatasource.gerarJson: pendente (ver DECISOES.md)');
  }
}
