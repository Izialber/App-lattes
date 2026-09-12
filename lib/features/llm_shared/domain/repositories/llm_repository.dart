import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/llm_provider_escolhido.dart';

/// Cliente de LLM compartilhado entre `certificate_capture` (extração de
/// dados de certificado) e `dossie_builder` (interpretação de edital).
/// BYOK: a chave nunca é lida diretamente por este repositório — ela chega
/// via `LlmApiKeyStore` (data/datasources), que por sua vez lê de
/// `SecureStorageService`. Ver RISCOS.md, "Chave de LLM (BYOK)".
abstract class LlmRepository {
  /// Envia uma imagem e um prompt de extração; espera resposta em JSON
  /// estruturado. Implementação valida o schema da resposta e retorna
  /// [LlmFailure] se o modelo não seguir o formato pedido (comum em modelos
  /// menores como Gemini Flash / GPT-4o-mini sob prompts longos).
  Future<Either<Failure, Map<String, dynamic>>> extrairJsonDeImagem({
    required List<int> imagemBytes,
    required String mimeType,
    required String promptExtracao,
  });

  /// Envia texto (extraído do PDF do edital) e um prompt de interpretação de
  /// critérios; espera resposta em JSON estruturado.
  Future<Either<Failure, Map<String, dynamic>>> extrairJsonDeTexto({
    required String texto,
    required String promptExtracao,
  });

  /// Faz uma chamada mínima (o menor prompt possível, sem custo relevante)
  /// só para confirmar que a chave BYOK é válida e o provedor está
  /// alcançável — por decisão explícita do usuário, chamado pela tela de
  /// configuração de chave NO MOMENTO EM QUE ELA É SALVA, em vez de deixar
  /// o usuário descobrir que a chave é inválida só no meio de um fluxo de
  /// captura ou de montagem de dossiê (ver DECISOES.md). Retorna
  /// `Either.left(LlmFailure(isQuotaOrAuth: true))` quando a chave é
  /// rejeitada pelo provedor, e `Either.left(LlmFailure(...))` (sem a flag)
  /// para falhas de rede/CORS que não significam necessariamente chave
  /// inválida.
  Future<Either<Failure, Unit>> testarConexao({
    required LlmProviderEscolhido provider,
    required String apiKey,
  });
}
