import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../llm_shared/domain/repositories/llm_repository.dart';

/// Extrai texto do PDF do edital (via `syncfusion_flutter_pdf`) e envia ao
/// LLM com o prompt de interpretação de critérios de Prova de Títulos.
///
/// Editais digitalizados como imagem (sem texto selecionável) não têm como
/// ser lidos por `PdfTextExtractor` — nesse caso, lança um erro claro (ver
/// [extrairCriterios]) em vez de mandar um texto vazio ao LLM, que
/// inventaria critérios a partir de nada. A UI de checklist (módulo 4)
/// sempre permite edição manual dos critérios de qualquer forma.
class LlmEditalDatasource {
  final LlmRepository _llmRepository;

  const LlmEditalDatasource(this._llmRepository);

  static const String _promptAssetPath = 'assets/prompts/extracao_criterios_edital.txt';

  Future<Map<String, dynamic>> extrairCriterios(List<int> editalPdfBytes) async {
    final texto = _extrairTextoDoPdf(editalPdfBytes);
    if (texto.trim().isEmpty) {
      throw StateError(
        'Não foi possível ler texto deste PDF — provavelmente é um edital digitalizado '
        '(imagem escaneada, sem texto selecionável). Preencha os critérios manualmente.',
      );
    }

    final prompt = await rootBundle.loadString(_promptAssetPath);
    final resultado = await _llmRepository.extrairJsonDeTexto(
      texto: texto,
      promptExtracao: prompt,
    );

    return resultado.match(
      (falha) => throw StateError(falha.message),
      (json) => json,
    );
  }

  String _extrairTextoDoPdf(List<int> bytes) {
    final documento = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(documento).extractText();
    } finally {
      documento.dispose();
    }
  }
}
