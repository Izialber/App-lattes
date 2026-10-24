import '../entities/entrada_lattes_ref.dart';
import '../entities/sugerir_entrada_por_nome.dart';
import '../entities/sugestao_lote.dart';
import '../repositories/sugestao_entrada_repository.dart';

/// Sugere uma entrada do Lattes pra cada arquivo do anexo em lote. Tenta o
/// LLM primeiro, em lotes de [tamanhoLote] arquivos; se uma chamada falhar
/// (sem provedor configurado, chave inválida, limite de tokens por minuto da
/// Groq gratuita, rede), esse lote e todos os seguintes caem na heurística
/// local por nome de arquivo ([sugerirEntradaPorNome]) — não insiste no
/// provedor que acabou de falhar, e o usuário recebe [ResultadoSugestaoLote.
/// avisoFallback] explicando o que aconteceu. Nada é anexado aqui: a tela de
/// revisão vem antes (ver DECISOES.md).
///
/// Antes de tudo, arquivo cujo nome já está em [entradaJaAnexadaPorNome] vai
/// direto para a entrada onde ele já foi anexado, sem passar pelo LLM nem
/// pela heurística: rodar o lote de novo sobre a mesma pasta é o caso
/// normal, e sem isso esses arquivos caíam em "sem entrada" quando a IA
/// falhava, em vez de aparecer como duplicata.
class SugerirEntradasEmLote {
  final SugestaoEntradaRepository _repository;

  /// 60 caminhos + ~40 entradas ficam em torno de 3-4K tokens de entrada —
  /// folga dentro dos 8K tokens/minuto da Groq gratuita, e a pasta típica
  /// do usuário (~100 arquivos) vai em 2 chamadas.
  final int tamanhoLote;

  const SugerirEntradasEmLote(this._repository, {this.tamanhoLote = 60});

  Future<ResultadoSugestaoLote> call({
    required List<ArquivoParaSugestao> arquivos,
    required List<EntradaLattesRef> entradas,
    Map<String, String> entradaJaAnexadaPorNome = const {},
  }) async {
    final jaAnexados = <String, SugestaoArquivo>{
      for (final a in arquivos)
        if (entradaJaAnexadaPorNome[a.caminho.split('/').last] case final entradaId?)
          a.id: SugestaoArquivo(
            arquivoId: a.id,
            entradaId: entradaId,
            origem: OrigemSugestao.jaAnexado,
          ),
    };
    if (jaAnexados.isEmpty) return _sugerir(arquivos: arquivos, entradas: entradas);

    final resto = await _sugerir(
      arquivos: [for (final a in arquivos) if (!jaAnexados.containsKey(a.id)) a],
      entradas: entradas,
    );
    final porId = {
      ...jaAnexados,
      for (final s in resto.sugestoes) s.arquivoId: s,
    };
    return ResultadoSugestaoLote(
      sugestoes: [for (final a in arquivos) porId[a.id]!],
      avisoFallback: resto.avisoFallback,
    );
  }

  Future<ResultadoSugestaoLote> _sugerir({
    required List<ArquivoParaSugestao> arquivos,
    required List<EntradaLattesRef> entradas,
  }) async {
    if (arquivos.isEmpty) return const ResultadoSugestaoLote(sugestoes: []);
    if (entradas.isEmpty) {
      return ResultadoSugestaoLote(
        sugestoes: [
          for (final a in arquivos)
            SugestaoArquivo(arquivoId: a.id, entradaId: null, origem: OrigemSugestao.nomeDoArquivo),
        ],
      );
    }

    final sugestoes = <SugestaoArquivo>[];
    String? aviso;

    for (var inicio = 0; inicio < arquivos.length; inicio += tamanhoLote) {
      final fim = inicio + tamanhoLote > arquivos.length ? arquivos.length : inicio + tamanhoLote;
      final lote = arquivos.sublist(inicio, fim);

      if (aviso == null) {
        final resultado = await _repository.sugerirPorLlm(arquivos: lote, entradas: entradas);
        final sucesso = resultado.match(
          (falha) {
            aviso = inicio == 0
                ? 'Sugestão por IA indisponível (${falha.message}). As sugestões abaixo vêm só '
                    'do nome de cada arquivo — confira com mais atenção.'
                : 'A IA sugeriu os primeiros $inicio arquivos, mas falhou no restante '
                    '(${falha.message}). Os demais foram sugeridos só pelo nome do arquivo.';
            return false;
          },
          (mapa) {
            sugestoes.addAll([
              for (final a in lote)
                SugestaoArquivo(arquivoId: a.id, entradaId: mapa[a.id], origem: OrigemSugestao.llm),
            ]);
            return true;
          },
        );
        if (sucesso) continue;
      }

      sugestoes.addAll([
        for (final a in lote)
          SugestaoArquivo(
            arquivoId: a.id,
            entradaId: sugerirEntradaPorNome(a.caminho, entradas),
            origem: OrigemSugestao.nomeDoArquivo,
          ),
      ]);
    }

    return ResultadoSugestaoLote(sugestoes: sugestoes, avisoFallback: aviso);
  }
}
