import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/llm_shared/data/datasources/groq_llm_datasource.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';

/// Responde em sequência com as respostas de [respostas] e guarda o corpo
/// de cada requisição recebida, sem tocar a rede.
class _AdapterSequencial implements HttpClientAdapter {
  _AdapterSequencial(this.respostas);

  final List<(int, Map<String, dynamic>)> respostas;
  final corposRecebidos = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    corposRecebidos.add(Map<String, dynamic>.from(options.data as Map));
    final (status, corpo) = respostas[corposRecebidos.length - 1];
    return ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _respostaComTexto(String texto) => {
      'choices': [
        {
          'message': {'content': texto},
        },
      ],
    };

const _falhaJsonMode = {
  'error': {
    'message': "Failed to validate JSON. Please adjust your prompt. See 'failed_generation' for more details.",
    'code': 'json_validate_failed',
  },
};

GroqLlmDatasource _datasourceCom(_AdapterSequencial adapter) =>
    GroqLlmDatasource(Dio()..httpClientAdapter = adapter);

void main() {
  test('rejeita application/pdf sem chamar a API', () async {
    final adapter = _AdapterSequencial([]);

    await expectLater(
      _datasourceCom(adapter).gerarJson(
        apiKey: 'chave',
        prompt: 'prompt',
        imagemBytes: const [1, 2, 3],
        mimeType: 'application/pdf',
      ),
      throwsA(isA<LlmApiException>()),
    );
    expect(adapter.corposRecebidos, isEmpty);
  });

  test('json_validate_failed: tenta de novo sem response_format e decodifica JSON em markdown', () async {
    final adapter = _AdapterSequencial([
      (400, _falhaJsonMode),
      (200, _respostaComTexto('```json\n{"criterios": []}\n```')),
    ]);

    final json = await _datasourceCom(adapter).gerarJson(apiKey: 'chave', prompt: 'prompt');

    expect(json, {'criterios': []});
    expect(adapter.corposRecebidos, hasLength(2));
    expect(adapter.corposRecebidos.first.containsKey('response_format'), isTrue);
    expect(adapter.corposRecebidos.last.containsKey('response_format'), isFalse);
  });

  test('outros erros 400 não disparam a segunda tentativa', () async {
    final adapter = _AdapterSequencial([
      (400, {
        'error': {'message': 'Invalid API Key', 'code': 'invalid_api_key'},
      }),
    ]);

    await expectLater(
      _datasourceCom(adapter).gerarJson(apiKey: 'chave', prompt: 'prompt'),
      throwsA(isA<LlmApiException>()),
    );
    expect(adapter.corposRecebidos, hasLength(1));
  });

  test('modelo de texto: raciocínio baixo e espaço de saída para o JSON', () async {
    final adapter = _AdapterSequencial([(200, _respostaComTexto('{"ok": true}'))]);

    await _datasourceCom(adapter).gerarJson(apiKey: 'chave', prompt: 'prompt');

    final corpo = adapter.corposRecebidos.single;
    expect(corpo['reasoning_effort'], 'low');
    expect(corpo['max_completion_tokens'], greaterThanOrEqualTo(4096));
  });

  test('resposta cortada por tamanho vira erro claro, não "JSON inválido"', () async {
    final adapter = _AdapterSequencial([
      (200, {
        'choices': [
          {
            'finish_reason': 'length',
            'message': {'content': ''},
          },
        ],
      }),
    ]);

    await expectLater(
      _datasourceCom(adapter).gerarJson(apiKey: 'chave', prompt: 'prompt'),
      throwsA(isA<LlmApiException>()
          .having((e) => e.message, 'message', contains('cortada'))),
    );
  });
}
