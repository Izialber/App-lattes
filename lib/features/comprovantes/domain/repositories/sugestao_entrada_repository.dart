import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/entrada_lattes_ref.dart';
import '../entities/sugestao_lote.dart';

/// Pergunta ao LLM configurado (BYOK, `llm_shared`) a qual entrada do Lattes
/// cada arquivo do lote pertence, olhando só o caminho do arquivo — ver
/// `ArquivoParaSugestao`.
abstract class SugestaoEntradaRepository {
  /// Mapa `arquivo.id -> entrada.id`, com valor null pros arquivos que o
  /// modelo disse não ter entrada correspondente. Todo arquivo de [arquivos]
  /// aparece como chave; ids de entrada inventados pelo modelo viram null.
  /// `Left(LlmFailure)` quando o provedor falha — o use case decide o
  /// fallback, não este repositório.
  Future<Either<Failure, Map<String, String?>>> sugerirPorLlm({
    required List<ArquivoParaSugestao> arquivos,
    required List<EntradaLattesRef> entradas,
  });
}
