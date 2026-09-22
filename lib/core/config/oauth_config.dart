import '../../features/cloud_sync/domain/entities/cloud_provider.dart';

/// Configuração pública do fluxo OAuth2 (Authorization Code + PKCE — ver
/// DECISOES.md). O Client ID não é segredo: um Client ID OAuth de app
/// público (SPA) é, por design, visível no código-fonte distribuído ao
/// navegador. O que protege a conta do usuário é o `redirect_uri` fixo (só
/// o domínio configurado no Google Cloud/Azure recebe o `code`) e o PKCE (o
/// `code_verifier` nunca sai do navegador).
///
/// [googleClientSecret] É DIFERENTE — em teoria deveria ser mantido em
/// servidor, mas este app não tem backend. Achado ao testar o login ao
/// vivo (2026-09-22): o Google EXIGE `client_secret` na troca do code por
/// tokens mesmo com PKCE, quando o Client ID é do tipo "Aplicativo da Web"
/// (obrigatório aqui — só client types como "Desktop"/"TV" dispensam o
/// secret, mas esses só aceitam redirect URI `localhost`, incompatíveis
/// com o domínio de produção deste app). Sem alternativa sem backend: o
/// secret fica embutido no bundle JS público, mitigado por (1) escopo
/// mínimo `drive.file`, (2) PKCE ainda impede um secret sozinho (sem o
/// `code`+`code_verifier` corretos) de ser útil a um atacante, (3) app em
/// modo "Testing" com só o próprio usuário como test user. Ver DECISOES.md.
///
/// [googleClientId] preenchido com o Client ID do projeto "Certificados
/// Lattes" no Google Cloud Console (tipo "Aplicativo da Web"), app OAuth em
/// modo "Testing" (Externo) com o próprio usuário como test user — ver
/// DECISOES.md/RISCOS.md para o passo de publicar em produção mais adiante.
class OAuthConfig {
  OAuthConfig._();

  static const String googleClientId =
      '880663744398-p9hm87tu007vqr7qtud93tq472hpolgf.apps.googleusercontent.com';

  /// Injetado em tempo de build via `--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=...`
  /// (variável de ambiente do Cloudflare Pages, NUNCA commitada — ver
  /// DECISOES.md). Continua acabando visível no bundle JS público depois de
  /// compilado (é o trade-off aceito, documentado acima), mas não fica em
  /// texto puro no histórico do git, onde ficaria exposto permanentemente
  /// e sujeito a scanners automáticos de segredo (o repositório é público).
  static const String googleClientSecret =
      String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET');
  static const String microsoftClientId = '';

  /// Precisa bater exatamente com uma "Authorized redirect URI" cadastrada
  /// no provedor — inclui o path completo da subpasta de deploy.
  static const String redirectUri = 'https://izialber.com.br/app-lattes/oauth/callback';

  static ProviderOAuthConfig forProvider(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.googleDrive:
        return const ProviderOAuthConfig(
          clientId: googleClientId,
          // Google exige client_secret na troca do code por tokens mesmo
          // com PKCE para Client ID tipo "Aplicativo da Web" — ver
          // docstring de [googleClientSecret] acima.
          clientSecret: googleClientSecret,
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
          // drive.file: só arquivos criados por este app — nunca o Drive
          // inteiro do usuário (decisão de escopo mínimo, ver RISCOS.md).
          scope: 'openid email https://www.googleapis.com/auth/drive.file',
        );
      case CloudProvider.oneDrive:
        return const ProviderOAuthConfig(
          clientId: microsoftClientId,
          authorizationEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
          tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
          scope: 'openid email offline_access Files.ReadWrite.AppFolder',
        );
    }
  }
}

class ProviderOAuthConfig {
  final String clientId;
  final String? clientSecret;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String scope;

  const ProviderOAuthConfig({
    required this.clientId,
    this.clientSecret,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scope,
  });

  bool get isConfigured => clientId.isNotEmpty;
}
