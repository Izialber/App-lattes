import 'dart:convert';

import 'llm_api_exception.dart';

/// Modelos menores (Gemini Flash, GPT-4o-mini) ocasionalmente envolvem o
/// JSON pedido em texto extra mesmo sob `response_format`/
/// `responseMimeType` — este parser tolera cercas de código markdown
/// (` ```json ... ``` `) antes de desistir, em vez de falhar num caso comum
/// e evitável. Compartilhado entre `GeminiLlmDatasource` e
/// `OpenAiLlmDatasource` porque as duas APIs devolvem o JSON como uma
/// string de texto dentro de um envelope diferente, mas o texto em si
/// precisa do mesmo tratamento.
Map<String, dynamic> decodificarJsonDoModelo(String textoCru) {
  final texto = _semCercaMarkdown(textoCru.trim());

  try {
    final decodificado = jsonDecode(texto);
    if (decodificado is! Map<String, dynamic>) {
      throw const FormatException('JSON raiz não é um objeto.');
    }
    return decodificado;
  } on FormatException catch (e) {
    throw LlmApiException('O modelo não retornou um JSON válido: $e');
  }
}

String _semCercaMarkdown(String texto) {
  if (!texto.startsWith('```')) return texto;

  final semAbertura = texto.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
  final semFechamento = semAbertura.endsWith('```')
      ? semAbertura.substring(0, semAbertura.length - 3)
      : semAbertura;
  return semFechamento.trim();
}
