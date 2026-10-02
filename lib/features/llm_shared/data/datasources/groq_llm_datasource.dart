import 'dart:convert';

import 'package:dio/dio.dart';

import 'llm_api_exception.dart';
import 'llm_json_utils.dart';

/// Chamada HTTP direta à API da Groq (`api.groq.com/openai/v1/chat/
/// completions`) a partir do navegador — a Groq expõe uma API COMPATÍVEL
/// com a da OpenAI (mesmo formato de request/response), então esta
/// implementação espelha `OpenAiLlmDatasource` quase inteira, só trocando
/// endpoint/modelo. Gratuito (sem cartão de crédito), por decisão explícita
/// do usuário — ver DECISOES.md.
///
/// ATENÇÃO: `qwen/qwen3.8-27b` (único modelo com suporte a imagem na Groq
/// hoje, confirmado em console.groq.com/docs/vision em 2026-10) é o ponto
/// mais frágil desta integração — modelos de visão na Groq mudam/são
/// descontinuados com frequência maior que os outros provedores. Se a
/// extração de certificado em imagem parar de funcionar com erro 404/
/// "model decommissioned", este é o primeiro lugar a checar.
class GroqLlmDatasource {
  GroqLlmDatasource([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'qwen/qwen3.8-27b';

  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) async {
    if (mimeType == 'application/pdf') {
      // Mesma limitação da OpenAI: a API de chat completions só aceita
      // imagem em image_url (a Groq não tem um endpoint de arquivos/PDF
      // nativo) — falha explícita é melhor que um erro genérico da API.
      throw const LlmApiException(
        'A Groq não suporta certificados em PDF neste app ainda. '
        'Troque para o Gemini Flash em Configurações, ou envie este certificado como imagem.',
      );
    }

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
      if (imagemBytes != null && mimeType != null)
        {
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,${base64Encode(imagemBytes)}'},
        },
    ];

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        _endpoint,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
        data: {
          'model': _model,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'user', 'content': content},
          ],
        },
      );
    } on DioException catch (e) {
      throw LlmApiException.deChamadaHttp('Groq', e);
    }

    return decodificarJsonDoModelo(_extrairTexto(response.data));
  }

  String _extrairTexto(dynamic data) {
    try {
      final escolhas = data['choices'] as List;
      return escolhas.first['message']['content'] as String;
    } catch (e) {
      throw LlmApiException('Resposta da Groq fora do formato esperado: $e');
    }
  }
}
