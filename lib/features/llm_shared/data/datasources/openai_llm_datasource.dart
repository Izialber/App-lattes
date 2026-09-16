import 'dart:convert';

import 'package:dio/dio.dart';

import 'llm_api_exception.dart';
import 'llm_json_utils.dart';

/// Chamada HTTP direta à API da OpenAI (`api.openai.com/v1/chat/completions`,
/// modelo `gpt-4o-mini`) a partir do navegador, com a chave BYOK no header
/// `Authorization`. CORS: diferente do Gemini, a OpenAI historicamente
/// restringe CORS para chamadas client-side — ver RISCOS.md, seção de CORS.
/// Esta implementação está pronta e é usada quando o usuário escolhe este
/// provedor, mas o comportamento de CORS em produção ainda não foi validado
/// contra uma chave real (ver DECISOES.md); se a OpenAI bloquear, o sintoma
/// é um erro de rede genérico igual ao que ocorreu com o endpoint de token
/// OAuth antes da correção de CSP — o console do navegador é o primeiro
/// lugar a checar.
class OpenAiLlmDatasource {
  OpenAiLlmDatasource([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o-mini';

  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) async {
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
      throw LlmApiException(
        'Falha ao chamar a API da OpenAI: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }

    return decodificarJsonDoModelo(_extrairTexto(response.data));
  }

  String _extrairTexto(dynamic data) {
    try {
      final escolhas = data['choices'] as List;
      return escolhas.first['message']['content'] as String;
    } catch (e) {
      throw LlmApiException('Resposta da OpenAI fora do formato esperado: $e');
    }
  }
}
