import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import '../../../../core/config/oauth_config.dart';
import '../../domain/entities/cloud_provider.dart';

const _sessionKeyVerifier = 'oauth_code_verifier';
const _sessionKeyState = 'oauth_state';
const _sessionKeyProvider = 'oauth_provider';

/// Gera code_verifier/code_challenge (S256) via `package:crypto`, monta a
/// URL de autorização e faz o fluxo Authorization Code + PKCE inteiramente
/// por REDIRECT de página inteira (nunca popup — bloqueado pelo Safari
/// iOS). Como um redirect de página completa perde qualquer estado em
/// memória, `code_verifier`/`state`/provedor ficam em `sessionStorage`
/// entre a ida e a volta (apagados assim que consumidos em
/// [trocarCodePorTokens]).
///
/// Só Google está implementado por enquanto (decisão do usuário: Microsoft
/// fica para depois). Chamar com [CloudProvider.oneDrive] lança
/// [UnimplementedError].
class OauthPkceDatasource {
  final Dio _dio;

  OauthPkceDatasource({Dio? dio}) : _dio = dio ?? Dio();

  String _gerarCodeVerifier() {
    final bytes = Uint8List(32);
    web.window.crypto.getRandomValues(bytes.toJS);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _gerarCodeChallenge(String verifier) {
    final digest = crypto.sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _gerarState() {
    final bytes = Uint8List(16);
    web.window.crypto.getRandomValues(bytes.toJS);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  void _garantirSuportado(CloudProvider provider) {
    final config = OAuthConfig.forProvider(provider);
    if (!config.isConfigured) {
      throw UnimplementedError(
        'OauthPkceDatasource: Client ID de ${provider.name} ainda não configurado '
        '(ver lib/core/config/oauth_config.dart)',
      );
    }
  }

  /// Monta a URL de autorização e já persiste o `code_verifier`/`state`
  /// em `sessionStorage` para o retorno do redirect consumir.
  Future<Uri> montarUrlAutorizacao({required CloudProvider provider}) async {
    _garantirSuportado(provider);
    final config = OAuthConfig.forProvider(provider);

    final verifier = _gerarCodeVerifier();
    final challenge = _gerarCodeChallenge(verifier);
    final state = _gerarState();

    web.window.sessionStorage.setItem(_sessionKeyVerifier, verifier);
    web.window.sessionStorage.setItem(_sessionKeyState, state);
    web.window.sessionStorage.setItem(_sessionKeyProvider, provider.name);

    return Uri.parse(config.authorizationEndpoint).replace(queryParameters: {
      'client_id': config.clientId,
      'redirect_uri': OAuthConfig.redirectUri,
      'response_type': 'code',
      'scope': config.scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      // access_type=offline + prompt=consent: sem isso o Google só emite
      // refresh_token na PRIMEIRA autorização de cada usuário, o que
      // quebraria silenciosamente uma reautorização futura (ex.: depois de
      // revogar acesso manualmente).
      if (provider == CloudProvider.googleDrive) 'access_type': 'offline',
      if (provider == CloudProvider.googleDrive) 'prompt': 'consent',
    });
  }

  /// Lê `code_verifier`/`state` salvos por [montarUrlAutorizacao], valida o
  /// `state` recebido (anti-CSRF) e troca o `code` pelos tokens. Limpa o
  /// `sessionStorage` ao final, com sucesso ou falha.
  Future<Map<String, dynamic>> trocarCodePorTokens({
    required String code,
    required String stateRecebido,
  }) async {
    final providerName = web.window.sessionStorage.getItem(_sessionKeyProvider);
    final verifier = web.window.sessionStorage.getItem(_sessionKeyVerifier);
    final stateEsperado = web.window.sessionStorage.getItem(_sessionKeyState);

    web.window.sessionStorage.removeItem(_sessionKeyVerifier);
    web.window.sessionStorage.removeItem(_sessionKeyState);
    web.window.sessionStorage.removeItem(_sessionKeyProvider);

    if (providerName == null || verifier == null || stateEsperado == null) {
      throw StateError('Sessão de login expirada ou inválida — nenhum fluxo OAuth em andamento.');
    }
    if (stateRecebido != stateEsperado) {
      throw StateError('State OAuth não confere (possível CSRF) — login abortado.');
    }

    final provider = CloudProvider.values.firstWhere((p) => p.name == providerName);
    final config = OAuthConfig.forProvider(provider);

    final response = await _dio.post<Map<String, dynamic>>(
      config.tokenEndpoint,
      data: {
        'client_id': config.clientId,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': OAuthConfig.redirectUri,
        'grant_type': 'authorization_code',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> renovarComRefreshToken({
    required CloudProvider provider,
    required String refreshToken,
  }) async {
    _garantirSuportado(provider);
    final config = OAuthConfig.forProvider(provider);

    final response = await _dio.post<Map<String, dynamic>>(
      config.tokenEndpoint,
      data: {
        'client_id': config.clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return response.data!;
  }
}
