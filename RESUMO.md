# Resumo da entrega (atualizado após o Módulo 2 ficar funcional)

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

77 testes unitários no total (35 anteriores + 42 novos): parsing/tolerância de JSON de modelo,
detecção de HEIC por magic bytes, `LlmRepositoryImpl` (resolução de provedor + tradução de erro),
`LlmExtractionDatasource` (validação de chaves obrigatórias, carregamento real do prompt-asset),
`CertificateRepositoryImpl` (os 5 métodos do repositório, incluindo os 3 casos de
`normalizarFormatoImagem` e o pipeline completo de `extrairDados`) e `LlmSettingsController`
(carregamento do provedor salvo, troca de provedor, salvar-só-após-testar-com-sucesso).

Módulos 3-4 continuam com a camada de dados em stub — não fizeram parte desta rodada.

Sem SDK Flutter neste ambiente — nada foi compilado; tudo revisado como texto.
