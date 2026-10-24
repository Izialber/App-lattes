import 'package:equatable/equatable.dart';

/// Um arquivo do lote, do jeito que a sugestão enxerga: só um id opaco e o
/// caminho (nome do arquivo, com a subpasta quando veio de uma pasta
/// inteira). Nenhum byte — por decisão de projeto, a sugestão do anexo em
/// lote olha só o NOME do arquivo, nunca o conteúdo (ver DECISOES.md,
/// "Anexar vários comprovantes de uma vez"): cabe no limite da Groq
/// gratuita e funciona com qualquer provedor, inclusive os que não leem PDF.
class ArquivoParaSugestao extends Equatable {
  final String id;
  final String caminho;

  const ArquivoParaSugestao({required this.id, required this.caminho});

  @override
  List<Object?> get props => [id, caminho];
}

/// De onde veio a sugestão — a tela de revisão mostra isso pro usuário
/// saber o quanto confiar em cada linha.
/// [jaAnexado]: o currículo já tem um comprovante com esse mesmo nome de
/// arquivo, e a sugestão é a entrada dele (a tela então descarta como
/// duplicata).
enum OrigemSugestao { llm, nomeDoArquivo, jaAnexado }

/// Sugestão pra UM arquivo do lote. [entradaId] null = "sem entrada": nem o
/// LLM nem a heurística acharam uma entrada correspondente.
class SugestaoArquivo extends Equatable {
  final String arquivoId;
  final String? entradaId;
  final OrigemSugestao origem;

  const SugestaoArquivo({
    required this.arquivoId,
    required this.entradaId,
    required this.origem,
  });

  @override
  List<Object?> get props => [arquivoId, entradaId, origem];
}

/// Resultado do lote inteiro. [avisoFallback] vem preenchido quando o LLM
/// falhou (provedor não configurado, chave inválida, limite de tokens da
/// Groq etc.) e parte ou todo o lote caiu na heurística por nome de arquivo
/// — a tela mostra o aviso em vez de esconder a troca.
class ResultadoSugestaoLote extends Equatable {
  final List<SugestaoArquivo> sugestoes;
  final String? avisoFallback;

  const ResultadoSugestaoLote({required this.sugestoes, this.avisoFallback});

  @override
  List<Object?> get props => [sugestoes, avisoFallback];
}
