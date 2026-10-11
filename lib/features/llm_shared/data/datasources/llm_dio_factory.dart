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
/// não otimizar latência.
Dio criarDioLlm() => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 30),
    ));
