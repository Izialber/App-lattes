import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../cloud_sync/presentation/providers/cloud_sync_providers.dart';
import '../../domain/entities/certificado_capturado.dart';
import '../providers/certificate_capture_providers.dart';

/// Tela de captura: upload/seleção múltipla de imagens de certificado (usa
/// `file_picker`, funciona igual em desktop e mobile — inclusive dispara o
/// seletor de câmera/galeria nativo em navegadores mobile quando o input
/// aceita imagem). Cada arquivo selecionado passa pelo pipeline completo
/// (captura -> normalização HEIC -> extração via LLM) e aparece na lista com
/// o status atual.
///
/// Câmera ao vivo (getUserMedia): `CameraServiceWeb` já está implementada
/// (ver `core/platform/camera/camera_service_web.dart`), mas o widget de
/// preview ao vivo (`HtmlElementView` ligado ao `<video>`) ainda não foi
/// integrado nesta tela — pendência da próxima rodada.
class CertificateCapturePage extends ConsumerWidget {
  const CertificateCapturePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(certificateCaptureControllerProvider);
    final estadoSync = ref.watch(cloudSyncControllerProvider);
    final temCertificadosProntos = estado.certificados.any(
      (c) =>
          c.status == StatusCertificado.pendenteRevisao || c.status == StatusCertificado.aprovado,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar certificados'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com o Google Drive',
            icon: estadoSync.sincronizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            onPressed: (!temCertificadosProntos || estadoSync.sincronizando)
                ? null
                : () => ref.read(cloudSyncControllerProvider.notifier).sincronizarTodos(),
          ),
          IconButton(
            tooltip: 'Configurar provedor de LLM',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.configuracoesLlm),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: estado.processando ? null : () => _abrirMenuDeSelecao(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Adicionar certificados'),
      ),
      body: _corpo(context, ref, estado),
    );
  }

  Future<void> _abrirMenuDeSelecao(BuildContext context, WidgetRef ref) {
    final controller = ref.read(certificateCaptureControllerProvider.notifier);
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Selecionar arquivos'),
              onTap: () {
                Navigator.of(context).pop();
                controller.selecionarESincronizarArquivos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Selecionar uma pasta inteira'),
              subtitle: const Text(
                'Inclui todas as subpastas. Pode não funcionar em alguns navegadores mobile.',
              ),
              onTap: () {
                Navigator.of(context).pop();
                controller.selecionarPastaESincronizar();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(BuildContext context, WidgetRef ref, CertificateCaptureState estado) {
    final estadoSync = ref.watch(cloudSyncControllerProvider);

    return Column(
      children: [
        if (estado.erro != null)
          MaterialBanner(
            content: Text(estado.erro!),
            leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            actions: [
              TextButton(
                onPressed: () =>
                    ref.read(certificateCaptureControllerProvider.notifier).limparErro(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        if (estadoSync.erro != null)
          MaterialBanner(
            content: Text(estadoSync.erro!),
            leading: const Icon(Icons.cloud_off_outlined),
            actions: [
              TextButton(
                onPressed: () => ref.read(cloudSyncControllerProvider.notifier).limparErro(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        if (estado.processando) ...[
          LinearProgressIndicator(
            value: estado.totalSelecionado == 0
                ? null // total ainda desconhecido (seletor de arquivo/pasta ainda aberto)
                : estado.processadosAteAgora / estado.totalSelecionado,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              estado.totalSelecionado == 0
                  ? 'Selecionando arquivos…'
                  : 'Processando ${estado.processadosAteAgora} de '
                      '${estado.totalSelecionado} certificados…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        Expanded(
          child: estado.certificados.isEmpty
              ? _estadoVazio(context)
              : _lista(context, ref, estado.certificados),
        ),
      ],
    );
  }

  Widget _estadoVazio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nenhum certificado ainda. Selecione fotos ou PDFs digitalizados dos seus '
          'certificados e diplomas para começar a montar o dossiê.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, WidgetRef ref, List<CertificadoCapturado> certificados) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: certificados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _CertificadoCard(certificado: certificados[index]),
    );
  }
}

class _CertificadoCard extends ConsumerWidget {
  final CertificadoCapturado certificado;

  const _CertificadoCard({required this.certificado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: _iconePorStatus(context, certificado.status),
        title: Text(certificado.tituloExtraido ?? 'Processando…'),
        subtitle: Text(_subtitulo(certificado)),
        trailing: _botaoTentarNovamente(ref),
      ),
    );
  }

  Widget? _botaoTentarNovamente(WidgetRef ref) {
    switch (certificado.status) {
      case StatusCertificado.falhaExtracao:
        return IconButton(
          tooltip: 'Tentar extrair de novo',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref
              .read(certificateCaptureControllerProvider.notifier)
              .reextrair(certificado.id),
        );
      case StatusCertificado.falhaSincronizacao:
        return IconButton(
          tooltip: 'Tentar enviar de novo',
          icon: const Icon(Icons.cloud_sync_outlined),
          onPressed: () =>
              ref.read(cloudSyncControllerProvider.notifier).retentarUm(certificado.id),
        );
      default:
        return null;
    }
  }

  String _subtitulo(CertificadoCapturado c) {
    if (c.status == StatusCertificado.falhaExtracao ||
        c.status == StatusCertificado.falhaSincronizacao) {
      return c.mensagemErro ?? 'Falha ao processar este certificado.';
    }
    if (c.status == StatusCertificado.capturado || c.status == StatusCertificado.extraindoDados) {
      return 'Extraindo dados do certificado…';
    }

    final partes = <String>[
      if (c.instituicaoExtraida != null) c.instituicaoExtraida!,
      if (c.cargaHorariaExtraidaHoras != null) '${c.cargaHorariaExtraidaHoras}h',
      if (c.dataExtraida != null) DateFormat('dd/MM/yyyy').format(c.dataExtraida!),
    ];
    return partes.isEmpty ? _rotuloStatus(c.status) : partes.join(' · ');
  }

  String _rotuloStatus(StatusCertificado status) {
    switch (status) {
      case StatusCertificado.capturado:
        return 'Capturado';
      case StatusCertificado.extraindoDados:
        return 'Extraindo dados…';
      case StatusCertificado.pendenteRevisao:
        return 'Aguardando revisão';
      case StatusCertificado.aprovado:
        return 'Aprovado';
      case StatusCertificado.enviandoParaCloud:
        return 'Enviando…';
      case StatusCertificado.sincronizado:
        return 'Sincronizado';
      case StatusCertificado.falhaExtracao:
        return 'Falha na extração';
      case StatusCertificado.falhaSincronizacao:
        return 'Falha na sincronização';
    }
  }

  Widget _iconePorStatus(BuildContext context, StatusCertificado status) {
    switch (status) {
      case StatusCertificado.capturado:
      case StatusCertificado.extraindoDados:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case StatusCertificado.pendenteRevisao:
        return const Icon(Icons.rate_review_outlined);
      case StatusCertificado.aprovado:
      case StatusCertificado.sincronizado:
        return Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary);
      case StatusCertificado.enviandoParaCloud:
        return const Icon(Icons.cloud_upload_outlined);
      case StatusCertificado.falhaExtracao:
      case StatusCertificado.falhaSincronizacao:
        return Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error);
    }
  }
}
