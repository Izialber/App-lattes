import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;

import '../../../../core/error/failures.dart';
import '../../../../core/platform/heic/heic_converter.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/comprovante_entrada.dart';
import '../../domain/repositories/comprovante_repository.dart';
import '../local/comprovante_local_store.dart';

/// Implementação real — sem LLM, sem múltiplos passos de status: um
/// comprovante existe ou não existe pra uma entrada (ver DECISOES.md, "Módulo
/// 2 redesenhado"). A única transformação aplicada é normalização de HEIC
/// pra JPEG (mesma lógica do Módulo 2 antigo), porque HEIC não tem preview
/// confiável em todo navegador — PDF e as demais imagens passam direto.
class ComprovanteRepositoryImpl implements ComprovanteRepository {
  final ComprovanteLocalStore _localStore;
  final HeicConverter _heicConverter;

  const ComprovanteRepositoryImpl(this._localStore, this._heicConverter);

  @override
  Future<Either<Failure, ComprovanteEntrada>> anexar({
    required String entradaId,
    required CategoriaEntradaLattes categoria,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) async {
    var bytesFinais = bytes;
    var mimeTypeFinal = mimeType;
    var nomeFinal = nomeArquivo;

    if (_heicConverter.pareceHeic(bytes)) {
      try {
        final convertida = await _heicConverter.converterParaJpeg(bytes);
        bytesFinais = convertida.bytes;
        mimeTypeFinal = convertida.mimeType;
        nomeFinal = '${nomeArquivo.split('.').first}.jpg';
      } on HeicConversionUnsupportedException catch (e) {
        return Left(CaptureFailure(e.message));
      } catch (e) {
        return Left(CaptureFailure('Falha ao converter HEIC: $e'));
      }
    }

    try {
      await _localStore.salvarBytes(entradaId, bytesFinais);
      final comprovante = ComprovanteEntrada(
        entradaId: entradaId,
        categoria: categoria,
        nomeArquivo: nomeFinal,
        mimeType: mimeTypeFinal,
        anexadoEm: DateTime.now(),
      );
      await _localStore.salvar(comprovante);
      return Right(comprovante);
    } catch (e) {
      return Left(LocalStorageFailure('Não foi possível salvar o comprovante: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> remover(String entradaId) async {
    try {
      await _localStore.remover(entradaId);
      return const Right(unit);
    } catch (e) {
      return Left(LocalStorageFailure('Não foi possível remover o comprovante: $e'));
    }
  }

  @override
  Future<Map<String, ComprovanteEntrada>> listarTodos() async => _localStore.listarTodos();

  @override
  Uint8List? lerBytes(String entradaId) => _localStore.lerBytes(entradaId);
}
