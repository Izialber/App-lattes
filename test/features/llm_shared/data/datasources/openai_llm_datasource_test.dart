import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/llm_shared/data/datasources/llm_api_exception.dart';
import 'package:certificados_lattes/features/llm_shared/data/datasources/openai_llm_datasource.dart';

/// O endpoint de chat completions da OpenAI só aceita imagem em
/// `image_url` — PDF exigiria a API de Files/Assistants, fora do escopo
/// desta implementação. `gerarJson` deve recusar antes de tentar a chamada
/// HTTP (não faz sentido testar via rede/mock de Dio; é uma checagem pura
/// no início do método).
void main() {
  test('rejeita application/pdf sem chamar a API', () async {
    final datasource = OpenAiLlmDatasource();

    await expectLater(
      datasource.gerarJson(
        apiKey: 'chave-qualquer',
        prompt: 'prompt',
        imagemBytes: const [1, 2, 3],
        mimeType: 'application/pdf',
      ),
      throwsA(isA<LlmApiException>()),
    );
  });
}
