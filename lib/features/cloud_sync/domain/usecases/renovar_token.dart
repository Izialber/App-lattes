import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/cloud_provider.dart';
import '../entities/oauth_token.dart';
import '../repositories/auth_repository.dart';

/// Chamado por um interceptor do Dio antes de cada request e, de forma
/// preventiva, por um timer de background enquanto há itens na fila de
/// upload — nunca esperamos o 401 da API para reagir.
class RenovarToken {
  final AuthRepository _repository;

  const RenovarToken(this._repository);

  Future<Either<Failure, OAuthToken>> call(CloudProvider provider) {
    return _repository.obterTokenValido(provider);
  }
}
