import 'dart:convert';

import 'package:dio/dio.dart';

import 'llm_api_exception.dart';
import 'llm_json_utils.dart';

/// Chamada HTTP direta à API da Anthropic (`api.anthropic.com/v1/messages`,
/// modelo `claude-haiku-4-5`) a partir do navegador, com a chave BYOK no
/// header `x-api-key`. CORS: a Anthropic bloqueia chamadas client-side por
/// padrão (desencoraja uso direto do browser por segurança) a menos que o
/// header `anthropic-dangerous-direct-browser-access: true` seja enviado —
/// sem ele, toda chamada falha com erro de CORS genérico, mesmo padrão
/// silencioso já visto com outras integrações nesta sessão (ver RISCOS.md,
/// "CORS nas chamadas ao LLM"). Diferente da OpenAI, a Anthropic lê PDF
/// nativamente (`type: 'document'`) — sem a limitação que
/// `OpenAiLlmDatasource` tem.
class AnthropicLlmDatasource {
  AnthropicLlmDatasource([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  // Sem sufixo de data de propósito — IDs de modelo da Anthropic são
  // completos como estão na documentação oficial; acrescentar uma data
  // (ex. '-20251001') quebra a chamada com 404 "model not found".
  static const _model = 'claude-haiku-4-5';
  static const _anthropicVersion = '2023-06-01';

  Future<Map<String, dynamic>> gerarJson({
    required String apiKey,
    required String prompt,
    List<int>? imagemBytes,
    String? mimeType,
  }) async {
    // Documento/imagem ANTES do texto — ordem recomendada pela própria
    // documentação da Anthropic pra blocos `document` (afeta qualidade da
    // extração, não é só estético).
    final content = <Map<String, dynamic>>[
      if (imagemBytes != null && mimeType != null)
        {
          'type': mimeType == 'application/pdf' ? 'document' : 'image',
          'source': {
            'type': 'base64',
            'media_type': mimeType,
            'data': base64Encode(imagemBytes),
          },
        },
      {'type': 'text', 'text': prompt},
    ];

    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        _endpoint,
        options: Options(headers: {
          'x-api-key': apiKey,
          'anthropic-version': _anthropicVersion,
          'anthropic-dangerous-direct-browser-access': 'true',
        }),
        data: {
          'model': _model,
          'max_tokens': 4096,
          'messages': [
            {'role': 'user', 'content': content},
          ],
        },
      );
    } on DioException catch (e) {
      throw LlmApiException.deChamadaHttp('Anthropic', e);
    }

    return decodificarJsonDoModelo(_extrairTexto(response.data));
  }

  String _extrairTexto(dynamic data) {
    try {
      final blocos = data['content'] as List;
      return blocos.firstWhere((b) => b['type'] == 'text')['text'] as String;
    } catch (e) {
      throw LlmApiException('Resposta da Anthropic fora do formato esperado: $e');
    }
  }
}
