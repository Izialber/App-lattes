import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/constants.dart';
import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../../../certificate_capture/presentation/providers/certificate_capture_providers.dart';
import '../../data/datasources/google_drive_datasource.dart';
import '../../data/datasources/onedrive_graph_datasource.dart';
import '../../data/datasources/pdf_builder_datasource.dart';
import '../../data/local/upload_queue_local_store.dart';
import '../../data/repositories/cloud_storage_repository_impl.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/upload_task.dart';
import '../../domain/repositories/cloud_storage_repository.dart';
import '../../domain/usecases/enviar_pdf_para_cloud.dart';
import '../../domain/usecases/processar_fila_offline.dart';
import '../../domain/usecases/renovar_token.dart';
import 'auth_providers.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Providers de infraestrutura do módulo 3 — ver convenção em
// `lattes_providers.dart`.
// ---------------------------------------------------------------------------

final googleDriveDatasourceProvider = Provider(
  (ref) => GoogleDriveDatasource(ref.watch(authRepositoryProvider)),
);

final oneDriveGraphDatasourceProvider = Provider((ref) => OneDriveGraphDatasource());

final pdfBuilderDatasourceProvider = Provider((ref) => PdfBuilderDatasource());

final uploadQueueLocalStoreProvider = Provider((ref) => const UploadQueueLocalStore());

final cloudStorageRepositoryProvider = Provider<CloudStorageRepository>(
  (ref) => CloudStorageRepositoryImpl(
    ref.watch(googleDriveDatasourceProvider),
    ref.watch(oneDriveGraphDatasourceProvider),
    ref.watch(uploadQueueLocalStoreProvider),
  ),
);

final renovarTokenProvider = Provider(
  (ref) => RenovarToken(ref.watch(authRepositoryProvider)),
);

final enviarPdfParaCloudProvider = Provider(
  (ref) => EnviarPdfParaCloud(
    ref.watch(cloudStorageRepositoryProvider),
    ref.watch(renovarTokenProvider),
  ),
);

final processarFilaOfflineProvider = Provider(
  (ref) => ProcessarFilaOffline(ref.watch(enviarPdfParaCloudProvider)),
);

/// Estado da sincronização com o cloud: `sincronizando` cobre tanto o envio
/// disparado pelo usuário quanto a retomada automática da fila pendente ao
/// abrir a tela (ver [CloudSyncController.build]).
class CloudSyncState {
  final bool sincronizando;
  final String? erro;

  const CloudSyncState({this.sincronizando = false, this.erro});

  CloudSyncState copyWith({bool? sincronizando, String? erro, bool limparErro = false}) {
    return CloudSyncState(
      sincronizando: sincronizando ?? this.sincronizando,
      erro: limparErro ? null : (erro ?? this.erro),
    );
  }
}

/// Orquestra o módulo 3: converte cada certificado aprovado/pendente de
/// revisão para PDF, monta a `UploadTask`, persiste na fila (sobrevive a
/// reload) e envia. Não é um use case de domínio porque cruza dados de dois
/// módulos (certificado + fila de upload) — mesma justificativa de
/// `CertificateCaptureController` orquestrar múltiplos use cases em
/// sequência na camada de apresentação.
class CloudSyncController extends Notifier<CloudSyncState> {
  @override
  CloudSyncState build() {
    _retomarPendentes();
    return const CloudSyncState();
  }

  void limparErro() => state = state.copyWith(limparErro: true);

  /// Tarefas que ficaram pendentes/com falha temporária de uma sessão
  /// anterior (reload de aba no meio do upload) — retomadas automaticamente
  /// ao montar a tela, sem exigir que o usuário clique em nada.
  Future<void> _retomarPendentes() async {
    final fila = ref.read(uploadQueueLocalStoreProvider).listarTodas();
    final pendentes = fila.where(
      (t) => t.status == UploadStatus.pendente || t.status == UploadStatus.falhaTemporaria,
    );
    if (pendentes.isEmpty) return;

    state = state.copyWith(sincronizando: true);
    final atualizadas = await ref.read(processarFilaOfflineProvider).call(pendentes.toList());
    await _persistirResultadoDaFila(atualizadas);
    state = state.copyWith(sincronizando: false);
  }

  Future<void> sincronizarTodos() async {
    state = state.copyWith(sincronizando: true, limparErro: true);

    final certificateRepo = ref.read(certificateRepositoryProvider);
    final todos = await certificateRepo.listarTodos();
    final prontos = todos.where(
      (c) =>
          c.status == StatusCertificado.pendenteRevisao || c.status == StatusCertificado.aprovado,
    );

    for (final certificado in prontos) {
      await _sincronizarUm(certificado);
    }

    state = state.copyWith(sincronizando: false);
  }

  /// Tenta de novo um único certificado que falhou na sincronização (botão
  /// "Tentar novamente" na UI) — `sincronizarTodos` não o alcançaria porque
  /// `falhaSincronizacao` não é um dos status elegíveis lá.
  Future<void> retentarUm(String certificadoId) async {
    final certificateRepo = ref.read(certificateRepositoryProvider);
    final todos = await certificateRepo.listarTodos();

    final certificado = todos.firstWhereOrNull((c) => c.id == certificadoId);
    if (certificado == null) return;

    state = state.copyWith(sincronizando: true, limparErro: true);
    await _sincronizarUm(certificado);
    state = state.copyWith(sincronizando: false);
  }

  Future<void> _sincronizarUm(CertificadoCapturado certificado) async {
    final certificateRepo = ref.read(certificateRepositoryProvider);
    await certificateRepo.atualizarStatus(certificado.id, StatusCertificado.enviandoParaCloud);

    final bytes = ref.read(certificateLocalStoreProvider).lerImagem(certificado.id);
    if (bytes == null) {
      await certificateRepo.atualizarStatus(
        certificado.id,
        StatusCertificado.falhaSincronizacao,
        mensagemErro: 'Imagem/PDF original não encontrado localmente.',
      );
      return;
    }

    final List<int> pdfBytes;
    try {
      pdfBytes = await ref
          .read(pdfBuilderDatasourceProvider)
          .construirPdf(bytes: bytes, mimeType: certificado.mimeType);
    } catch (e) {
      final mensagem = 'Falha ao gerar PDF: $e';
      state = state.copyWith(erro: 'Falha ao gerar PDF de "${_rotulo(certificado)}": $e');
      await certificateRepo.atualizarStatus(
        certificado.id,
        StatusCertificado.falhaSincronizacao,
        mensagemErro: mensagem,
      );
      return;
    }

    final taskId = _uuid.v4();
    final uploadStore = ref.read(uploadQueueLocalStoreProvider);
    await uploadStore.salvarPdf(taskId, pdfBytes);

    final task = UploadTask(
      id: taskId,
      certificadoId: certificado.id,
      provider: CloudProvider.googleDrive,
      nomeArquivoDeterministico: _nomeArquivoDeterministico(certificado),
      caminhoPdfLocal: taskId,
      status: UploadStatus.pendente,
    );
    await uploadStore.salvar(task);

    final resultado = await ref.read(enviarPdfParaCloudProvider).call(task);

    await resultado.match(
      (falha) async {
        state = state.copyWith(erro: 'Falha ao sincronizar "${_rotulo(certificado)}": ${falha.message}');
        await certificateRepo.atualizarStatus(
          certificado.id,
          StatusCertificado.falhaSincronizacao,
          mensagemErro: falha.message,
        );
      },
      (tarefaConcluida) async {
        await uploadStore.remover(tarefaConcluida.id);
        await certificateRepo.atualizarStatus(certificado.id, StatusCertificado.sincronizado);
      },
    );
  }

  /// Retomada da fila (ver [_retomarPendentes]) não tem o `CertificadoCapturado`
  /// em mãos diretamente — só a `UploadTask`, que carrega `certificadoId`.
  Future<void> _persistirResultadoDaFila(List<UploadTask> atualizadas) async {
    final certificateRepo = ref.read(certificateRepositoryProvider);
    final uploadStore = ref.read(uploadQueueLocalStoreProvider);

    for (final task in atualizadas) {
      if (task.status == UploadStatus.concluido) {
        await uploadStore.remover(task.id);
        await certificateRepo.atualizarStatus(task.certificadoId, StatusCertificado.sincronizado);
      } else {
        await uploadStore.salvar(task);
        if (task.status == UploadStatus.falhaPermanente) {
          await certificateRepo.atualizarStatus(
            task.certificadoId,
            StatusCertificado.falhaSincronizacao,
            mensagemErro: task.mensagemErro,
          );
        }
      }
    }
  }

  String _rotulo(CertificadoCapturado c) => c.tituloExtraido ?? c.id;

  String _nomeArquivoDeterministico(CertificadoCapturado certificado) {
    final data = certificado.dataExtraida ?? DateTime.now();
    final dataFormatada = '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
    final categoria = _sanitizarParaNomeDeArquivo(certificado.tituloExtraido ?? 'certificado');
    final hash = certificado.id.substring(0, 8);

    return AppConstants.pdfNamePattern
        .replaceFirst('{data}', dataFormatada)
        .replaceFirst('{categoria}', categoria)
        .replaceFirst('{hash}', hash);
  }

  /// Remove caracteres que não são seguros em nome de arquivo em
  /// Drive/OneDrive/sistemas de arquivo em geral, e limita o tamanho — o
  /// título extraído pelo LLM pode ser bem mais longo que um nome de
  /// arquivo razoável.
  String _sanitizarParaNomeDeArquivo(String texto) {
    final semCaracteresInvalidos = texto.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim();
    final comHifen = semCaracteresInvalidos.replaceAll(RegExp(r'\s+'), '-');
    return comHifen.length > 60 ? comHifen.substring(0, 60) : comHifen;
  }
}

final cloudSyncControllerProvider =
    NotifierProvider<CloudSyncController, CloudSyncState>(CloudSyncController.new);
