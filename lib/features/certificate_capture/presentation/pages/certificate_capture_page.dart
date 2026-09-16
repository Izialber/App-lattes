import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar certificados'),
        actions: [
          IconButton(
            tooltip: 'Configurar provedor de LLM',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.configuracoesLlm),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: estado.processando
            ? null
            : () => ref
                .read(certificateCaptureControllerProvider.notifier)
                .selecionarESincronizarArquivos(),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Selecionar certificados'),
      ),
      body: _corpo(context, ref, estado),
    );
  }

  Widget _corpo(BuildContext context, WidgetRef ref, CertificateCaptureState estado) {
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
        if (estado.processando) const LinearProgressIndicator(),
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
        trailing: certificado.status == StatusCertificado.falhaExtracao
            ? IconButton(
                tooltip: 'Tentar novamente',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref
                    .read(certificateCaptureControllerProvider.notifier)
                    .reextrair(certificado.id),
              )
            : null,
      ),
    );
  }

  String _subtitulo(CertificadoCapturado c) {
    if (c.status == StatusCertificado.falhaExtracao) {
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
