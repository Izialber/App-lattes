import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/cloud_provider.dart';
import '../entities/oauth_token.dart';

abstract class AuthRepository {
  /// Inicia o fluxo OAuth2 Authorization Code + PKCE por REDIRECT (nunca
  /// popup — bloqueado pelo Safari). Redireciona a própria aba/janela para
  /// o provedor; o retorno é tratado por [handleRedirectCallback] ao recarregar.
  Future<Either<Failure, Unit>> iniciarLogin(CloudProvider provider);

  /// Chamado na inicialização do app para detectar se a URL atual é um
  /// retorno de redirect OAuth (contendo `code` e `state`), trocar o code
  /// pelos tokens, e persistir via SecureStorageService.
  Future<Either<Failure, OAuthToken>> tratarRetornoRedirect();

  /// Retorna um token válido, renovando automaticamente via refresh token
  /// se estiver perto de expirar. É o ÚNICO ponto de leitura de token usado
  /// pelos demais repositórios (nunca leem SecureStorageService diretamente).
  Future<Either<Failure, OAuthToken>> obterTokenValido(CloudProvider provider);

  Future<void> logout(CloudProvider provider);
}
