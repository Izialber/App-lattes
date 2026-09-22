import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../repositories/comprovante_repository.dart';

class RemoverComprovante {
  final ComprovanteRepository _repository;

  const RemoverComprovante(this._repository);

  Future<Either<Failure, Unit>> call(String entradaId) => _repository.remover(entradaId);
}
