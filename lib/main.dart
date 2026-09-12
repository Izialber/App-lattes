import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'core/routing/app_router.dart';

/// Ponto de entrada. Duas coisas acontecem ANTES de `runApp`, propositalmente
/// nesta ordem, porque o app precisa restaurar estado persistido antes do
/// primeiro frame (requisito de "retomável após recarga de aba"):
///
/// 1. `WidgetsFlutterBinding.ensureInitialized()` — obrigatório antes de
///    qualquer chamada assíncrona de plugin.
/// 2. Abertura das Hive boxes usadas pela fila de upload, vínculos aprovados
///    e estado do dossiê em montagem (feita dentro de `bootstrap()`,
///    mantida fora deste arquivo para não acoplar `main.dart` a Hive
///    diretamente — ver DECISOES.md).
///
/// A checagem de retorno de redirect OAuth (`tratarRetornoRedirect`) também
/// acontece aqui, antes do primeiro frame, para que o usuário nunca veja a
/// tela inicial "piscar" antes de ser redirecionado de volta ao fluxo em que
/// estava.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove o "#" das URLs no Flutter Web (usa History API em vez de hash
  // routing). Necessário para o app funcionar corretamente publicado em uma
  // subpasta (ex.: /certificados-lattes/) em vez da raiz do domínio.
  usePathUrlStrategy();

  // PENDENTE (fora do escopo do entregável 5): await bootstrap() abrindo as
  // Hive boxes e chamando AuthRepository.tratarRetornoRedirect() quando a
  // URL atual for AppRoutes.oauthCallback.

  runApp(const ProviderScope(child: CertificadosLattesApp()));
}

class CertificadosLattesApp extends StatelessWidget {
  const CertificadosLattesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Certificados Lattes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5FFF),
      ),
      routerConfig: appRouter,
    );
  }
}
