import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/categoria_entrada_lattes.dart';
import '../entities/comprovante_entrada.dart';
import '../repositories/comprovante_repository.dart';

class AnexarComprovante {
  final ComprovanteRepository _repository;

  const AnexarComprovante(this._repository);

  Future<Either<Failure, ComprovanteEntrada>> call({
    required String entradaId,
    required CategoriaEntradaLattes categoria,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) {
    return _repository.anexar(
      entradaId: entradaId,
      categoria: categoria,
      bytes: bytes,
      nomeArquivo: nomeArquivo,
      mimeType: mimeType,
    );
  }
}
