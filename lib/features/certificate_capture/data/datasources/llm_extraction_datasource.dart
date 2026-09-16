import 'package:flutter/services.dart' show rootBundle;
import 'package:fpdart/fpdart.dart' show Either, Left, Right;

import '../../../../core/error/failures.dart';
import '../../../llm_shared/domain/repositories/llm_repository.dart';

/// Monta o prompt de extração de certificado (título, instituição, carga
/// horária, data) e chama [LlmRepository]. O prompt em si é um asset
/// versionado (não hardcoded aqui) para permitir ajuste sem recompilar —
/// ver DECISOES.md, "Prompts como assets versionados". A sugestão de
/// vínculo com o currículo Lattes NÃO faz parte desta extração: é
/// calculada depois, comparando certificados já sincronizados contra um
/// edital (`SugerirVinculos`, módulo 4) — ver `sugerir_vinculos.dart`.
class LlmExtractionDatasource {
  final LlmRepository _llmRepository;

  const LlmExtractionDatasource(this._llmRepository);

  static const String _promptAssetPath = 'assets/prompts/extracao_certificado.txt';

  /// Chaves que precisam estar presentes na resposta do LLM para o
  /// certificado ser considerado extraído com sucesso — "instituicao" e
  /// "titulo" são as únicas que a UI de revisão humana (módulo 4) não tem
  /// como preencher razoavelmente sozinha; "cargaHorariaHoras" e "data"
  /// podem legitimamente vir `null` (ver prompt).
  static const _chavesObrigatorias = ['titulo', 'instituicao'];

  Future<Either<Failure, Map<String, dynamic>>> extrair({
    required List<int> imagemBytes,
    required String mimeType,
  }) async {
    final String prompt;
    try {
      prompt = await rootBundle.loadString(_promptAssetPath);
    } catch (e) {
      return Left(LlmFailure('Não foi possível carregar o prompt de extração: $e'));
    }

    final resultado = await _llmRepository.extrairJsonDeImagem(
      imagemBytes: imagemBytes,
      mimeType: mimeType,
      promptExtracao: prompt,
    );

    return resultado.flatMap(_validarChavesObrigatorias);
  }

  Either<Failure, Map<String, dynamic>> _validarChavesObrigatorias(Map<String, dynamic> json) {
    final chavesFaltando = _chavesObrigatorias.where((chave) => json[chave] == null).toList();
    if (chavesFaltando.isNotEmpty) {
      return Left(
        LlmFailure(
          'O modelo não conseguiu identificar ${chavesFaltando.join(", ")} neste certificado.',
        ),
      );
    }
    return Right(json);
  }
}
