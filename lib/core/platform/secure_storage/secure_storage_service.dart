/// Abstração de armazenamento de segredos: tokens OAuth (access + refresh) e
/// a chave de API do LLM (BYOK). NUNCA usar Hive/IndexedDB puro para estes
/// dados — apenas esta interface, cujas implementações cifram o conteúdo.
abstract class SecureStorageService {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});

  /// Apaga todos os segredos guardados (usado no logout / troca de conta
  /// cloud, e como parte do fluxo de "esqueci minha chave LLM").
  Future<void> clearAll();
}

/// Chaves conhecidas, centralizadas para evitar strings mágicas espalhadas
/// pelas features.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const googleAccessToken = 'google_access_token';
  static const googleRefreshToken = 'google_refresh_token';
  static const microsoftAccessToken = 'microsoft_access_token';
  static const microsoftRefreshToken = 'microsoft_refresh_token';
  static const llmApiKeyGemini = 'llm_api_key_gemini';
  static const llmApiKeyOpenAi = 'llm_api_key_openai';

  /// Qual provedor (`LlmProviderEscolhido.name`) o usuário escolheu usar —
  /// não é um segredo em si, mas fica junto das chaves BYOK por
  /// conveniência: os dois sempre mudam juntos na tela de configuração.
  static const llmProviderEscolhido = 'llm_provider_escolhido';
}
