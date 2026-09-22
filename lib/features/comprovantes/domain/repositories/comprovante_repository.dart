import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/categoria_entrada_lattes.dart';
import '../entities/comprovante_entrada.dart';

abstract class ComprovanteRepository {
  /// Normaliza formato (HEIC -> JPEG quando aplicável) e anexa [bytes] à
  /// entrada [entradaId] — substitui um comprovante anterior da mesma
  /// entrada, se houver (MVP: 1 arquivo por entrada, ver DECISOES.md).
  Future<Either<Failure, ComprovanteEntrada>> anexar({
    required String entradaId,
    required CategoriaEntradaLattes categoria,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  });

  Future<Either<Failure, Unit>> remover(String entradaId);

  /// Todos os comprovantes já anexados, indexados por `entradaId` — a UI usa
  /// isso pra decidir o ícone de status de cada `EntradaLattesRef`.
  Future<Map<String, ComprovanteEntrada>> listarTodos();

  Uint8List? lerBytes(String entradaId);
}
