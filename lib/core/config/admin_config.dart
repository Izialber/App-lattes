/// Quem tem acesso à página de administração de códigos de convite
/// (`/admin/codigos`). Checado contra `FirebaseAuth.instance.currentUser?.
/// email` — só login via Firebase Auth dá ao Firestore uma identidade
/// verificável (`request.auth.token.email`) pras regras de segurança
/// confiarem; o login "Continuar com Google" do resto do app é um fluxo
/// OAuth PKCE separado, sem essa garantia (ver DECISOES.md, "Códigos de
/// convite"). Por isso a conta admin é uma conta de e-mail/senha dedicada,
/// independente da sessão Google normal.
class AdminConfig {
  AdminConfig._();

  static const String email = 'izialber@gmail.com';
}
