import 'package:equatable/equatable.dart';

/// As três estratégias possíveis para compilar o dossiê final, dado o teto
/// de memória do dispositivo atual (`TaskRunner.estimatedSafeHeapBytes`) —
/// substituem a decisão binária original ("cabe" / "não cabe, vá pro
/// desktop") por decisão explícita do usuário (ver DECISOES.md):
///
/// - [direta]: todos os PDFs cabem numa única mesclagem.
/// - [emPartes]: não cabem de uma vez, mas cabem processados em lotes
///   sequenciais — cada lote é mesclado num PDF intermediário (liberando a
///   memória dos PDFs de origem daquele lote antes do próximo), e ao final
///   os PDFs intermediários (bem menores que os originais somados) são
///   mesclados entre si no arquivo final.
/// - [inviavelNoDispositivo]: nem o maior certificado isolado cabe dentro
///   do teto — não há tamanho de lote (nem "lote de 1") que resolva. Único
///   caso em que ainda faz sentido pedir para o usuário concluir no
///   desktop.
enum EstrategiaMesclagemDossie { direta, emPartes, inviavelNoDispositivo }

/// Resultado de [DecidirEstrategiaDeMemoria]: a estratégia escolhida e,
/// quando [EstrategiaMesclagemDossie.emPartes], como dividir o trabalho.
class PlanoDeMesclagem extends Equatable {
  final EstrategiaMesclagemDossie estrategia;

  /// Quantidade de PDFs no maior lote do plano (0 quando não se aplica).
  final int tamanhoDoLote;

  /// Quantidade total de lotes (0 quando não se aplica).
  final int totalDeLotes;

  const PlanoDeMesclagem({
    required this.estrategia,
    this.tamanhoDoLote = 0,
    this.totalDeLotes = 0,
  });

  @override
  List<Object?> get props => [estrategia, tamanhoDoLote, totalDeLotes];
}

/// Lógica pura (sem I/O, sem Flutter) que decide como compilar o dossiê
/// dado o tamanho estimado de cada PDF de entrada e o teto de memória atual
/// (`TaskRunner.estimatedSafeHeapBytes`/`batchSizeBytesHint`). Separada da
/// execução real da mesclagem (`PdfMergeDatasource`, que continua stub
/// nesta entrega) porque é a parte que carrega a regra de negócio e que
/// mais vale a pena ter coberta por teste determinístico, sem depender de
/// bytes de PDF reais.
class DecidirEstrategiaDeMemoria {
  const DecidirEstrategiaDeMemoria();

  /// [fatorDeFolga] reflete que a estrutura interna do PDF mesclado ocupa
  /// mais memória do que a soma bruta dos bytes de entrada (mesma heurística
  /// já usada em `PdfMergeDatasource.estimarBytesSaida`).
  PlanoDeMesclagem call({
    required List<int> tamanhosBytesPorPdf,
    required int estimatedSafeHeapBytes,
    required int batchSizeBytesHint,
    double fatorDeFolga = 1.6,
  }) {
    if (tamanhosBytesPorPdf.isEmpty) {
      return const PlanoDeMesclagem(estrategia: EstrategiaMesclagemDossie.direta);
    }

    final totalBruto = tamanhosBytesPorPdf.fold<int>(0, (soma, bytes) => soma + bytes);
    if (_comFolga(totalBruto, fatorDeFolga) <= estimatedSafeHeapBytes) {
      return const PlanoDeMesclagem(estrategia: EstrategiaMesclagemDossie.direta);
    }

    final maiorPdf = tamanhosBytesPorPdf.reduce((a, b) => a > b ? a : b);
    if (_comFolga(maiorPdf, fatorDeFolga) > estimatedSafeHeapBytes) {
      // Nem o maior certificado isolado cabe sozinho: nenhum tamanho de
      // lote resolve — só resta a degradação explícita.
      return const PlanoDeMesclagem(estrategia: EstrategiaMesclagemDossie.inviavelNoDispositivo);
    }

    final tamanhosDosLotes = _montarLotes(
      tamanhosBytesPorPdf: tamanhosBytesPorPdf,
      batchSizeBytesHint: batchSizeBytesHint,
      fatorDeFolga: fatorDeFolga,
    );

    return PlanoDeMesclagem(
      estrategia: EstrategiaMesclagemDossie.emPartes,
      tamanhoDoLote: tamanhosDosLotes.reduce((a, b) => a > b ? a : b),
      totalDeLotes: tamanhosDosLotes.length,
    );
  }

  /// Agrupamento guloso em ordem: acumula PDFs no lote atual até que
  /// adicionar o próximo estouraria o hint de tamanho de lote; nesse ponto
  /// fecha o lote atual e começa um novo. Sempre fecha com pelo menos 1 PDF
  /// por lote (já garantido pela checagem de "maior PDF cabe sozinho" feita
  /// antes de chamar este método).
  List<int> _montarLotes({
    required List<int> tamanhosBytesPorPdf,
    required int batchSizeBytesHint,
    required double fatorDeFolga,
  }) {
    final lotes = <int>[];
    var acumuladoBytes = 0;
    var acumuladoCount = 0;

    for (final tamanho in tamanhosBytesPorPdf) {
      final acumuladoSeAdicionar = _comFolga(acumuladoBytes + tamanho, fatorDeFolga);
      if (acumuladoCount > 0 && acumuladoSeAdicionar > batchSizeBytesHint) {
        lotes.add(acumuladoCount);
        acumuladoBytes = 0;
        acumuladoCount = 0;
      }
      acumuladoBytes += tamanho;
      acumuladoCount += 1;
    }

    if (acumuladoCount > 0) {
      lotes.add(acumuladoCount);
    }

    return lotes;
  }

  int _comFolga(int bytes, double fator) => (bytes * fator).round();
}
