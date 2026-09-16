import 'package:dio/dio.dart';

/// Exceção interna de infraestrutura lançada pelos datasources de LLM
/// (Gemini/OpenAI). Nunca cruza a fronteira para `domain`/`presentation` —
/// `LlmRepositoryImpl` captura e traduz para [LlmFailure].
class LlmApiException implements Exception {
  final String message;
  final int? statusCode;

  const LlmApiException(this.message, {this.statusCode});

  /// Monta a partir de um [DioException] tentando extrair a mensagem real do
  /// corpo de erro da API (`{"error": {"message": "..."}}` — formato usado
  /// tanto pelo Gemini quanto pela OpenAI) em vez do texto genérico do Dio
  /// ("response has a status code of 400"), que não diz qual foi o problema
  /// de verdade. Sem isso, um erro como "API key not valid" (Gemini
  /// devolve 400, não 401, para chave inválida) fica indistinguível de
  /// qualquer outro 400 só olhando a tela.
  factory LlmApiException.deChamadaHttp(String provedor, DioException e) {
    final mensagemDaApi = _mensagemDoCorpoDeErro(e.response?.data);
    return LlmApiException(
      'Falha ao chamar a API do $provedor: ${mensagemDaApi ?? e.message}',
      statusCode: e.response?.statusCode,
    );
  }

  static String? _mensagemDoCorpoDeErro(dynamic corpo) {
    try {
      final mensagem = (corpo as Map)['error']['message'];
      return mensagem is String && mensagem.isNotEmpty ? mensagem : null;
    } catch (_) {
      return null;
    }
  }

  /// A Gemini API devolve 400 (não 401) para chave de API inválida/mal
  /// formada ("API_KEY_INVALID") — por isso 400 entra aqui junto com
  /// 401/403 (chave inválida/sem permissão) e 429 (quota excedida): todos
  /// são casos em que a UI deve pedir para o usuário revisar a chave BYOK,
  /// em vez de tratar como uma falha de rede transitória qualquer — ver
  /// `LlmRepository.testarConexao`.
  bool get isQuotaOrAuth =>
      statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 429;

  @override
  String toString() => 'LlmApiException($statusCode): $message';
}
