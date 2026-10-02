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
///
/// Dois modelos diferentes, não um só: achado ao vivo — usar o modelo de
/// visão também pra texto puro (ex.: interpretar um edital inteiro) estoura
/// o limite de tokens por minuto do plano gratuito da Groq, que é BEM mais
/// apertado pro modelo de visão (7000 TPM) do que pros modelos de texto
/// (`llama-3.1-8b-instant`, 6000 TPM mas sem o overhead de processar
/// imagem — na prática aguenta textos mais longos antes de estourar, e tem
/// RPM/RPD maiores). Visão só entra quando há de fato uma imagem anexada.
class GroqLlmDatasource {
  GroqLlmDatasource([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _modeloTexto = 'llama-3.1-8b-instant';
  static const _modeloVisao = 'qwen/qwen3.8-27b';

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
          'model': imagemBytes != null && mimeType != null ? _modeloVisao : _modeloTexto,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'user', 'content': content},
          ],
        },
      );
    } on DioException catch (e) {
      final excecao = LlmApiException.deChamadaHttp('Groq', e);
      // "Request too large... tokens per minute (ITPM)" é a mensagem bruta
      // da Groq quando o texto enviado estoura a cota do plano gratuito —
      // acontece com editais longos. Mensagem técnica da API trocada por
      // uma acionável, mesmo espírito do aviso de PDF acima.
      if (excecao.message.contains('tokens per minute')) {
        throw const LlmApiException(
          'Este texto é grande demais pro plano gratuito da Groq (limite de tokens por '
          'minuto). Troque para outro provedor em Configurações pra este documento '
          '(Gemini Flash tem limite bem mais folgado).',
        );
      }
      throw excecao;
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
