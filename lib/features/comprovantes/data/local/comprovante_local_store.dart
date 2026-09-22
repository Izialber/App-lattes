import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/comprovante_entrada.dart';

/// Persistência dos comprovantes anexados — mesmo padrão de
/// `CertificateLocalStore` (metadados e bytes em boxes separadas, chave
/// única `entradaId`, já que este módulo é 1 arquivo por entrada). As boxes
/// precisam estar abertas antes de qualquer método aqui ser chamado (ver
/// `core/di/bootstrap.dart`).
class ComprovanteLocalStore {
  const ComprovanteLocalStore();

  static const metadataBoxName = 'comprovantes_metadata';
  static const bytesBoxName = 'comprovantes_bytes';

  Box<Map> get _metadata => Hive.box<Map>(metadataBoxName);
  Box<Uint8List> get _bytes => Hive.box<Uint8List>(bytesBoxName);

  Future<void> salvarBytes(String entradaId, List<int> bytes) {
    return _bytes.put(entradaId, Uint8List.fromList(bytes));
  }

  Uint8List? lerBytes(String entradaId) => _bytes.get(entradaId);

  Future<void> salvar(ComprovanteEntrada comprovante) {
    return _metadata.put(comprovante.entradaId, _paraMapa(comprovante));
  }

  ComprovanteEntrada? buscar(String entradaId) {
    final mapa = _metadata.get(entradaId);
    return mapa == null ? null : _daMapa(mapa);
  }

  Map<String, ComprovanteEntrada> listarTodos() {
    final comprovantes = _metadata.values.map(_daMapa);
    return {for (final c in comprovantes) c.entradaId: c};
  }

  Future<void> remover(String entradaId) async {
    await _metadata.delete(entradaId);
    await _bytes.delete(entradaId);
  }

  Map<String, dynamic> _paraMapa(ComprovanteEntrada c) => {
        'entradaId': c.entradaId,
        'categoria': c.categoria.name,
        'nomeArquivo': c.nomeArquivo,
        'mimeType': c.mimeType,
        'anexadoEm': c.anexadoEm.toIso8601String(),
      };

  ComprovanteEntrada _daMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    return ComprovanteEntrada(
      entradaId: mapa['entradaId'] as String,
      categoria: CategoriaEntradaLattes.values.byName(mapa['categoria'] as String),
      nomeArquivo: mapa['nomeArquivo'] as String,
      mimeType: mapa['mimeType'] as String,
      anexadoEm: DateTime.parse(mapa['anexadoEm'] as String),
    );
  }
}
