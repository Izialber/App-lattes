import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../../../../core/platform/secure_storage/secure_storage_service.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/oauth_token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/oauth_pkce_datasource.dart';

/// PENDENTE (fora do escopo do entregável 5): implementação completa.
/// `obterTokenValido` é o método mais sensível — deve ser thread-safe o
/// suficiente para não disparar duas renovações concorrentes quando vários
/// uploads da fila pedem token ao mesmo tempo (usar um `Completer`
/// compartilhado por provider).
class AuthRepositoryImpl implements AuthRepository {
  final OauthPkceDatasource _pkceDatasource;
  final SecureStorageService _secureStorage;

  const AuthRepositoryImpl(this._pkceDatasource, this._secureStorage);

  @override
  Future<Either<Failure, Unit>> iniciarLogin(CloudProvider provider) {
    throw UnimplementedError('AuthRepositoryImpl.iniciarLogin: pendente');
  }

  @override
  Future<Either<Failure, OAuthToken>> tratarRetornoRedirect() {
    throw UnimplementedError('AuthRepositoryImpl.tratarRetornoRedirect: pendente');
  }

  @override
  Future<Either<Failure, OAuthToken>> obterTokenValido(CloudProvider provider) {
    throw UnimplementedError('AuthRepositoryImpl.obterTokenValido: pendente');
  }

  @override
  Future<void> logout(CloudProvider provider) {
    throw UnimplementedError('AuthRepositoryImpl.logout: pendente');
  }
}
