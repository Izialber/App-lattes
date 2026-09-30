import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/comprovante_entrada.dart';
import '../repositories/comprovante_repository.dart';

class AtualizarStatusSincronizacaoComprovante {
  final ComprovanteRepository _repository;

  const AtualizarStatusSincronizacaoComprovante(this._repository);

  Future<Either<Failure, Unit>> call(
    String comprovanteId,
    StatusSincronizacaoComprovante status, {
    String? idArquivoCloud,
    String? mensagemErro,
  }) {
    return _repository.atualizarStatusSincronizacao(
      comprovanteId,
      status,
      idArquivoCloud: idArquivoCloud,
      mensagemErro: mensagemErro,
    );
  }
}
