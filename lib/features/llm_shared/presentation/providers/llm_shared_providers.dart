import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/gemini_llm_datasource.dart';
import '../../data/datasources/llm_api_key_store.dart';
import '../../data/datasources/openai_llm_datasource.dart';
import '../../data/repositories/llm_repository_impl.dart';
import '../../domain/entities/llm_provider_escolhido.dart';
import '../../domain/repositories/llm_repository.dart';

// ---------------------------------------------------------------------------
// Providers de infraestrutura do LLM compartilhado — em `llm_shared`, não em
// `core/di`, porque só `certificate_capture` (módulo 2) e `dossie_builder`
// (módulo 4) dependem deles, não o app inteiro (ver ARQUITETURA.md).
// ---------------------------------------------------------------------------

final geminiLlmDatasourceProvider = Provider((ref) => GeminiLlmDatasource());

final openAiLlmDatasourceProvider = Provider((ref) => OpenAiLlmDatasource());

final llmApiKeyStoreProvider = Provider(
  (ref) => LlmApiKeyStore(ref.watch(secureStorageServiceProvider)),
);

final llmRepositoryProvider = Provider<LlmRepository>(
  (ref) => LlmRepositoryImpl(
    ref.watch(geminiLlmDatasourceProvider),
    ref.watch(openAiLlmDatasourceProvider),
    ref.watch(llmApiKeyStoreProvider),
  ),
);

// ---------------------------------------------------------------------------
// Tela de configuração BYOK: escolher provedor + colar a chave de API. O
// teste de conexão (`LlmRepository.testarConexao`) roda ANTES de salvar —
// requisito explícito do usuário (ver DECISOES.md, "BYOK"): nunca deixar o
// usuário descobrir que a chave é inválida só no meio de uma extração.
// ---------------------------------------------------------------------------

enum StatusTesteLlm { ocioso, testando, sucesso, falha }

class LlmSettingsState {
  final LlmProviderEscolhido provider;
  final StatusTesteLlm status;
  final String? mensagemErro;
  final bool jaConfigurado;

  const LlmSettingsState({
    this.provider = LlmProviderEscolhido.geminiFlash,
    this.status = StatusTesteLlm.ocioso,
    this.mensagemErro,
    this.jaConfigurado = false,
  });

  LlmSettingsState copyWith({
    LlmProviderEscolhido? provider,
    StatusTesteLlm? status,
    String? mensagemErro,
    bool limparErro = false,
    bool? jaConfigurado,
  }) {
    return LlmSettingsState(
      provider: provider ?? this.provider,
      status: status ?? this.status,
      mensagemErro: limparErro ? null : (mensagemErro ?? this.mensagemErro),
      jaConfigurado: jaConfigurado ?? this.jaConfigurado,
    );
  }
}

class LlmSettingsController extends Notifier<LlmSettingsState> {
  @override
  LlmSettingsState build() {
    _carregarProvedorAtual();
    return const LlmSettingsState();
  }

  Future<void> _carregarProvedorAtual() async {
    final store = ref.read(llmApiKeyStoreProvider);
    final provider = await store.obterProvedorEscolhido();
    if (provider == null) return;

    final chave = await store.obterChave(provider);
    state = state.copyWith(provider: provider, jaConfigurado: chave != null && chave.isNotEmpty);
  }

  /// Trocar de provedor reseta o resultado do teste anterior — "conexão
  /// validada" para o Gemini não diz nada sobre uma chave da OpenAI ainda
  /// não testada.
  void selecionarProvedor(LlmProviderEscolhido provider) {
    state = LlmSettingsState(provider: provider);
  }

  Future<void> salvarETestar(String apiKey) async {
    state = state.copyWith(status: StatusTesteLlm.testando, limparErro: true);

    final resultado = await ref.read(llmRepositoryProvider).testarConexao(
          provider: state.provider,
          apiKey: apiKey,
        );

    await resultado.match(
      (falha) async {
        state = state.copyWith(status: StatusTesteLlm.falha, mensagemErro: falha.message);
      },
      (_) async {
        final store = ref.read(llmApiKeyStoreProvider);
        await store.salvarChave(state.provider, apiKey);
        await store.salvarProvedorEscolhido(state.provider);
        state = state.copyWith(status: StatusTesteLlm.sucesso, jaConfigurado: true);
      },
    );
  }
}

final llmSettingsControllerProvider =
    NotifierProvider<LlmSettingsController, LlmSettingsState>(LlmSettingsController.new);
