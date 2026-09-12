# Roadmap Mobile — Fase 2 (Android/iOS nativos)

Este documento lista, arquivo por arquivo, exatamente o que muda para transformar a Fase 1
(Flutter Web/PWA) em apps nativos, e qual limitação de navegador cada mudança resolve. Se um
arquivo não está listado aqui, ele não muda — essa é a prova de que a arquitetura feature-first
+ abstrações de plataforma cumpriu o objetivo de "troca de implementação, nunca reescrita".

## Regra geral

Toda mudança de Fase 2 acontece em um destes três lugares:
1. `lib/core/platform/*/**_native.dart` (implementações já esqueletizadas nesta entrega).
2. `lib/core/di/injection.dart` (seleção de implementação — hoje via `kIsWeb`, que já resolve
   sozinho para as implementações nativas quando compilado para Android/iOS).
3. `pubspec.yaml` (adicionar dependências nativas que hoje estão listadas como
   "[só nativo, fase 2]" mas já inclusas, e configuração de plataforma Android/iOS
   — `android/`, `ios/` — que não existe ainda porque este projeto foi criado só para web).

Nenhuma mudança acontece em `lib/features/*/domain/**` — é o contrato que este roadmap existe
para provar.

## Arquivo por arquivo

### `lib/core/platform/task_runner/task_runner_native.dart`
**Muda de:** stub que lança `UnimplementedError`.
**Para:** implementação real usando `Isolate.run(task)` (Dart 2.19+); `estimatedSafeHeapBytes`
passa a ler a memória real do aparelho (ex.: via `device_info_plus`) em vez da heurística de
`navigator.deviceMemory` usada na Fase 1 (que só existe em Chromium/Android — no iOS nativo
não há mais a limitação de "WebKit não expõe API de memória" que hoje força o valor fixo de
350MB).
**Resolve:** a limitação central do web — `dart:isolate` não existe no navegador, forçando a
Fase 1 a usar chunking manual com yield de event loop, ou Web Worker para tarefas pesadas. No
nativo, mesclagem de PDF e processamento de imagem passam a rodar em isolates reais, sem
nenhum código de chunking manual. A estratégia de 3 níveis (`DecidirEstrategiaDeMemoria`:
direta / em partes / inviável) é lógica pura de `domain/` e não muda — só os números que
alimentam `estimatedSafeHeapBytes` ficam mais precisos.

### `lib/core/platform/camera/camera_service_native.dart`
**Muda de:** stub.
**Para:** `CameraController` do plugin `camera` (já no pubspec, listado
"[só nativo, fase 2]").
**Resolve:** a limitação de `getUserMedia` exigir HTTPS + gesto explícito e produzir apenas
imagens estáticas via canvas; o plugin nativo dá acesso a controles de câmera reais (flash,
zoom, foco), desnecessários mas indisponíveis no web.

### `lib/core/platform/secure_storage/secure_storage_service_native.dart`
**Muda de:** stub.
**Para:** `flutter_secure_storage` (Keychain no iOS, Keystore/EncryptedSharedPreferences no
Android).
**Resolve:** a necessidade de implementar cifragem manual via Web Crypto API porque não há
binding confiável do plugin para web; no nativo, o SO já oferece um cofre de segredos e não há
risco de expiração de storage (item 6 de RISCOS.md é exclusivo do web).

### `lib/core/platform/connectivity/connectivity_gate.dart` (nova implementação nativa)
**Muda:** hoje só existe a interface; a implementação web usa `connectivity_plus` com
granularidade reduzida no Safari. No nativo, `connectivity_plus` reporta mudanças de rede de
forma mais granular e confiável (Wi-Fi ↔ celular).
**Resolve:** falsos negativos de "online" no Safari iOS que hoje exigem o erro de rede do Dio
como sinal redundante.

### `lib/features/certificate_capture/data/**` (HeicConverter)
**Muda de:** conversão via `<canvas>`/`<img>` no navegador, com fallback pedindo exportação
manual quando o Safari não decodifica o HEIC.
**Para:** `heic_to_jpg` (biblioteca nativa, já no pubspec como "[só nativo, fase 2]"),
decodificação sempre confiável.
**Resolve:** o caso em que o navegador falha silenciosamente ao decodificar HEIC (RISCOS.md,
item 7) — no nativo isso deixa de ser um risco.

### `lib/core/routing/app_router.dart` (rota `AppRoutes.oauthCallback`)
**Muda de:** captura o retorno do redirect OAuth via URL/`app_links` no navegador.
**Para:** `app_links` (já listado no pubspec) funciona de forma nativa e mais confiável via
deep link / Universal Link (iOS) / App Link (Android), sem depender de recarregar uma aba.
**Resolve:** a fragilidade do fluxo de redirect em PWA, onde o app precisa detectar o retorno
ao montar a página novamente (Fase 1) em vez de receber um callback direto do SO (Fase 2).

### `web/sw.js`, `web/manifest.json`, `web/index.html`
**Muda:** deixam de existir/ser relevantes — substituídos por configuração nativa de splash
screen, ícone de app e permissões (`android/app/src/main/AndroidManifest.xml`,
`ios/Runner/Info.plist`).
**Resolve:** o problema de storage efêmero do PWA (RISCOS.md item 6) desaparece — apps
instalados via loja não têm política de expiração de dados como o Safari ITP aplica a PWAs não
instalados.

### `pubspec.yaml`
**Muda:** pacotes marcados "[só nativo, fase 2]" (`camera`, `heic_to_jpg`,
`flutter_secure_storage`) passam a ser efetivamente usados; pacotes marcados
"[web com ressalva Safari]" (`file_picker`, `connectivity_plus`, `printing`, `app_links`)
continuam os mesmos pacotes, só que sem as ressalvas de Safari se aplicando.
**Resolve:** nenhuma limitação nova — apenas ativa dependências já previstas.

### Diretórios novos: `android/`, `ios/`
**Muda:** não existem na Fase 1 (projeto Flutter Web puro). Criados via
`flutter create --platforms=android,ios .` no diretório do projeto.
**Resolve:** empacotamento para as lojas (Google Play / App Store), assinatura de app,
configuração de permissões nativas (câmera, rede) — nenhuma dessas preocupações existe no web.

## O que NÃO muda (prova do desacoplamento)

- Todo `lib/features/*/domain/**` (entidades, repositórios, use cases) dos 4 módulos.
- `lib/core/error/failures.dart`.
- `lib/core/utils/breakpoints.dart` e a estratégia responsiva (um app nativo em tablet ainda
  usa os mesmos breakpoints).
- O parser do XML do Lattes (`lib/features/lattes_parser/data/parsers/**`) — é Dart puro,
  roda idêntico em qualquer plataforma, e é o motivo pelo qual foi o módulo escolhido para
  vir 100% pronto nesta entrega: ele já nasce sem nenhuma dívida técnica de portabilidade.
- Os testes unitários do parser (`test/features/lattes_parser/**`) — rodam sem alteração em
  qualquer plataforma de teste (`flutter test` não depende de device/emulador para este
  módulo).
- `lib/features/lattes_parser/presentation/**` (`LattesImportController`, `CurriculoListView`,
  `LattesImportPage`) — a primeira fatia funcional de ponta a ponta do app. Nenhum destes
  arquivos importa API específica de navegador diretamente.
- Provavelmente `lib/features/lattes_parser/data/datasources/lattes_file_datasource_web.dart`
  também não precisa de uma variante nativa separada: `file_picker` (o pacote usado nele) já
  tem implementação nativa Android/iOS madura por trás do mesmo `FilePicker.platform.
  pickFiles(...)`. Se o comportamento se mantiver idêntico na prática, o arquivo pode
  simplesmente perder o sufixo `_web` e passar a ser usado nas duas fases sem duplicação —
  única exceção observada neste projeto à regra "toda API de plataforma fica atrás de uma
  interface com duas implementações", justamente porque o próprio pacote já abstrai a
  plataforma por dentro.

## Ordem sugerida de execução da Fase 2

1. `flutter create --platforms=android,ios .` para gerar os diretórios de plataforma.
2. Implementar `TaskRunnerNative` e `SecureStorageServiceNative` primeiro (menor risco,
   maior valor — desbloqueiam os outros dois).
3. Implementar `CameraServiceNative` e o `HeicConverter` nativo.
4. Validar o fluxo OAuth via deep link nativo (`app_links`) — reaproveitando toda a lógica de
   `AuthRepositoryImpl`, que não muda.
5. Rodar a suíte de testes do parser sem nenhuma alteração, como critério de aceite de que o
   domínio realmente não teve regressão na migração.
