import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'core/config/firebase_config.dart';
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
/// A tela inicial é sempre o login (ver `AppRoutes.login`/`appRouterProvider`);
/// o retorno do redirect OAuth (`tratarRetornoDeRedirect`) é tratado pela
/// própria `OAuthCallbackPage` ao montar, não aqui.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove o "#" das URLs no Flutter Web (usa History API em vez de hash
  // routing). Necessário para o app funcionar corretamente publicado em uma
  // subpasta (ex.: /app-lattes/) em vez da raiz do domínio.
  usePathUrlStrategy();

  // Login por email/senha (Firebase Auth) fica indisponível até o projeto
  // Firebase ser criado e configurado — ver core/config/firebase_config.dart.
  // Não tenta inicializar com config vazia (falharia em runtime).
  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }

  // PENDENTE (fora do escopo do entregável 5): await bootstrap() abrindo as
  // Hive boxes usadas pela fila de upload e vínculos aprovados.

  runApp(const ProviderScope(child: CertificadosLattesApp()));
}

class CertificadosLattesApp extends ConsumerWidget {
  const CertificadosLattesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Certificados Lattes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5FFF),
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
