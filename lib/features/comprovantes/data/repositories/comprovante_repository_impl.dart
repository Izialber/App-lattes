import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/platform/heic/heic_converter.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/comprovante_entrada.dart';
import '../../domain/repositories/comprovante_repository.dart';
import '../local/comprovante_local_store.dart';

const _uuid = Uuid();

/// Implementação real — sem LLM, sem múltiplos passos de status: cada
/// arquivo enviado vira um `ComprovanteEntrada` novo, e uma entrada pode
/// acumular quantos quiser (ver DECISOES.md, "Módulo 2 redesenhado"). A
/// única transformação aplicada é normalização de HEIC pra JPEG (mesma
/// lógica do Módulo 2 antigo), porque HEIC não tem preview confiável em
/// todo navegador — PDF e as demais imagens passam direto.
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
      final id = _uuid.v4();
      await _localStore.salvarBytes(id, bytesFinais);
      final comprovante = ComprovanteEntrada(
        id: id,
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
  Future<Either<Failure, Unit>> remover(String comprovanteId) async {
    try {
      await _localStore.remover(comprovanteId);
      return const Right(unit);
    } catch (e) {
      return Left(LocalStorageFailure('Não foi possível remover o comprovante: $e'));
    }
  }

  @override
  Future<List<ComprovanteEntrada>> listarTodos() async => _localStore.listarTodos();

  @override
  Uint8List? lerBytes(String comprovanteId) => _localStore.lerBytes(comprovanteId);
}
