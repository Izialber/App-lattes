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

## Bugs encontrados e corrigidos ao vivo, testando o deploy (2026-09-16)

Testado direto em produção (`izialber.com.br/app-lattes/`) depois do Módulo 2 no ar. Três
achados reais, nenhum hipotético:

1. **"Esqueci minha senha" sempre "funcionava" mesmo sem conta** — o Firebase tem proteção
   contra enumeração de e-mail ligada por padrão (retorna sucesso mesmo para e-mail sem conta,
   por segurança). Não é bug — é o comportamento correto e não deve ser alterado (explicar
   "essa conta não existe" seria uma vulnerabilidade de enumeração de usuário). A causa real do
   caso relatado: nenhuma conta com e-mail/senha tinha sido criada de fato (só havia um usuário
   de teste `teste-ui-claude@example.com` no Firebase Console) — confirmado direto no Console
   (Authentication → Users), não só por inspeção de código.
2. **`gemini-2.0-flash` (id fixado em `GeminiLlmDatasource`) foi descontinuado pela Google** —
   toda chamada retornava 404. Trocado para o alias oficial `gemini-flash-latest`, que a Google
   promete manter sempre apontando para o Flash recomendado (ver
   https://ai.google.dev/gemini-api/docs/models) — evita que o id fique stale de novo sem
   precisar de um novo deploy toda vez que a Google descontinuar uma versão.
3. **Mensagem de erro genérica demais para diagnosticar em produção** — `DioException.message`
   só dizia "response has a status code de 400", sem a razão real. Descoberto que a Gemini API
   usa 400 (não 401) para chave de API inválida, então esse detalhe importa: agora
   `LlmApiException.deChamadaHttp` extrai `error.message` do corpo de resposta (formato comum a
   Gemini e OpenAI) e `isQuotaOrAuth` passa a considerar 400 também.

Também adicionado: ícone de configuração de LLM na tela de importação do Lattes (não só na de
captura), depois de relato de que sumia na versão mobile — provavelmente por exigir navegar até
a tela de captura primeiro, que por sua vez exige um currículo já importado.

## Seleção de pasta inteira no Módulo 2 (2026-09-16)

Pedido do usuário: poder selecionar uma pasta e o app ver todos os arquivos dela E de
subpastas, em vez de só seleção múltipla de arquivos avulsos. Antes de implementar, foi
discutida uma alternativa mais radical — usuário escolhe manualmente qual entrada do currículo
Lattes cada certificado comprova, eliminando a extração via LLM (o próprio XML já tem título/
instituição/carga horária/data de cada item). Decisão do usuário: manter o pipeline de LLM como
está por enquanto; a seleção de pasta é um complemento ao fluxo atual, não uma substituição — a
ideia de vínculo manual fica registrada aqui para retomar depois se fizer sentido.

Implementação: `file_picker` não suporta seleção de pasta no web (confirmado lendo o código
fonte do pacote — nenhuma implementação usa `webkitdirectory`). `CertificateUploadDatasourceWeb.
selecionarPasta()` é uma implementação própria via `package:web` puro (mesmo padrão de
`CameraServiceWeb`/`HeicConverterWeb`): cria um `<input type="file">` oculto com o atributo não
padronizado `webkitdirectory` (suportado em Chrome/Edge/Safari/Firefox recente), o que faz o
navegador listar recursivamente todos os arquivos de todas as subpastas num único `FileList` —
cada `File` carrega `webkitRelativePath` com o caminho original, preservado em
`ArquivoSelecionado.caminhoRelativo` para mensagens de erro mais úteis. Sem equivalente
confiável em mobile — por isso a UI oferece as duas opções lado a lado (menu no FAB), com
seleção de arquivo avulso continuando como caminho principal.

## Suporte a PDF no Módulo 2 (2026-09-16)

Pedido do usuário depois de testar a seleção de pasta e não ver nada acontecer — causa real:
os certificados dele eram PDF, formato que o pipeline silenciosamente descartava (sem nenhum
aviso, só corrigido agora com a mensagem "nenhum certificado em formato aceito").

Mudança estrutural: `CertificadoCapturado` ganhou o campo `mimeType` (antes recebido em
`registrarCaptura` mas descartado sem ser persistido) — sem ele não dava para saber, na hora de
chamar o LLM, se o arquivo original era imagem ou PDF. `_comprimir` (compressão via
`package:image`) agora pula direto para PDF (não é formato raster, o decoder retornaria null de
qualquer forma) e devolve o mimeType correto junto com os bytes, como um record
`({List<int> bytes, String mimeType})`, para o restante do pipeline nunca assumir "sempre vira
JPEG depois da compressão" (verdade só para os formatos de imagem).

Gemini lê PDF nativamente via `inline_data` (mesmo mecanismo de imagem, sem mudança no
datasource). **OpenAI não** — o endpoint de chat completions usado aqui (`image_url`) só aceita
imagem; PDF exigiria a API de Files/Assistants, fora do escopo. `OpenAiLlmDatasource.gerarJson`
recusa explicitamente `mimeType: application/pdf` com uma mensagem pedindo para trocar de
provedor, em vez de deixar a chamada falhar com um erro genérico da API.

## Módulo 3 — Sincronização com o Drive (2026-09-18)

Pedido do usuário para trabalhar de forma autônoma enquanto o login OAuth do Google/Drive
continua bloqueado (exige as credenciais dele ao vivo, ver pendência de 2026-09-16). Escolhido
como prioridade entre os itens pendentes. Implementação completa da camada de dados que antes
era só stub: `GoogleDriveDatasource` (chamadas REST reais à Drive API v3), `PdfBuilderDatasource`
(converte a imagem do certificado numa página de PDF via `package:pdf`; PDF de origem passa
direto), `UploadQueueLocalStore` (Hive, mesmo padrão de `CertificateLocalStore`, boxes separadas
para metadados e bytes do PDF) e `CloudStorageRepositoryImpl` ligando tudo.

Decisões de implementação:
1. **Autenticação via interceptor do Dio**, não parâmetro em cada método — mantém o contrato de
   `GoogleDriveDatasource` já documentado antes desta implementação (`criarPastaSeNaoExistir`
   etc. nunca receberam token como argumento). O interceptor chama
   `AuthRepository.obterTokenValido` (renova sozinho se necessário) antes de cada request; se não
   houver sessão válida, rejeita com `DioException(type: cancel)`, que
   `CloudStorageRepositoryImpl` traduz para `CloudStorageFailure(isTransient: false)` — sem
   sessão válida, tentar de novo automaticamente nunca resolveria sozinho.
2. **`UploadTask` e `CertificadoCapturado` ganharam campos que a implementação real precisou e
   os stubs não prometiam**: `UploadTask.idArquivoCloud` (o id do arquivo no Drive, só disponível
   depois que o upload termina — `enviarChunk` mudou de retornar só `int` para um record
   `({int bytesConfirmados, String? idArquivo})`) e `CertificateRepository.atualizarStatus` ganhou
   um parâmetro opcional `mensagemErro` (antes só dava para mudar o status, não registrar por que
   uma sincronização falhou).
3. **Upload resumível implementado como um único PUT do arquivo completo**, não em múltiplos
   chunks de verdade — PDFs de certificado (uma página, imagem comprimida) são pequenos o
   bastante para isso na prática. A assinatura de `enviarChunk` (`offset`, retorno com bytes
   confirmados) já segue o protocolo completo do Google (inclusive trata 308 Resume Incomplete
   como resposta válida, não erro), então dá para implementar chunking de verdade depois sem
   mudar a interface.
4. **`StatusCertificado.pendenteRevisao` E `aprovado` são tratados como "pronto para
   sincronizar"** pelo `CloudSyncController.sincronizarTodos` — não existe hoje uma tela de
   revisão humana separada (era a intenção original do comentário no enum, para o módulo 4, que
   continua stub), então exigir uma aprovação manual antes de sincronizar bloquearia o módulo 3
   inteiro por uma UI que não existe ainda. Pode ser revisto quando o módulo 4 ganhar uma tela de
   revisão de verdade.
5. **OneDrive continua fora de escopo** (decisão já registrada: Google primeiro) —
   `CloudStorageRepositoryImpl` retorna `CloudStorageFailure` explícita para esse provedor em vez
   de deixar `OneDriveGraphDatasource` lançar `UnimplementedError` sem contexto.

### Novas pendências abertas por esta rodada (2026-09-18)

1. **Nada disto foi testado ao vivo** — depende do login OAuth do Google funcionar (pendência já
   registrada), que por sua vez depende das credenciais do usuário. Todo o código foi revisado
   linha a linha contra a documentação da Drive API v3 e o código-fonte real do Dio/pdf/hive_ce
   (sem SDK Flutter neste ambiente para compilar).
2. **Upload em chunks de verdade** (arquivos grandes, retomada no meio de um chunk específico)
   não foi implementado — só upload de arquivo único. Ver decisão 3 acima.
3. **Tela de revisão humana do módulo 4** — quando existir, deve decidir se
   `sincronizarTodos` continua incluindo `pendenteRevisao` automaticamente ou passa a exigir
   `aprovado` explicitamente primeiro (ver decisão 4 acima).

## Módulo 4 — Montador de Dossiê (2026-09-18)

Continuação do trabalho autônomo (pedido do usuário: seguir sem esperar por ele, e pular para
outra coisa se travar em algo). Implementação completa da camada de dados que antes era só
stub — com uma descoberta técnica que mudou o desenho original.

**Descoberta: `package:pdf` não mescla PDFs existentes.** O contrato original de
`PdfMergeDatasource` (`pdfsEmOrdem: List<List<int>>`) assumia que dava pra pegar PDFs já
prontos (os que o módulo 3 gera por certificado) e "mesclar" — mas `package:pdf` é uma
biblioteca de ESCRITA de PDF (constrói documento a partir de conteúdo Dart), sem nenhuma
capacidade de importar página de um PDF já existente. Confirmado lendo o código-fonte do
pacote (não achei `importPage`/`merge`/equivalente) e o do `syncfusion_flutter_pdf` (usado
hoje só para extrair texto) — também sem essa capacidade na versão community usada aqui.
Cogitei rasterizar PDFs existentes via `Printing.raster()` (pacote `printing`, já dependência,
usa pdf.js no web) para contornar isso, mas isso exigiria carregar pdf.js de um CDN em tempo de
execução — quebraria a CSP atual (`script-src`) e traria uma dependência de rede externa não
testável ao vivo neste ambiente. Descartado por ora.

**Solução adotada**: `PdfMergeDatasource.mesclarComSumario` agora recebe as IMAGENS originais
dos certificados (não PDFs prontos) e constrói o dossiê inteiro como um documento novo, do
zero — mesma técnica de `PdfBuilderDatasource` (módulo 3), só que N páginas num documento em
vez de N documentos de 1 página. Isso resolve o problema por completo PARA CERTIFICADOS DE
ORIGEM IMAGEM (a maioria). **Certificados cuja origem já era PDF (suportado desde
2026-09-16) ficam de fora da mesclagem automática** — `DossieRepositoryImpl.
compilarDossieFinal` os exclui silenciosamente do PDF final, contando quantos foram excluídos
para a mensagem de erro no caso extremo de todos os aprovados serem PDF de origem.

**Consequência em cascata**: a estratégia `emPartes` de `DecidirEstrategiaDeMemoria` (mesclar
PDFs intermediários já prontos, para não estourar memória com dossiês grandes) também depende
de "mesclar PDF existente" — mesmo problema, sem solução disponível agora.
`PdfMergeDatasource.mesclarLote`/`mesclarIntermediariosComSumario` continuam
`UnimplementedError`, e `compilarDossieFinal` retorna uma `DossieFailure` clara (pedindo para
reduzir a quantidade de certificados ou usar um desktop) em vez de tentar chamá-los. Só a
estratégia `direta` está implementada de verdade.

**Gaps de interface descobertos ao implementar** (mesmo padrão das rodadas anteriores — a
interface original não sobrevivia ao contato com a implementação real):
1. `DossieRepository.sugerirVinculos` retornava `Either<Failure, Edital>` — mas `Edital` não
   tem nenhum campo para guardar sugestões de vínculo, e o método não muta os certificados
   passados. Criada a entidade `VinculoSugeridoDossie` (certificadoId + criterioId + confiança)
   e o retorno virou `Either<Failure, List<VinculoSugeridoDossie>>`.
2. `DossieRepository.extrairCriterios` não recebia o nome do arquivo original do edital, mas
   `Edital.nomeArquivoOriginal` é obrigatório — adicionado `nomeArquivoOriginal` como parâmetro.
3. `RegistrarDecisaoVinculo` era citado na docstring de `SugerirVinculos` desde a entrega
   original, mas a classe de use case nunca tinha sido criada — só o método do repositório
   existia. Criada agora.

**Sugestão de vínculo é heurística pura, não chamada de LLM** — decisão deliberada: comparação
de sobreposição de palavras (Jaccard simplificado) entre título/instituição do certificado e a
descrição de cada critério do edital, sem custo de API nem latência extra. É só uma sugestão
inicial revisada no checklist de qualquer forma, então o ganho de precisão de uma chamada de
LLM não pareceu compensar o custo/complexidade extra nesta rodada.

**Nada disto foi testado ao vivo** (mesmo motivo dos módulos 2/3) — 29 testes novos cobrindo
`DossieRepositoryImpl` (os 4 métodos, incluindo a heurística de sugestão e a exclusão de
certificados PDF na compilação) e `PdfMergeDatasource` (PDF de saída válido, com imagem PNG de
teste gerada via `package:image`).

### Novas pendências abertas por esta rodada (2026-09-18)

1. **Mesclagem em partes (`emPartes`)** não implementada — ver "Consequência em cascata" acima.
   Só é um problema real para dossiês com muitos certificados grandes; a maioria dos casos deve
   passar pela estratégia `direta`.

Duas pendências que estavam aqui (aviso visual de certificado PDF excluído da mesclagem, edição
manual dos critérios do edital) foram resolvidas na sequência, ainda na mesma sessão: cada
`_CertificadoVinculoTile` agora mostra um aviso quando o certificado é PDF de origem, e o
checklist ganhou "Adicionar critério manualmente" + remover critério (`Edital.copyWith`,
`DossieBuilderController.adicionarCriterioManual`/`removerCriterio`).

## Preview de câmera ao vivo no Módulo 2 (2026-09-18)

Última pendência antiga do módulo 2 (documentada desde 2026-09-16). `CameraServiceWeb` ganhou
um getter `stream` (o `MediaStream` cru, além do `<video>` interno que já existia para
`captureFrame`) — um mesmo `MediaStream` alimenta múltiplos elementos `<video>` sem conflito,
então o `<video>` visível desta tela e o interno usado para capturar o frame coexistem sem
problema. UI nova: `_CameraCapturePage` (tela cheia, câmera + botão de captura) e `_CameraPreview`
(`HtmlElementView.fromTagName('video', ...)`, liga `srcObject` ao stream) em
`certificate_capture_page.dart`. `start()` é chamado em `initState` — seguro porque a própria
navegação até a tela (tap no menu do FAB) já é o gesto do usuário que `getUserMedia` exige.

Não testado ao vivo — depende de `dart:ui_web`/`HtmlElementView.fromTagName`, que não pude
verificar contra o SDK Flutter real deste projeto (sem SDK neste ambiente). Risco de versão
verificado por inspeção do `pubspec.yaml`: o projeto exige `sdk: ">=3.3.0 <4.0.0"` (Dart), que
corresponde a Flutter ~3.19+ — bem depois do Flutter 3.10 (maio/2023), quando
`HtmlElementView.fromTagName` foi introduzido. Não elimina a necessidade de teste ao vivo (a
API pode ter mudado de comportamento, não só de existência), mas descarta o risco específico de
"API não existe nesta versão".

## Revisão de código dos módulos 2-4 (2026-09-18)

Rodei `/code-review high` sobre tudo implementado nesta sessão (`839a664..HEAD`, 67 arquivos)
enquanto trabalhava em outra coisa, seguindo a orientação do usuário de não parar esperando por
ele. 10 achados, 6 corrigidos na sequência (mais sérios primeiro):

1. **Corrupção silenciosa de upload no fallback do 308** (`GoogleDriveDatasource.enviarChunk`):
   quando a resposta 308 não vinha com header `Range` legível, o código fabricava `offset + 1`
   bytes confirmados em vez de admitir que não sabia quantos bytes o servidor recebeu — o
   próximo chunk pularia bytes nunca confirmados, corrompendo o PDF enviado. Corrigido para cair
   em `offset` (sem avanço nenhum) nesse caso, forçando reenviar o mesmo chunk.
2. **Casts diretos em JSON do LLM sem tratamento**, em dois lugares (`CertificateRepositoryImpl.
   extrairDados` e `DossieRepositoryImpl.extrairCriterios`): um `as String?`/`as num?` direto
   numa resposta com tipo inesperado (ex.: `cargaHorariaHoras: "40h"`) lançava uma exceção não
   capturada — o certificado ficava travado para sempre em "extraindoDados", ou a extração do
   edital inteiro falhava por causa de UM item malformado. Trocado por coerção defensiva
   (`_comoTextoOpcional`/`_comoInteiroOpcional`/`_comoDoubleOpcional`) que tenta converter em vez
   de assumir o tipo, e itens malformados de `criterios` agora são só ignorados
   (`.whereType<Map>()`), não derrubam o edital inteiro.
3. **`normalizarFormatoImagem` não persistia falha em exceções genéricas** (só no caso
   específico `HeicConversionUnsupportedException`) — um reload de aba fazia o certificado
   "voltar" ao status anterior, escondendo a falha real.
4. **Botão único de "tentar novamente" sempre pulava direto para a extração**, mesmo quando
   quem tinha falhado era a normalização HEIC — reenviava bytes HEIC não convertidos para a API
   do LLM. `reextrair` agora sempre repete a normalização (idempotente) antes de extrair.
5. **Busca da pasta do Drive repetida a cada certificado** dentro de uma sessão de sincronização
   (`sincronizarTodos`) — N buscas redundantes na Drive API pelo mesmo id, que não muda.
   `CloudStorageRepositoryImpl` ganhou um cache de instância (`_pastaId()`), compartilhado entre
   `garantirPastaDedicada` e `enviarArquivo`.
6. **Upload em chunks de verdade implementado** (não era bem um achado da revisão, mas foi feito
   na mesma leva): `enviarArquivo` agora envia em fatias de 2MiB com progresso persistido a cada
   chunk, em vez de um PUT só do arquivo inteiro — `GoogleDriveDatasource.enviarChunk` ganhou o
   parâmetro `tamanhoTotalArquivo` (o `Content-Range` precisa do tamanho total do arquivo, não
   só do chunk atual). Guard-rail contra loop infinito se o servidor nunca confirmar progresso
   (5 tentativas sem avanço → falha explícita).

Achados não corrigidos (severidade menor, escolha deliberada de priorizar os acima):
7. `compilarDossieFinal` não comunica no resultado quantos certificados PDF-de-origem foram
   excluídos da mesclagem — só o checklist avisa ANTES de compilar (ver rodada anterior).
   **Corrigido em 2026-09-18, ver entrada "Achado #7 corrigido" abaixo.**
8. ~~Certificados WEBP não testados contra o decoder de `package:pdf`/`package:image` — teoria,
   não confirmado como bug real.~~ **Verificado em 2026-09-18 por inspeção do código-fonte
   pacote em `~/.pub-cache/hosted/pub.dev/image-4.9.2`**: `decodeImage` já detecta WEBP pela
   assinatura de bytes (`WebPDecoder().isValidFile`) e decodifica via `WebPDecoder` puro-Dart
   (`lib/src/formats/webp_decoder.dart`), sem depender de plugin nativo/plataforma — funciona
   igual no Flutter Web. Não é um bug real; fechado sem alteração de código.
9. Erros da câmera ao vivo usam `String` bruta (`'$e'`) em vez do modelo `Either<Failure,...>`
   do resto do app — `CameraCaptureDatasource` (que prometeria essa tradução) nunca chegou a
   ser injetado em lugar nenhum. Mantido como está: o erro fica só no estado local do widget
   `_CameraCapturePage` (câmera ao vivo é uma tela cheia isolada, não faz parte do pipeline de
   domínio persistido em `CertificateCaptureState`), então o padrão `Either` do domínio não se
   aplica diretamente — seria refatoração sem ganho de correção, não uma correção de bug.

5 testes novos cobrindo os achados corrigidos (chunking de verdade com `tamanhoDoChunk`
configurável só para teste, cache de pasta compartilhado, coerção de tipo em JSON malformado,
persistência de falha genérica). 115 testes no total.

## Achado #7 corrigido: resultado da compilação agora avisa sobre PDFs excluídos (2026-09-18)

O checklist já avisava, ANTES de compilar, quais certificados aprovados são PDF de origem e por
isso não entram na mesclagem automática (ver "Suporte a PDF no Módulo 2"). Mas o RESULTADO da
compilação em si não repetia esse aviso — um usuário que não reparasse no aviso anterior via só
"compilado com sucesso", sem saber que o PDF final está incompleto. `DossieRepositoryImpl.
_compilarDireto` agora recebe `totalPdfDeOrigemExcluidos` e, quando > 0, grava uma nota no mesmo
campo `mensagemDegradacao` do dossiê (reaproveitado como campo genérico de "nota informativa",
não só de degradação por memória) — `dossie_compile_page.dart` exibe essa nota como subtítulo
abaixo de "Dossiê compilado com sucesso!".

Efeito colateral encontrado: `Dossie.copyWith` tinha a mesma limitação já corrigida antes em
`CertificadoCapturado.copyWith` — um `String? mensagemDegradacao` com fallback `??` nunca
conseguia "limpar" o campo (só sobrescrever com outro valor não-nulo). Precisava disso para o
caso comum (0 certificados excluídos → mensagem deve ficar `null`, não herdar uma mensagem de
degradação de uma tentativa anterior já corrigida). Adicionado `limparMensagemDegradacao` (bool,
default `false`) ao `copyWith`, mesmo padrão de antes.

**Primeira tentativa da segunda rodada de `/code-review high` (pedida pelo usuário, "revise mais
uma vez tudo") não completou** — o coordenador e a maioria dos sub-agentes de busca falharam com
HTTP 429 (limite de sessão da API da Claude, reset 15h America/São_Paulo). Re-tentada depois das
15h, ver entrada seguinte para os achados reais dessa rodada.

## 2ª revisão de código (retry após rate limit) — 10 achados, 9 corrigidos (2026-09-18)

Rodei `/code-review high 839a664..HEAD` de novo depois das 15h (quando o rate limit da tentativa
anterior deveria ter resetado) — desta vez completou, 8 ângulos de busca + verificação em 3
lotes. Um candidato (cache do id da pasta do Drive ficar obsoleto ao trocar de conta) foi
REFUTADO pelo próprio revisor: o fluxo OAuth só faz redirect de página inteira, que destrói o
`ProviderContainer` — trocar de conta sempre recria o cache do zero, não há como ficar obsoleto.

Achados corrigidos (mais sérios primeiro):

1. **`CertificadoCapturado.copyWith` nunca conseguia limpar `mensagemErro`** (mesma limitação de
   `Dossie.copyWith`, corrigida na entrada anterior, só que eu não tinha percebido que
   `CertificadoCapturado` tinha o mesmo problema desde o início). Um certificado que falhava e
   depois tinha sucesso numa nova tentativa continuava exibindo a mensagem de erro antiga para
   sempre. Adicionado `limparMensagemErro` ao `copyWith`; `extrairDados` (sucesso),
   `normalizarFormatoImagem` (sucesso) e `atualizarStatus` (quando chamado sem `mensagemErro`,
   que é toda transição de progresso/sucesso) agora limpam o campo.
2. **`_marcarFalha` (certificate_capture_providers.dart) grudava toda falha em
   `falhaExtracao`**, mesmo a de normalização HEIC — a `reextrair` já tratava as duas causas de
   forma diferente ao reprocessar (rodada anterior), mas o status em si não distinguia.
   Adicionado `StatusCertificado.falhaNormalizacao`, persistido pelo repositório e agora também
   refletido corretamente no estado em memória (`_marcarFalha` passou a receber o status certo
   em vez de assumir `falhaExtracao`). UI (`certificate_capture_page.dart`) ganhou os 3 casos
   novos nos switches exaustivos — ícone/botão de retry idênticos aos de `falhaExtracao`, rótulo
   próprio ("Falha ao converter o arquivo").
3. **Retry de chunk sem confirmação de progresso (308) não tinha backoff** — reenviava o mesmo
   chunk (potencialmente MBs) 5 vezes seguidas sem espera; se a causa fosse rate limiting
   transitório, isso só pioraria. Adicionado backoff exponencial simples (500ms, 1s, 2s, 4s)
   entre tentativas.
4. **Validação de campos obrigatórios do LLM só checava `null`**, não string vazia — um
   `{"titulo": ""}` passava a revisão humana como se tivesse dado certo. Agora trata string vazia
   (ou só espaços) igual a ausente.
5. **`DossieCompilePage` recompilava do zero toda vez que a tela abria**, mesmo com o dossiê já
   compilado com sucesso (voltar e reabrir, ou recarregar a URL). Adicionada checagem de status
   antes de disparar `compilar` de novo.
6. **Nota de PDFs excluídos (achado #7 da 1ª rodada, corrigida na entrada anterior) reaproveitava
   `mensagemDegradacao`** — um consumidor futuro que checasse esse campo para detectar
   degradação real de memória teria falso positivo em qualquer compilação comum que só excluiu
   PDFs. Campo próprio criado: `Dossie.notaCompilacao`.
7. **`UploadTask.copyWith` tinha a mesma limitação do achado #1**, e uma retomada bem-sucedida da
   fila de upload não limpava `mensagemErro` de uma falha temporária anterior da mesma tarefa.
   Mesmo fix (`limparMensagemErro`).
8. **Três implementações inconsistentes de "primeiro item ou null"** no diff — um loop manual
   (`cloud_sync_providers.dart`), um helper próprio `_primeiraOuNulo` (`dossie_checklist_page.
   dart`), e um `firstWhere` sem `orElse` (`certificate_capture_providers.dart`, que lançaria
   `StateError` se chamado antes do certificado existir na lista). Unificado nos 3 lugares usando
   `firstWhereOrNull`/`firstOrNull` de `package:collection` (promovida de dependência transitiva
   para direta no `pubspec.yaml`).
9. **`bootstrap()` abria as 7 Hive boxes sequencialmente** apesar de serem independentes — trocado
   por `Future.wait`, evitando somar 7 round-trips de IndexedDB no cold start.

Achado não corrigido (severidade menor, escolha deliberada):
10. `certificate_local_store.dart`, `dossie_local_store.dart` e `upload_queue_local_store.dart`
    reimplementam cada um, de forma independente, o mesmo padrão "Hive box de metadados + box de
    bytes, salvar/buscar/listar/remover". Extrair uma classe base resolveria a duplicação, mas é
    uma refatoração estrutural nas 3 camadas de persistência sem SDK Flutter disponível para
    validar que nada quebra — risco maior que o benefício nesta sessão. Fica registrado para uma
    sessão futura com o SDK disponível.

4 testes novos cobrindo os achados corrigidos (validação de string vazia, limpeza de
`mensagemErro` em sucesso de extração/atualização de status/upload). 119 testes no total.

## Primeiro teste ao vivo do login com Google — bug real encontrado e corrigido (2026-09-22)

Testado o fluxo "Continuar com Google" pela primeira vez desde que foi implementado (bloqueado
a sessão inteira anterior — ver entradas de 2026-09). Via Claude em Chrome: logout, "Continuar
com Google", account chooser, aviso de app não verificado (esperado, app em modo Testing), tela
de consentimento (escopo `drive.file`) — tudo funcionou até a troca do `code` por tokens, que
falhou com HTTP 400 (`DioException [bad response]`).

**Causa raiz**: `OauthPkceDatasource.trocarCodePorTokens`/`renovarComRefreshToken` não enviavam
`client_secret` na requisição ao `token_endpoint` do Google. A suposição original (documentada no
pubspec e no `oauth_config.dart` antigo: "Authorization Code + PKCE, sem client secret") está
correta para a maioria dos provedores (Auth0, Okta, etc. suportam client público sem secret), mas
**o Google não segue essa parte do espírito da RFC 7636** — exige `client_secret` na troca de
token mesmo com PKCE, para todo Client ID do tipo "Aplicativo da Web". Os únicos tipos de Client
ID do Google que dispensam secret ("Desktop app", "TVs and Limited Input devices") só aceitam
`redirect_uri` do tipo `http://localhost`/scheme customizado — incompatíveis com um PWA hospedado
em domínio próprio (`https://izialber.com.br/...`). Ou seja: não havia como configurar o Client ID
de um jeito que evitasse essa exigência, dado que o app precisa do redirect no próprio domínio.

**Correção**: gerado um novo Client secret no Google Cloud Console (o original, criado junto com
o Client ID em 2026-09-16, nunca tinha sido visualizado — a Console do Google só mostra o valor
uma vez, na criação; como ninguém tinha copiado, ficou irrecuperável, por isso "novo" e não
"recuperado"). Enviado em `client_secret` nas duas chamadas ao `token_endpoint` (troca inicial e
renovação via refresh_token), lido de `OAuthConfig.googleClientSecret`.

**Ajuste de segurança no meio do caminho**: a primeira tentativa colocou o secret como literal em
`oauth_config.dart` — o `git push` foi bloqueado pelo classificador de segurança do Claude Code
(corretamente: este repositório é público no GitHub, e GOCSPX- é um padrão que scanners
automáticos de segredo detectam; commitar em texto puro o exporia permanentemente no histórico,
não só no bundle compilado). Corrigido para `String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET')`
— o valor entra via `--dart-define` no comando de build do Cloudflare Pages, configurado como
variável de ambiente no próprio painel do Cloudflare, nunca commitado.

**Trade-off aceito conscientemente, documentado no código**: como o app não tem backend, esse
secret ainda acaba visível no bundle JS público depois de compilado (visível a qualquer um que
inspecionar o `main.dart.js`) — não é um "segredo" de verdade neste contexto de SPA, mas pelo
menos não fica em texto puro no histórico do git de um repo público. Mitigado também por: (1) escopo
mínimo `drive.file` (só arquivos criados pelo próprio app, nunca o Drive inteiro do usuário); (2)
PKCE — o secret sozinho não basta, precisa também do `code` de autorização (de uso único, expira
em minutos) e do `code_verifier` correto, que nunca saem do navegador de quem fez o login; (3) app
OAuth em modo "Testing", com o próprio usuário como único test user cadastrado — ninguém mais
consegue completar o fluxo de autorização mesmo tendo o secret. Alternativa mais correta
(proxy server-side para a troca de token, mantendo o secret fora do navegador) foi considerada e
descartada por ora — decisão explícita do usuário de priorizar a rota mais rápida para um app
pessoal de um usuário só; documentado aqui para reconsiderar se o app for publicado para mais
gente no futuro.

**Confirmado ao vivo em 2026-09-22**: login "Continuar com Google" completa de ponta a ponta com
o `client_secret` novo — account chooser, aviso de app não verificado, tela de consentimento,
redirect de volta pra `/importar-lattes` sem erro. Fluxo OAuth do Google Drive desbloqueado.

## Módulo 2 redesenhado: comprovante por entrada do Lattes, sem LLM (2026-09-22)

Discussão de UX com o usuário (ver transcript da sessão) mudou o desenho do Módulo 2 por completo.
O desenho antigo (`certificate_capture/**`) capturava certificados avulsos e usava LLM pra tentar
*adivinhar* título/instituição/data e depois a qual critério do edital cada um pertencia
(heurística de similaridade no Módulo 4). Decisão do usuário: inverter a lógica — **cada entrada
do currículo Lattes já importado (Módulo 1) precisa ter um botão de upload do lado dela**, sem
LLM (título/instituição/data já vêm do XML, não tem nada pra extrair de novo) e sem heurística de
vínculo (o vínculo já nasce certo, porque o botão está na própria entrada). O cruzamento com um
edital específico (Módulo 4, quais entradas contam pra quais critérios) fica pra depois, como
etapa separada que vai selecionar dentro dessa biblioteca de comprovantes já completa — **fora de
escopo nesta rodada**, por instrução explícita ("vamos fazer primeiro esse módulo 2 antes de
seguir para o próximo").

**Achado bloqueante na exploração**: `CurriculoLattes` (currículo importado no Módulo 1) não era
persistido em lugar nenhum — `LattesImportController` era um `Notifier` cujo estado vivia só em
memória, perdido a cada reload de aba. Inofensivo enquanto o Módulo 1 era "importar e olhar uma
vez", mas inviabilizava o novo Módulo 2 (anexar comprovante a 50-100+ entradas é tarefa de vários
dias). Corrigido com `CurriculoLocalStore` novo (`lattes_parser/data/local/`), que persiste o
currículo inteiro em Hive (chave fixa, só existe um currículo por usuário) — `importarArquivo` e
`confirmarVinculo` salvam a cada mudança, `build()` carrega o persistido antes de cair na tela de
"selecionar XML".

**Identidade estável das entradas**: nenhuma entidade do Lattes (`Curso`, `Publicacao` etc.) tem
id — todas são `Equatable` por valor. Preciso de um id estável pra guardar "esta entrada tem
comprovante" e sobreviver a reimportações do mesmo XML. Solução: hash sha256 (truncado, via
`package:crypto`, já dependência do projeto) sobre os campos que identificam cada entrada dentro
da sua categoria, prefixado pelo nome da categoria pra evitar colisão cross-categoria — ver
`gerarIdEntrada`/`gerarEntradasLattes`, `comprovantes/domain/entities/entrada_lattes_ref.dart` e
`mapear_entradas_lattes.dart`. **Limitação aceita conscientemente**: se o usuário editar um campo
identificador da entrada no Lattes oficial e reexportar, o id derivado muda e o comprovante antigo
fica "órfão" — não é perdido (fica numa seção separada "Comprovantes sem entrada correspondente"
na tela), só desvinculado, até o usuário decidir manualmente o que fazer com ele. Fuzzy-matching
pra tentar re-ligar automaticamente foi considerado e descartado por complexidade desproporcional
ao problema.

Nova feature `comprovantes/` (domain/data/presentation, mesmo padrão Clean Architecture do resto
do projeto) — `ComprovanteRepository`/`ComprovanteLocalStore` seguem exatamente o padrão de boxes
Hive separadas (metadados + bytes) já usado em `CertificateLocalStore`. MVP: 1 arquivo por
entrada (troca a chave do Hive de `entradaId` pra `entradaId#índice` se precisar de mais de um no
futuro). Sem câmera ao vivo nesta rodada — só botão de upload de arquivo, que foi literalmente o
que o usuário pediu; fácil de adicionar depois reaproveitando `cameraServiceProvider` se fizer
falta.

**Fora de escopo, deliberado**: Módulo 3 (sync Drive) e Módulo 4 (dossiê/edital) continuam
operando sobre `CertificadoCapturado`/`StatusCertificado` do Módulo 2 antigo, sem nenhuma mudança
— não ficam quebrados, só desconectados da nova tela. O código do Módulo 2 antigo não foi
removido, só ficou inalcançável pela navegação principal (o botão que ia pra
`AppRoutes.capturarCertificados` agora vai pra `AppRoutes.comprovantes`; a rota antiga continua
existindo). Decidir se remove de vez ou reaproveita fica pra quando entrarmos no Módulo 3/4.

Testado como texto (sem SDK Flutter neste ambiente, mesma limitação de toda a sessão) — testes
novos cobrem a geração de id (determinismo, sem colisão cross-categoria, sensibilidade a mudança
de campo) e o repositório de comprovantes (anexar, substituir, HEIC, remover, listar). Sem teste
de round-trip do `CurriculoLocalStore` em si — o projeto não testa nenhum local store Hive
diretamente (só via mock na camada de repositório), mesmo padrão mantido aqui.

## Múltiplos comprovantes por entrada (2026-09-30)

Testado ao vivo pela primeira vez (importação real de um XML do Lattes com dados reais do
usuário) — o módulo funcionou de ponta a ponta: todas as 8 categorias apareceram na ordem
certa, com contagem e botão de upload por item. Nesse teste o usuário pediu uma mudança:
**precisa poder anexar mais de um arquivo por entrada** (ex.: diploma + histórico do mesmo
curso) — o MVP original (1 arquivo por entrada, substituindo o anterior) já estava documentado
como limitação deliberada com essa extensão prevista.

Mudança: `ComprovanteEntrada` ganhou `id` próprio (gerado via `Uuid`, mesmo pacote já usado em
`certificate_repository_impl.dart`) — antes a chave de persistência era `entradaId` (só cabia
um por entrada); agora é `id`, e `entradaId` vira uma chave estrangeira que se repete entre
vários comprovantes da mesma entrada. `ComprovanteLocalStore`/`ComprovanteRepository.listarTodos`
passam a devolver uma lista achatada (não mais um `Map<entradaId, ComprovanteEntrada>`) — quem
precisa agrupar por entrada (a tela) faz isso na camada de apresentação, não na de dados.
`anexar()` nunca mais substitui: cada chamada cria um registro novo. `remover()` agora recebe o
id do comprovante específico, não o da entrada (senão não daria pra remover só um dos vários).

UI: cada entrada mostra o botão de upload sempre disponível (não trocava mais entre
"anexar"/"substituir"), e abaixo dele a lista dos arquivos já anexados, cada um com seu próprio
baixar/remover. Achado de teste ao vivo, não de revisão de código — mesmo padrão de correção
"acha na prática, corrige na hora" desta sessão.

## Seções recolhíveis, progresso geral e reimportação do XML (2026-09-30)

Mais achados do mesmo teste ao vivo, pela razão que o usuário deu: "não vai ser possível pra
alguém entrar com todos os certificados de uma vez" — um currículo real tem 30-40+ entradas
espalhadas por 8 categorias, preenchidas aos poucos, em várias sessões. Três ajustes:

1. Cada seção de categoria virou um `ExpansionTile` (recolhível), aberta por padrão, com
   contagem "X de Y com comprovante" no subtítulo — deixa de ser uma parede de itens expandidos
   o tempo todo.
2. Cabeçalho fixo no topo da tela com o progresso geral ("X de Y entradas com comprovante,
   Z%") + barra de progresso. Isto é o mesmo recurso que eu tinha proposto no desenho original
   e o usuário cortou por escopo na época — voltou a fazer sentido depois de ver a tela real com
   quase 40 entradas.
3. Botão na AppBar de Comprovantes pra voltar direto pra tela de importação do Lattes
   (`AppRoutes.importarLattes`), de onde dá pra reimportar um XML atualizado (botão "Importar
   outro XML" já existia lá, só não tinha como chegar nele a partir da tela de comprovantes).
   Reimportar já atualiza as entradas e preserva os comprovantes já anexados pelas entradas que
   não mudaram (via id estável) — as que mudaram/sumiram viram órfãs, mecanismo que já existia
   desde o desenho original.

## Conectar o Módulo 3 (sync com o Drive) ao módulo de comprovantes (2026-09-30)

Usuário perguntou onde os comprovantes anexados estavam sendo salvos no Drive — resposta real:
em lugar nenhum. O módulo novo (comprovantes) só gravava localmente; a sincronização com o Drive
(Módulo 3) existia e funcionava (testada ao vivo, OAuth corrigido nesta sessão), mas foi escrita
pro módulo antigo (`CertificadoCapturado`), desconectado desde o redesenho do Módulo 2. Decisão
do usuário: conectar os dois agora, em vez de deixar pra quando entrar no Módulo 3 formalmente.

Toda a mecânica de upload resumível (chunking, backoff, retomada de sessão — a parte com mais
bugs já corrigidos nesta sessão) é genérica, sem acoplamento nenhum a `CertificadoCapturado`. Só
precisou generalizar o que carregava esse acoplamento pelo NOME:

1. **`UploadTask.certificadoId` virou `UploadTask.referenciaId`** — sempre foi usado só como
   chave opaca (a fila nunca interpreta o valor). Os dois módulos agora compartilham a MESMA
   fila/box do Hive em vez de duplicar toda a lógica de retry — `subpastaNome` (só preenchido
   pelo módulo de comprovantes) separa as tarefas de cada módulo dentro da fila compartilhada:
   `CloudSyncController._retomarPendentes` (antigo) filtra `subpastaNome == null`,
   `ComprovantesSyncController._retomarPendentes` (novo) filtra o oposto — sem isso, os dois
   controllers tentariam retomar as tarefas um do outro. `UploadQueueLocalStore` lê o nome de
   campo antigo (`certificadoId`) como fallback ao desserializar, pra não perder nenhuma tarefa
   que já estivesse na fila antes desta mudança.

2. **Organização no Drive, respondendo "confirma que estão organizados"**: uma subpasta por
   categoria dentro da pasta dedicada (`Certificados Lattes/Formação acadêmica/`, `Certificados
   Lattes/Idiomas/` etc.) — `GoogleDriveDatasource.criarPastaSeNaoExistir` ganhou `pastaPaiId`
   opcional (query da Drive API passa a filtrar `'pastaPaiId' in parents`), e
   `CloudStorageRepositoryImpl._pastaId` ganhou um segundo cache (`_subpastaIdCache`, por nome de
   categoria) além do cache da pasta raiz que já existia. Nome do arquivo no Drive: nome original
   do upload (sanitizado, sem extensão) + hash curto do próprio comprovante — não repete a
   categoria no nome do arquivo porque ela já é o nome da subpasta.

3. **Status de sincronização por comprovante**: `ComprovanteEntrada` ganhou
   `statusSincronizacao`/`idArquivoCloud`/`mensagemErroSincronizacao` + `copyWith` (mesmo padrão
   de `StatusCertificado`, só sem os status intermediários de extração que não existem mais
   neste módulo). `ComprovanteLocalStore` lê `naoSincronizado` como fallback pra comprovantes
   gravados antes desses campos existirem (os anexados no teste ao vivo anterior a esta mudança).

4. **Novo orquestrador** `ComprovantesSyncController` (`cloud_sync/presentation/providers/
   comprovantes_sync_providers.dart` — fica em `cloud_sync`, não em `comprovantes`, mesmo papel
   cross-feature que `CloudSyncController` já tinha) espelha o antigo método a método:
   retomada automática de pendentes ao abrir a tela, `sincronizarTodos`/`retentarUm`.

**Decisão confirmada com o usuário**: disparo manual (ícone "sincronizar" na AppBar que envia
tudo pendente de uma vez), não automático por arquivo — evita 1 round-trip de rede por anexo
quando o usuário sobe vários de uma vez sem querer esperar a rede a cada clique.

UI: ícone de sincronizar na AppBar (habilitado só quando há algo pendente), e cada linha de
anexo ganhou um indicador de nuvem (cinza = não sincronizado, spinner = enviando, check verde =
sincronizado, vermelho = falha — toca pra tentar de novo só aquele arquivo).

**Fora de escopo, deliberado**: Módulo 4 continua sem tocar (ainda lê só `CertificadoCapturado`
sincronizado). Testes novos cobrem `criarPastaSeNaoExistir` com `pastaPaiId`, cache de subpasta
por categoria em `CloudStorageRepositoryImpl`, e `ComprovanteRepositoryImpl.
atualizarStatusSincronizacao`.

## Bug ao vivo: tela de Comprovantes renderizando quebrada depois do deploy da sync (2026-09-30)

Depois do deploy da integração acima, `/comprovantes` carregou com vários elementos
invisíveis (ícones da AppBar, subtítulo/chevron do `ExpansionTile`, cabeçalho de progresso) —
confirmado por zoom em pixel, não só baixo contraste. Investigação descartou, nessa ordem:
service worker/cache desatualizado (`sw.js` desregistrado, cache limpo, sem efeito); deploy
desatualizado (ETag do `main.dart.js` já tinha mudado); corrupção de dado (inspeção ingênua do
IndexedDB via `JSON.stringify` mostrou 3 registros como `{}`, mas isso é enganoso — o Hive CE
grava valores como `ArrayBuffer` binário, não JSON puro; só confirmável checando `instanceof
ArrayBuffer`).

**Causa real**: `ComprovantesController._carregarComprovantes()` não tinha try/catch. Havia 3
registros de teste gravados numa sessão anterior, de antes da mudança que deu a cada
`ComprovanteEntrada` seu próprio `id` — ao desserializar, `mapa['id'] as String` estourava em
cima de um valor `null`. Como essa chamada é fire-and-forget (disparada dentro de `build()`,
convenção já estabelecida no projeto), a exceção não tratada virava uma `Future` rejeitada sem
ninguém ouvindo — e isso bastou pra derrubar a renderização de widgets *irmãos* não relacionados,
consistente com o comportamento do Flutter de isolar erros por elemento (a subárvore afetada vira
um `ErrorWidget` quase invisível em release, sem crashar o resto da árvore).

**Fix**: try/catch adicionado nos 4 métodos fire-and-forget que ainda não tinham — mesmo padrão
usado pra tudo mais no projeto que roda dentro de `build()`:
`ComprovantesController._carregarComprovantes`, e em `ComprovantesSyncController`:
`_retomarPendentes`, `sincronizarTodos`, `retentarUm`. Falhas agora aparecem no
`MaterialBanner` de erro já existente na tela, em vez de sumirem silenciosamente. Os 3 registros
de teste (confirmados como lixo de um teste anterior, não dado real do usuário) foram limpos
direto via IndexedDB (`store.clear()` em `comprovantes_metadata`/`comprovantes_bytes`).

**Lição pro projeto**: toda chamada fire-and-forget disparada de dentro de `build()` precisa de
try/catch — não é só estilo, é o que evita que uma falha em UM controller quebre a renderização
de partes não relacionadas da tela. Vale revisar os outros controllers do projeto com o mesmo
padrão (`build()` chamando método async sem `await`) se aparecer outro bug de renderização
parecido.

## Teste ao vivo confirmado: sincronização de comprovantes com o Drive (2026-09-30)

Depois do fix acima, testado de ponta a ponta com os 2 arquivos já anexados (diploma + histórico
de "Licenciatura em Matemática"): clique no ícone de sincronizar da AppBar, e os dois passaram de
"não sincronizado" pra "sincronizado" (ícone `cloud_done_outlined` azul), confirmado por reload
da página. Conferido também diretamente no Google Drive: os dois PDFs apareceram em
`Certificados Lattes/Formação acadêmica/`, com nome determinístico
(`Diploma_-LICENCIATURA-EM-MATEMATICA-<hash>.pdf` e `Historico_-...-<hash>.pdf`). Organização por
subpasta funcionando exatamente como desenhado. A integração do Módulo 3 com o módulo de
comprovantes está confirmada funcionando ao vivo, não só revisada como texto.

## Botão de voltar em todas as telas internas (2026-09-30)

Usuário apontou um problema real: o app não tinha botão de voltar em lugar nenhum. Causa: a
navegação inteira usa `context.go()` (substitui a rota atual, não empilha — ver comentário em
`app_router.dart` sobre por que rotas de URL real foram escolhidas desde o início), então o
`Navigator` nunca acumula uma pilha de verdade — o botão de voltar automático do `AppBar`
(que só aparece quando `Navigator.canPop()` é verdadeiro) nunca apareceria sozinho.

Fix: novo `VoltarAppBarButton` (`core/routing/voltar_app_bar_button.dart`), um `IconButton`
reutilizável que recebe `rotaPai` (a rota lógica de origem daquela tela, não histórico de
navegador) e chama `context.go(rotaPai)`. Adicionado como `leading` do `AppBar` em todas as
telas internas, mapeado pelo fluxo real de navegação (quem tem um `context.go()` apontando pra
cada uma): Comprovantes → `/importar-lattes`, Configurar LLM → `/importar-lattes`, Capturar
certificados → `/importar-lattes`, Montar dossiê → `/certificados`, Revisar dossiê →
`/dossie/novo`, Compilar dossiê → `/dossie/:id/checklist` (único caso com rota dinâmica, não
`const`). `/importar-lattes` (home pós-login) e `/login`/`/oauth/callback` não recebem — são
pontos de entrada, sem "pai" lógico.

Testado ao vivo: os 4 casos com rota-pai estática (Comprovantes, Configurar LLM, Capturar
certificados, Montar dossiê) confirmados navegando corretamente. Os 2 casos do checklist/compilar
de dossiê não foram testados ao vivo (exigiriam montar um dossiê completo só pra isso) — mesmo
padrão de widget já confirmado funcionando nos outros 4, revisado como texto.

## Melhorias de UX/UI pesquisadas antes de implementar (2026-09-30)

Usuário pediu uma "melhorada de UX/UI baseada em práticas de mercado", mas com uma instrução
explícita e marcada como muito importante: pesquisar e avaliar opções ANTES de implementar
qualquer coisa. Pesquisa feita (Material Design 3, padrões de listas longas/busca, indicadores de
progresso, upload de arquivo) e confirmada contra o código real do app antes de virar opção —
achados genéricos descartados quando não bateram com o estado atual (ex.: Material 3 já estava
habilitado em `main.dart`, então não virou opção). Três lacunas confirmadas viraram opções
apresentadas ao usuário, que escolheu as três:

1. **Busca na lista de Comprovantes**: listas com mais de ~20-30 itens se beneficiam de uma caixa
   de busca no topo em vez de só depender de scroll/seções recolhíveis — a lista real do usuário
   tem 40 entradas em 8 categorias. Decisão explícita do usuário sobre o comportamento: as 8
   seções continuam SEMPRE visíveis durante a busca (não somem se não tiverem resultado), só os
   itens dentro de cada uma são filtrados — diferente do padrão mais comum de "esconder grupo sem
   resultado" que a pesquisa também trouxe como opção, mas que o usuário não escolheu.

2. **Progresso textual na sincronização**: pesquisa mostrou que rótulos de texto ("Enviando 2 de
   5 arquivos") tranquilizam mais que um spinner silencioso, sobretudo em conexões lentas.
   `ComprovantesSyncState` ganhou `enviados`/`totalParaSincronizar`, populados só por
   `sincronizarTodos()` (a fila manual, a única longa o suficiente pra o rótulo valer a pena — a
   retomada automática e o retry de um único arquivo continuam só com spinner).

3. **Avisos de tipo/tamanho no upload**: conferido no código (`comprovante_upload_datasource.dart`)
   que o seletor nativo já filtra por extensão, mas a tela nunca dizia isso, e não existia limite
   de tamanho nenhum. Tooltip do botão de anexar agora lista os formatos aceitos, e um limite real
   de 15MB foi adicionado em `ComprovantesController.selecionarEAnexar` (antes inexistente —
   um arquivo gigante entrava sem aviso nenhum).

**Fora de escopo por enquanto**: dark mode, navegação tipo "stepper"/breadcrumb entre os módulos,
preview de arquivo antes do upload — não pesquisados a fundo ainda porque o usuário não os
priorizou nesta rodada (ver pergunta feita com opções antes de implementar).

**Testado ao vivo**: busca confirmada (filtra "Matemática" corretamente, categorias sem resultado
mostram "Nenhuma entrada desta categoria corresponde à busca." em vez de sumir, exatamente como
pedido); tooltip do botão de anexar confirmado ("Anexar comprovante — JPG, PNG, HEIC, WEBP ou PDF,
até 15MB"); sincronização de 4 arquivos novos confirmada funcionando (todos passaram para
"sincronizado"), mas o texto de progresso "Enviando X de Y" não foi capturado visualmente — com
poucos arquivos pequenos e rede rápida, o processo terminou rápido demais entre o clique e a
próxima screenshot. Lógica revisada como código, consistente com o padrão já confirmado em outros
indicadores de status desta mesma tela.

## Códigos de convite de uso único + página de administração (2026-09-30)

Usuário pediu: controlar quem consegue entrar no app, exigindo um código de convite de uso único
pra criar acesso, com uma página só dele pra gerar/gerenciar esses códigos. Decidido em modo de
planejamento (`EnterPlanMode`), com duas perguntas explícitas ao usuário antes de escrever
qualquer código, dado o tamanho da mudança — ver raciocínio completo abaixo.

**Isto é o primeiro backend compartilhado do projeto.** Até aqui o app era inteiramente estático:
Google OAuth direto do navegador (PKCE, sem servidor) + Firebase Auth só pra autenticação
(login por e-mail/senha), nenhum banco de dados compartilhado — documentado deliberadamente assim
desde o início (`auth_providers.dart`: "Não existe conta própria do app com backend
compartilhado"). Códigos de uso único de verdade (não reaproveitáveis, geridos remotamente) exigem
um banco compartilhado — usado o Firestore do mesmo projeto Firebase que já existia
(`certificados-lattes`), sem introduzir nenhum provedor novo.

### Decisões confirmadas com o usuário

1. **As duas portas de entrada precisam do código** — tanto "Continuar com Google" quanto "Criar
   conta" por e-mail/senha. O usuário escolheu isso sabendo que a porta Google é mais fraca de
   proteger (ver próximo ponto).
2. **Gate do login Google: versão simples e gratuita, sem Cloud Function.** O login Google é um
   fluxo OAuth PKCE que não passa pelo Firebase Auth — então o Firestore não tem como confirmar
   criptograficamente QUE e-mail está de fato resgatando um código (`request.auth` fica nulo pra
   esse fluxo). A alternativa robusta (Cloud Function verificando o `id_token` no servidor)
   exigiria colocar o projeto Firebase no plano pago Blaze e montar uma pipeline de deploy nova
   (Node.js/Firebase CLI) inexistente hoje. O usuário aceitou a versão sem Cloud Function.
   **Mitigação aplicada nas regras do Firestore, mais forte do que a apresentada originalmente na
   pergunta**: a criação de `acessos_autorizados/{email}` (o registro que libera o Google sem
   pedir código de novo) só é permitida se já existir um `codigos/{algumCodigo}` com `usado: true`
   e `usadoPara` batendo com esse e-mail exato — e a ÚNICA forma de um código virar `usado: true`
   é a transição controlada (`usado:false -> true`, mais nada), que exige o código existir e
   ainda não ter sido usado. Ou seja: a brecha real ficou bem mais estreita do que "qualquer um
   pode se auto-autorizar sem código nenhum" — sobra só "alguém que JÁ tem um código válido e não
   usado em mãos pode resgatá-lo sob um e-mail arbitrário, sem prova de que aquele e-mail é
   mesmo dele" (o código em si continua sendo o controle real de acesso). Ver `firestore.rules`
   pro texto completo e comentado.
3. **Admin = izialber@gmail.com, via conta de e-mail/senha DEDICADA no Firebase** — não a sessão
   Google normal do resto do app. Necessário pela mesma razão do ponto 2: só uma sessão Firebase
   Auth dá ao Firestore uma identidade verificável (`request.auth.token.email`) pras regras
   confiarem. A conta admin precisa ser criada manualmente no Firebase Console (não pelo
   formulário de "Criar conta" do próprio app) — senão vira um problema do ovo e da galinha
   (criar conta exige código, e não existe nenhum código até o admin existir).

### O que foi implementado

- **Novo módulo `lib/features/access_control/`** (Clean Architecture, mesmo padrão do resto do
  projeto): `CodigoAcesso` (entidade), `CodigoAcessoRepository`/`Impl` (Firestore direto, sem
  camada de use case — cada método já é uma operação atômica sem lógica de negócio adicional, um
  wrapper seria só passthrough), `AccessCodeFailure` (nova em `core/error/failures.dart`).
  `resgatarCodigo` usa `FirebaseFirestore.runTransaction` — garante que dois resgates simultâneos
  do mesmo código não passem os dois.
- **Fluxo e-mail/senha** (`login_page.dart` + `AuthController.criarContaComEmailSenha`): novo
  campo "Código de convite", só visível em modo "Criar conta". Ordem: resgata o código PRIMEIRO,
  só then cria a conta no Firebase — se a criação falhar depois (e-mail já em uso, senha fraca),
  o código já foi queimado; aceito, admin gera outro.
- **Fluxo Google**: o `id_token` que o Google já devolvia na troca de code por token (escopo já
  pedia `openid email`) era descartado — passou a ser usado. `OauthPkceDatasource.
  confirmarEmailDoIdToken` chama `GET https://oauth2.googleapis.com/tokeninfo` (endpoint público
  do próprio Google, mesmo domínio já liberado na CSP) em vez de só decodificar o JWT sem checar.
  E-mail persistido em `SecureStorageKeys.googleEmail` — `AuthController.build()` reusa esse
  valor salvo a cada abertura do app (a renovação via `refresh_token` não devolve `id_token`
  novo). Novo estado `AuthPendenteCodigo(email)`; nova rota pública `/login/codigo`
  (`CodigoPendentePage`) — única tela alcançável nesse estado, com campo de código e botão "Sair"
  pra tentar outra conta Google.
- **Página de admin** (`/admin/codigos`, `AdminCodigosPage`): gate PRÓPRIO contra
  `FirebaseAuth.instance.currentUser?.email == AdminConfig.email`, independente do `AuthState`
  geral do app (pela razão do ponto 3 acima) — mostra um mini-login e-mail/senha se a sessão
  Firebase atual não for a do admin. Lista códigos (status, rótulo, criado em, usado por/em),
  botão "Gerar código" (rótulo opcional) e revogar (só não-usados). Ícone de atalho (`Icons.
  admin_panel_settings_outlined`) na AppBar de `/importar-lattes`, visível só quando
  `AuthState.email == AdminConfig.email` (reaproveita o e-mail agora disponível também pro login
  Google, ver acima) — não aparece pra ninguém mais.
- `web/index.html`: CSP ganhou `firestore.googleapis.com` em `connect-src` — mesmo padrão de
  problema silencioso já visto com as outras chamadas do Firebase nesta sessão (erro de rede
  genérico, não CORS explícito, se esquecido).

**Fora de escopo, deliberado**: revogar um código já usado (não faz sentido — a pessoa já tem
acesso); expiração automática de códigos; testes automatizados desta feature (`AuthController`/
`CodigoAcessoRepositoryImpl` — camada de controller de presentation já não tem testes em nenhum
outro módulo do projeto, e mockar `cloud_firestore` exigiria uma dependência nova
`fake_cloud_firestore` só pra isso; revisado como texto, mesma limitação de sempre sem SDK
Flutter neste ambiente).

### Passos manuais pendentes (fora do alcance desta sessão — sem Firebase CLI/credenciais aqui)

Antes disto funcionar de ponta a ponta, no Firebase Console do projeto `certificados-lattes`:
1. Ativar o Cloud Firestore (modo nativo, escolher região).
2. Colar o conteúdo de `firestore.rules` (raiz do repo) na aba Rules — ou `firebase deploy
   --only firestore:rules` se tiver a CLI instalada localmente (`firebase.json`/`.firebaserc`
   já versionados, prontos pra isso).
3. Criar manualmente a conta admin em Authentication → Users → Add user (izialber@gmail.com +
   senha à escolha) — pelo problema do ovo e da galinha explicado no ponto 3 acima.

**Testado ao vivo de ponta a ponta, com sucesso, depois dos 3 passos manuais**: Firestore ativado
em `southamerica-east1`, regras publicadas via editor do Console (colado via clipboard, não
digitado — o editor duplica chaves/parênteses em auto-fechamento se digitado caractere a
caractere), conta admin já existia de um teste anterior desta mesma sessão. Depois do bug de
roteamento abaixo corrigido: login de admin confirmado, geração de código confirmada
(`4UF9YBFR`, rótulo "teste ao vivo"), e o resgate completo confirmado direto no Firestore —
`codigos/4UF9YBFR` virou `usado: true`, `usadoPara: "teste-codigo-convite@example.com"` depois de
uma conta de teste ser criada com esse código pelo formulário "Criar conta". Ciclo completo
validado: admin gera código → usuário resgata → conta criada → código não pode ser reusado.

## Bug achado ao vivo: /admin/codigos bloqueada pelo gate do login Google (2026-09-30)

Depois dos 3 passos manuais (Firestore ativado, regras publicadas, conta admin já existia de um
teste anterior), primeiro teste ao vivo de `/admin/codigos` falhou: caía direto em
`/login/codigo` em vez de mostrar o formulário de login do admin. Causa: o `redirect` do router
checava `AuthPendenteCodigo` (sessão Google sem código resgatado) e forçava `/login/codigo` de
forma incondicional, sem saber que `/admin/codigos` tem seu PRÓPRIO gate via Firebase Auth,
independente do login Google do resto do app (ver seção acima). Mesmo problema, de um jeito
menor, pro caso de ninguém logado: `/admin/codigos` não estava em `_rotaPublica`, então o router
também expulsava pra `/login` um visitante sem sessão nenhuma antes de ele ver o formulário.

**Fix**: `/admin/codigos` entrou em `_rotaPublica` (o router nunca a bloqueia por conta do
`AuthState` geral) + exceção explícita no branch de `AuthPendenteCodigo` pra não capturar essa
rota. Correto ela ser "pública" do ponto de vista do router — a proteção de verdade continua
sendo o gate interno da própria página (Firebase Auth) e as regras do Firestore, exatamente como
já era o design original, só que o router estava atrapalhando antes de a página ter a chance de
se proteger sozinha.

## Bug achado ao vivo: Formação complementar misturada com Formação acadêmica (2026-09-30)

Usuário reportou, testando a importação de um XML real: "a formação acadêmica titulação está
junta com formação complementar e deveria estar separado". Confirmado no código:
`LattesXmlParser._parseCursos` já lê as duas seções do XML corretamente como coisas diferentes
(`FORMACAO-ACADEMICA-TITULACAO` em `DADOS-GERAIS` vs. `FORMACAO-COMPLEMENTAR-CURSO-DE-CURTA-
DURACAO` em `DADOS-COMPLEMENTARES`), mas achatava as duas no mesmo campo `CurriculoLattes.
cursos` (distinguidas só pelo `Curso.nivel == NivelCurso.cursoCurta`) — e tanto
`CurriculoListView` (tela de importação) quanto `mapear_entradas_lattes.dart` (tela de
Comprovantes) tratavam esse campo como UMA seção só de "Formação acadêmica".

**Fix**: separado por `nivel` nos dois lugares que exibem/categorizam isso — `CurriculoListView`
ganhou uma segunda seção condicional "Formação complementar" (só aparece se não vazia, mesmo
padrão de Orientações/Produção técnica); `CategoriaEntradaLattes` ganhou um valor novo
`formacaoComplementar` (rótulo "Formação complementar", posicionado logo depois de `curso` na
declaração do enum — controla a ordem das seções recolhíveis em Comprovantes e vira subpasta
própria no Drive automaticamente, sem mudança adicional). `mapear_entradas_lattes.dart` agora
itera `curriculo.cursos` duas vezes, filtrando por `nivel`, cada uma gerando o id pela sua
categoria final correta.

**Efeito colateral aceito**: como o id de cada entrada é um hash que inclui a categoria (ver
`gerarIdEntrada`), qualquer comprovante já anexado a um curso de curta duração ANTES deste fix
fica "órfão" na próxima reimportação do XML (mecanismo que já existia, mesmo padrão de qualquer
mudança de campo identificador — o arquivo não se perde, só desvincula e aparece na seção de
órfãos). Baixo risco: a feature de comprovantes é recente nesta mesma sessão, pouco tempo de uso
real antes do fix.

Teste novo cobrindo a separação em `entrada_lattes_ref_test.dart` (domínio puro, sem depender de
SDK Flutter). Ainda não testado ao vivo com um XML real.

## Discriminar técnico/graduação/pós lato sensu/pós stricto sensu (2026-09-30)

Pedido do usuário, continuação natural do bug acima: dentro de "Formação acadêmica", técnico,
graduação, pós-graduação lato sensu (especialização) e pós-graduação stricto sensu (mestrado/
doutorado/pós-doutorado) são coisas diferentes pra uma Prova de Títulos, e estavam todas juntas
numa seção só.

`NivelCurso` ganhou o valor `tecnico`. `CategoriaEntradaLattes.curso` teve seu SIGNIFICADO restrito
(passa a valer só pra graduação; rótulo mudou de "Formação acadêmica" para "Graduação") mas o NOME
do valor do enum foi mantido de propósito — `gerarIdEntrada` usa `categoria.name` como parte do
hash do id, então manter o nome evita orfanizar comprovantes já anexados a entradas de graduação
(só especialização/mestrado/doutorado, que migram pra categorias novas, ficam órfãos na próxima
reimportação — mesmo trade-off já aceito no bug anterior). Duas categorias novas:
`posLatoSensu`/`posStrictoSensu`. `_categoriaDoCurso` (`mapear_entradas_lattes.dart`) centraliza o
mapeamento `NivelCurso` → `CategoriaEntradaLattes` num switch exaustivo, usado tanto pra gerar o id
quanto a categoria de cada entrada; `curriculo_list_view.dart` espelha a mesma classificação.

**Pergunta feita ao usuário antes de implementar**: curso técnico aparece hoje em algum lugar do
app (mal categorizado) ou não aparece em lugar nenhum? Resposta: não aparece em lugar nenhum —
confirma que o parser nunca leu essa seção do XML. **Risco assumido, não confirmado contra XML
real**: a tag adicionada em `_tagsNivelFormacao`
(`ENSINO-MEDIO-E-TECNICO-PROFISSIONALIZANTE`) é a melhor hipótese pro schema do CNPq, mas —
diferente de toda outra tag desta lista, todas já confirmadas contra XML real do usuário — essa
não foi. Se não aparecer nenhuma entrada em "Técnico" ao reimportar um XML que deveria ter curso
técnico, essa tag é a primeira coisa a revisar (comentário deixado no código apontando isso).

Ainda não testado ao vivo.

## Conectar o Módulo 4 (Montar Dossiê) ao módulo de Comprovantes (2026-10-02)

Investigação + plano feitos em modo de planejamento (`EnterPlanMode`, com um agent de exploração
mapeando toda a dependência antes de desenhar a mudança). O Módulo 4 (montar o dossiê de Prova de
Títulos) estava inteiramente construído sobre o módulo antigo de captura de certificados
(`CertificadoCapturado`), desconectado da navegação desde o redesenho do Módulo 2 — ou seja, a
tela de "Montar dossiê" não enxergava os comprovantes reais do fluxo principal, e nem era
alcançável pela UI (só existia um link pra `/dossie/novo` dentro de `/certificados`, também
órfã).

Achado que simplificou a migração: as entidades do `dossie_builder`
(`Dossie`/`VinculoAprovado`/`VinculoSugeridoDossie`) já guardavam `certificadoId` como `String`
solta, nunca tipada em `CertificadoCapturado` — só a assinatura de `DossieRepository.
sugerirVinculos` (e a implementação, que lê bytes/metadados direto de um local store) precisaram
mudar de verdade. Renomeado pra `comprovanteId` por clareza (mesmo padrão já usado pra
`UploadTask.certificadoId` → `referenciaId`).

Diferença de forma real entre os dois modelos: `CertificadoCapturado` tinha `tituloExtraido`/
`instituicaoExtraida` (extraídos por LLM), que é o que a heurística de matching (interseção de
palavras contra a descrição de cada critério do edital, limiar 0.15 — algoritmo em si não mudou)
lia. `ComprovanteEntrada` não tem nada equivalente — é só um arquivo anexado, sem extração
nenhuma. O texto de match passou a vir de `EntradaLattesRef` (título + subtítulo), resolvida via
`ComprovanteEntrada.entradaId` — que não é persistida, é recalculada a cada carregamento a partir
do `CurriculoLattes` (`gerarEntradasLattes`, mesmo padrão já usado em `ComprovantesController`).
Por isso `sugerirVinculos` e `compilarDossieFinal` passaram a receber a lista de entradas junto
dos comprovantes, não só uma lista sozinha como antes. Comprovante órfão (entrada removida numa
reimportação do Lattes) usa o nome do arquivo como texto de match/título no sumário do PDF, em
vez de ficar de fora — mesma filosofia de "nunca perder o arquivo de vista" já praticada em
outros lugares do projeto.

A migração não filtra por categoria em nenhum ponto — comprovantes de qualquer uma das 12
categorias (técnico, graduação, pós lato/stricto sensu, formação complementar, experiência
profissional, publicação, orientação, produção técnica, participação em evento, projeto de
pesquisa, idioma) entram igual na sugestão de vínculo contra os critérios do edital.

**Navegação**: `/dossie/novo` era inatingível pela UI antes desta mudança (só alcançável a partir
de `/certificados`, módulo desconectado) — corrigido com um novo ícone "Montar dossiê" na AppBar
de Comprovantes. `dossie_new_page.dart` trocou sua rota-pai de `/certificados` pra `/comprovantes`.

**Revisão de código** (fork dedicado, leitura completa de todos os arquivos tocados + referências
cruzadas): só um achado de severidade baixa, PRÉ-EXISTENTE (não introduzido por esta migração) —
`dossie_local_store.dart`'s `_dossieDaMapa` não tem try/catch ao redor do cast de
`comprovanteId`, então um dado corrompido lançaria uma exceção não tratada em
`carregarChecklist`. O código original já tinha exatamente esse mesmo risco (sem fallback
nenhum); esta migração só adicionou um fallback mais seguro (`?? v['certificadoId']`), não
piorou nada. Fica registrado como possível follow-up, fora de escopo desta mudança.

Testes reescritos em `dossie_repository_impl_test.dart` (grupos `sugerirVinculos` e
`compilarDossieFinal`, fixtures viram `ComprovanteEntrada`/`EntradaLattesRef`, mock troca de
`MockCertificateLocalStore` pra `MockComprovanteLocalStore`) + 2 casos novos cobrindo
comprovante órfão (um em cada grupo). `certificate_capture` continua no repo, intocado — só
deixou de ser a fonte de dados do Módulo 4.

Ainda não testado ao vivo.

## Terceiro provedor de LLM: Anthropic (Claude Haiku) (2026-10-02)

Motivado por um erro real ao vivo: chave do Gemini configurada, mas a API respondeu "This model
is currently experiencing high demand" (pico transitório do lado do Google). Usuário pediu uma
opção adicional de provedor BYOK pra não ficar refém de um único provedor sob alta demanda.

`LlmProviderEscolhido` ganhou `claudeHaiku`; os dois pontos que antes usavam ternário binário
(`provider == geminiFlash ? x : y`) em `LlmApiKeyStore`/`LlmRepositoryImpl` viraram `switch`
exaustivo — o compilador agora obriga tratar os 3 casos se um quarto provedor for adicionado no
futuro. Novo `AnthropicLlmDatasource` segue o mesmo contrato dos outros dois
(`gerarJson({apiKey, prompt, imagemBytes?, mimeType?})`), API Messages
(`api.anthropic.com/v1/messages`), autenticação via header `x-api-key` +
`anthropic-version: 2023-06-01` + `anthropic-dangerous-direct-browser-access: true` (sem esse
último header a Anthropic bloqueia chamada direta do navegador por padrão — mesmo padrão de "CORS
silencioso" já visto com outras integrações). Diferente da OpenAI, a Anthropic lê PDF nativamente
(bloco `document`, igual ao Gemini) — sem a limitação de "só imagem" que `OpenAiLlmDatasource`
tem.

**Revisão de código pega um bug real antes do deploy**: o ID do modelo usado inicialmente
(`claude-haiku-4-5-20251001`, com sufixo de data) quebraria toda chamada com 404 — IDs de modelo
da Anthropic são completos como estão, sem sufixo de data (confirmado contra a skill de
referência oficial da API Claude). Corrigido para `claude-haiku-4-5`. Também corrigida a ordem do
bloco de conteúdo (documento/imagem antes do texto do prompt — ordem recomendada pela
documentação da Anthropic pra blocos `document`, afeta qualidade da extração).

CSP (`web/index.html`) ganhou `api.anthropic.com` em `connect-src` — mesmo cuidado de sempre
nesta sessão (esquecer isso produz erro de rede genérico, não um erro CORS explícito).

Anthropic não tem um "modo JSON" nativo equivalente a `responseMimeType`/`response_format` dos
outros dois provedores — confia só no prompt pedindo JSON + no parser já tolerante a cercas
markdown (`decodificarJsonDoModelo`, compartilhado pelos 3 datasources). Funciona, mas é a única
das três integrações sem essa garantia adicional — fica registrado como possível melhoria futura
(a Anthropic tem um recurso de structured outputs mais novo, não investigado a fundo ainda).

Teste novo em `llm_repository_impl_test.dart` cobrindo o novo provedor, mesmo padrão do teste já
existente pra OpenAI. **Testado ao vivo (UI)**: terceira opção "Claude Haiku" aparece
corretamente no seletor, com instruções específicas (`console.anthropic.com/settings/keys`).
Ainda falta testar a chamada real à API (depende de uma chave de API da Anthropic do usuário).
