import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../../../certificate_capture/presentation/providers/certificate_capture_providers.dart';
import '../../../llm_shared/presentation/providers/llm_shared_providers.dart';
import '../../data/datasources/edital_upload_datasource.dart';
import '../../data/datasources/llm_edital_datasource.dart';
import '../../data/datasources/pdf_merge_datasource.dart';
import '../../data/local/dossie_local_store.dart';
import '../../data/repositories/dossie_repository_impl.dart';
import '../../domain/entities/dossie.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';
import '../../domain/entities/vinculo_sugerido_dossie.dart';
import '../../domain/repositories/dossie_repository.dart';
import '../../domain/usecases/compilar_dossie.dart';
import '../../domain/usecases/extrair_criterios_edital.dart';
import '../../domain/usecases/registrar_decisao_vinculo.dart';
import '../../domain/usecases/sugerir_vinculos.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Providers de infraestrutura do módulo 4 — ver convenção em
// `lattes_providers.dart`.
// ---------------------------------------------------------------------------

final editalUploadDatasourceProvider = Provider<EditalUploadDatasource>(
  (ref) => EditalUploadDatasourceWeb(),
);

final llmEditalDatasourceProvider = Provider(
  (ref) => LlmEditalDatasource(ref.watch(llmRepositoryProvider)),
);

final pdfMergeDatasourceProvider = Provider(
  (ref) => PdfMergeDatasource(ref.watch(taskRunnerProvider)),
);

final dossieLocalStoreProvider = Provider((ref) => const DossieLocalStore());

final dossieRepositoryProvider = Provider<DossieRepository>(
  (ref) => DossieRepositoryImpl(
    ref.watch(llmEditalDatasourceProvider),
    ref.watch(pdfMergeDatasourceProvider),
    ref.watch(taskRunnerProvider),
    ref.watch(dossieLocalStoreProvider),
    ref.watch(certificateLocalStoreProvider),
  ),
);

final extrairCriteriosEditalProvider = Provider(
  (ref) => ExtrairCriteriosEdital(ref.watch(dossieRepositoryProvider)),
);

final sugerirVinculosProvider = Provider(
  (ref) => SugerirVinculos(ref.watch(dossieRepositoryProvider)),
);

final registrarDecisaoVinculoProvider = Provider(
  (ref) => RegistrarDecisaoVinculo(ref.watch(dossieRepositoryProvider)),
);

final compilarDossieProvider = Provider(
  (ref) => CompilarDossie(ref.watch(dossieRepositoryProvider)),
);

/// Estado das telas do módulo 4 — cobre tanto a criação de um dossiê novo
/// quanto o checklist/compilação de um já existente, porque as duas telas
/// compartilham o mesmo `Notifier` (evita duplicar a lógica de carregar
/// edital/certificados/sugestões).
class DossieBuilderState {
  final bool carregando;
  final String? erro;
  final Dossie? dossie;
  final Edital? edital;
  final List<VinculoSugeridoDossie> sugestoes;
  final List<CertificadoCapturado> certificadosSincronizados;

  const DossieBuilderState({
    this.carregando = false,
    this.erro,
    this.dossie,
    this.edital,
    this.sugestoes = const [],
    this.certificadosSincronizados = const [],
  });

  DossieBuilderState copyWith({
    bool? carregando,
    String? erro,
    bool limparErro = false,
    Dossie? dossie,
    Edital? edital,
    List<VinculoSugeridoDossie>? sugestoes,
    List<CertificadoCapturado>? certificadosSincronizados,
  }) {
    return DossieBuilderState(
      carregando: carregando ?? this.carregando,
      erro: limparErro ? null : (erro ?? this.erro),
      dossie: dossie ?? this.dossie,
      edital: edital ?? this.edital,
      sugestoes: sugestoes ?? this.sugestoes,
      certificadosSincronizados: certificadosSincronizados ?? this.certificadosSincronizados,
    );
  }
}

class DossieBuilderController extends Notifier<DossieBuilderState> {
  @override
  DossieBuilderState build() => const DossieBuilderState();

  void limparErro() => state = state.copyWith(limparErro: true);

  /// Seleciona o edital, extrai critérios via LLM, cria o `Dossie` inicial
  /// e já calcula as sugestões de vínculo. Retorna o id do dossiê criado
  /// (para a UI navegar ao checklist), ou `null` se o usuário cancelou o
  /// seletor ou algo falhou (mensagem fica em `state.erro`).
  Future<String?> criarNovoDossie() async {
    state = state.copyWith(carregando: true, limparErro: true);

    final EditalSelecionado? selecionado;
    try {
      selecionado = await ref.read(editalUploadDatasourceProvider).selecionarEdital();
    } catch (e) {
      state = state.copyWith(
        carregando: false,
        erro: 'Não foi possível abrir o seletor de arquivo: $e',
      );
      return null;
    }
    if (selecionado == null) {
      state = state.copyWith(carregando: false);
      return null;
    }

    final resultadoExtracao = await ref.read(extrairCriteriosEditalProvider).call(
          editalId: _uuid.v4(),
          nomeArquivoOriginal: selecionado.nomeArquivo,
          editalPdfBytes: selecionado.bytes,
        );

    return resultadoExtracao.match(
      (falha) async {
        state = state.copyWith(carregando: false, erro: falha.message);
        return null;
      },
      (edital) => _finalizarCriacaoComEdital(edital),
    );
  }

  Future<String> _finalizarCriacaoComEdital(Edital edital) async {
    final dossieId = _uuid.v4();
    final dossieInicial = Dossie(
      id: dossieId,
      editalId: edital.id,
      status: StatusDossie.aguardandoRevisaoHumana,
    );
    await ref.read(dossieLocalStoreProvider).salvarDossie(dossieInicial);

    state = state.copyWith(carregando: false, edital: edital, dossie: dossieInicial);
    return dossieId;
  }

  /// Carrega tudo que o checklist precisa para um dossiê já existente
  /// (reload de aba, ou navegação direta pela URL) — as sugestões de
  /// vínculo NÃO são persistidas (é uma heurística pura e determinística,
  /// então recalcular é mais simples e barato do que guardar em Hive).
  Future<void> carregarChecklist(String dossieId) async {
    state = state.copyWith(carregando: true, limparErro: true);

    final dossie = ref.read(dossieLocalStoreProvider).buscarDossie(dossieId);
    if (dossie == null) {
      state = state.copyWith(carregando: false, erro: 'Dossiê não encontrado.');
      return;
    }

    final edital = ref.read(dossieLocalStoreProvider).buscarEdital(dossie.editalId);
    if (edital == null) {
      state = state.copyWith(carregando: false, erro: 'Edital deste dossiê não encontrado.');
      return;
    }

    final todosOsCertificados = await ref.read(certificateRepositoryProvider).listarTodos();
    final sincronizados =
        todosOsCertificados.where((c) => c.status == StatusCertificado.sincronizado).toList();

    final resultadoSugestoes = await ref.read(sugerirVinculosProvider).call(
          edital: edital,
          certificadosSincronizados: sincronizados,
        );

    resultadoSugestoes.match(
      (falha) => state = state.copyWith(
        carregando: false,
        erro: falha.message,
        dossie: dossie,
        edital: edital,
        certificadosSincronizados: sincronizados,
      ),
      (sugestoes) => state = state.copyWith(
        carregando: false,
        dossie: dossie,
        edital: edital,
        sugestoes: sugestoes,
        certificadosSincronizados: sincronizados,
      ),
    );
  }

  Future<void> registrarDecisao(VinculoAprovado decisao) async {
    final dossie = state.dossie;
    if (dossie == null) return;

    final resultado = await ref
        .read(registrarDecisaoVinculoProvider)
        .call(dossieId: dossie.id, decisao: decisao);

    resultado.match(
      (falha) => state = state.copyWith(erro: falha.message),
      (atualizado) => state = state.copyWith(dossie: atualizado),
    );
  }

  Future<void> compilar(String dossieId) async {
    state = state.copyWith(carregando: true, limparErro: true);

    final resultado = await ref.read(compilarDossieProvider).call(dossieId);

    resultado.match(
      (falha) => state = state.copyWith(carregando: false, erro: falha.message),
      (atualizado) => state = state.copyWith(carregando: false, dossie: atualizado),
    );
  }

  /// Bytes do PDF final compilado, para a UI oferecer download — `null`
  /// antes da compilação terminar com sucesso.
  Uint8List? lerPdfFinal(String dossieId) {
    return ref.read(dossieLocalStoreProvider).lerPdfFinal(dossieId);
  }
}

final dossieBuilderControllerProvider =
    NotifierProvider<DossieBuilderController, DossieBuilderState>(DossieBuilderController.new);
