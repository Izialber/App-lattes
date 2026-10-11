# Arquitetura — Certificados Lattes

Fase 1: Flutter Web (PWA), instalável em desktop e mobile. Fase 2: apps nativos Android/iOS
reaproveitando domínio e casos de uso sem reescrita. Este documento descreve a fundação criada
para sustentar essa transição.

## 1. Princípios

1. **Feature-first + Clean Architecture.** Cada módulo de negócio é uma feature isolada com três
   camadas (`domain`, `data`, `presentation`). Dependências apontam sempre para dentro: `presentation`
   depende de `domain`, `data` implementa `domain`, e `domain` não depende de nada externo.
2. **Domínio 100% agnóstico de plataforma.** Nenhuma entidade, repositório ou use case importa
   `dart:html`, `package:web`, `camera`, ou qualquer API específica de navegador ou SO.
3. **Tudo que é específico de plataforma vive atrás de uma interface em `core/platform`.** A troca
   Web → Nativo na fase 2 é troca de implementação (uma classe nova), nunca reescrita de use case.
4. **Sem backend próprio PARA DADOS DO USUÁRIO.** O "backend" de arquivos é o Google Drive/
   OneDrive do usuário; o "backend" de inteligência é a API de LLM chamada diretamente do
   cliente (BYOK, ver RISCOS.md). Exceção pontual, deliberada: o Firestore do projeto Firebase
   (mesmo projeto do login por e-mail/senha) é usado como backend compartilhado SÓ pro controle
   de acesso (códigos de convite de uso único + painel de admin, `features/access_control/`) —
   nenhum arquivo/dado acadêmico do usuário passa por ele, só metadados de quem tem permissão
   de criar conta (ver DECISOES.md, "Códigos de convite").
5. **Multiusuário desde a concepção, sem storage compartilhado.** Qualquer pessoa loga com a
   própria conta Google/Microsoft (ver `AuthRepository`); cada sessão de navegador autentica e
   opera isoladamente sobre a nuvem da própria pessoa. Não existe conceito de "usuário dono do
   app" nem arquivo visível entre contas diferentes — confirmado explicitamente pelo usuário em
   2026-09-12 (já era o design original; ver DECISOES.md e RISCOS.md item 10 para as
   implicações de operar isso em produção).

## 2. Camadas

- **domain/**: entidades (`Equatable`, imutáveis), interfaces de repositório (contratos, sem
  implementação) e use cases (uma classe por ação de negócio, com um método `call`). É a única
  camada com 100% de cobertura de teste exigida e a única que pode ser copiada sem alteração para
  o app nativo da fase 2.
- **data/**: implementações concretas dos repositórios, datasources (XML, HTTP, câmera via
  `core/platform`, storage local) e mapeamento entre modelos externos (XML, JSON de API) e
  entidades de domínio. É aqui que exceções de infraestrutura são capturadas e traduzidas em
  `Failure`s de domínio (ver `core/error/failures.dart`).
- **presentation/**: providers Riverpod (`AsyncNotifier`/`StateNotifier`), páginas e widgets.
  Não contém regra de negócio; apenas orquestra chamadas a use cases e exibe estado.

## 3. Estrutura de diretórios (resumo — árvore completa no item 3 dos entregáveis)

```
lib/
  core/
    di/                 -> injeção de dependência (Riverpod ProviderScope + overrides)
    routing/             -> go_router, rotas nomeadas, restauração de fluxo pós-reload
    platform/             -> abstrações de plataforma (task_runner, camera, secure_storage)
    error/                -> Failure e exceções de domínio
    utils/                -> constantes, breakpoints responsivos
  features/
    lattes_parser/        -> Módulo 1
    comprovantes/          -> Módulo 2 (substituiu certificate_capture — ver nota abaixo)
    cloud_sync/            -> Módulo 3 (login + sincronização com a nuvem)
    dossie_builder/        -> Módulo 4
    llm_shared/            -> cliente LLM compartilhado (BYOK) entre o Módulo 4 e certificate_capture
    certificate_capture/   -> módulo ORIGINAL de captura+extração por LLM, mantido no repo mas
                              desconectado da navegação desde o redesenho do Módulo 2 (ver nota)
    access_control/        -> transversal, não numerado: códigos de convite + painel de admin
                              (gate de criação de conta, único módulo com backend compartilhado —
                              Firestore; ver princípio 4 acima e DECISOES.md)
web/
  index.html, manifest.json, sw.js
test/
  features/..., fixtures/...
```

## 4. Fluxo de dados dos 4 módulos

Os 4 estão conectados de ponta a ponta e alcançáveis pela navegação principal (atualizado — na
entrega original só o Módulo 1 estava assim; os módulos 2-4 foram conectados em sessões
posteriores, incluindo um redesenho do Módulo 2, ver DECISOES.md).

### 4.1 Parser Lattes (100% local, sem IA)

```
Usuário toca "Selecionar XML do Lattes" (LattesImportPage)
  -> LattesFileDatasourceWeb (file_picker; withData: true; fallback UTF-8 -> Latin-1)
  -> LattesXmlParser.parse(String xmlContent)   [core: dart:xml, síncrono]
  -> LattesRepositoryImpl mapeia XmlDocument -> CurriculoLattes (entidade), nunca lança
  -> ImportarCurriculoLattes (use case) retorna Either<Failure, CurriculoLattes>
  -> LattesImportController (Riverpod Notifier, lattes_providers.dart) expõe LattesImportState
  -> CurriculoListView renderiza dados gerais, cursos, experiências, publicações, orientações
     e produção técnica; vínculos com precisaConfirmacaoVinculoAtual mostram botões Sim/Não
  -> Resposta do usuário -> ConfirmarVinculoAtual (use case) -> novo CurriculoLattes no estado
```

### 4.2 Comprovantes (`features/comprovantes/` — substituiu `certificate_capture`)

Redesenho em relação à entrega original: em vez de capturar uma foto solta e extrair
título/instituição por LLM, o usuário anexa um arquivo (foto/PDF) DIRETO em cima de uma entrada
já existente do currículo Lattes (`EntradaLattesRef`, recalculada de `CurriculoLattes` via
`gerarEntradasLattes` — nunca persistida por si só). Sem extração por LLM neste módulo —
título/instituição vêm do próprio XML, mais confiável que uma extração livre.

```
CurriculoListView ("Anexar comprovantes") -> ComprovantesLattesPage
  -> lista EntradaLattesRef agrupadas por CategoriaEntradaLattes (técnico, graduação, pós lato/
     stricto sensu, formação complementar, experiência profissional, publicação, orientação,
     produção técnica, participação em evento, projeto de pesquisa, idioma)
  -> usuário anexa 1+ arquivos numa entrada -> ComprovanteUploadDatasourceWeb (file_picker)
  -> HeicConverter (se necessário) roda em TaskRunner
  -> ComprovanteEntrada (entidade) criado com entradaId + status = pendenteSincronizacao
  -> persistido via ComprovanteLocalStore (Hive/IndexedDB)
```

`certificate_capture/` (módulo original, câmera + extração por LLM) continua no repo intocado,
só desconectado da navegação — `llm_shared/` ainda é usado por ele.

### 4.3 Sincronização Cloud (`features/cloud_sync/`)

```
ComprovanteEntrada pendente (ver 4.2)
  -> ComprovantesSyncController (comprovantes_sync_providers.dart, em cloud_sync/)
  -> AtualizarStatusSincronizacaoComprovante (use case) marca sincronizando
  -> Renomear em padrão determinístico: {AAAA-MM-DD}_{categoria}_{hashCurto}.{ext}
  -> CloudStorageRepository (Google Drive API; subpasta por categoria, cacheada)
  -> Upload resumível (sessão de upload da própria API); falha de rede -> volta pra fila
     offline-first com retry exponencial (package:retry)
  -> AuthRepository garante token válido (renovação automática de refresh token antes de cada
     chamada; token nunca é lido diretamente pelos use cases, só via interceptor do Dio)
```

Login (Google OAuth PKCE ou e-mail/senha via Firebase Auth) também vive em `cloud_sync/` — ver
`AuthController`/`AuthRepository`. Criação de conta por qualquer um dos dois caminhos exige um
código de convite de uso único (`features/access_control/`, ver princípio 4 e DECISOES.md).

### 4.4 Montador de Dossiê (human-in-the-loop obrigatório)

```
Usuário fornece PDF do edital
  -> ExtrairCriteriosEdital (use case) -> LlmRepository interpreta critérios de pontuação
     da Prova de Títulos -> List<CriterioPontuacao>
  -> SugerirVinculos (use case) cruza critérios com ComprovanteEntrada já sincronizados (texto
     de match vem de EntradaLattesRef.titulo/subtitulo ligada por entradaId, recalculada do
     currículo — não mais de extração por LLM, ver 4.2) -> List<VinculoSugerido> (nunca
     aprovado automaticamente)
  -> DossieChecklistPage: usuário aprova / altera / exclui cada vínculo
     -> estado DossieEmMontagem persistido a cada interação (retomável pós-reload)
  -> Usuário confirma -> CompilarDossie (use case) -> DecidirEstrategiaDeMemoria escolhe entre:
     (a) mesclagem DIRETA (cabe tudo de uma vez no teto de TaskRunner.estimatedSafeHeapBytes:
         350MB fixo no iOS, dinâmico via navigator.deviceMemory no Android);
     (b) mesclagem EM PARTES (lotes sequenciais -> PDFs intermediários -> mesclagem final),
         com Dossie.loteAtual/totalDeLotes atualizados a cada lote para a UI mostrar progresso;
     (c) DegradacaoExplicita (só quando nem o maior certificado isolado cabe no dispositivo):
         interrompe ANTES de travar e orienta o usuário a concluir no desktop
```

## 5. Diagrama (Mermaid)

```mermaid
flowchart TD
    subgraph M1["Módulo 1: Parser Lattes"]
        A1[Seletor de arquivo / Drag&Drop] --> A2[LattesXmlParser]
        A2 --> A3[CurriculoLattes]
    end

    subgraph M2["Módulo 2: Comprovantes"]
        B1[Entrada do currículo] --> B2[Anexar arquivo: file_picker]
        B2 --> B2b[HeicConverter se necessário]
        B2b --> B4[ComprovanteEntrada pendenteSincronizacao]
    end

    subgraph M3["Módulo 3: Sincronização Cloud"]
        C1[Renomear em padrão determinístico] --> C2[Fila offline-first]
        C2 --> C3{Token válido?}
        C3 -- não --> C4[Renovar refresh token]
        C4 --> C3
        C3 -- sim --> C5[Upload resumível Google Drive]
    end

    subgraph M4["Módulo 4: Montador de Dossiê"]
        D1[PDF do edital] --> D2[LlmRepository: critérios]
        D2 --> D3[Sugestão de vínculos]
        D3 --> D4[[Checklist humano: aprovar/alterar/excluir]]
        D4 --> D5{DecidirEstrategiaDeMemoria}
        D5 -- cabe direto --> D6[Mesclagem direta]
        D5 -- cabe em lotes --> D6b[Mesclagem em partes: lotes -> intermediários -> final]
        D5 -- nem o maior cabe --> D7[Degradação explícita: concluir no desktop]
    end

    subgraph AC["access_control (transversal, gate de conta)"]
        AC1[Código de convite] --> AC2[Firestore: codigos / acessos_autorizados]
    end

    A3 --> D3
    A3 -. gera EntradaLattesRef .-> B1
    B4 --> C1
    C5 --> D3
    AC2 -. libera criação de conta, antes do login .-> B1

    subgraph CORE["core/platform (abstrações)"]
        T[TaskRunner]
        CAM[CameraService]
        SEC[SecureStorageService]
    end

    B2b -. usa .-> T
    C1 -. usa .-> T
    D6 -. usa .-> T
    C4 -. usa .-> SEC
```

## 6. Abstrações de plataforma

Vivem em `lib/core/platform/*`. Cada uma define uma interface abstrata (`domain` da própria
abstração, sem qualquer import de UI) e duas implementações: `_web.dart` (ativa hoje) e
`_native.dart` (esqueleto documentado para a fase 2, com corpo `throw UnimplementedError('fase 2')`
e comentário explicando o que vai entrar ali). A seleção de implementação acontece em
`core/di/injection.dart` via `kIsWeb`.

| Abstração | Interface | Implementação Web (fase 1) | O que muda na fase 2 (nativo) |
|---|---|---|---|
| `TaskRunner` | roda função pesada fora da UI thread; expõe `estimatedSafeHeapBytes` (350MB fixo no iOS, dinâmico via `navigator.deviceMemory` no Android, fixo no desktop) | Processamento em chunks com `Future.delayed(Duration.zero)`/`Timer` para ceder o event loop (dart:isolate não existe no Web); tarefas realmente pesadas (merge de PDF grande) usam Web Worker via `package:web` + `dart:js_interop` | `dart:isolate` (`Isolate.run`); teto de memória lido do dispositivo real (ex. `device_info_plus`) em vez de `navigator.deviceMemory` |
| `CameraService` | captura de foto ao vivo | `getUserMedia` + `<video>`/`<canvas>` via `package:web` — hoje só exercida pelo módulo legado `certificate_capture/`, desconectado da navegação (ver seção 4.2); o Módulo 2 atual (`comprovantes/`) usa `file_picker`, não câmera | plugin `camera` nativo (Isolate para pós-processamento) |
| `SecureStorageService` | guarda tokens OAuth e chave LLM | Web Crypto API (AES-GCM), chave não exportável em IndexedDB | `flutter_secure_storage` (Keychain/Keystore) |
| `HeicConverter` | HEIC -> JPEG | `<img>`/`<canvas>` (Safari decodifica HEIC nativamente); fallback pede export manual | `heic_to_jpg` (biblioteca nativa) |
| `ConnectivityGate` | detecta perda/retorno de rede | `connectivity_plus` + erro de rede do Dio como sinal redundante | `connectivity_plus` nativo (eventos mais granulares) |

Detalhe de teto de tamanho (memória) documentado por abstração em `RISCOS.md`, seção
"Memória no Safari iOS", com valores separados para desktop e Safari iOS.

## 7. Estratégia responsiva

Breakpoints (definidos em `lib/core/utils/breakpoints.dart`):

| Nome | Largura | Uso |
|---|---|---|
| `compact` | 360–599px | celular retrato; navegação em bottom bar; checklist de vínculo em lista de cards full-width; alvo de toque mínimo 48x48dp |
| `medium` | 600–1023px | tablet retrato / celular paisagem; navegação em rail lateral colapsado; duas colunas no checklist |
| `expanded` | 1024–1919px | desktop/tablet paisagem; navegação em rail expandido; três colunas; drag&drop de múltiplos arquivos habilitado |
| `large` | ≥1920px | desktop grande; conteúdo centralizado com largura máxima de 1600px para não esticar linhas de texto |

Regras fixas: nenhum layout é "desktop encolhido" — cada breakpoint tem uma composição de widgets
própria (`LayoutBuilder` + `ResponsiveScaffold` em `core/utils`), não apenas reflow do mesmo
`Row`/`Column`. Componentes de decisão crítica (aprovar vínculo, confirmar compilação do dossiê)
usam alvos de toque ≥48dp mesmo em `expanded`/`large`, para consistência entre mouse e dedo.

## 8. O que fica fixo entre Fase 1 e Fase 2

`domain/**` de todas as features, `core/error`, e as assinaturas dos use cases não mudam. O que
muda está inteiramente documentado em `ROADMAP_MOBILE.md`.
