import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;
import 'package:web/web.dart' as web;

import '../../../../core/error/failures.dart';
import '../../../../core/platform/secure_storage/secure_storage_service.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/entities/oauth_token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/oauth_pkce_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final OauthPkceDatasource _pkceDatasource;
  final SecureStorageService _secureStorage;

  const AuthRepositoryImpl(this._pkceDatasource, this._secureStorage);

  ({String access, String refresh}) _keysPara(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.googleDrive:
        return (
          access: SecureStorageKeys.googleAccessToken,
          refresh: SecureStorageKeys.googleRefreshToken,
        );
      case CloudProvider.oneDrive:
        return (
          access: SecureStorageKeys.microsoftAccessToken,
          refresh: SecureStorageKeys.microsoftRefreshToken,
        );
    }
  }

  Future<void> _persistirToken(OAuthToken token) async {
    final keys = _keysPara(token.provider);
    await _secureStorage.write(key: keys.access, value: token.accessToken);
    await _secureStorage.write(key: keys.refresh, value: token.refreshToken);
    await _secureStorage.write(
      key: '${keys.access}_expira_em',
      value: token.expiraEm.toIso8601String(),
    );
  }

  OAuthToken _tokenDoResponse(CloudProvider provider, Map<String, dynamic> data, {String? refreshTokenAnterior}) {
    final expiresIn = data['expires_in'] as int? ?? 3600;
    return OAuthToken(
      provider: provider,
      accessToken: data['access_token'] as String,
      // Refresh token só vem na primeira autorização (com prompt=consent);
      // numa renovação, mantém o mesmo refresh token já guardado.
      refreshToken: (data['refresh_token'] as String?) ?? refreshTokenAnterior ?? '',
      expiraEm: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  @override
  Future<Either<Failure, Unit>> iniciarLogin(CloudProvider provider) async {
    try {
      final url = await _pkceDatasource.montarUrlAutorizacao(provider: provider);
      web.window.location.href = url.toString();
      return const Right(unit);
    } on UnimplementedError catch (e) {
      return Left(AuthFailure(e.message ?? 'Provedor ainda não suportado'));
    } catch (e) {
      return Left(AuthFailure('Não foi possível iniciar o login: $e'));
    }
  }

  @override
  Future<Either<Failure, OAuthToken>> tratarRetornoRedirect() async {
    final params = Uri.base.queryParameters;
    final erroRecebido = params['error'];
    if (erroRecebido != null) {
      return Left(AuthFailure('O provedor recusou o login: $erroRecebido', requiresReauth: true));
    }

    final code = params['code'];
    final state = params['state'];
    if (code == null || state == null) {
      return const Left(AuthFailure('Retorno de OAuth sem code/state — link inválido ou expirado.'));
    }

    try {
      final data = await _pkceDatasource.trocarCodePorTokens(code: code, stateRecebido: state);
      // O provider já foi lido/validado dentro do datasource a partir do
      // sessionStorage; aqui só precisamos saber qual token persistir. Como
      // trocarCodePorTokens não devolve o provider, inferimos pelo único
      // provider hoje suportado — quando Microsoft entrar, o datasource
      // passa a devolver o provider junto da resposta.
      final token = _tokenDoResponse(CloudProvider.googleDrive, data);
      await _persistirToken(token);
      return Right(token);
    } catch (e) {
      return Left(AuthFailure('Falha ao trocar o código de autorização por tokens: $e', requiresReauth: true));
    }
  }

  @override
  Future<Either<Failure, OAuthToken>> obterTokenValido(CloudProvider provider) async {
    final keys = _keysPara(provider);
    final accessToken = await _secureStorage.read(key: keys.access);
    final refreshToken = await _secureStorage.read(key: keys.refresh);
    final expiraEmStr = await _secureStorage.read(key: '${keys.access}_expira_em');

    if (accessToken == null || refreshToken == null || expiraEmStr == null) {
      return const Left(AuthFailure('Nenhuma sessão ativa — faça login novamente.', requiresReauth: true));
    }

    final tokenAtual = OAuthToken(
      provider: provider,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiraEm: DateTime.parse(expiraEmStr),
    );

    if (!tokenAtual.precisaRenovar) {
      return Right(tokenAtual);
    }

    try {
      final data = await _pkceDatasource.renovarComRefreshToken(
        provider: provider,
        refreshToken: refreshToken,
      );
      final renovado = _tokenDoResponse(provider, data, refreshTokenAnterior: refreshToken);
      await _persistirToken(renovado);
      return Right(renovado);
    } catch (e) {
      return Left(AuthFailure('Falha ao renovar sessão: $e', requiresReauth: true));
    }
  }

  @override
  Future<void> logout(CloudProvider provider) async {
    final keys = _keysPara(provider);
    await _secureStorage.delete(key: keys.access);
    await _secureStorage.delete(key: keys.refresh);
    await _secureStorage.delete(key: '${keys.access}_expira_em');
  }
}
