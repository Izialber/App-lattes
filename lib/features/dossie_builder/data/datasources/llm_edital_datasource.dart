import '../../../llm_shared/domain/repositories/llm_repository.dart';

/// Extrai texto do PDF do edital (via `syncfusion_flutter_pdf`, página a
/// página, cedendo o event loop entre páginas) e envia ao LLM com o prompt
/// de interpretação de critérios de Prova de Títulos.
///
/// PENDENTE (fora do escopo do entregável 5): implementação real, incluindo
/// tratamento de editais digitalizados como imagem (sem texto extraível) —
/// nesse caso, retornar falha clara pedindo que o usuário confirme os
/// critérios manualmente, em vez de enviar página em branco ao LLM.
class LlmEditalDatasource {
  final LlmRepository _llmRepository;

  const LlmEditalDatasource(this._llmRepository);

  static const String _promptAssetPath = 'assets/prompts/extracao_criterios_edital.txt';

  Future<Map<String, dynamic>> extrairCriterios(List<int> editalPdfBytes) {
    throw UnimplementedError('LlmEditalDatasource.extrairCriterios: pendente (ver DECISOES.md)');
  }
}
