import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/sanitizar_nome_arquivo.dart';
import '../../../comprovantes/domain/entities/categoria_entrada_lattes.dart';
import '../../../comprovantes/domain/entities/comprovante_entrada.dart';
import '../../../comprovantes/domain/usecases/atualizar_status_sincronizacao_comprovante.dart';
import '../../../comprovantes/presentation/providers/comprovantes_providers.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/upload_task.dart';
import 'cloud_sync_providers.dart';

const _uuid = Uuid();

final atualizarStatusSincronizacaoComprovanteProvider = Provider(
  (ref) => AtualizarStatusSincronizacaoComprovante(ref.watch(comprovanteRepositoryProvider)),
);

/// Estado da sincronização de comprovantes — mesmo desenho de
/// `CloudSyncState` (módulo antigo, `cloud_sync_providers.dart`).
class ComprovantesSyncState {
  final bool sincronizando;
  final String? erro;

  /// Progresso textual de [sincronizarTodos] ("Enviando X de Y arquivos"),
  /// não usado pela retomada automática nem pelo retry de um único arquivo
  /// — só o disparo manual ("sincronizar tudo") tem uma fila longa o
  /// suficiente pra um rótulo de progresso valer a pena (ver DECISOES.md,
  /// pesquisa de UX sobre indicadores com texto vs. spinner silencioso).
  final int enviados;
  final int totalParaSincronizar;

  const ComprovantesSyncState({
    this.sincronizando = false,
    this.erro,
    this.enviados = 0,
    this.totalParaSincronizar = 0,
  });

  ComprovantesSyncState copyWith({
    bool? sincronizando,
    String? erro,
    bool limparErro = false,
    int? enviados,
    int? totalParaSincronizar,
  }) {
    return ComprovantesSyncState(
      sincronizando: sincronizando ?? this.sincronizando,
      erro: limparErro ? null : (erro ?? this.erro),
      enviados: enviados ?? this.enviados,
      totalParaSincronizar: totalParaSincronizar ?? this.totalParaSincronizar,
    );
  }
}

/// Orquestra o envio dos comprovantes pro Drive — mesmo desenho de
/// `CloudSyncController` (módulo antigo), adaptado pra `ComprovanteEntrada`.
/// Compartilha a MESMA fila de upload (`UploadQueueLocalStore`) com o
/// módulo antigo em vez de duplicar toda a lógica de retry/chunking já
/// testada — `UploadTask.subpastaNome` (sempre preenchido aqui, sempre
/// null no módulo antigo) separa as tarefas de cada um dentro da fila
/// compartilhada (ver DECISOES.md, "Conectar o Módulo 3 ao módulo de
/// comprovantes").
class ComprovantesSyncController extends Notifier<ComprovantesSyncState> {
  @override
  ComprovantesSyncState build() {
    _retomarPendentes();
    return const ComprovantesSyncState();
  }

  void limparErro() => state = state.copyWith(limparErro: true);

  Future<void> _retomarPendentes() async {
    try {
      final fila = ref.read(uploadQueueLocalStoreProvider).listarTodas();
      final pendentes = fila.where(
        (t) =>
            t.subpastaNome != null &&
            (t.status == UploadStatus.pendente || t.status == UploadStatus.falhaTemporaria),
      );
      if (pendentes.isEmpty) return;

      state = state.copyWith(sincronizando: true);
      final atualizadas = await ref.read(processarFilaOfflineProvider).call(pendentes.toList());
      await _persistirResultadoDaFila(atualizadas);
      state = state.copyWith(sincronizando: false);
    } catch (e) {
      // Sem isso, uma falha aqui virava uma exceção não tratada silenciosa
      // — achado ao investigar um bug ao vivo (ver DECISOES.md).
      state = state.copyWith(sincronizando: false, erro: 'Falha ao retomar a fila de envio: $e');
    }
  }

  Future<void> sincronizarTodos() async {
    state = state.copyWith(
      sincronizando: true,
      limparErro: true,
      enviados: 0,
      totalParaSincronizar: 0,
    );

    try {
      final todos = await ref.read(comprovanteRepositoryProvider).listarTodos();
      final pendentes = todos
          .where((c) => c.statusSincronizacao != StatusSincronizacaoComprovante.sincronizado)
          .toList();

      state = state.copyWith(totalParaSincronizar: pendentes.length);

      for (final comprovante in pendentes) {
        await _sincronizarUm(comprovante);
        state = state.copyWith(enviados: state.enviados + 1);
      }
    } catch (e) {
      state = state.copyWith(erro: 'Falha ao listar comprovantes pendentes: $e');
    }

    state = state.copyWith(sincronizando: false, enviados: 0, totalParaSincronizar: 0);
  }

  /// Tenta de novo um único comprovante que falhou (botão de retry na UI).
  Future<void> retentarUm(String comprovanteId) async {
    state = state.copyWith(sincronizando: true, limparErro: true);
    try {
      final todos = await ref.read(comprovanteRepositoryProvider).listarTodos();
      final comprovante = todos.firstWhereOrNull((c) => c.id == comprovanteId);
      if (comprovante != null) {
        await _sincronizarUm(comprovante);
      }
    } catch (e) {
      state = state.copyWith(erro: 'Falha ao tentar sincronizar de novo: $e');
    }
    state = state.copyWith(sincronizando: false);
  }

  Future<void> _sincronizarUm(ComprovanteEntrada comprovante) async {
    final atualizarStatus = ref.read(atualizarStatusSincronizacaoComprovanteProvider);
    await atualizarStatus(comprovante.id, StatusSincronizacaoComprovante.sincronizando);
    _atualizarUiLocal();

    final bytes = ref.read(comprovanteRepositoryProvider).lerBytes(comprovante.id);
    if (bytes == null) {
      await atualizarStatus(
        comprovante.id,
        StatusSincronizacaoComprovante.falha,
        mensagemErro: 'Arquivo não encontrado localmente.',
      );
      _atualizarUiLocal();
      return;
    }

    final List<int> pdfBytes;
    try {
      pdfBytes = await ref
          .read(pdfBuilderDatasourceProvider)
          .construirPdf(bytes: bytes, mimeType: comprovante.mimeType);
    } catch (e) {
      final mensagem = 'Falha ao gerar PDF: $e';
      state = state.copyWith(erro: 'Falha ao gerar PDF de "${comprovante.nomeArquivo}": $e');
      await atualizarStatus(
        comprovante.id,
        StatusSincronizacaoComprovante.falha,
        mensagemErro: mensagem,
      );
      _atualizarUiLocal();
      return;
    }

    final taskId = _uuid.v4();
    final uploadStore = ref.read(uploadQueueLocalStoreProvider);
    await uploadStore.salvarPdf(taskId, pdfBytes);

    final task = UploadTask(
      id: taskId,
      referenciaId: comprovante.id,
      provider: CloudProvider.googleDrive,
      nomeArquivoDeterministico: _nomeArquivoDeterministico(comprovante),
      caminhoPdfLocal: taskId,
      status: UploadStatus.pendente,
      subpastaNome: comprovante.categoria.rotulo,
    );
    await uploadStore.salvar(task);

    final resultado = await ref.read(enviarPdfParaCloudProvider).call(task);

    await resultado.match(
      (falha) async {
        state = state.copyWith(
          erro: 'Falha ao sincronizar "${comprovante.nomeArquivo}": ${falha.message}',
        );
        await atualizarStatus(
          comprovante.id,
          StatusSincronizacaoComprovante.falha,
          mensagemErro: falha.message,
        );
      },
      (tarefaConcluida) async {
        await uploadStore.remover(tarefaConcluida.id);
        await atualizarStatus(
          comprovante.id,
          StatusSincronizacaoComprovante.sincronizado,
          idArquivoCloud: tarefaConcluida.idArquivoCloud,
        );
      },
    );
    _atualizarUiLocal();
  }

  /// Retomada da fila (ver [_retomarPendentes]) só tem a `UploadTask` em
  /// mãos — `referenciaId` é o id do `ComprovanteEntrada`.
  Future<void> _persistirResultadoDaFila(List<UploadTask> atualizadas) async {
    final uploadStore = ref.read(uploadQueueLocalStoreProvider);
    final atualizarStatus = ref.read(atualizarStatusSincronizacaoComprovanteProvider);

    for (final task in atualizadas) {
      if (task.status == UploadStatus.concluido) {
        await uploadStore.remover(task.id);
        await atualizarStatus(
          task.referenciaId,
          StatusSincronizacaoComprovante.sincronizado,
          idArquivoCloud: task.idArquivoCloud,
        );
      } else {
        await uploadStore.salvar(task);
        if (task.status == UploadStatus.falhaPermanente) {
          await atualizarStatus(
            task.referenciaId,
            StatusSincronizacaoComprovante.falha,
            mensagemErro: task.mensagemErro,
          );
        }
      }
    }
    _atualizarUiLocal();
  }

  /// `ComprovantesController` (tela) tem seu próprio estado em memória —
  /// sem isso, a tela só refletiria o status novo depois de um reload.
  void _atualizarUiLocal() => ref.invalidate(comprovantesControllerProvider);

  /// Nome do original (sem extensão, sanitizado) + hash curto do próprio
  /// comprovante — não usa a categoria aqui porque ela já vira o nome da
  /// SUBPASTA (ver `subpastaNome` acima); repetir na pasta e no arquivo
  /// seria redundante.
  String _nomeArquivoDeterministico(ComprovanteEntrada comprovante) {
    final nome = comprovante.nomeArquivo;
    final semExtensao = nome.contains('.') ? nome.substring(0, nome.lastIndexOf('.')) : nome;
    final nomeSanitizado = sanitizarParaNomeDeArquivo(semExtensao);
    final hash = comprovante.id.substring(0, 8);
    return '$nomeSanitizado-$hash.pdf';
  }
}

final comprovantesSyncControllerProvider =
    NotifierProvider<ComprovantesSyncController, ComprovantesSyncState>(
  ComprovantesSyncController.new,
);
