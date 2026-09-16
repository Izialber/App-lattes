import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/certificate_capture/presentation/pages/certificate_capture_page.dart';
import '../../features/cloud_sync/presentation/pages/login_page.dart';
import '../../features/cloud_sync/presentation/pages/oauth_callback_page.dart';
import '../../features/cloud_sync/presentation/providers/auth_providers.dart';
import '../../features/dossie_builder/presentation/pages/dossie_checklist_page.dart';
import '../../features/dossie_builder/presentation/pages/dossie_compile_page.dart';
import '../../features/lattes_parser/presentation/pages/lattes_import_page.dart';
import '../../features/llm_shared/presentation/pages/llm_settings_page.dart';

/// Rotas nomeadas via go_router. Usar rotas de URL real (não apenas troca de
/// widget em memória) é requisito indireto do projeto: o app precisa
/// "sobreviver a uma recarga no meio do fluxo sem perder trabalho do
/// usuário" — isso só é possível de forma robusta se a URL identificar em
/// qual etapa o usuário estava, permitindo à camada de apresentação
/// restaurar o estado persistido (Hive) correspondente àquela rota ao
/// montar a página novamente após o reload.
abstract class AppRoutes {
  static const login = '/login';
  static const importarLattes = '/importar-lattes';
  static const capturarCertificados = '/certificados';
  static const configuracoesLlm = '/configuracoes/llm';
  static const dossieChecklist = '/dossie/:dossieId/checklist';
  static const dossieCompilar = '/dossie/:dossieId/compilar';

  // Rota especial: destino do redirect OAuth2 (Google/Microsoft). Não
  // renderiza UI própria — apenas processa `code`/`state` da query string via
  // `AuthController.tratarRetornoDeRedirect` e redireciona de volta para
  // dentro do app (ou para o login, em caso de falha) — ver
  // `OAuthCallbackPage`.
  static const oauthCallback = '/oauth/callback';
}

/// Notifica o go_router para reavaliar `redirect` sempre que o estado de
/// autenticação mudar — sem isso, uma mudança de [authControllerProvider]
/// (ex.: login concluído) não teria efeito até a próxima navegação manual.
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

/// Rotas que não exigem sessão ativa — o gate de autenticação nunca redireciona
/// para longe delas por conta própria (a navegação de saída delas é sempre
/// explícita: [LoginPage] ao logar, [OAuthCallbackPage] ao terminar de processar).
bool _rotaPublica(String location) =>
    location == AppRoutes.login || location == AppRoutes.oauthCallback;

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final indoParaRotaPublica = _rotaPublica(state.matchedLocation);

      return authState.when(
        loading: () => null,
        error: (_, __) => indoParaRotaPublica ? null : AppRoutes.login,
        data: (value) {
          final autenticado = value is AuthAuthenticated;
          if (!autenticado && !indoParaRotaPublica) return AppRoutes.login;
          if (autenticado && state.matchedLocation == AppRoutes.login) {
            return AppRoutes.importarLattes;
          }
          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.oauthCallback,
        builder: (context, state) => const OAuthCallbackPage(),
      ),
      GoRoute(
        path: AppRoutes.importarLattes,
        builder: (context, state) => const LattesImportPage(),
      ),
      GoRoute(
        path: AppRoutes.capturarCertificados,
        builder: (context, state) => const CertificateCapturePage(),
      ),
      GoRoute(
        path: AppRoutes.configuracoesLlm,
        builder: (context, state) => const LlmSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.dossieChecklist,
        builder: (context, state) => DossieChecklistPage(
          dossieId: state.pathParameters['dossieId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.dossieCompilar,
        builder: (context, state) => DossieCompilePage(
          dossieId: state.pathParameters['dossieId']!,
        ),
      ),
    ],
  );
});
