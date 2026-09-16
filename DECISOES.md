# Decisões — Certificados Lattes

Registro das premissas assumidas de forma autônoma, alternativas descartadas e por quê, e a
lista priorizada do que precisa da sua validação antes de avançar.

## Premissas assumidas

1. **Riverpod em vez de Bloc, para gerenciamento de estado global.**
   Alternativa descartada: Bloc/Cubit. Motivo: os 4 módulos têm bastante estado assíncrono
   concorrente (fila de upload, extração LLM, montagem de dossiê, parser) que precisa ser
   retomável após reload — `AsyncNotifier` do Riverpod modela isso com menos boilerplate que
   Bloc, e a árvore de providers é testável sem `BuildContext`, o que importa porque o domínio
   precisa ficar 100% agnóstico de Flutter/plataforma. Bloc continua uma escolha defensável; se
   sua equipe já tem convenção estabelecida em Bloc, a troca fica isolada em `presentation/` e
   `core/di`, sem tocar `domain`.

2. **`Either<Failure, T>` (via `fpdart`) em vez de exceptions tipadas cruzando a fronteira
   domain/data.** Motivo: o requisito "nunca lançar exceção não tratada" fica mais fácil de
   auditar quando o tipo de retorno já obriga o chamador a tratar o caminho de erro (o
   compilador reclama se você ignora o `Left`). Alternativa descartada: exceptions customizadas
   capturadas em `try/catch` na camada de apresentação — mais familiar, mas mais fácil de
   esquecer um `catch`. Se preferir, a reversão é mecânica: trocar `Either<Failure, T>` por
   `Future<T>` que lança `Failure` como exception em todas as assinaturas de `domain/`.

3. **Prompts de LLM como assets versionados (`assets/prompts/*.txt`), não strings no código.**
   Permite ajustar o prompt de extração sem recompilar, e versionar mudanças de prompt junto
   com o código de forma revisável (diff de texto simples).

4. **BYOK cobre Gemini Flash e GPT-4o-mini; Gemini é o caminho testado primeiro para CORS.**
   A API do Gemini historicamente aceita chamadas diretas do navegador com API key sem
   necessidade de proxy; a API da OpenAI é mais restritiva quanto a CORS para uso client-side.
   Por isso a extração de certificados usa Gemini Flash como padrão, com OpenAI como opção
   secundária documentada (ver RISCOS.md, "CORS nas chamadas ao LLM").

5. **Detecção de HEIC pelos magic bytes do arquivo, não pelo `mimetype` reportado pelo
   navegador.** O upload no Safari iOS pode reportar `image/jpeg` para um arquivo que na
   verdade é HEIC (ver contexto do projeto). Verificar a assinatura binária (`ftyp` box com
   `heic`/`heix`/`mif1` etc.) é a única forma confiável.

6. **Teto de memória: 350MB fixo no iOS, dinâmico no Android via `navigator.deviceMemory`,
   com processamento em partes quando não cabe de uma vez.** Atualizado por decisão do
   usuário em 2026-09-07 (ver "Decisões confirmadas" abaixo) — substitui a versão anterior
   deste documento, que usava uma única constante de ~380MB para todo o web e degradava
   direto para "conclua no desktop". Agora: iOS mantém constante fixa (WebKit não expõe API
   de memória); Android lê `navigator.deviceMemory` e usa uma fração conservadora da RAM
   relatada; e a estratégia de compilação do dossiê tem 3 níveis — direta, em partes (lotes
   sequenciais com PDFs intermediários), ou degradação explícita — só caindo em "conclua no
   desktop" quando nem o maior certificado isolado cabe no dispositivo. Ver
   `DecidirEstrategiaDeMemoria` e RISCOS.md, "Memória no Safari iOS".

7. **Nome do arquivo determinístico no cloud: `{AAAA-MM-DD}_{categoria}_{hashCurto}.pdf`.**
   `categoria` vem do tipo do certificado (curso, artigo etc.) quando conhecido, ou
   "certificado" como fallback; `hashCurto` evita colisão entre certificados do mesmo dia e
   categoria sem expor nenhum dado pessoal no nome do arquivo.

8. **Parser do Lattes expandido: formação acadêmica, atuação profissional, produção
   bibliográfica (artigos, trabalhos em eventos, capítulos e livros), orientações
   (concluídas e em andamento) e produção técnica (software e produto tecnológico).**
   Atualizado por decisão do usuário em 2026-09-07 — a versão original cobria só formação +
   atuação + produção bibliográfica. Projetos de pesquisa, prêmios e participação em bancas
   continuam fora do escopo; podem ser adicionados depois seguindo o mesmo padrão defensivo,
   sem mudança de arquitetura.

9. **Ambiguidade "vínculo em andamento" vs. "data de fim não informada" no XML do Lattes —
   resolvida com confirmação explícita do usuário, não mais assumida silenciosamente.**
   O schema do CNPq não distingue essas duas situações quando `ANO-DE-FIM` está ausente —
   ambas resultam no mesmo XML. Por decisão do usuário em 2026-09-07, o parser marca
   `precisaConfirmacaoVinculoAtual: true` nesses casos (mantendo `vinculoAtual: true` como
   leitura provisória) e a tela de importação pergunta explicitamente ("este vínculo ainda
   está ativo?") antes do vínculo poder entrar em um dossiê — ver `ConfirmarVinculoAtual` e
   `CurriculoLattes.temVinculosPendentesDeConfirmacao`.

10. **Estrutura de diretórios: `llm_shared` como feature própria**, em vez de duplicar o
    cliente LLM dentro de `certificate_capture` e `dossie_builder`. Os dois módulos que chamam
    LLM (extração de certificado, interpretação de edital) compartilham a mesma preocupação de
    BYOK/CORS/schema de resposta.

## Alternativas descartadas

| Decisão | Alternativa descartada | Motivo da rejeição |
|---|---|---|
| `pdf` (Dart puro) para geração/mesclagem de PDF | `pdfrx`/bindings nativos | Não têm build web funcional; `pdf` roda em qualquer plataforma sem FFI |
| Hive CE para storage estruturado | `sqflite`/SQLite | Sem suporte web maduro; Hive usa IndexedDB nativamente |
| Web Crypto manual para segredos no web | `flutter_secure_storage` direto | Plugin não tem binding real para web (cai em localStorage sem cifrar) |
| OAuth por redirect | OAuth por popup | Popup é bloqueado pelo Safari iOS (requisito explícito do projeto) |
| `syncfusion_flutter_pdf` para extrair texto de edital | `pdf_text`/OCR sempre | Editais raramente são digitalizados como imagem; OCR fica como fallback, não padrão (custo de API maior) |
| iCloud Drive como terceiro provedor de storage | Exportação manual via download + folha "Salvar em Arquivos" (chegou a ser implementada em 2026-09-12) | Usuário decidiu não seguir com isso; Apple também não tem API pública equivalente à Drive/Graph para escrever direto na pasta do usuário, então a alternativa viável já nascia limitada (sem confirmação de entrega) |

## Decisões confirmadas pelo usuário (2026-09-07)

Todas as 8 pendências da entrega anterior foram respondidas. Registro do que foi decidido e
o que mudou no código em consequência:

1. **Riverpod como gerenciador de estado global — aprovado.** Sem mudança de código (já era
   a escolha usada em toda a base).

2. **`syncfusion_flutter_pdf` — aceito** para esta fase de prototipagem. Sem mudança de
   código; permanece a decisão a reavaliar antes de uso comercial/monetizado.

3. **Escopo do parser do Lattes — expandido**, não mantido como estava. Adicionadas as
   entidades `Orientacao` e `ProducaoTecnica`, parsing de `OUTRA-PRODUCAO` (orientações
   concluídas/em andamento, software e produto tecnológico), fixture e testes atualizados.
   Ver item 8 acima.

4. **Teste de chave BYOK ao salvar — confirmado: testar.** Adicionado `LlmRepository.
   testarConexao({provider, apiKey})` ao contrato de domínio (antes só existiam os métodos de
   extração); a implementação da chamada em si continua pendente junto com o resto da camada
   de dados do módulo de LLM. `LlmProviderEscolhido` foi movido de `data/` para `domain/
   entities/`, já que agora é referenciado pelo contrato do repositório.

5. **Pergunta explícita sobre "vínculo em andamento" — confirmado: sim.** Não ficou só
   registrado em texto: implementado de fato. `ExperienciaProfissional` ganhou o campo
   `precisaConfirmacaoVinculoAtual` (+ `copyWith`), o parser marca esse campo quando
   `ANO-DE-FIM` está ausente, `CurriculoLattes.temVinculosPendentesDeConfirmacao` resume o
   estado para a UI, e o novo use case `ConfirmarVinculoAtual` resolve a resposta do usuário.
   A tela de importação (`LattesImportPage`/`CurriculoListView`) já pergunta "este vínculo
   ainda está ativo?" com botões Sim/Não para cada vínculo ambíguo. Ver item 9 acima.

6. **Teto de memória — não foi um "aceitar como está": o usuário pediu uma estratégia
   diferente da recomendação padrão.** Resposta literal: "350 para iOS e regular a memória de
   acordo com o celular Android e fazer em partes caso passar do limite". Implementado:
   - `AppConstants.estimatedSafariIosSafeHeapBytes` alterado de 380MB para 350MB.
   - `TaskRunnerWeb` agora lê `navigator.deviceMemory` (quando disponível — Chrome/Android) e
     calcula o teto como uma fração conservadora (25%) da RAM total relatada, com piso e teto
     absolutos; iOS continua com o valor fixo (WebKit não expõe essa API); qualquer outro
     navegador sem a API cai no valor de desktop, como antes.
   - Novo use case puro `DecidirEstrategiaDeMemoria` (com testes unitários) decide entre
     mesclagem direta, mesclagem em partes (lotes sequenciais com PDFs intermediários) ou
     degradação explícita — a degradação só acontece agora quando nem o maior certificado
     isolado cabe no dispositivo, não mais sempre que o dossiê inteiro não cabe de uma vez.
   - `Dossie`/`StatusDossie` ganharam `compilandoEmPartes` + `loteAtual`/`totalDeLotes` para a
     UI mostrar progresso real durante a compilação em partes.
   - `PdfMergeDatasource` ganhou `mesclarLote` e `mesclarIntermediariosComSumario` (ambos
     stubs documentados, como o resto da mesclagem de PDF real).

7. **Atualização do PWA em uso — confirmado: avisar e deixar o usuário escolher.** Sem
   mudança de código (já era o comportamento esqueletizado em `web/sw.js`).

8. **Ordem da Fase 2 (Android vs. iOS) — o usuário não respondeu a pergunta como feita:
   pediu para primeiro ter algo rodando no navegador antes de discutir a ordem da Fase 2
   nativa.** Interpretação adotada: pausar a decisão Android/iOS (ainda em aberto,
   ROADMAP_MOBILE.md não precisou mudar) e priorizar imediatamente uma fatia end-to-end
   funcional da Fase 1 web. Implementado como consequência: `LattesFileDatasourceWeb` (seleção
   real de arquivo via `file_picker`, com fallback de encoding UTF-8/Latin-1), os providers
   Riverpod do módulo 1 (`lattes_providers.dart`), o widget `CurriculoListView` e a tela
   `LattesImportPage` reescrita como fluxo funcional completo: selecionar XML -> parsear ->
   exibir currículo -> confirmar vínculos ambíguos. É a primeira parte do app que roda de
   ponta a ponta no navegador (os módulos 2-4 continuam com a camada de dados em stub).

## Novas pendências abertas por estas decisões

1. **Ordem Android vs. iOS na Fase 2** continua sem resposta — só foi adiada, não respondida.
   Retomar quando a Fase 1 web tiver mais módulos funcionais.
2. **Calibração da fração de 25% da RAM usada no cálculo de `navigator.deviceMemory`** foi
   escolhida como valor conservador inicial, não validada com nenhum dispositivo real.
   Recomendação padrão: ajustar com telemetria de campo assim que houver uso real em Android.
3. **Tamanho mínimo viável de lote na mesclagem em partes** (hoje 60% do teto de memória,
   `TaskRunner.batchSizeBytesHint`) também é um valor inicial não validado com PDFs reais de
   certificado. Recomendação padrão: ajustar depois de medir o tamanho médio real dos PDFs
   gerados a partir de fotos de certificado.

## Decisões confirmadas pelo usuário (2026-09-12)

1. **Confirmação explícita do modelo multiusuário.** O app é multiusuário desde a concepção:
   qualquer pessoa faz login com a própria conta Google ou Microsoft, e todo arquivo processado
   vai para o Drive/OneDrive DELA, não para um storage central do app — não existe "dono" do
   app nem arquivo compartilhado entre usuários. Isso não exigiu mudança de código (já era o
   design de `AuthRepository`/`CloudStorageRepository`/`SecureStorageService`, cada sessão de
   navegador com seu próprio token), mas expôs duas pendências práticas de produção, novas
   nesta rodada — ver RISCOS.md, item 10: (a) o cadastro do app OAuth no Google Cloud Console e
   no Azure AD precisa estar como "Externo/Produção" (não "modo de teste", que limita a ~100
   usuários e exige listá-los manualmente); (b) a cota de chamadas da Google Drive API e do
   Microsoft Graph é por PROJETO/aplicativo, compartilhada entre todos os usuários do app, não
   por usuário — em volume, isso é um teto real diferente da cota de armazenamento individual
   já coberta em RISCOS.md item 3.

2. **Terceiro provedor de armazenamento (iCloud Drive) — avaliado e descartado pelo usuário.**
   Havia sido implementado nesta mesma rodada como `EntregaExportacaoManual` (download nativo +
   folha "Salvar em Arquivos", já que a Apple não tem API pública equivalente à Drive
   API/Graph para apps web escreverem na pasta pessoal do usuário), mas o usuário decidiu não
   seguir com isso. Revertido por completo: `MetodoEntregaArquivo`, `ManualExportService`
   (web/nativo), `ManualExportRepository`/`Impl`, `ManualExportFailure` e o use case
   `EntregarArquivoProcessado` foram removidos; `CloudProvider` voltou a ser só
   `{googleDrive, oneDrive}`. Ver "Alternativas descartadas" acima. Escopo de armazenamento do
   app fica definitivamente Google Drive + OneDrive, sem terceiro provedor por ora.

## Novas pendências abertas por esta rodada (2026-09-12)

1. **Registro dos apps OAuth como "Externo/Produção"** no Google Cloud Console e no Azure AD,
   com a URL final de produção (`https://izialber.com.br/certificados-lattes/`) cadastrada como
   redirect URI — hoje só documentado como necessidade, não executado (depende do deploy).
   Google pode exigir processo de verificação para o escopo do Drive quando o número de
   usuários crescer além do limite de app não verificado.

## Implementação do Módulo 2 — Captura de Certificados (2026-09-16)

Continuação pedida pelo usuário após o teste ao vivo do login com Google ter falhado (erro
retomado depois — ver RISCOS.md/pendência de OAuth). Decisões tomadas para sair do stub
documentado para uma implementação real, sem pergunta prévia ao usuário porque cada uma decorria
diretamente do contrato já fixado pelas entidades/interfaces existentes:

1. **`LlmRepository.extrairJsonDeImagem`/`extrairJsonDeTexto` não recebem o provedor como
   parâmetro** (só `testarConexao` recebe) — mas nada no código anterior dizia COMO o
   repositório saberia qual provedor usar. Resolvido estendendo `LlmApiKeyStore` (que já
   guardava as chaves BYOK) para também guardar qual provedor está ativo
   (`SecureStorageKeys.llmProviderEscolhido`, gravado como o nome do enum). `LlmRepositoryImpl`
   lê essa preferência a cada chamada; se não houver provedor configurado ou a chave dele não
   estiver salva, retorna `LlmFailure(isQuotaOrAuth: true)` pedindo para configurar em
   Configurações (tela de configuração de chave em si continua fora do escopo desta rodada).

2. **Sugestão de vínculo (`VinculoSugerido`) NÃO é calculada durante a extração do
   certificado**, mesmo o diagrama de ARQUITETURA.md (seção 4.2) sugerindo isso na descrição em
   texto. Ficou explícito ao ler `SugerirVinculos` (módulo 4, `dossie_builder`): esse use case
   recebe uma lista de `CertificadoCapturado` JÁ sincronizados e um `Edital`, e é o único lugar
   que de fato tem acesso a candidatos reais de vínculo (itens do currículo Lattes cruzados
   contra critérios do edital). Pedir para o LLM "adivinhar" um `idItemLattesReferenciado` na
   extração do certificado não faria sentido sem esse contexto. `CertificadoCapturado.
   vinculoSugerido` fica `null` até o módulo 4 rodar — o prompt de extração (`assets/prompts/
   extracao_certificado.txt`) pede só título, instituição, carga horária e data.

3. **HeicConverter virou uma abstração de plataforma nova** (`core/platform/heic/`, mesmo
   padrão de `CameraService`/`SecureStorageService`), porque `ARQUITETURA.md` já a descrevia na
   tabela de abstrações (linha `HeicConverter`) mas a classe em si nunca tinha sido criada.
   Implementação Web usa `<img>`/`<canvas>` (Safari decodifica HEIC nativamente; outros
   navegadores lançam `HeicConversionUnsupportedException`, tratada pela UI como pedido de
   exportação manual). Detecção de HEIC é por magic bytes do box `ftyp` (ISOBMFF) — nunca por
   mimetype/extensão, por causa do RISCOS.md já registrado sobre mimetype genérico no iOS.

4. **Persistência local do módulo 2 em duas Hive boxes separadas** (`certificate_capture_
   metadata` para os campos de `CertificadoCapturado`, `certificate_capture_images` para os
   bytes crus) em vez de uma só — decisão de performance, não só de organização: `listarTodos()`
   (usado toda vez que a tela de lista monta) só precisa ler metadados; carregar os bytes de
   TODAS as imagens de uma vez só para mostrar status seria desperdício de memória crescente com
   o número de certificados. `caminhoImagemLocal` (campo que já existia na entidade, documentado
   como "referência local / IndexedDB key") passou a ser literalmente o `id` do certificado,
   usado como chave nas duas boxes. Isso também preencheu a pendência de `main.dart` de abrir
   as Hive boxes antes do primeiro frame — criado `core/di/bootstrap.dart` para isso, só abrindo
   as boxes que já têm um repositório real por trás (não as de fila de upload/dossiê, que
   continuam stub).

5. **Compressão de imagem (`package:image`) antes do envio ao LLM, dentro de `TaskRunner.run`**
   — reduz para no máximo 1600px de largura e reencoda em JPEG qualidade 85 antes de mandar para
   Gemini/OpenAI; se a decodificação falhar (formato não reconhecido pelo decoder puro Dart),
   segue com a imagem original em vez de bloquear a extração inteira por causa de uma otimização.

6. **Câmera ao vivo (`getUserMedia`) implementada em `CameraServiceWeb`, mas SEM o widget de
   preview ligado na tela ainda** — decisão de escopo, não de arquitetura: a integração de um
   `<video>` ao vivo dentro da árvore de widgets do Flutter Web (`HtmlElementView` + registro de
   view factory) é a peça de maior risco de bug não detectável sem um ambiente Flutter real para
   testar (este ambiente não tem o SDK Flutter — ver RESUMO.md), e o upload via `file_picker` já
   cobre o caso de uso completo hoje, inclusive em mobile (o seletor de arquivo abre a
   câmera/galeria nativa do aparelho quando o `accept` é imagem). Fica como pendência explícita
   para a próxima rodada, não como algo esquecido.

7. **Tela de configuração BYOK implementada na mesma rodada** (`LlmSettingsPage`, rota
   `/configuracoes/llm`, `LlmSettingsController`) assim que ficou claro que sem ela o pipeline
   inteiro do Módulo 2 é inutilizável (`extrairDados` sempre cai em "nenhum provedor
   configurado"). Segue o mesmo requisito já registrado para BYOK: `testarConexao` roda ANTES
   de `salvarChave`/`salvarProvedorEscolhido` — nunca salva uma chave não testada. Acessível
   pelo ícone de engrenagem na tela de captura de certificados.

### Novas pendências abertas por esta rodada (2026-09-16)

1. **Widget de preview da câmera ao vivo** (`HtmlElementView` ligado a
   `CameraServiceWeb.previewElement`) — ver decisão 6 acima.
2. **CORS da OpenAI a partir do navegador** ainda não foi validado contra uma chave real em
   produção (ver comentário em `openai_llm_datasource.dart`) — só o Gemini foi desenhado com
   confiança de que funciona sem proxy, por já ter essa confirmação em RISCOS.md.
