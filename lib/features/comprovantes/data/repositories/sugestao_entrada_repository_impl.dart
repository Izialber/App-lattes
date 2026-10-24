import 'package:fpdart/fpdart.dart' show Either, Left, Right;

import '../../../../core/error/failures.dart';
import '../../../llm_shared/domain/repositories/llm_repository.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/sugestao_lote.dart';
import '../../domain/repositories/sugestao_entrada_repository.dart';

const _instrucoes = '''
Você vai ligar arquivos de comprovantes (certificados, diplomas, históricos escolares,
declarações) às entradas do currículo Lattes de uma pessoa. Você vê SÓ o caminho de cada
arquivo (nome e subpasta), nunca o conteúdo.

Regras:
- Cada arquivo vai para no máximo UMA entrada. Vários arquivos podem ir para a mesma entrada
  (ex.: diploma + histórico, frente + verso, "1de2" e "2de2").
- Use o nome da subpasta como pista (ex.: "Diplomas/", "Eventos/").
- Se nenhuma entrada corresponder com segurança, use null. NÃO chute: um vínculo errado é pior
  que nenhum.
- Use só ids que existem nas listas abaixo.

Responda APENAS com um objeto JSON, sem texto adicional, no formato:
{"atribuicoes": {"a1": "e3", "a2": null}}
com uma chave para CADA arquivo.''';

/// Monta o texto enviado ao LLM — ids curtos (`e1`, `a1`...) em vez dos ids
/// reais (hash de 24 caracteres de `gerarIdEntrada`, uuid dos arquivos):
/// economiza tokens (limite apertado da Groq gratuita) e dá menos chance do
/// modelo copiar um id errado. Os mapas devolvidos traduzem de volta.
({String texto, Map<String, String> entradaPorIdCurto, Map<String, String> arquivoPorIdCurto})
    montarTextoMapeamento(List<ArquivoParaSugestao> arquivos, List<EntradaLattesRef> entradas) {
  final entradaPorIdCurto = <String, String>{};
  final arquivoPorIdCurto = <String, String>{};
  final buffer = StringBuffer('Entradas do currículo (id | seção | título | detalhes):\n');

  for (var i = 0; i < entradas.length; i++) {
    final e = entradas[i];
    final idCurto = 'e${i + 1}';
    entradaPorIdCurto[idCurto] = e.id;
    buffer.writeln('$idCurto | ${e.categoria.rotulo} | ${e.titulo}'
        '${e.subtitulo.isEmpty ? '' : ' | ${e.subtitulo}'}');
  }

  buffer.writeln('\nArquivos (id | caminho):');
  for (var i = 0; i < arquivos.length; i++) {
    final idCurto = 'a${i + 1}';
    arquivoPorIdCurto[idCurto] = arquivos[i].id;
    buffer.writeln('$idCurto | ${arquivos[i].caminho}');
  }

  return (
    texto: buffer.toString(),
    entradaPorIdCurto: entradaPorIdCurto,
    arquivoPorIdCurto: arquivoPorIdCurto,
  );
}

/// Traduz a resposta do modelo de volta pros ids reais. Tolerante ao que
/// modelos pequenos costumam fazer: id de entrada inexistente, valor que não
/// é string, arquivo faltando na resposta, espaço/maiúscula no id — tudo
/// isso vira null ("sem entrada") em vez de falhar o lote inteiro. Só falha
/// (FormatException) se não vier o objeto `atribuicoes`.
Map<String, String?> interpretarRespostaMapeamento(
  Map<String, dynamic> resposta, {
  required Map<String, String> entradaPorIdCurto,
  required Map<String, String> arquivoPorIdCurto,
}) {
  final atribuicoes = resposta['atribuicoes'];
  if (atribuicoes is! Map) {
    throw const FormatException('Resposta do modelo sem o objeto "atribuicoes".');
  }

  final normalizadas = {
    for (final entry in atribuicoes.entries)
      entry.key.toString().trim().toLowerCase(): entry.value,
  };

  return {
    for (final MapEntry(key: idCurto, value: arquivoId) in arquivoPorIdCurto.entries)
      arquivoId: switch (normalizadas[idCurto]) {
        final String valor => entradaPorIdCurto[valor.trim().toLowerCase()],
        _ => null,
      },
  };
}

/// Implementação via `LlmRepository` compartilhado — o provedor é o que o
/// usuário configurou (BYOK), resolvido lá dentro.
class SugestaoEntradaRepositoryImpl implements SugestaoEntradaRepository {
  final LlmRepository _llmRepository;

  const SugestaoEntradaRepositoryImpl(this._llmRepository);

  @override
  Future<Either<Failure, Map<String, String?>>> sugerirPorLlm({
    required List<ArquivoParaSugestao> arquivos,
    required List<EntradaLattesRef> entradas,
  }) async {
    final montado = montarTextoMapeamento(arquivos, entradas);
    final resultado = await _llmRepository.extrairJsonDeTexto(
      texto: montado.texto,
      promptExtracao: _instrucoes,
    );

    return resultado.match(
      (falha) => Left(falha),
      (json) {
        try {
          return Right(interpretarRespostaMapeamento(
            json,
            entradaPorIdCurto: montado.entradaPorIdCurto,
            arquivoPorIdCurto: montado.arquivoPorIdCurto,
          ));
        } on FormatException catch (e) {
          return Left(LlmFailure('O modelo respondeu fora do formato esperado: ${e.message}'));
        }
      },
    );
  }
}
