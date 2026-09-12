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
}
