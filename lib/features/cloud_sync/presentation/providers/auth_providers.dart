import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/oauth_pkce_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/cloud_provider.dart';
import '../../domain/repositories/auth_repository.dart';

/// Estado de autenticação do app. Hoje só existe uma "conta" possível por
/// sessão de navegador (a mesma usada para login e para sincronizar com o
/// Drive/OneDrive — ver DECISOES.md: sem conta própria do app, sem backend).
sealed class AuthState {
  const AuthState();
}

class AuthAuthenticated extends AuthState {
  final CloudProvider provider;
  const AuthAuthenticated(this.provider);
}

class AuthUnauthenticated extends AuthState {
  final String? erro;
  const AuthUnauthenticated({this.erro});
}

final oauthPkceDatasourceProvider = Provider((ref) => OauthPkceDatasource());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(oauthPkceDatasourceProvider),
    ref.watch(secureStorageServiceProvider),
  );
});

/// Único provedor suportado por enquanto (decisão do usuário: Google
/// primeiro, Microsoft fica para depois — ver DECISOES.md).
const _providerPrincipal = CloudProvider.googleDrive;

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repositorio = ref.watch(authRepositoryProvider);
    final resultado = await repositorio.obterTokenValido(_providerPrincipal);
    return resultado.match(
      (falha) => const AuthUnauthenticated(),
      (token) => AuthAuthenticated(token.provider),
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
    state = AsyncData(resultado.match(
      (falha) => AuthUnauthenticated(erro: falha.message),
      (token) => AuthAuthenticated(token.provider),
    ));
  }

  Future<void> logout() async {
    final repositorio = ref.read(authRepositoryProvider);
    await repositorio.logout(_providerPrincipal);
    state = const AsyncData(AuthUnauthenticated());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
