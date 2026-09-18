import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/platform/camera/camera_service.dart';
import '../../../llm_shared/presentation/providers/llm_shared_providers.dart';
import '../../data/datasources/certificate_upload_datasource.dart';
import '../../data/datasources/llm_extraction_datasource.dart';
import '../../data/local/certificate_local_store.dart';
import '../../data/repositories/certificate_repository_impl.dart';
import '../../domain/entities/certificado_capturado.dart';
import '../../domain/repositories/certificate_repository.dart';
import '../../domain/usecases/capturar_certificado.dart';
import '../../domain/usecases/converter_heic_para_jpeg.dart';
import '../../domain/usecases/extrair_dados_certificado_llm.dart';

// ---------------------------------------------------------------------------
// Providers de infraestrutura do módulo 2 (repositório, datasources, use
// cases) — ver convenção em `lattes_providers.dart`.
// ---------------------------------------------------------------------------

final certificateUploadDatasourceProvider = Provider<CertificateUploadDatasource>(
  (ref) => CertificateUploadDatasourceWeb(),
);

final certificateLocalStoreProvider = Provider((ref) => const CertificateLocalStore());

final llmExtractionDatasourceProvider = Provider(
  (ref) => LlmExtractionDatasource(ref.watch(llmRepositoryProvider)),
);

final certificateRepositoryProvider = Provider<CertificateRepository>(
  (ref) => CertificateRepositoryImpl(
    ref.watch(llmExtractionDatasourceProvider),
    ref.watch(certificateLocalStoreProvider),
    ref.watch(heicConverterProvider),
    ref.watch(taskRunnerProvider),
  ),
);

final capturarCertificadoProvider = Provider(
  (ref) => CapturarCertificado(ref.watch(certificateRepositoryProvider)),
);

final converterHeicParaJpegProvider = Provider(
  (ref) => ConverterHeicParaJpeg(ref.watch(certificateRepositoryProvider)),
);

final extrairDadosCertificadoLlmProvider = Provider(
  (ref) => ExtrairDadosCertificadoLlm(ref.watch(certificateRepositoryProvider)),
);

/// Estado da tela de captura: lista de certificados (já persistidos, mais os
/// que estão sendo processados nesta sessão) mais um erro "de topo" para
/// falhas que não pertencem a nenhum certificado específico (ex.: seletor de
/// arquivo não abriu).
class CertificateCaptureState {
  final List<CertificadoCapturado> certificados;
  final bool processando;
  final int totalSelecionado;
  final int processadosAteAgora;
  final String? erro;

  const CertificateCaptureState({
    this.certificados = const [],
    this.processando = false,
    this.totalSelecionado = 0,
    this.processadosAteAgora = 0,
    this.erro,
  });

  CertificateCaptureState copyWith({
    List<CertificadoCapturado>? certificados,
    bool? processando,
    int? totalSelecionado,
    int? processadosAteAgora,
    String? erro,
    bool limparErro = false,
  }) {
    return CertificateCaptureState(
      certificados: certificados ?? this.certificados,
      processando: processando ?? this.processando,
      totalSelecionado: totalSelecionado ?? this.totalSelecionado,
      processadosAteAgora: processadosAteAgora ?? this.processadosAteAgora,
      erro: limparErro ? null : (erro ?? this.erro),
    );
  }
}

/// Controller da tela de captura de certificados. Cada arquivo selecionado
/// passa pelo mesmo pipeline de 3 passos descrito em ARQUITETURA.md:
/// registrar captura -> normalizar formato (HEIC -> JPEG, se necessário) ->
/// extrair dados via LLM. Os passos são sequenciais e cada um já persiste o
/// estado intermediário via [CertificateLocalStore], então uma falha no
/// meio do caminho não perde o que já foi feito (o certificado fica visível
/// na lista com o status/erro do passo em que parou).
class CertificateCaptureController extends Notifier<CertificateCaptureState> {
  @override
  CertificateCaptureState build() {
    _carregarExistentes();
    return const CertificateCaptureState();
  }

  Future<void> _carregarExistentes() async {
    final certificados = await ref.read(certificateRepositoryProvider).listarTodos();
    state = state.copyWith(certificados: certificados);
  }

  void limparErro() => state = state.copyWith(limparErro: true);

  Future<void> selecionarESincronizarArquivos() => _selecionarEProcessar(
        () => ref.read(certificateUploadDatasourceProvider).selecionarImagens(),
        'Não foi possível abrir o seletor de arquivo',
      );

  /// Seleciona uma pasta inteira (com subpastas) de uma vez — ver
  /// `CertificateUploadDatasourceWeb.selecionarPasta` para o porquê de não
  /// existir um equivalente confiável em mobile.
  Future<void> selecionarPastaESincronizar() => _selecionarEProcessar(
        () => ref.read(certificateUploadDatasourceProvider).selecionarPasta(),
        'Não foi possível abrir o seletor de pasta',
      );

  Future<void> _selecionarEProcessar(
    Future<List<ArquivoSelecionado>> Function() selecionar,
    String mensagemErroSeletor,
  ) async {
    state = state.copyWith(
      processando: true,
      totalSelecionado: 0,
      processadosAteAgora: 0,
      limparErro: true,
    );

    final List<ArquivoSelecionado> arquivos;
    try {
      arquivos = await selecionar();
    } catch (e) {
      state = state.copyWith(processando: false, erro: '$mensagemErroSeletor: $e');
      return;
    }

    // Lista vazia é o retorno normal quando o usuário fecha o seletor sem
    // escolher nada — mas também acontece quando ele ESCOLHE uma
    // pasta/arquivo que não tem nenhum formato aceito (ex.: pasta cheia de
    // PDF, que este pipeline ainda não lê). Sem esta mensagem, os dois
    // casos ficam indistinguíveis de "não fez nada" (relatado ao vivo).
    if (arquivos.isEmpty) {
      state = state.copyWith(
        processando: false,
        erro: 'Nenhum certificado foi adicionado. Se você selecionou arquivos ou uma pasta, '
            'confira se o formato é aceito (JPG, PNG, HEIC/HEIF ou WEBP).',
      );
      return;
    }

    state = state.copyWith(totalSelecionado: arquivos.length);
    for (final arquivo in arquivos) {
      await _processarArquivo(arquivo);
      state = state.copyWith(processadosAteAgora: state.processadosAteAgora + 1);
    }

    state = state.copyWith(processando: false);
  }

  /// Processa um frame capturado ao vivo pela câmera (ver `CameraServiceWeb`
  /// e o widget `_CameraCapturePage` em `certificate_capture_page.dart`) —
  /// mesmo pipeline de 3 passos de `_processarArquivo`, só que a partir de
  /// um `CapturedFrame` em vez de um arquivo selecionado.
  Future<void> processarFrameDaCamera(CapturedFrame frame) async {
    state = state.copyWith(processando: true, totalSelecionado: 1, processadosAteAgora: 0);
    await _processarArquivo(
      ArquivoSelecionado(
        bytes: frame.bytes,
        mimeType: frame.mimeType,
        nomeArquivo: 'camera_${frame.capturedAt.millisecondsSinceEpoch}.jpg',
      ),
    );
    state = state.copyWith(processando: false, processadosAteAgora: 1);
  }

  Future<void> _processarArquivo(ArquivoSelecionado arquivo) async {
    final resultadoCaptura = await ref.read(capturarCertificadoProvider).call(
          imagemBytes: arquivo.bytes,
          mimeType: arquivo.mimeType,
        );

    final capturado = resultadoCaptura.match((falha) {
      state = state.copyWith(
        erro: 'Falha ao capturar "${arquivo.caminhoRelativo}": ${falha.message}',
      );
      return null;
    }, (c) => c);
    if (capturado == null) return;

    state = state.copyWith(certificados: [...state.certificados, capturado]);

    await reextrair(capturado.id);
  }

  /// Chamado tanto pelo pipeline automático quanto pelo botão "Tentar
  /// novamente" na UI — para QUALQUER certificado com falha, não só falha
  /// de extração: repete a normalização HEIC antes de extrair (idempotente
  /// quando a imagem já não é HEIC, ver `ConverterHeicParaJpeg`), porque o
  /// único botão de retry da UI não distinguia entre as duas causas
  /// possíveis de falha e sempre pulava direto para a extração, reenviando
  /// bytes HEIC não convertidos para a API do LLM quando quem tinha
  /// falhado era a conversão (achado da revisão de código).
  Future<void> reextrair(String certificadoId) async {
    final resultadoNormalizacao =
        await ref.read(converterHeicParaJpegProvider).call(certificadoId);
    if (resultadoNormalizacao.isLeft()) {
      resultadoNormalizacao.match(
        (falha) {
          final atual = state.certificados.firstWhere((c) => c.id == certificadoId);
          _marcarFalha(atual, falha.message);
        },
        (_) {},
      );
      return;
    }

    final resultado = await ref.read(extrairDadosCertificadoLlmProvider).call(certificadoId);
    resultado.match(
      (falha) {
        final atual = state.certificados.firstWhere((c) => c.id == certificadoId);
        _marcarFalha(atual, falha.message);
      },
      (atualizado) => _atualizarNaLista(atualizado),
    );
  }

  void _marcarFalha(CertificadoCapturado certificado, String mensagem) {
    _atualizarNaLista(
      certificado.copyWith(status: StatusCertificado.falhaExtracao, mensagemErro: mensagem),
    );
  }

  void _atualizarNaLista(CertificadoCapturado atualizado) {
    state = state.copyWith(
      certificados: [
        for (final c in state.certificados) if (c.id == atualizado.id) atualizado else c,
      ],
    );
  }
}

final certificateCaptureControllerProvider =
    NotifierProvider<CertificateCaptureController, CertificateCaptureState>(
  CertificateCaptureController.new,
);
