import 'dart:convert';

import 'package:dio/dio.dart';

import 'llm_api_exception.dart';
import 'llm_json_utils.dart';

/// Chamada HTTP direta à API do Gemini (`generativelanguage.googleapis.com`)
/// a partir do navegador, com a chave BYOK em query param. CORS: a API do
/// Gemini permite chamadas de origem arbitrária com API key (ver RISCOS.md,
/// "CORS nas chamadas ao LLM"); caso isso mude, o ponto de troca é este
/// datasource, sem impacto em `domain`.
class GeminiLlmDatasource {
  GeminiLlmDatasource([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// `gemini-2.0-flash` (versão original desta implementação) passou a
  /// devolver 404 — a Google descontinuou o id datado. Trocado para o alias
  /// oficial `gemini-flash-latest`, que a própria Google promete manter
  /// sempre apontando para o Flash recomendado do momento ("hot-swapped a
  /// cada novo release", com aviso de 2 semanas por e-mail antes de
  /// mudanças que quebram compatibilidade) — evita que este id fique stale
  /// de novo. Ver https://ai.google.dev/gemini-api/docs/models.
  static const _model = 'gemini-flash-latest';

  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imagemBytes != null && mimeType != null)
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(imagemBytes),
          },
        },
    ];

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_baseUrl/$_model:generateContent',
        queryParameters: {'key': apiKey},
        data: {
          'contents': [
            {'parts': parts},
          ],
          'generationConfig': {'responseMimeType': 'application/json'},
        },
      );
    } on DioException catch (e) {
      throw LlmApiException(
        'Falha ao chamar a API do Gemini: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }

    return decodificarJsonDoModelo(_extrairTexto(response.data));
  }

  String _extrairTexto(dynamic data) {
    try {
      final candidatos = data['candidates'] as List;
      final partes = candidatos.first['content']['parts'] as List;
      return partes.first['text'] as String;
    } catch (e) {
      throw LlmApiException('Resposta do Gemini fora do formato esperado: $e');
    }
  }
}
