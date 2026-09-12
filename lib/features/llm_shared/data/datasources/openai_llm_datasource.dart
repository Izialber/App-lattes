/// Chamada HTTP direta à API da OpenAI (`api.openai.com/v1/chat/completions`,
/// modelo `gpt-4o-mini`) a partir do navegador, com a chave BYOK. CORS:
/// diferente do Gemini, a OpenAI historicamente restringe CORS para
/// chamadas client-side — ver RISCOS.md, seção de CORS, para o plano B
/// (permitir só Gemini no web nesta fase, manter OpenAI como opção
/// documentada para quando houver proxy serverless).
///
/// PENDENTE (fora do escopo do entregável 5): implementação real via Dio.
class OpenAiLlmDatasource {
  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) {
    throw UnimplementedError('OpenAiLlmDatasource.gerarJson: pendente (ver DECISOES.md)');
  }
}
