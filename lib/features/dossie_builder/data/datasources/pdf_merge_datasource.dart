import '../../../../core/platform/task_runner/task_runner.dart';
import '../../domain/usecases/decidir_estrategia_de_memoria.dart';

/// Mescla os PDFs individuais dos certificados aprovados em um único PDF
/// paginado com sumário, usando `package:pdf` (puro Dart, funciona no web).
/// TODA a mesclagem passa por [TaskRunner.run] — nunca chamada direta no
/// isolate de UI.
///
/// A decisão de COMO mesclar (direto / em partes / inviável) é feita por
/// [DecidirEstrategiaDeMemoria] (lógica pura, testada — ver
/// `test/features/dossie_builder/domain/usecases/decidir_estrategia_de_memoria_test.dart`),
/// chamada pelo `DossieRepositoryImpl.compilarDossieFinal` ANTES de invocar
/// os métodos deste datasource. Este arquivo só executa a mesclagem em si.
///
/// PENDENTE (fora do escopo do entregável 5): implementação real da
/// composição de páginas e geração do sumário (título + número de página).
class PdfMergeDatasource {
  final TaskRunner _taskRunner;

  const PdfMergeDatasource(this._taskRunner);

  /// Mesclagem direta de todos os PDFs de uma vez (estratégia
  /// [EstrategiaMesclagemDossie.direta]).
  Future<List<int>> mesclarComSumario({
    required List<List<int>> pdfsEmOrdem,
    required List<String> titulosParaSumario,
  }) {
    throw UnimplementedError('PdfMergeDatasource.mesclarComSumario: pendente (ver DECISOES.md)');
  }

  /// Mescla apenas UM lote em um PDF intermediário (sem sumário — o sumário
  /// final só é montado na mesclagem dos intermediários). Usado pela
  /// estratégia [EstrategiaMesclagemDossie.emPartes]: o chamador libera os
  /// bytes dos PDFs de origem daquele lote assim que este método retorna,
  /// antes de processar o próximo lote, para nunca manter mais de um lote
  /// de PDFs originais na memória ao mesmo tempo.
  Future<List<int>> mesclarLote(List<List<int>> pdfsDoLote) {
    throw UnimplementedError('PdfMergeDatasource.mesclarLote: pendente (ver DECISOES.md)');
  }

  /// Mescla os PDFs intermediários (um por lote, já bem menores que a soma
  /// dos originais) no PDF final, agora sim com o sumário completo — último
  /// passo da estratégia [EstrategiaMesclagemDossie.emPartes].
  Future<List<int>> mesclarIntermediariosComSumario({
    required List<List<int>> pdfsIntermediarios,
    required List<String> titulosParaSumario,
  }) {
    throw UnimplementedError(
      'PdfMergeDatasource.mesclarIntermediariosComSumario: pendente (ver DECISOES.md)',
    );
  }

  /// Heurística de estimativa de bytes de saída de uma mesclagem direta —
  /// mesmo fator de folga usado em [DecidirEstrategiaDeMemoria], mantido
  /// aqui só para quem quiser estimar o tamanho final do arquivo (não é
  /// usado para a decisão de estratégia, que trabalha com os tamanhos de
  /// entrada brutos).
  int estimarBytesSaida(List<List<int>> pdfsEmOrdem) {
    final somaEntrada = pdfsEmOrdem.fold<int>(0, (soma, pdf) => soma + pdf.length);
    return (somaEntrada * 1.6).round();
  }
}
