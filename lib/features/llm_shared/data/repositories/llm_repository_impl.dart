import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;

import '../../../../core/error/failures.dart';
import '../../domain/entities/llm_provider_escolhido.dart';
import '../../domain/repositories/llm_repository.dart';
import '../datasources/gemini_llm_datasource.dart';
import '../datasources/llm_api_exception.dart';
import '../datasources/llm_api_key_store.dart';
import '../datasources/openai_llm_datasource.dart';

/// Implementação real do repositório de LLM compartilhado. Fora de
/// [testarConexao] (chamado explicitamente pela tela de configuração, que
/// sabe qual provedor o usuário está tentando salvar), os outros dois
/// métodos NÃO recebem o provedor como parâmetro — resolvem "o provedor
/// configurado agora" lendo [LlmApiKeyStore], porque o resto do app
/// (captura de certificado, interpretação de edital) sempre opera sobre a
/// escolha BYOK já feita, nunca sobre uma escolha ad-hoc por chamada.
class LlmRepositoryImpl implements LlmRepository {
  final GeminiLlmDatasource _gemini;
  final OpenAiLlmDatasource _openAi;
  final LlmApiKeyStore _apiKeyStore;

  const LlmRepositoryImpl(this._gemini, this._openAi, this._apiKeyStore);

  @override
  Future<Either<Failure, Map<String, dynamic>>> extrairJsonDeImagem({
    required List<int> imagemBytes,
    required String mimeType,
    required String promptExtracao,
  }) async {
    final configuracao = await _resolverConfiguracaoAtiva();
    return configuracao.match(
      (falha) async => Left(falha),
      (c) => _chamarComTratamento(
        () => _gerarJson(c, promptExtracao, imagemBytes: imagemBytes, mimeType: mimeType),
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> extrairJsonDeTexto({
    required String texto,
    required String promptExtracao,
  }) async {
    final configuracao = await _resolverConfiguracaoAtiva();
    return configuracao.match(
      (falha) async => Left(falha),
      (c) => _chamarComTratamento(() => _gerarJson(c, '$promptExtracao\n\n$texto')),
    );
  }

  @override
  Future<Either<Failure, Unit>> testarConexao({
    required LlmProviderEscolhido provider,
    required String apiKey,
  }) async {
    const promptMinimo = 'Responda apenas com o JSON {"ok": true}, sem nenhum texto adicional.';
    try {
      await (provider == LlmProviderEscolhido.geminiFlash
          ? _gemini.gerarJson(apiKey: apiKey, prompt: promptMinimo)
          : _openAi.gerarJson(apiKey: apiKey, prompt: promptMinimo));
      return const Right(unit);
    } on LlmApiException catch (e) {
      return Left(LlmFailure(e.message, isQuotaOrAuth: e.isQuotaOrAuth));
    } catch (e) {
      return Left(LlmFailure('Não foi possível conectar ao provedor: $e'));
    }
  }

  Future<Map<String, dynamic>> _gerarJson(
    _ConfiguracaoLlmAtiva config,
    String prompt, {
    List<int>? imagemBytes,
    String? mimeType,
  }) {
    return config.provider == LlmProviderEscolhido.geminiFlash
        ? _gemini.gerarJson(
            apiKey: config.apiKey,
            prompt: prompt,
            imagemBytes: imagemBytes,
            mimeType: mimeType,
          )
        : _openAi.gerarJson(
            apiKey: config.apiKey,
            prompt: prompt,
            imagemBytes: imagemBytes,
            mimeType: mimeType,
          );
  }

  Future<Either<Failure, _ConfiguracaoLlmAtiva>> _resolverConfiguracaoAtiva() async {
    final provider = await _apiKeyStore.obterProvedorEscolhido();
    if (provider == null) {
      return const Left(
        LlmFailure(
          'Nenhum provedor de LLM configurado ainda. Configure sua chave de API em Configurações.',
          isQuotaOrAuth: true,
        ),
      );
    }

    final apiKey = await _apiKeyStore.obterChave(provider);
    if (apiKey == null || apiKey.isEmpty) {
      return const Left(
        LlmFailure(
          'Chave de API do provedor configurado não foi encontrada. Configure-a novamente em Configurações.',
          isQuotaOrAuth: true,
        ),
      );
    }

    return Right(_ConfiguracaoLlmAtiva(provider: provider, apiKey: apiKey));
  }

  Future<Either<Failure, Map<String, dynamic>>> _chamarComTratamento(
    Future<Map<String, dynamic>> Function() chamada,
  ) async {
    try {
      return Right(await chamada());
    } on LlmApiException catch (e) {
      return Left(LlmFailure(e.message, isQuotaOrAuth: e.isQuotaOrAuth));
    } catch (e) {
      return Left(LlmFailure('Falha inesperada ao chamar o provedor de LLM: $e'));
    }
  }
}

class _ConfiguracaoLlmAtiva {
  final LlmProviderEscolhido provider;
  final String apiKey;
  const _ConfiguracaoLlmAtiva({required this.provider, required this.apiKey});
}
