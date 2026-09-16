import '../../features/cloud_sync/domain/entities/cloud_provider.dart';

/// Configuração pública do fluxo OAuth2 (Authorization Code + PKCE, sem
/// client secret — ver DECISOES.md). Nada aqui é segredo: um Client ID
/// OAuth de app público (SPA) é, por design, visível no código-fonte
/// distribuído ao navegador. O que protege a conta do usuário é o
/// `redirect_uri` fixo (só o domínio configurado no Google Cloud/Azure
/// recebe o `code`) e o PKCE (o `code_verifier` nunca sai do navegador).
///
/// [googleClientId] preenchido com o Client ID do projeto "Certificados
/// Lattes" no Google Cloud Console (tipo "Aplicativo da Web"), app OAuth em
/// modo "Testing" (Externo) com o próprio usuário como test user — ver
/// DECISOES.md/RISCOS.md para o passo de publicar em produção mais adiante.
class OAuthConfig {
  OAuthConfig._();

  static const String googleClientId =
      '880663744398-p9hm87tu007vqr7qtud93tq472hpolgf.apps.googleusercontent.com';
  static const String microsoftClientId = '';

  /// Precisa bater exatamente com uma "Authorized redirect URI" cadastrada
  /// no provedor — inclui o path completo da subpasta de deploy.
  static const String redirectUri = 'https://izialber.com.br/app-lattes/oauth/callback';

  static ProviderOAuthConfig forProvider(CloudProvider provider) {
    switch (provider) {
      case CloudProvider.googleDrive:
        return const ProviderOAuthConfig(
          clientId: googleClientId,
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
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String scope;

  const ProviderOAuthConfig({
    required this.clientId,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.scope,
  });

  bool get isConfigured => clientId.isNotEmpty;
}
