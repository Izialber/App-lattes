import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_json_utils.dart';

/// Modelos menores ocasionalmente envolvem o JSON pedido em cerca de código
/// markdown mesmo sob `response_format: json_object`/`responseMimeType:
/// application/json` — este parser precisa tolerar isso sem exigir que
/// GeminiLlmDatasource/OpenAiLlmDatasource dupliquem a mesma lógica.
void main() {
  test('decodifica JSON puro sem nenhuma formatação extra', () {
    final resultado = decodificarJsonDoModelo('{"titulo": "Curso X", "cargaHorariaHoras": 40}');
    expect(resultado, {'titulo': 'Curso X', 'cargaHorariaHoras': 40});
  });

  test('remove cerca de código markdown com a linguagem anotada', () {
    final resultado = decodificarJsonDoModelo('```json\n{"titulo": "Curso X"}\n```');
    expect(resultado, {'titulo': 'Curso X'});
  });

  test('remove cerca de código markdown sem a linguagem anotada', () {
    final resultado = decodificarJsonDoModelo('```\n{"titulo": "Curso X"}\n```');
    expect(resultado, {'titulo': 'Curso X'});
  });

  test('tolera espaço em branco ao redor do JSON', () {
    final resultado = decodificarJsonDoModelo('  \n{"titulo": "Curso X"}\n  ');
    expect(resultado, {'titulo': 'Curso X'});
  });

  test('lança LlmApiException quando o texto não é JSON válido', () {
    expect(
      () => decodificarJsonDoModelo('não é json'),
      throwsA(isA<LlmApiException>()),
    );
  });

  test('lança LlmApiException quando o JSON raiz não é um objeto', () {
    expect(
      () => decodificarJsonDoModelo('[1, 2, 3]'),
      throwsA(isA<LlmApiException>()),
    );
  });
}
