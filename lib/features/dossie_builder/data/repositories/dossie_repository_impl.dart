import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/platform/task_runner/task_runner.dart';
import '../../../comprovantes/data/local/comprovante_local_store.dart';
import '../../../comprovantes/domain/entities/comprovante_entrada.dart';
import '../../../comprovantes/domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/criterio_pontuacao.dart';
import '../../domain/entities/dossie.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';
import '../../domain/entities/vinculo_sugerido_dossie.dart';
import '../../domain/repositories/dossie_repository.dart';
import '../../domain/usecases/decidir_estrategia_de_memoria.dart';
import '../datasources/llm_edital_datasource.dart';
import '../datasources/pdf_merge_datasource.dart';
import '../local/dossie_local_store.dart';

const _uuid = Uuid();

/// Implementação real do módulo 4.
///
/// `compilarDossieFinal` usa a estratégia de 3 níveis decidida pelo usuário
/// (ver DECISOES.md e `DecidirEstrategiaDeMemoria`), mas só a estratégia
/// `direta` está de fato implementada nesta rodada — `emPartes` depende de
/// mesclar PDFs intermediários já prontos, o que `PdfMergeDatasource` ainda
/// não faz (ver docstring da classe e DECISOES.md, "Mesclagem do dossiê");
/// nesse caso o método retorna uma [DossieFailure] clara em vez de tentar e
/// falhar de um jeito confuso.
class DossieRepositoryImpl implements DossieRepository {
  final LlmEditalDatasource _llmEditalDatasource;
  final PdfMergeDatasource _pdfMergeDatasource;
  final TaskRunner _taskRunner;
  final DecidirEstrategiaDeMemoria _decidirEstrategia;
  final DossieLocalStore _localStore;
  final ComprovanteLocalStore _comprovanteLocalStore;

  const DossieRepositoryImpl(
    this._llmEditalDatasource,
    this._pdfMergeDatasource,
    this._taskRunner,
    this._localStore,
    this._comprovanteLocalStore, [
    this._decidirEstrategia = const DecidirEstrategiaDeMemoria(),
  ]);

  @override
  Future<Either<Failure, Edital>> extrairCriterios({
    required String editalId,
    required String nomeArquivoOriginal,
    required List<int> editalPdfBytes,
  }) async {
    final Map<String, dynamic> json;
    final List<CriterioPontuacao> criterios;
    try {
      json = await _llmEditalDatasource.extrairCriterios(editalPdfBytes);
      // Coerção defensiva, não cast direto: o schema pedido ao LLM no
      // prompt não é imposto pela API — cada item de "criterios" que não
      // vier no formato esperado é simplesmente ignorado, em vez de um
      // `as Map`/`as String?` direto derrubar a extração inteira do edital
      // por causa de UM item malformado (achado da revisão de código).
      final criteriosBrutos = (json['criterios'] as List?) ?? const [];
      criterios = criteriosBrutos
          .whereType<Map>()
          .map((c) => CriterioPontuacao(
                id: _uuid.v4(),
                descricao: c['descricao']?.toString() ?? 'Critério sem descrição',
                pontosPorUnidade: _comoDoubleOpcional(c['pontosPorUnidade']),
                limiteMaximoUnidades: _comoInteiroOpcional(c['limiteMaximoUnidades']),
              ))
          .toList();
    } catch (e) {
      return Left(DossieFailure('Falha ao interpretar o edital: $e'));
    }

    final edital = Edital(
      id: editalId,
      nomeArquivoOriginal: nomeArquivoOriginal,
      orgaoOuBanca: json['orgaoOuBanca']?.toString(),
      criterios: criterios,
    );

    await _localStore.salvarEdital(edital);
    return Right(edital);
  }

  double? _comoDoubleOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().replaceAll(',', '.'));
  }

  int? _comoInteiroOpcional(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.round();
    return int.tryParse(valor.toString().replaceAll(RegExp('[^0-9-]'), ''));
  }

  @override
  Future<Either<Failure, List<VinculoSugeridoDossie>>> sugerirVinculos({
    required Edital edital,
    required List<ComprovanteEntrada> comprovantesSincronizados,
    required List<EntradaLattesRef> entradas,
  }) async {
    final entradasPorId = {for (final e in entradas) e.id: e};
    final sugestoes = <VinculoSugeridoDossie>[];
    for (final comprovante in comprovantesSincronizados) {
      final sugestao = _melhorCriterioPara(
        comprovante,
        entradasPorId[comprovante.entradaId],
        edital.criterios,
      );
      if (sugestao != null) sugestoes.add(sugestao);
    }
    return Right(sugestoes);
  }

  /// Heurística pura de similaridade textual (sem LLM): compara o
  /// título/subtítulo da entrada do currículo ligada ao comprovante
  /// (`ComprovanteEntrada` em si não carrega texto descritivo nenhum — é só
  /// um arquivo anexado, ver DECISOES.md "Conectar o Módulo 4") contra a
  /// descrição de cada critério do edital, por sobreposição de palavras
  /// (Jaccard simplificado — interseção sobre o tamanho da descrição do
  /// critério). [entrada] nula (comprovante órfão — entrada removida numa
  /// reimportação do Lattes) cai no nome do arquivo em vez de ficar de fora
  /// do match. Decisão deliberada de NÃO chamar LLM aqui: o resultado é só
  /// uma sugestão inicial que o usuário sempre revisa no checklist — ver
  /// DECISOES.md.
  VinculoSugeridoDossie? _melhorCriterioPara(
    ComprovanteEntrada comprovante,
    EntradaLattesRef? entrada,
    List<CriterioPontuacao> criterios,
  ) {
    const limiarMinimoDeConfianca = 0.15;

    final textoComprovante = entrada == null
        ? comprovante.nomeArquivo.toLowerCase()
        : '${entrada.titulo} ${entrada.subtitulo}'.toLowerCase();
    final palavrasComprovante = _palavrasRelevantes(textoComprovante);
    if (palavrasComprovante.isEmpty) return null;

    CriterioPontuacao? melhorCriterio;
    double melhorPontuacao = 0;

    for (final criterio in criterios) {
      final palavrasCriterio = _palavrasRelevantes(criterio.descricao.toLowerCase());
      if (palavrasCriterio.isEmpty) continue;

      final intersecao = palavrasComprovante.intersection(palavrasCriterio).length;
      final pontuacao = intersecao / palavrasCriterio.length;
      if (pontuacao > melhorPontuacao) {
        melhorPontuacao = pontuacao;
        melhorCriterio = criterio;
      }
    }

    if (melhorCriterio == null || melhorPontuacao < limiarMinimoDeConfianca) return null;
    return VinculoSugeridoDossie(
      comprovanteId: comprovante.id,
      criterioId: melhorCriterio.id,
      confianca: melhorPontuacao.clamp(0, 1),
    );
  }

  Set<String> _palavrasRelevantes(String texto) {
    return texto.split(RegExp(r'\W+')).where((palavra) => palavra.length > 2).toSet();
  }

  @override
  Future<Either<Failure, Dossie>> registrarDecisaoVinculo({
    required String dossieId,
    required VinculoAprovado decisao,
  }) async {
    final dossie = _localStore.buscarDossie(dossieId);
    if (dossie == null) {
      return Left(DossieFailure('Dossiê $dossieId não encontrado.'));
    }

    // Substitui uma decisão anterior para o mesmo par comprovante/critério
    // em vez de duplicar — o usuário pode mudar de ideia no checklist.
    final semDuplicata = dossie.vinculosRevisados
        .where((v) =>
            !(v.comprovanteId == decisao.comprovanteId && v.criterioId == decisao.criterioId))
        .toList();

    final atualizado = dossie.copyWith(vinculosRevisados: [...semDuplicata, decisao]);
    await _localStore.salvarDossie(atualizado);
    return Right(atualizado);
  }

  @override
  Future<Either<Failure, Dossie>> compilarDossieFinal(
    String dossieId, {
    required List<EntradaLattesRef> entradas,
  }) async {
    final dossie = _localStore.buscarDossie(dossieId);
    if (dossie == null) {
      return Left(DossieFailure('Dossiê $dossieId não encontrado.'));
    }

    final aprovados =
        dossie.vinculosRevisados.where((v) => v.decisao == DecisaoVinculo.aprovado).toList();
    if (aprovados.isEmpty) {
      return const Left(
        DossieFailure('Nenhum vínculo aprovado ainda — revise o checklist antes de compilar.'),
      );
    }

    await _localStore.salvarDossie(dossie.copyWith(status: StatusDossie.compilando));

    final entradasPorId = {for (final e in entradas) e.id: e};
    final imagensElegiveis = <List<int>>[];
    final titulos = <String>[];
    var totalPdfDeOrigemExcluidos = 0;

    for (final vinculo in aprovados) {
      final comprovante = _comprovanteLocalStore.buscar(vinculo.comprovanteId);
      final bytes = _comprovanteLocalStore.lerBytes(vinculo.comprovanteId);
      if (comprovante == null || bytes == null) continue;

      // PDFs de origem não podem ser mesclados automaticamente ainda — ver
      // docstring de PdfMergeDatasource. Excluídos silenciosamente do PDF
      // final em vez de travar a compilação inteira por causa deles.
      if (comprovante.mimeType == 'application/pdf') {
        totalPdfDeOrigemExcluidos++;
        continue;
      }

      imagensElegiveis.add(bytes);
      titulos.add(entradasPorId[comprovante.entradaId]?.titulo ?? comprovante.nomeArquivo);
    }

    if (imagensElegiveis.isEmpty) {
      final mensagem = totalPdfDeOrigemExcluidos > 0
          ? 'Todos os $totalPdfDeOrigemExcluidos comprovantes aprovados são PDF de origem, '
              'que ainda não pode ser mesclado automaticamente.'
          : 'Nenhum comprovante aprovado tem arquivo disponível localmente.';
      await _localStore.salvarDossie(dossie.copyWith(status: StatusDossie.falhaCompilacao));
      return Left(DossieFailure(mensagem));
    }

    final tamanhos = imagensElegiveis.map((bytes) => bytes.length).toList();
    final plano = _decidirEstrategia(
      tamanhosBytesPorPdf: tamanhos,
      estimatedSafeHeapBytes: _taskRunner.estimatedSafeHeapBytes,
      batchSizeBytesHint: _taskRunner.batchSizeBytesHint,
    );

    switch (plano.estrategia) {
      case EstrategiaMesclagemDossie.direta:
        return _compilarDireto(
          dossie,
          imagensElegiveis,
          titulos,
          totalPdfDeOrigemExcluidos: totalPdfDeOrigemExcluidos,
        );
      case EstrategiaMesclagemDossie.emPartes:
        await _localStore.salvarDossie(dossie.copyWith(status: StatusDossie.falhaCompilacao));
        return const Left(
          DossieFailure(
            'Este dossiê tem certificados demais para compilar de uma vez neste '
            'dispositivo, e a compilação em partes ainda não está implementada '
            '(ver DECISOES.md). Tente num computador com mais memória, ou remova '
            'alguns certificados aprovados.',
          ),
        );
      case EstrategiaMesclagemDossie.inviavelNoDispositivo:
        const mensagem = 'Pelo menos um certificado é grande demais para este dispositivo. '
            'Conclua a compilação num computador desktop.';
        await _localStore.salvarDossie(
          dossie.copyWith(
            status: StatusDossie.degradadoAguardandoDesktop,
            mensagemDegradacao: mensagem,
          ),
        );
        return Left(
          InsufficientDeviceMemoryFailure(
            mensagem,
            estimatedBytesNeeded: tamanhos.reduce((a, b) => a > b ? a : b),
            estimatedBytesAvailable: _taskRunner.estimatedSafeHeapBytes,
          ),
        );
    }
  }

  Future<Either<Failure, Dossie>> _compilarDireto(
    Dossie dossie,
    List<List<int>> imagensElegiveis,
    List<String> titulos, {
    required int totalPdfDeOrigemExcluidos,
  }) async {
    try {
      final pdfFinal = await _pdfMergeDatasource.mesclarComSumario(
        imagensEmOrdem: imagensElegiveis,
        titulosParaSumario: titulos,
      );
      await _localStore.salvarPdfFinal(dossie.id, pdfFinal);

      // Achado da revisão de código: antes da compilação, o checklist já
      // avisa quais certificados são PDF de origem (não entram na
      // mesclagem automática), mas o RESULTADO da compilação em si não
      // comunicava isso — um usuário que não reparou no aviso anterior via
      // só "compilado com sucesso" sem saber que faltam certificados no PDF
      // final. Usa `notaCompilacao`, não `mensagemDegradacao` — este é um
      // sucesso, não uma degradação por memória (2ª revisão de código:
      // reaproveitar o campo de degradação criaria falso positivo para
      // qualquer consumidor futuro que checasse "degradação == houve
      // problema de memória"). `limparNotaCompilacao` evita que uma nota de
      // uma tentativa anterior fique presa aqui para sempre.
      final atualizado = dossie.copyWith(
        status: StatusDossie.compilado,
        caminhoPdfFinal: dossie.id,
        notaCompilacao: totalPdfDeOrigemExcluidos > 0
            ? '$totalPdfDeOrigemExcluidos certificado(s) aprovado(s) são PDF de origem e não '
                'entraram neste PDF — mesclagem automática de PDF ainda não suportada.'
            : null,
        limparNotaCompilacao: totalPdfDeOrigemExcluidos == 0,
      );
      await _localStore.salvarDossie(atualizado);
      return Right(atualizado);
    } catch (e) {
      await _localStore.salvarDossie(dossie.copyWith(status: StatusDossie.falhaCompilacao));
      return Left(DossieFailure('Falha ao mesclar o dossiê: $e'));
    }
  }
}
