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

  static const String apiKey = 'AIzaSyDvFU3uxn0g0I_DvOzd3XiDofpQ4DzfK18';
  static const String authDomain = 'certificados-lattes.firebaseapp.com';
  static const String projectId = 'certificados-lattes';
  static const String storageBucket = 'certificados-lattes.firebasestorage.app';
  static const String messagingSenderId = '1042408353618';
  static const String appId = '1:1042408353618:web:94dc052f5a7bed4639d48b';

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Nome do app Firebase SECUNDÁRIO, usado só pela sessão de admin
  /// (`/admin/codigos`) — isolado de propósito do app padrão (usado pelo
  /// login por e-mail/senha do resto do app). Achado numa revisão de
  /// código: sem isso, `FirebaseAuth.instance` é compartilhado entre a
  /// página de admin e o `AuthController` global, e um login (até um
  /// errado) na página de admin sobrescreve/derruba a sessão do app
  /// principal, porque os dois escutam o mesmo `authStateChanges()`. Mesmo
  /// projeto/config (`options` abaixo) — só o app-instance do SDK client-side
  /// é outro, Firestore/Firebase Auth continuam enxergando o mesmo projeto.
  static const String adminAppName = 'admin';

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        storageBucket: storageBucket,
        messagingSenderId: messagingSenderId,
        appId: appId,
      );
}
