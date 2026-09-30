import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/codigo_acesso_repository_impl.dart';
import '../../domain/entities/codigo_acesso.dart';
import '../../domain/repositories/codigo_acesso_repository.dart';

final codigoAcessoRepositoryProvider = Provider<CodigoAcessoRepository>(
  (ref) => CodigoAcessoRepositoryImpl(),
);

/// Identidade Firebase Auth crua — independente do `AuthState` genérico do
/// resto do app (ver `auth_providers.dart`), usada só pra gate da página de
/// admin (`/admin/codigos`), que precisa especificamente de uma sessão
/// Firebase (não Google OAuth) pro Firestore confiar (ver DECISOES.md).
final firebaseAuthStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Estado da página de administração (`/admin/codigos`) — só a listagem e
/// as ações de admin; resgatar um código (login Google/e-mail-senha) não
/// passa por aqui, cada fluxo de login chama o repositório diretamente.
class AdminCodigosState {
  final bool carregando;
  final List<CodigoAcesso> codigos;
  final String? erro;

  const AdminCodigosState({this.carregando = false, this.codigos = const [], this.erro});

  AdminCodigosState copyWith({
    bool? carregando,
    List<CodigoAcesso>? codigos,
    String? erro,
    bool limparErro = false,
  }) {
    return AdminCodigosState(
      carregando: carregando ?? this.carregando,
      codigos: codigos ?? this.codigos,
      erro: limparErro ? null : (erro ?? this.erro),
    );
  }
}

class AdminCodigosController extends Notifier<AdminCodigosState> {
  @override
  AdminCodigosState build() {
    _carregar();
    return const AdminCodigosState(carregando: true);
  }

  Future<void> _carregar() async {
    try {
      final resultado = await ref.read(codigoAcessoRepositoryProvider).listarCodigos();
      resultado.match(
        (falha) => state = state.copyWith(carregando: false, erro: falha.message),
        (codigos) => state = state.copyWith(carregando: false, codigos: codigos),
      );
    } catch (e) {
      // Mesmo cuidado de sempre com chamada fire-and-forget disparada de
      // dentro de build() — ver DECISOES.md, bug de renderização quebrada.
      state = state.copyWith(carregando: false, erro: 'Falha ao carregar códigos: $e');
    }
  }

  void limparErro() => state = state.copyWith(limparErro: true);

  Future<void> gerarCodigo({String? rotulo}) async {
    state = state.copyWith(limparErro: true);
    final resultado = await ref.read(codigoAcessoRepositoryProvider).criarCodigo(rotulo: rotulo);
    resultado.match(
      (falha) => state = state.copyWith(erro: falha.message),
      (novo) => state = state.copyWith(codigos: [novo, ...state.codigos]),
    );
  }

  Future<void> revogar(String codigo) async {
    state = state.copyWith(limparErro: true);
    final resultado = await ref.read(codigoAcessoRepositoryProvider).revogarCodigo(codigo);
    resultado.match(
      (falha) => state = state.copyWith(erro: falha.message),
      (_) => state =
          state.copyWith(codigos: state.codigos.where((c) => c.codigo != codigo).toList()),
    );
  }
}

final adminCodigosControllerProvider =
    NotifierProvider<AdminCodigosController, AdminCodigosState>(AdminCodigosController.new);
