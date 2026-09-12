import 'package:go_router/go_router.dart';

import '../../features/certificate_capture/presentation/pages/certificate_capture_page.dart';
import '../../features/dossie_builder/presentation/pages/dossie_checklist_page.dart';
import '../../features/dossie_builder/presentation/pages/dossie_compile_page.dart';
import '../../features/lattes_parser/presentation/pages/lattes_import_page.dart';

/// Rotas nomeadas via go_router. Usar rotas de URL real (não apenas troca de
/// widget em memória) é requisito indireto do projeto: o app precisa
/// "sobreviver a uma recarga no meio do fluxo sem perder trabalho do
/// usuário" — isso só é possível de forma robusta se a URL identificar em
/// qual etapa o usuário estava, permitindo à camada de apresentação
/// restaurar o estado persistido (Hive) correspondente àquela rota ao
/// montar a página novamente após o reload.
abstract class AppRoutes {
  static const importarLattes = '/importar-lattes';
  static const capturarCertificados = '/certificados';
  static const dossieChecklist = '/dossie/:dossieId/checklist';
  static const dossieCompilar = '/dossie/:dossieId/compilar';

  // Rota especial: destino do redirect OAuth2 (Google/Microsoft). Não
  // renderiza UI própria — apenas processa `code`/`state` da query string via
  // `AuthRepository.tratarRetornoRedirect()` e redireciona de volta para a
  // rota em que o usuário estava antes de iniciar o login (guardada em
  // `state`, ver DECISOES.md "Preservação de rota durante redirect OAuth").
  static const oauthCallback = '/oauth/callback';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.importarLattes,
  routes: [
    GoRoute(
      path: AppRoutes.importarLattes,
      builder: (context, state) => const LattesImportPage(),
    ),
    GoRoute(
      path: AppRoutes.capturarCertificados,
      builder: (context, state) => const CertificateCapturePage(),
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
    GoRoute(
      path: AppRoutes.oauthCallback,
      // PENDENTE: builder que dispara tratarRetornoRedirect() e faz
      // `context.go(rotaOriginal)` assim que resolver.
      builder: (context, state) => const LattesImportPage(),
    ),
  ],
);
