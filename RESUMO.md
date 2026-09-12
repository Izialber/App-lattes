# Resumo da entrega (atualizado após decisões do usuário)

Base Flutter Web (PWA) feature-first + Clean Architecture completa, mais as 8 decisões
pendentes respondidas e aplicadas ao código nesta rodada (ver DECISOES.md para o detalhe de
cada uma). Três delas divergiram da recomendação padrão e mudaram arquitetura de fato:
escopo do parser (expandido), estratégia de memória (350MB iOS + `navigator.deviceMemory`
no Android + processamento em partes, em vez de um valor único) e prioridade (pausar a
ordem Android/iOS da Fase 2 para primeiro ter algo funcional no navegador).

**Módulo 1 (Parser Lattes) agora está funcional de ponta a ponta, não só o parser:**
seleção real de arquivo (`file_picker`, com fallback UTF-8/Latin-1), providers Riverpod
(`LattesImportController`), tela (`LattesImportPage`/`CurriculoListView`) exibindo currículo
completo — incluindo as novas seções de orientações e produção técnica — e o fluxo de
confirmação humana ("este vínculo ainda está ativo?") para vínculos ambíguos.

Parser expandido: além de formação/atuação/produção bibliográfica, agora cobre orientações
(concluídas e em andamento) e produção técnica (software, produto tecnológico). 26 testes
unitários no total (17 anteriores + 9 novos: orientações/produção técnica, confirmação de
vínculo, estratégia de memória).

Nova lógica de memória: `DecidirEstrategiaDeMemoria` (pura, testada) decide entre mesclagem
direta, em partes (lotes com PDFs intermediários) ou degradação explícita — a degradação só
acontece quando nem o maior certificado isolado cabe no dispositivo. `Dossie` ganhou
`compilandoEmPartes` + progresso de lote.

BYOK: `LlmRepository.testarConexao` adicionado ao contrato, para validar a chave no momento
em que o usuário a salva.

Módulos 2-4 continuam com a camada de dados em stub documentado — não fizeram parte do pedido
desta rodada. `DECISOES.md` termina com 3 novas pendências (Android vs. iOS ainda em aberto,
calibração da fração de RAM do Android, calibração do tamanho de lote).

Sem SDK Flutter neste ambiente — nada foi compilado; tudo revisado como texto.
