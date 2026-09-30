import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/firebase_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/platform/secure_storage/secure_storage_service.dart';
import '../../../access_control/presentation/providers/codigo_acesso_providers.dart';
import '../../data/datasources/oauth_pkce_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/repositories/auth_repository.dart';

/// Como o usuário "entrou" no app. Login por email/senha (Firebase) é uma
/// via de acesso INDEPENDENTE de conectar um provedor de nuvem — quem entra
/// assim ainda vai precisar conectar Google Drive/OneDrive separadamente
/// quando for salvar um PDF, diferente de quem já loga com Google (onde as
/// duas coisas são a mesma conta). Ver DECISOES.md.
enum MetodoLogin { google, microsoft, email }

/// Estado de autenticação do app. Não existe conta própria do app com
/// backend compartilhado (ver DECISOES.md) — cada método de login é
/// independente: Google/Microsoft (OAuth PKCE, sem servidor) ou email/senha
/// (Firebase Authentication, que cuida de hash de senha/recuperação, mas
/// não guarda nenhum arquivo do usuário).
sealed class AuthState {
  const AuthState();
}

class AuthAuthenticated extends AuthState {
  final MetodoLogin metodo;
  final CloudProvider? cloudProvider;
  final String? email;
  const AuthAuthenticated({required this.metodo, this.cloudProvider, this.email});
}

class AuthUnauthenticated extends AuthState {
  final String? erro;
  const AuthUnauthenticated({this.erro});
}

/// Login "Continuar com Google" concluído (tokens de Drive já válidos), mas
/// este e-mail ainda não resgatou um código de convite — ver DECISOES.md,
/// "Códigos de convite". Estado intermediário: `/login/codigo` é a única
/// tela alcançável enquanto isto for verdade (ver `app_router.dart`).
class AuthPendenteCodigo extends AuthState {
  final String email;
  const AuthPendenteCodigo(this.email);
}

final oauthPkceDatasourceProvider = Provider((ref) => OauthPkceDatasource());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(oauthPkceDatasourceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

/// Único provedor de NUVEM suportado por enquanto (decisão do usuário:
/// Google primeiro, Microsoft fica para depois — ver DECISOES.md). Não
/// confundir com o login por email/senha, que não depende disto.
const _providerPrincipal = CloudProvider.googleDrive;

/// Traduz uma [FirebaseAuthException] para uma mensagem em português que faz
/// sentido para quem está tentando entrar/criar conta — os códigos do
/// Firebase não devem vazar para a UI.
String _mensagemErroFirebase(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'user-disabled':
      return 'Esta conta foi desativada.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Já existe uma conta com este e-mail. Tente entrar em vez de criar uma nova.';
    case 'weak-password':
      return 'Senha muito fraca — use pelo menos 6 caracteres.';
    case 'too-many-requests':
      return 'Muitas tentativas seguidas. Aguarde um pouco antes de tentar de novo.';
    default:
      return 'Não foi possível completar: ${e.message ?? e.code}';
  }
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    if (FirebaseConfig.isConfigured) {
      final firebaseUser = await FirebaseAuth.instance.authStateChanges().first;

      // Continua escutando depois do primeiro evento para refletir
      // login/logout feitos em outra aba sem precisar de F5. Só reage aqui
      // quando o método atual é 'email' (login/logout via Google é
      // controlado pelo próprio fluxo OAuth, não pelo Firebase).
      final subscription = FirebaseAuth.instance.authStateChanges().skip(1).listen((user) {
        final atual = state.valueOrNull;
        if (user != null) {
          state = AsyncData(AuthAuthenticated(metodo: MetodoLogin.email, email: user.email));
        } else if (atual is AuthAuthenticated && atual.metodo == MetodoLogin.email) {
          state = const AsyncData(AuthUnauthenticated());
        }
      });
      ref.onDispose(subscription.cancel);

      if (firebaseUser != null) {
        return AuthAuthenticated(metodo: MetodoLogin.email, email: firebaseUser.email);
      }
    }

    final repositorio = ref.watch(authRepositoryProvider);
    final resultado = await repositorio.obterTokenValido(_providerPrincipal);
    if (resultado.isLeft()) {
      return const AuthUnauthenticated();
    }
    return _resolverEstadoGoogle();
  }

  /// Token de Drive válido confirmado — falta só checar o gate de código de
  /// convite (ver DECISOES.md). `googleEmail` é escrito por
  /// `AuthRepositoryImpl.tratarRetornoRedirect` no momento do login; se
  /// ainda não existir (sessão de antes desta feature existir), força um
  /// novo login em vez de assumir acesso liberado.
  Future<AuthState> _resolverEstadoGoogle() async {
    final email = await ref.read(secureStorageServiceProvider).read(key: SecureStorageKeys.googleEmail);
    if (email == null) {
      return const AuthUnauthenticated();
    }

    final autorizado = await ref.read(codigoAcessoRepositoryProvider).emailAutorizado(email);
    return autorizado.match(
      (falha) => AuthUnauthenticated(erro: falha.message),
      (jaAutorizado) => jaAutorizado
          ? AuthAuthenticated(metodo: MetodoLogin.google, cloudProvider: _providerPrincipal, email: email)
          : AuthPendenteCodigo(email),
    );
  }

  /// Redireciona a aba inteira para o provedor OAuth. Não há "depois" a
  /// tratar aqui além de um erro imediato (ex.: provedor não configurado):
  /// em caso de sucesso, a página literalmente navega para fora do app.
  Future<void> loginComGoogle() async {
    final repositorio = ref.read(authRepositoryProvider);
    final resultado = await repositorio.iniciarLogin(_providerPrincipal);
    resultado.match(
      (falha) => state = AsyncData(AuthUnauthenticated(erro: falha.message)),
      (_) {},
    );
  }

  /// Chamado pela página de callback (`/oauth/callback`) ao montar.
  Future<void> tratarRetornoDeRedirect() async {
    state = const AsyncLoading();
    final repositorio = ref.read(authRepositoryProvider);
    final resultado = await repositorio.tratarRetornoRedirect();
    final erro = resultado.match((falha) => falha.message, (_) => null);
    if (erro != null) {
      state = AsyncData(AuthUnauthenticated(erro: erro));
      return;
    }
    state = AsyncData(await _resolverEstadoGoogle());
  }

  /// Retorna `null` em caso de sucesso (o listener de [build] já atualiza o
  /// estado global) ou uma mensagem de erro pronta para mostrar na tela.
  Future<String?> entrarComEmailSenha({required String email, required String senha}) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensagemErroFirebase(e);
    }
  }

  /// Resgata o código PRIMEIRO, só then cria a conta no Firebase — se a
  /// criação falhar depois (e-mail já em uso, senha fraca), o código já foi
  /// queimado; aceito (admin gera outro, ver DECISOES.md, "Códigos de
  /// convite"). A ordem inversa arriscaria uma conta criada sem nunca ter
  /// passado por um código válido, caso o resgate falhasse depois.
  Future<String?> criarContaComEmailSenha({
    required String email,
    required String senha,
    required String codigo,
  }) async {
    final resgate = await ref
        .read(codigoAcessoRepositoryProvider)
        .resgatarCodigo(codigo: codigo, identificador: email);
    final erroCodigo = resgate.match((falha) => falha.message, (_) => null);
    if (erroCodigo != null) return erroCodigo;

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: senha);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensagemErroFirebase(e);
    }
  }

  /// Chamado pela tela de código pendente (`/login/codigo`) — só aplicável
  /// quando o login Google já terminou mas este e-mail ainda não tinha
  /// código resgatado (ver [AuthPendenteCodigo]).
  Future<String?> resgatarCodigoGoogle(String codigo) async {
    final atual = state.valueOrNull;
    if (atual is! AuthPendenteCodigo) {
      return 'Nenhum login pendente de código.';
    }

    final resultado = await ref
        .read(codigoAcessoRepositoryProvider)
        .resgatarCodigo(codigo: codigo, identificador: atual.email);

    return resultado.match(
      (falha) => falha.message,
      (_) {
        state = AsyncData(AuthAuthenticated(
          metodo: MetodoLogin.google,
          cloudProvider: _providerPrincipal,
          email: atual.email,
        ));
        return null;
      },
    );
  }

  Future<String?> enviarEmailRecuperacaoSenha(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensagemErroFirebase(e);
    }
  }

  Future<void> logout() async {
    final atual = state.valueOrNull;
    if (atual is AuthAuthenticated && atual.metodo == MetodoLogin.email) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    final repositorio = ref.read(authRepositoryProvider);
    await repositorio.logout(_providerPrincipal);
    state = const AsyncData(AuthUnauthenticated());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
