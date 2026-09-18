# Resumo da entrega (atualizado após o Módulo 3 sair do stub)

**Módulo 2 (Captura de Certificados) agora está funcional de ponta a ponta no navegador**,
igual ao que já valia para o Módulo 1: seleção de imagens (`file_picker`, multi-seleção) ->
registro local (Hive/IndexedDB, sobrevive a reload de aba) -> normalização de formato (detecção
de HEIC por magic bytes + conversão via `<canvas>`) -> compressão (`package:image`, via
`TaskRunner`) -> extração de dados via LLM (Gemini/OpenAI, BYOK) -> tela de lista com status por
certificado e "tentar novamente" para falhas de extração. Câmera ao vivo (`getUserMedia`) está
implementada em `CameraServiceWeb` mas ainda sem widget de preview ligado na tela — pendência da
próxima rodada (upload continua sendo o caminho principal, inclusive no mobile, onde o seletor de
arquivo já abre a câmera/galeria nativa do aparelho).

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
resumível implementado como PUT único (PDFs de certificado são pequenos o bastante), mas já
segue o protocolo completo do Google (trata 308 Resume Incomplete, permite retomar sessão após
reload) — chunking de verdade fica fácil de adicionar depois sem mudar a interface. Botão de
sincronizar na tela de captura, com retomada automática de tarefas pendentes ao abrir a tela.
Nada disto foi testado ao vivo — depende do login OAuth do Google, que continua bloqueado (ver
DECISOES.md).

96 testes unitários no total (77 anteriores + 19 novos): os anteriores mais
`CloudStorageRepositoryImpl` (pasta dedicada, upload com sucesso/retomada/erro transitório vs.
permanente, OneDrive fora de escopo) e `PdfBuilderDatasource` (passthrough de PDF de origem).

Módulo 4 (montador de dossiê) continua com a camada de dados em stub.

Sem SDK Flutter neste ambiente — nada foi compilado; tudo revisado como texto.
