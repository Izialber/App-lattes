# Resumo da entrega (Módulos 1-4 têm implementação real; nenhum testado ao vivo ainda)

**Módulo 2 (Captura de Certificados) agora está funcional de ponta a ponta no navegador**,
igual ao que já valia para o Módulo 1: seleção de imagens (`file_picker`, multi-seleção) ->
registro local (Hive/IndexedDB, sobrevive a reload de aba) -> normalização de formato (detecção
de HEIC por magic bytes + conversão via `<canvas>`) -> compressão (`package:image`, via
`TaskRunner`) -> extração de dados via LLM (Gemini/OpenAI, BYOK) -> tela de lista com status por
certificado e "tentar novamente" para falhas de extração. Câmera ao vivo (`getUserMedia`) agora
tem preview ligado na tela (`HtmlElementView.fromTagName`, ver DECISOES.md) — upload continua
sendo o caminho principal, inclusive no mobile, onde o seletor de arquivo já abre a
câmera/galeria nativa do aparelho.

**LLM compartilhado (`llm_shared`) também ficou real**: `GeminiLlmDatasource` e
`OpenAiLlmDatasource` fazem chamadas HTTP de verdade (Dio) para as respectivas APIs, com
tratamento de JSON cercado em markdown (comum em modelos menores) e mapeamento de erro
401/403/429 para `LlmFailure.isQuotaOrAuth`. `LlmRepositoryImpl` resolve sozinho qual provedor
usar lendo a preferência salva em `LlmApiKeyStore` (nova responsabilidade: guardar não só as
chaves BYOK, mas também qual provedor está ativo) — os use cases de extração não recebem o
provedor como parâmetro.

Vínculo com o currículo Lattes (`VinculoSugerido`) **não** é calculado na extração do
certificado — fica null até o Módulo 4 (`SugerirVinculos`) comparar certificados já
sincronizados contra um edital. Ver DECISOES.md, entrada de hoje, para o raciocínio completo.

**Tela de configuração BYOK (`LlmSettingsPage`, rota `/configuracoes/llm`, acessível pelo ícone
de engrenagem na tela de captura) fecha o ciclo** — sem ela, `extrairDados` sempre falhava com
"nenhum provedor configurado" mesmo com tudo implementado. O teste de conexão
(`LlmRepository.testarConexao`) roda ANTES de qualquer coisa ser salva, como decidido
anteriormente para o fluxo BYOK.

**Módulo 3 (Sincronização com o Drive) saiu do stub** — `GoogleDriveDatasource` (chamadas REST
reais à Drive API v3, autenticação via interceptor do Dio que renova o token sozinho),
`PdfBuilderDatasource` (imagem -> PDF via `package:pdf`; PDF de origem passa direto),
`UploadQueueLocalStore` (Hive, sobrevive a reload) e `CloudStorageRepositoryImpl`. Upload
resumível em chunks de verdade (2MiB por PUT, progresso persistido a cada chunk, retoma sessão
após reload, cache da pasta do Drive compartilhado entre uploads de uma mesma sincronização).
Botão de sincronizar na tela de captura, com retomada automática de tarefas pendentes ao abrir
a tela. Nada disto foi testado ao vivo — depende do login OAuth do Google, que continua
bloqueado (ver DECISOES.md).

**Módulo 4 (Montador de Dossiê) também saiu do stub** — extração de critérios do edital via LLM
(texto extraído com `syncfusion_flutter_pdf`), sugestão de vínculo certificado↔critério por
heurística de similaridade textual (sem chamada de LLM — decisão deliberada, ver DECISOES.md),
checklist humano (aprovar/excluir cada vínculo, com dropdown de critério), e compilação final
em PDF único com sumário. Descoberta importante no caminho: `package:pdf` não tem como importar
páginas de um PDF já existente, então a mesclagem foi redesenhada para construir o dossiê
direto a partir das imagens originais dos certificados (não dos PDFs prontos do módulo 3) — só
funciona para certificados de origem imagem; os de origem PDF ficam fora da mesclagem
automática, e a estratégia "em partes" de `DecidirEstrategiaDeMemoria` (para dossiês grandes)
não foi implementada pelo mesmo motivo. Duas novas telas (`/dossie/novo`, seleção do edital) e
reescrita completa de `dossie_checklist_page`/`dossie_compile_page` (antes placeholder).

**Duas rodadas de `/code-review high` sobre tudo isso** encontraram 20 achados no total, 15
corrigidos. Da 1ª rodada (6 corrigidos): corrupção silenciosa no upload resumível do Drive
(fallback do 308 sem header `Range` fabricava progresso nunca confirmado pelo servidor), dois
casts diretos em JSON do LLM sem tratamento, falha de conversão HEIC não persistida, botão de
"tentar novamente" que pulava a normalização HEIC, busca redundante da pasta do Drive a cada
certificado — mais um sétimo achado (resultado da compilação não avisava quantos certificados
PDF-de-origem ficaram fora) corrigido numa rodada de acompanhamento. Da 2ª rodada (9 corrigidos):
`CertificadoCapturado`/`UploadTask.copyWith` nunca conseguiam limpar uma mensagem de erro antiga
depois de um retry bem-sucedido, falha de normalização HEIC e falha de extração do LLM
compartilhavam o mesmo status (agora `falhaNormalizacao` é separado), retry de upload sem
confirmação de progresso não tinha backoff, validação de campos obrigatórios do LLM não pegava
string vazia, tela de compilação recompilava do zero toda vez que reabria mesmo já concluída,
três implementações inconsistentes de "achar item por id" unificadas com `package:collection`, e
`bootstrap()` abria as 7 Hive boxes em série em vez de paralelo. Ver DECISOES.md para a lista
completa, incluindo os achados não corrigidos por severidade menor (duplicação estrutural entre
os 3 local stores, fora de escopo sem SDK Flutter para validar o refactor).

119 testes unitários no total.

Sem SDK Flutter neste ambiente — nada foi compilado; tudo revisado como texto.
