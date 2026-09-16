import '../../../../core/platform/secure_storage/secure_storage_service.dart';
import '../../domain/entities/llm_provider_escolhido.dart';

/// BYOK: o usuário cola a própria chave de API (Gemini ou OpenAI) em uma
/// tela de configuração; ela é gravada SOMENTE via [SecureStorageService]
/// (cifrada no web, Keychain/Keystore na fase 2) e nunca sai do navegador
/// dele — não existe endpoint próprio que veja essa chave. Ver RISCOS.md,
/// "Chave de LLM (BYOK)" para o risco residual e o ponto de troca futuro
/// para um proxy serverless.
class LlmApiKeyStore {
  final SecureStorageService _secureStorage;

  const LlmApiKeyStore(this._secureStorage);

  Future<String?> obterChave(LlmProviderEscolhido provider) {
    final key = provider == LlmProviderEscolhido.geminiFlash
        ? SecureStorageKeys.llmApiKeyGemini
        : SecureStorageKeys.llmApiKeyOpenAi;
    return _secureStorage.read(key: key);
  }

  Future<void> salvarChave(LlmProviderEscolhido provider, String apiKey) {
    final key = provider == LlmProviderEscolhido.geminiFlash
        ? SecureStorageKeys.llmApiKeyGemini
        : SecureStorageKeys.llmApiKeyOpenAi;
    return _secureStorage.write(key: key, value: apiKey);
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
