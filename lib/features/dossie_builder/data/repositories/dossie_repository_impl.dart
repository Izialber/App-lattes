import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../../../core/platform/task_runner/task_runner.dart';
import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../../domain/entities/dossie.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';
import '../../domain/repositories/dossie_repository.dart';
import '../../domain/usecases/decidir_estrategia_de_memoria.dart';
import '../datasources/llm_edital_datasource.dart';
import '../datasources/pdf_merge_datasource.dart';

/// PENDENTE (fora do escopo do entregável 5): implementação completa.
///
/// `compilarDossieFinal` é o método com a estratégia de 3 níveis decidida
/// pelo usuário (ver DECISOES.md e `DecidirEstrategiaDeMemoria`):
/// 1. Chama `_decidirEstrategia` com os tamanhos dos PDFs de entrada e
///    `_taskRunner.estimatedSafeHeapBytes`/`batchSizeBytesHint`.
/// 2. `EstrategiaMesclagemDossie.direta` -> `_pdfMergeDatasource.
///    mesclarComSumario` de uma vez.
/// 3. `EstrategiaMesclagemDossie.emPartes` -> status do `Dossie` vira
///    `compilandoEmPartes`; para cada lote, chama `_pdfMergeDatasource.
///    mesclarLote`, persiste o PDF intermediário, ATUALIZA `loteAtual` no
///    `Dossie` persistido (para sobreviver a reload no meio da compilação —
///    mesmo requisito de retomabilidade já aplicado à fila de upload), e só
///    então libera os bytes dos PDFs originais daquele lote; ao final,
///    `mesclarIntermediariosComSumario` produz o PDF definitivo.
/// 4. `EstrategiaMesclagemDossie.inviavelNoDispositivo` -> retorna
///    `Either.left(InsufficientDeviceMemoryFailure(...))`; a UI troca o
///    status para `StatusDossie.degradadoAguardandoDesktop`.
class DossieRepositoryImpl implements DossieRepository {
  final LlmEditalDatasource _llmEditalDatasource;
  final PdfMergeDatasource _pdfMergeDatasource;
  final TaskRunner _taskRunner;
  final DecidirEstrategiaDeMemoria _decidirEstrategia;

  const DossieRepositoryImpl(
    this._llmEditalDatasource,
    this._pdfMergeDatasource,
    this._taskRunner, [
    this._decidirEstrategia = const DecidirEstrategiaDeMemoria(),
  ]);

  @override
  Future<Either<Failure, Edital>> extrairCriterios({
    required String editalId,
    required List<int> editalPdfBytes,
  }) {
    throw UnimplementedError('DossieRepositoryImpl.extrairCriterios: pendente');
  }

  @override
  Future<Either<Failure, Edital>> sugerirVinculos({
    required Edital edital,
    required List<CertificadoCapturado> certificadosSincronizados,
  }) {
    throw UnimplementedError('DossieRepositoryImpl.sugerirVinculos: pendente');
  }

  @override
  Future<Either<Failure, Dossie>> registrarDecisaoVinculo({
    required String dossieId,
    required VinculoAprovado decisao,
  }) {
    throw UnimplementedError('DossieRepositoryImpl.registrarDecisaoVinculo: pendente');
  }

  @override
  Future<Either<Failure, Dossie>> compilarDossieFinal(String dossieId) {
    // A chamada a _decidirEstrategia(...) usando _taskRunner.
    // estimatedSafeHeapBytes e _taskRunner.batchSizeBytesHint acontece aqui
    // assim que os tamanhos dos PDFs de entrada estiverem disponíveis (via
    // storage local) — ver passo a passo na docstring da classe.
    throw UnimplementedError('DossieRepositoryImpl.compilarDossieFinal: pendente');
  }
}
