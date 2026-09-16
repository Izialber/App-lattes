import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/gemini_llm_datasource.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_key_store.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/openai_llm_datasource.dart';
import 'package:certificados_lattes/features/llm_shared/data/repositories/llm_repository_impl.dart';
import 'package:certificados_lattes/features/llm_shared/domain/entities/llm_provider_escolhido.dart';

class MockGeminiLlmDatasource extends Mock implements GeminiLlmDatasource {}

class MockOpenAiLlmDatasource extends Mock implements OpenAiLlmDatasource {}

class MockLlmApiKeyStore extends Mock implements LlmApiKeyStore {}

void main() {
  late MockGeminiLlmDatasource gemini;
  late MockOpenAiLlmDatasource openAi;
  late MockLlmApiKeyStore keyStore;
  late LlmRepositoryImpl repository;

  setUp(() {
    gemini = MockGeminiLlmDatasource();
    openAi = MockOpenAiLlmDatasource();
    keyStore = MockLlmApiKeyStore();
    repository = LlmRepositoryImpl(gemini, openAi, keyStore);
  });

  group('extrairJsonDeImagem', () {
    test('LlmFailure(isQuotaOrAuth: true) quando nenhum provedor está configurado', () async {
      when(() => keyStore.obterProvedorEscolhido()).thenAnswer((_) async => null);

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      expect(resultado.isLeft(), isTrue);
      resultado.match(
        (falha) => expect((falha as LlmFailure).isQuotaOrAuth, isTrue),
        (_) => fail('esperava Left'),
      );
      verifyNever(() => gemini.gerarJson(
            apiKey: any(named: 'apiKey'),
            prompt: any(named: 'prompt'),
          ));
    });

    test('LlmFailure quando o provedor está configurado mas sem chave salva', () async {
      when(() => keyStore.obterProvedorEscolhido())
          .thenAnswer((_) async => LlmProviderEscolhido.geminiFlash);
      when(() => keyStore.obterChave(LlmProviderEscolhido.geminiFlash))
          .thenAnswer((_) async => null);

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      expect(resultado.isLeft(), isTrue);
    });

    test('chama o Gemini quando o provedor configurado é geminiFlash', () async {
      when(() => keyStore.obterProvedorEscolhido())
          .thenAnswer((_) async => LlmProviderEscolhido.geminiFlash);
      when(() => keyStore.obterChave(LlmProviderEscolhido.geminiFlash))
          .thenAnswer((_) async => 'chave-gemini');
      when(() => gemini.gerarJson(
            apiKey: 'chave-gemini',
            prompt: 'prompt',
            imagemBytes: const [1, 2, 3],
            mimeType: 'image/jpeg',
          )).thenAnswer((_) async => {'titulo': 'Curso X'});

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (json) => expect(json['titulo'], 'Curso X'));
      verifyNever(() => openAi.gerarJson(
            apiKey: any(named: 'apiKey'),
            prompt: any(named: 'prompt'),
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          ));
    });

    test('chama a OpenAI quando o provedor configurado é gpt4oMini', () async {
      when(() => keyStore.obterProvedorEscolhido())
          .thenAnswer((_) async => LlmProviderEscolhido.gpt4oMini);
      when(() => keyStore.obterChave(LlmProviderEscolhido.gpt4oMini))
          .thenAnswer((_) async => 'chave-openai');
      when(() => openAi.gerarJson(
            apiKey: 'chave-openai',
            prompt: 'prompt',
            imagemBytes: const [1, 2, 3],
            mimeType: 'image/jpeg',
          )).thenAnswer((_) async => {'titulo': 'Curso X'});

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      expect(resultado.isRight(), isTrue);
    });

    test('traduz LlmApiException(401) em LlmFailure.isQuotaOrAuth', () async {
      when(() => keyStore.obterProvedorEscolhido())
          .thenAnswer((_) async => LlmProviderEscolhido.geminiFlash);
      when(() => keyStore.obterChave(LlmProviderEscolhido.geminiFlash))
          .thenAnswer((_) async => 'chave-invalida');
      when(() => gemini.gerarJson(
            apiKey: 'chave-invalida',
            prompt: 'prompt',
            imagemBytes: const [1, 2, 3],
            mimeType: 'image/jpeg',
          )).thenThrow(const LlmApiException('chave inválida', statusCode: 401));

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      resultado.match(
        (falha) => expect((falha as LlmFailure).isQuotaOrAuth, isTrue),
        (_) => fail('esperava Left'),
      );
    });

    test('erro de rede (sem statusCode) vira LlmFailure sem isQuotaOrAuth', () async {
      when(() => keyStore.obterProvedorEscolhido())
          .thenAnswer((_) async => LlmProviderEscolhido.geminiFlash);
      when(() => keyStore.obterChave(LlmProviderEscolhido.geminiFlash))
          .thenAnswer((_) async => 'chave');
      when(() => gemini.gerarJson(
            apiKey: 'chave',
            prompt: 'prompt',
            imagemBytes: const [1, 2, 3],
            mimeType: 'image/jpeg',
          )).thenThrow(const LlmApiException('falha de rede'));

      final resultado = await repository.extrairJsonDeImagem(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
        promptExtracao: 'prompt',
      );

      resultado.match(
        (falha) => expect((falha as LlmFailure).isQuotaOrAuth, isFalse),
        (_) => fail('esperava Left'),
      );
    });
  });

  group('testarConexao', () {
    test('Right(unit) quando a chamada mínima tem sucesso', () async {
      when(() => gemini.gerarJson(apiKey: 'chave', prompt: any(named: 'prompt')))
          .thenAnswer((_) async => {'ok': true});

      final resultado = await repository.testarConexao(
        provider: LlmProviderEscolhido.geminiFlash,
        apiKey: 'chave',
      );

      expect(resultado.isRight(), isTrue);
    });

    test('LlmFailure quando a API rejeita a chave', () async {
      when(() => openAi.gerarJson(apiKey: 'chave-ruim', prompt: any(named: 'prompt')))
          .thenThrow(const LlmApiException('unauthorized', statusCode: 401));

      final resultado = await repository.testarConexao(
        provider: LlmProviderEscolhido.gpt4oMini,
        apiKey: 'chave-ruim',
      );

      expect(resultado.isLeft(), isTrue);
      resultado.match(
        (falha) => expect((falha as LlmFailure).isQuotaOrAuth, isTrue),
        (_) => fail('esperava Left'),
      );
    });
  });
}
