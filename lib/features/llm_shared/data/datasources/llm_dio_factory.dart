import 'package:dio/dio.dart';

/// `Dio()` sem configuração nenhuma não tem timeout — uma chamada de LLM
/// travada (provedor lento, rate limit silencioso, rede ruim) fica pendurada
/// indefinidamente, sem jeito de cancelar, com o spinner da UI preso pra
/// sempre. Achado em revisão de código, compartilhado pelas 4 datasources
/// de LLM (`GeminiLlmDatasource`, `OpenAiLlmDatasource`,
/// `AnthropicLlmDatasource`, `GroqLlmDatasource`) em vez de configurado
/// individualmente em cada uma.
///
/// Valores generosos de propósito: extração de um edital longo (texto grande
/// de entrada, JSON grande de saída) pode legitimamente levar dezenas de
/// segundos num provedor sob carga — o objetivo aqui é só ter ALGUM teto,
/// não otimizar latência. Os 180s de resposta vêm de uma medição ao vivo
/// (2026-10-24): sob alta demanda o Gemini levou 81s e 110s para responder
/// a uma pergunta trivial; com 90s, a extração de um edital caía no timeout.
Dio criarDioLlm() => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 180),
      sendTimeout: const Duration(seconds: 30),
    ));

/// Status de "provedor sobrecarregado, tente de novo": 503 do Gemini ("This
/// model is currently experiencing high demand") e 529 da Anthropic
/// ("overloaded_error"). Chave inválida e cota (400/401/429) NÃO entram: repetir
/// não muda o resultado e só atrasa o fallback.
const _statusDeSobrecarga = {503, 529};

/// `dio.post` que repete até [tentativas] vezes quando o provedor responde
/// com sobrecarga, esperando [espera] entre uma e outra. Qualquer outro erro
/// (ou a última sobrecarga) sobe como [DioException], igual a `dio.post`.
Future<Response<dynamic>> postComRetentativaEmSobrecarga(
  Dio dio,
  String url, {
  Object? data,
  Map<String, dynamic>? queryParameters,
  Options? options,
  int tentativas = 3,
  Duration espera = const Duration(seconds: 3),
}) async {
  for (var tentativa = 1;; tentativa++) {
    try {
      return await dio.post<dynamic>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      final sobrecarga = _statusDeSobrecarga.contains(e.response?.statusCode);
      if (!sobrecarga || tentativa >= tentativas) rethrow;
      await Future<void>.delayed(espera * tentativa);
    }
  }
}
