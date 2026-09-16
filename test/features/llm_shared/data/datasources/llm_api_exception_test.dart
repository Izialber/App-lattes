import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';

/// A Gemini API devolve 400 (não 401) para chave de API inválida — foi
/// exatamente o que aconteceu ao vivo (ver DECISOES.md): sem esses dois
/// comportamentos (400 em `isQuotaOrAuth`, extração da mensagem real do
/// corpo de erro), a UI mostrava só "status code 400" sem dizer o motivo.
void main() {
  DioException dioExceptionCom({required int statusCode, dynamic corpo}) {
    final requestOptions = RequestOptions(path: '/qualquer');
    return DioException(
      requestOptions: requestOptions,
      response: Response(
        requestOptions: requestOptions,
        statusCode: statusCode,
        data: corpo,
      ),
      message: 'response has a status code of $statusCode',
    );
  }

  group('LlmApiException.deChamadaHttp', () {
    test('extrai a mensagem real do corpo de erro (formato Gemini/OpenAI)', () {
      final e = dioExceptionCom(
        statusCode: 400,
        corpo: {
          'error': {'code': 400, 'message': 'API key not valid. Please pass a valid API key.'},
        },
      );

      final excecao = LlmApiException.deChamadaHttp('Gemini', e);

      expect(excecao.message, contains('API key not valid'));
      expect(excecao.statusCode, 400);
    });

    test('cai para a mensagem genérica do Dio quando o corpo não tem o formato esperado', () {
      final e = dioExceptionCom(statusCode: 500, corpo: 'erro de servidor sem JSON');

      final excecao = LlmApiException.deChamadaHttp('OpenAI', e);

      expect(excecao.message, contains('response has a status code of 500'));
    });

    test('cai para a mensagem genérica quando não há corpo de resposta nenhum', () {
      final requestOptions = RequestOptions(path: '/qualquer');
      final e = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
        message: 'Connection failed',
      );

      final excecao = LlmApiException.deChamadaHttp('Gemini', e);

      expect(excecao.message, contains('Connection failed'));
      expect(excecao.statusCode, isNull);
    });
  });

  group('isQuotaOrAuth', () {
    test('true para 400 (Gemini usa 400 para chave inválida, não 401)', () {
      expect(const LlmApiException('x', statusCode: 400).isQuotaOrAuth, isTrue);
    });

    test('true para 401, 403 e 429', () {
      expect(const LlmApiException('x', statusCode: 401).isQuotaOrAuth, isTrue);
      expect(const LlmApiException('x', statusCode: 403).isQuotaOrAuth, isTrue);
      expect(const LlmApiException('x', statusCode: 429).isQuotaOrAuth, isTrue);
    });

    test('false para 500 ou quando não há statusCode (erro de rede)', () {
      expect(const LlmApiException('x', statusCode: 500).isQuotaOrAuth, isFalse);
      expect(const LlmApiException('x').isQuotaOrAuth, isFalse);
    });
  });
}
