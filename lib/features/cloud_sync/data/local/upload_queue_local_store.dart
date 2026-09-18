import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/upload_task.dart';

/// Persistência da fila offline-first em Hive (IndexedDB no web) — mesmo
/// padrão de `CertificateLocalStore`: metadados e bytes do PDF em boxes
/// separadas, para não carregar todos os PDFs na memória só para listar a
/// fila. Todo método grava de forma síncrona com a mudança de estado do use
/// case correspondente — a fila nunca deve existir só em memória, senão um
/// reload de aba (comum no Safari iOS sob pressão de memória) perde o
/// progresso do usuário.
///
/// As boxes precisam estar abertas (`Hive.openBox`) ANTES de qualquer
/// método desta classe ser chamado — feito em `core/di/bootstrap.dart`.
class UploadQueueLocalStore {
  const UploadQueueLocalStore();

  static const metadataBoxName = 'upload_queue_metadata';
  static const pdfsBoxName = 'upload_queue_pdfs';

  Box<Map> get _metadata => Hive.box<Map>(metadataBoxName);
  Box<Uint8List> get _pdfs => Hive.box<Uint8List>(pdfsBoxName);

  Future<void> salvarPdf(String taskId, List<int> bytes) {
    return _pdfs.put(taskId, Uint8List.fromList(bytes));
  }

  Uint8List? lerPdf(String taskId) => _pdfs.get(taskId);

  Future<void> salvar(UploadTask task) {
    return _metadata.put(task.id, _paraMapa(task));
  }

  List<UploadTask> listarTodas() {
    return _metadata.values.map(_daMapa).toList(growable: false);
  }

  Future<void> remover(String taskId) async {
    await _metadata.delete(taskId);
    await _pdfs.delete(taskId);
  }

  Map<String, dynamic> _paraMapa(UploadTask t) => {
        'id': t.id,
        'certificadoId': t.certificadoId,
        'provider': t.provider.name,
        'nomeArquivoDeterministico': t.nomeArquivoDeterministico,
        'caminhoPdfLocal': t.caminhoPdfLocal,
        'status': t.status.name,
        'tentativas': t.tentativas,
        'uploadSessionUrl': t.uploadSessionUrl,
        'bytesEnviados': t.bytesEnviados,
        'idArquivoCloud': t.idArquivoCloud,
        'mensagemErro': t.mensagemErro,
      };

  UploadTask _daMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);

    return UploadTask(
      id: mapa['id'] as String,
      certificadoId: mapa['certificadoId'] as String,
      provider: CloudProvider.values.byName(mapa['provider'] as String),
      nomeArquivoDeterministico: mapa['nomeArquivoDeterministico'] as String,
      caminhoPdfLocal: mapa['caminhoPdfLocal'] as String,
      status: UploadStatus.values.byName(mapa['status'] as String),
      tentativas: mapa['tentativas'] as int? ?? 0,
      uploadSessionUrl: mapa['uploadSessionUrl'] as String?,
      bytesEnviados: mapa['bytesEnviados'] as int? ?? 0,
      idArquivoCloud: mapa['idArquivoCloud'] as String?,
      mensagemErro: mapa['mensagemErro'] as String?,
    );
  }
}
