import 'package:firebase_core/firebase_core.dart';

/// Configuração pública do projeto Firebase (login por email/senha). Como o
/// Client ID OAuth (ver oauth_config.dart), nada aqui é segredo: a config
/// Web do Firebase é, por design, visível no código-fonte distribuído ao
/// navegador — quem protege os dados são as regras de segurança do próprio
/// Firebase, não o sigilo destes valores.
///
/// PENDENTE: preencher com os valores do Firebase Console (Configurações do
/// projeto → Seus apps → app Web) assim que o projeto for criado. Enquanto
/// [apiKey] estiver vazio, a tela de login mantém o formulário de
/// email/senha desabilitado em vez de tentar inicializar o Firebase sem
/// config válida.
class FirebaseConfig {
  FirebaseConfig._();

  static const String apiKey = '';
  static const String authDomain = '';
  static const String projectId = '';
  static const String storageBucket = '';
  static const String messagingSenderId = '';
  static const String appId = '';

  static bool get isConfigured => apiKey.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        storageBucket: storageBucket,
        messagingSenderId: messagingSenderId,
        appId: appId,
      );
}
