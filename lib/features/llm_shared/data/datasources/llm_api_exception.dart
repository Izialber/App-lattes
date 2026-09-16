/// Exceção interna de infraestrutura lançada pelos datasources de LLM
/// (Gemini/OpenAI). Nunca cruza a fronteira para `domain`/`presentation` —
/// `LlmRepositoryImpl` captura e traduz para [LlmFailure].
class LlmApiException implements Exception {
  final String message;
  final int? statusCode;

  const LlmApiException(this.message, {this.statusCode});

  /// 401/403 (chave inválida/sem permissão) e 429 (quota excedida) são os
  /// casos em que a UI deve pedir para o usuário revisar a chave BYOK, em
  /// vez de tratar como uma falha de rede transitória qualquer — ver
  /// `LlmRepository.testarConexao`.
  bool get isQuotaOrAuth => statusCode == 401 || statusCode == 403 || statusCode == 429;

  @override
  String toString() => 'LlmApiException($statusCode): $message';
}
