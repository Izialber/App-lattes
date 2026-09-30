import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/comprovante_entrada.dart';

/// Persistência dos comprovantes anexados — mesmo padrão de
/// `CertificateLocalStore` (metadados e bytes em boxes separadas). Chave
/// única é `comprovante.id` (não `entradaId`): uma entrada pode ter vários
/// comprovantes (ex.: diploma + histórico do mesmo curso), então
/// `entradaId` se repete entre registros. As boxes precisam estar abertas
/// antes de qualquer método aqui ser chamado (ver `core/di/bootstrap.dart`).
class ComprovanteLocalStore {
  const ComprovanteLocalStore();

  static const metadataBoxName = 'comprovantes_metadata';
  static const bytesBoxName = 'comprovantes_bytes';

  Box<Map> get _metadata => Hive.box<Map>(metadataBoxName);
  Box<Uint8List> get _bytes => Hive.box<Uint8List>(bytesBoxName);

  Future<void> salvarBytes(String comprovanteId, List<int> bytes) {
    return _bytes.put(comprovanteId, Uint8List.fromList(bytes));
  }

  Uint8List? lerBytes(String comprovanteId) => _bytes.get(comprovanteId);

  Future<void> salvar(ComprovanteEntrada comprovante) {
    return _metadata.put(comprovante.id, _paraMapa(comprovante));
  }

  ComprovanteEntrada? buscar(String comprovanteId) {
    final mapa = _metadata.get(comprovanteId);
    return mapa == null ? null : _daMapa(mapa);
  }

  List<ComprovanteEntrada> listarTodos() {
    return _metadata.values.map(_daMapa).toList(growable: false);
  }

  Future<void> remover(String comprovanteId) async {
    await _metadata.delete(comprovanteId);
    await _bytes.delete(comprovanteId);
  }

  Map<String, dynamic> _paraMapa(ComprovanteEntrada c) => {
        'id': c.id,
        'entradaId': c.entradaId,
        'categoria': c.categoria.name,
        'nomeArquivo': c.nomeArquivo,
        'mimeType': c.mimeType,
        'anexadoEm': c.anexadoEm.toIso8601String(),
      };

  ComprovanteEntrada _daMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    return ComprovanteEntrada(
      id: mapa['id'] as String,
      entradaId: mapa['entradaId'] as String,
      categoria: CategoriaEntradaLattes.values.byName(mapa['categoria'] as String),
      nomeArquivo: mapa['nomeArquivo'] as String,
      mimeType: mapa['mimeType'] as String,
      anexadoEm: DateTime.parse(mapa['anexadoEm'] as String),
    );
  }
}
