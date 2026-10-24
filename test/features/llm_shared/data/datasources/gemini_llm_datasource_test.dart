import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/llm_shared/data/datasources/gemini_llm_datasource.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';

/// Responde em sequência com [respostas], sem tocar a rede.
class _AdapterSequencial implements HttpClientAdapter {
  _AdapterSequencial(this.respostas);

  final List<(int, Map<String, dynamic>)> respostas;
  var chamadas = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, corpo) = respostas[chamadas++];
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

const _altaDemanda = {
  'error': {
    'code': 503,
    'message': 'This model is currently experiencing high demand. Spikes in demand are usually '
        'temporary. Please try again later.',
    'status': 'UNAVAILABLE',
  },
};

const _chaveInvalida = {
  'error': {'code': 400, 'message': 'API key not valid. Please pass a valid API key.'},
};

Map<String, dynamic> _respostaComTexto(String texto) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': texto},
            ],
          },
        },
      ],
    };

GeminiLlmDatasource _datasourceCom(_AdapterSequencial adapter) => GeminiLlmDatasource(Dio()..httpClientAdapter = adapter, Duration.zero);

void main() {
  test('503 de alta demanda: tenta de novo e usa a resposta seguinte', () async {
    final adapter = _AdapterSequencial([
      (503, _altaDemanda),
      (200, _respostaComTexto('{"ok": true}')),
    ]);

    final json = await _datasourceCom(adapter).gerarJson(apiKey: 'k', prompt: 'p');

    expect(json, {'ok': true});
    expect(adapter.chamadas, 2);
  });

  test('503 persistente: desiste depois de 3 tentativas com a mensagem do provedor', () async {
    final adapter = _AdapterSequencial([
      (503, _altaDemanda),
      (503, _altaDemanda),
      (503, _altaDemanda),
    ]);

    await expectLater(
      _datasourceCom(adapter).gerarJson(apiKey: 'k', prompt: 'p'),
      throwsA(isA<LlmApiException>()
          .having((e) => e.message, 'message', contains('high demand'))),
    );
    expect(adapter.chamadas, 3);
  });

  test('chave inválida não é repetida', () async {
    final adapter = _AdapterSequencial([(400, _chaveInvalida)]);

    await expectLater(
      _datasourceCom(adapter).gerarJson(apiKey: 'k', prompt: 'p'),
      throwsA(isA<LlmApiException>()),
    );
    expect(adapter.chamadas, 1);
  });
}
