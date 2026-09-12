import '../../../llm_shared/domain/repositories/llm_repository.dart';

/// Monta o prompt de extração de certificado (título, instituição, carga
/// horária, data, sugestão de vínculo) e chama [LlmRepository]. O prompt em
/// si é um asset versionado (não hardcoded aqui) para permitir ajuste sem
/// recompilar — ver DECISOES.md, "Prompts como assets versionados".
class LlmExtractionDatasource {
  final LlmRepository _llmRepository;

  const LlmExtractionDatasource(this._llmRepository);

  static const String _promptAssetPath = 'assets/prompts/extracao_certificado.txt';

  Future<Map<String, dynamic>> extrair({
    required List<int> imagemBytes,
    required String mimeType,
  }) {
    // TODO: carregar _promptAssetPath, chamar _llmRepository.extrairJsonDeImagem
    // e validar as chaves obrigatorias do JSON de resposta antes de retornar.
    throw UnimplementedError('LlmExtractionDatasource.extrair: pendente (ver DECISOES.md)');
  }
}
