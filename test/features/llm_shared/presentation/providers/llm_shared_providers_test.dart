import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Left, Right, unit;
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_key_store.dart';
import 'package:certificados_lattes/features/llm_shared/domain/entities/llm_provider_escolhido.dart';
import 'package:certificados_lattes/features/llm_shared/domain/repositories/llm_repository.dart';
import 'package:certificados_lattes/features/llm_shared/presentation/providers/llm_shared_providers.dart';

class MockLlmApiKeyStore extends Mock implements LlmApiKeyStore {}

class MockLlmRepository extends Mock implements LlmRepository {}

/// Testa `LlmSettingsController`: o teste de conexão precisa ter sucesso
/// ANTES da chave ser salva (requisito de DECISOES.md, "BYOK") — nunca o
/// contrário.
void main() {
  late MockLlmApiKeyStore keyStore;
  late MockLlmRepository repository;
  late ProviderContainer container;

  ProviderContainer novoContainer() {
    final c = ProviderContainer(
      overrides: [
        llmApiKeyStoreProvider.overrideWithValue(keyStore),
        llmRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    keyStore = MockLlmApiKeyStore();
    repository = MockLlmRepository();
    when(() => keyStore.obterProvedorEscolhido()).thenAnswer((_) async => null);

    container = novoContainer();
  });

  test('estado inicial: geminiFlash, ocioso, sem chave configurada', () {
    final estado = container.read(llmSettingsControllerProvider);
    expect(estado.provider, LlmProviderEscolhido.geminiFlash);
    expect(estado.status, StatusTesteLlm.ocioso);
    expect(estado.jaConfigurado, isFalse);
  });

  test('carrega o provedor e a presença de chave já salvos ao iniciar', () async {
    when(() => keyStore.obterProvedorEscolhido())
        .thenAnswer((_) async => LlmProviderEscolhido.gpt4oMini);
    when(() => keyStore.obterChave(LlmProviderEscolhido.gpt4oMini))
        .thenAnswer((_) async => 'chave-existente');

    final outroContainer = novoContainer();
    // build() dispara o carregamento de forma assíncrona (fire-and-forget) —
    // espera o microtask resolver antes de checar o estado atualizado.
    await Future<void>.delayed(Duration.zero);

    final estado = outroContainer.read(llmSettingsControllerProvider);
    expect(estado.provider, LlmProviderEscolhido.gpt4oMini);
    expect(estado.jaConfigurado, isTrue);
  });

  test('selecionarProvedor troca o provedor e reseta status/erro', () {
    final notifier = container.read(llmSettingsControllerProvider.notifier);
    notifier.selecionarProvedor(LlmProviderEscolhido.gpt4oMini);

    final estado = container.read(llmSettingsControllerProvider);
    expect(estado.provider, LlmProviderEscolhido.gpt4oMini);
    expect(estado.status, StatusTesteLlm.ocioso);
    expect(estado.mensagemErro, isNull);
  });

  test('salvarETestar: sucesso salva a chave e o provedor', () async {
    when(() => repository.testarConexao(
          provider: LlmProviderEscolhido.geminiFlash,
          apiKey: 'chave-boa',
        )).thenAnswer((_) async => const Right(unit));
    when(() => keyStore.salvarChave(LlmProviderEscolhido.geminiFlash, 'chave-boa'))
        .thenAnswer((_) async {});
    when(() => keyStore.salvarProvedorEscolhido(LlmProviderEscolhido.geminiFlash))
        .thenAnswer((_) async {});

    final notifier = container.read(llmSettingsControllerProvider.notifier);
    await notifier.salvarETestar('chave-boa');

    final estado = container.read(llmSettingsControllerProvider);
    expect(estado.status, StatusTesteLlm.sucesso);
    expect(estado.jaConfigurado, isTrue);
    verify(() => keyStore.salvarChave(LlmProviderEscolhido.geminiFlash, 'chave-boa')).called(1);
    verify(() => keyStore.salvarProvedorEscolhido(LlmProviderEscolhido.geminiFlash)).called(1);
  });

  test('salvarETestar: falha não salva nada e expõe a mensagem de erro', () async {
    when(() => repository.testarConexao(
          provider: LlmProviderEscolhido.geminiFlash,
          apiKey: 'chave-ruim',
        )).thenAnswer(
      (_) async => const Left(LlmFailure('chave inválida', isQuotaOrAuth: true)),
    );

    final notifier = container.read(llmSettingsControllerProvider.notifier);
    await notifier.salvarETestar('chave-ruim');

    final estado = container.read(llmSettingsControllerProvider);
    expect(estado.status, StatusTesteLlm.falha);
    expect(estado.mensagemErro, 'chave inválida');
    verifyNever(() => keyStore.salvarChave(any(), any()));
    verifyNever(() => keyStore.salvarProvedorEscolhido(any()));
  });
}
