import '../../../../core/platform/secure_storage/secure_storage_service.dart';
import '../../domain/entities/llm_provider_escolhido.dart';

/// BYOK: o usuário cola a própria chave de API (Gemini, OpenAI ou
/// Anthropic) em uma tela de configuração; ela é gravada SOMENTE via
/// [SecureStorageService] (cifrada no web, Keychain/Keystore na fase 2) e
/// nunca sai do navegador dele — não existe endpoint próprio que veja essa
/// chave. Ver RISCOS.md, "Chave de LLM (BYOK)" para o risco residual e o
/// ponto de troca futuro para um proxy serverless.
class LlmApiKeyStore {
  final SecureStorageService _secureStorage;

  const LlmApiKeyStore(this._secureStorage);

  String _chaveStorage(LlmProviderEscolhido provider) => switch (provider) {
        LlmProviderEscolhido.geminiFlash => SecureStorageKeys.llmApiKeyGemini,
        LlmProviderEscolhido.gpt4oMini => SecureStorageKeys.llmApiKeyOpenAi,
        LlmProviderEscolhido.claudeHaiku => SecureStorageKeys.llmApiKeyAnthropic,
      };

  Future<String?> obterChave(LlmProviderEscolhido provider) {
    return _secureStorage.read(key: _chaveStorage(provider));
  }

  Future<void> salvarChave(LlmProviderEscolhido provider, String apiKey) {
    return _secureStorage.write(key: _chaveStorage(provider), value: apiKey);
  }

  /// Provedor ativo hoje — fora da tela de configuração (onde o provider é
  /// escolhido explicitamente), o resto do app sempre opera sobre "o
  /// provedor configurado agora", nunca pede para o chamador especificar.
  Future<LlmProviderEscolhido?> obterProvedorEscolhido() async {
    final nome = await _secureStorage.read(key: SecureStorageKeys.llmProviderEscolhido);
    for (final provider in LlmProviderEscolhido.values) {
      if (provider.name == nome) return provider;
    }
    return null;
  }

  Future<void> salvarProvedorEscolhido(LlmProviderEscolhido provider) {
    return _secureStorage.write(
      key: SecureStorageKeys.llmProviderEscolhido,
      value: provider.name,
    );
  }
}
