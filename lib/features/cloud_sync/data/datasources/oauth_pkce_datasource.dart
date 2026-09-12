/// Gera code_verifier/code_challenge (S256) via `package:crypto`, monta a
/// URL de autorização e usa `openid_client` para o fluxo Authorization Code
/// + PKCE por REDIRECT. Nunca abre popup (bloqueado pelo Safari iOS — ver
/// contexto do projeto). `app_links` captura o retorno na inicialização do
/// app (ver `tratarRetornoRedirect` em `AuthRepositoryImpl`).
///
/// PENDENTE (fora do escopo do entregável 5): implementação completa do
/// fluxo, incluindo o `state` anti-CSRF persistido em sessionStorage/Hive
/// antes do redirect (para validar no retorno).
class OauthPkceDatasource {
  Future<Uri> montarUrlAutorizacao({required String provider}) {
    throw UnimplementedError('OauthPkceDatasource.montarUrlAutorizacao: pendente');
  }

  Future<Map<String, dynamic>> trocarCodePorTokens({
    required String provider,
    required String code,
    required String codeVerifier,
  }) {
    throw UnimplementedError('OauthPkceDatasource.trocarCodePorTokens: pendente');
  }

  Future<Map<String, dynamic>> renovarComRefreshToken({
    required String provider,
    required String refreshToken,
  }) {
    throw UnimplementedError('OauthPkceDatasource.renovarComRefreshToken: pendente');
  }
}
