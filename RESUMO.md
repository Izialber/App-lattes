**Quarto provedor de LLM: Groq (gratuito, sem cartão de crédito)** — pedido do usuário logo
após o Anthropic. API compatível com a OpenAI, mesma limitação de não ler PDF. Modelo
`qwen/qwen3.8-27b` confirmado contra documentação oficial (único da Groq com suporte a imagem
hoje). Ainda não testado ao vivo.

**Terceiro provedor de LLM: Anthropic (Claude Haiku)** — motivado por um erro real ao vivo
(Gemini sob alta demanda, "This model is currently experiencing high demand"). BYOK, mesmo padrão
dos outros dois provedores, lê PDF nativamente (diferente da OpenAI). Revisão de código pegou um
bug real antes do deploy: ID do modelo com sufixo de data indevido, que quebraria toda chamada
com 404 — corrigido. Ainda não testado ao vivo com uma chave real.

**Módulo 4 (Montar Dossiê) conectado ao módulo de Comprovantes** — até aqui o Módulo 4
dependia inteiramente do módulo antigo de certificados, desconectado da navegação desde o
redesenho do Módulo 2 — a tela de "Montar dossiê" não enxergava os comprovantes reais, e nem era
alcançável pela UI. A heurística de match (interseção de palavras contra os critérios do edital)
não mudou — só passou a ler o texto de título/instituição da entrada do currículo ligada ao
comprovante (`ComprovanteEntrada` não tem extração por LLM como o módulo antigo tinha). Novo
ícone "Montar dossiê" na tela de Comprovantes fecha um buraco de navegação que já existia antes
desta mudança. Ainda não testado ao vivo.

**Botão de voltar adicionado em todas as telas internas** — o app navegava só com
`context.go()` (substitui a rota, não empilha), então o Navigator nunca tinha uma pilha real de
voltar. Novo `VoltarAppBarButton` reutilizável, apontando pra rota-pai lógica de cada tela (ex.:
Comprovantes → Importar currículo). Testado ao vivo em 4 das 6 telas (as 2 restantes usam o
mesmo padrão, sem teste ao vivo por exigirem montar um dossiê completo).

**Três melhorias de UX/UI, pesquisadas (Material Design 3, padrões de mercado) e confirmadas
contra o código antes de implementar, por instrução explícita do usuário**: busca por
nome/instituição na tela de Comprovantes (mantendo as 8 seções sempre visíveis, só filtrando
itens dentro — decisão explícita do usuário); rótulo textual "Enviando X de Y arquivos..." durante
a sincronização manual, em vez de só um spinner; e avisos de formato/tamanho no botão de anexar,
com um limite real de 15MB que antes não existia.

**Códigos de convite de uso único + página de administração — primeiro backend compartilhado do
projeto.** Usuário quis controlar quem consegue entrar no app: as duas portas de login (Google e
e-mail/senha) agora exigem um código de convite de uso único, gerido numa página de admin nova
(`/admin/codigos`, acesso só pra izialber@gmail.com via uma conta Firebase dedicada). Usa o
Firestore do mesmo projeto Firebase já existente — decisão tomada em modo de planejamento, com
perguntas explícitas ao usuário sobre escopo (as duas portas ou só uma) e nível de segurança
aceito pro lado Google (que não passa pelo Firebase Auth, então não dá pra verificar
criptograficamente a identidade sem uma Cloud Function paga — o usuário aceitou a versão simples
e gratuita). As regras do Firestore fecham a maior parte dessa brecha mesmo assim: só é possível
"lembrar" um e-mail Google como autorizado se ele já tiver resgatado de verdade um código válido
e não usado antes (ver DECISOES.md para o raciocínio completo). **Ainda não testado ao vivo**:
depende de 3 passos manuais no Firebase Console (ativar Firestore, publicar as regras de
`firestore.rules`, criar a conta admin) que ficam fora do alcance desta sessão sem Firebase
CLI/credenciais — documentados passo a passo no DECISOES.md.

**Bug achado ao vivo ao testar a importação de um XML real**: "Formação complementar" (cursos de
curta duração) aparecia misturada dentro da seção "Formação acadêmica" — o parser já lia as duas
seções certo do XML, só a exibição/categorização achatava as duas juntas. Corrigido: vira seção
própria (tela de importação e de Comprovantes), com subpasta própria no Drive automaticamente.

**Formação acadêmica discriminada em técnico/graduação/pós lato sensu/pós stricto sensu** —
pedido de continuação do achado acima. Técnico é uma seção nova que nunca existiu antes (o parser
não lia essa parte do XML) — a tag usada (`ENSINO-MEDIO-E-TECNICO-PROFISSIONALIZANTE`) é a melhor
hipótese pro schema, mas ainda NÃO confirmada contra um XML real, diferente de todo o resto do
parser. Ainda não testado ao vivo.

# Resumo da entrega (Módulos 1-4 têm implementação real; nenhum testado ao vivo ainda)

**Login "Continuar com Google" testado ao vivo pela primeira vez, e confirmado funcionando** —
encontrou um bug real (o Google exige `client_secret` na troca de token mesmo com PKCE, pra
Client ID tipo "Aplicativo da Web"), corrigido, e reconfirmado de ponta a ponta depois do deploy
(ver DECISOES.md). O fluxo OAuth do Google Drive, bloqueado desde o início do projeto, está
desbloqueado.

**Módulo 2 foi redesenhado do zero**, por decisão do usuário depois de discutir a UX: em vez de
capturar certificados soltos e usar LLM pra tentar adivinhar a qual entrada do currículo cada um
pertence, agora **cada entrada do currículo Lattes importado (Módulo 1) já tem seu próprio botão
de upload ao lado** — sem LLM (título/instituição/data já vêm do XML), sem heurística de vínculo
(o vínculo nasce certo, porque o botão está na própria entrada). Nova feature `comprovantes/`,
nova tela em `/comprovantes`. Pré-requisito descoberto no caminho: o currículo importado não era
persistido nenhum lugar (reload de aba perdia tudo) — corrigido com `CurriculoLocalStore` novo.
Como as entidades do Lattes não têm id, um id estável é derivado por hash dos campos que
identificam cada entrada — ver DECISOES.md para a limitação aceita (edição de um campo
identificador no Lattes oficial "orfaniza" o comprovante antigo, que fica visível numa seção
separada em vez de sumir). O Módulo 2 antigo (captura solta + LLM) continua no repositório, só
desconectado da navegação principal.

**Testado ao vivo com um XML real do usuário e confirmado funcionando de ponta a ponta** — todas
as 8 categorias, na ordem certa, com botão de upload por item. Achado no teste ao vivo: uma
entrada pode precisar de mais de um arquivo (ex.: diploma + histórico do mesmo curso) — o MVP de
"1 arquivo por entrada" foi estendido para múltiplos: cada comprovante ganhou id próprio (a chave
de persistência deixou de ser `entradaId`), `anexar()` nunca mais substitui, e a tela mostra a
lista de arquivos já anexados por entrada, cada um com seu baixar/remover.

Ainda no mesmo teste ao vivo: seções da tela de Comprovantes viraram recolhíveis (currículo real
tem 30-40+ entradas, ninguém preenche tudo de uma vez), ganhou um cabeçalho com % de conclusão
geral, e um botão na AppBar pra voltar e reimportar um XML atualizado do Lattes.

**Módulo 3 (sync com o Drive) conectado ao módulo de comprovantes, e testado ao vivo com
sucesso** — até aqui os comprovantes só ficavam salvos localmente, sem backup nenhum (achado ao
usuário perguntar onde estava indo pro Drive). Toda a mecânica de upload resumível já existente
(chunking, backoff, retomada de sessão) é reaproveitada sem duplicar — só generalizada
(`UploadTask.certificadoId` virou `referenciaId`, um campo opaco que os dois módulos compartilham
na mesma fila). Organização no Drive: uma subpasta por categoria dentro da pasta dedicada
(`Certificados Lattes/Formação acadêmica/`, `Certificados Lattes/Idiomas/` etc.). Ícone de
sincronizar na AppBar (disparo manual, por decisão do usuário) + indicador de status (nuvem
cinza/spinner/check/erro) em cada arquivo já anexado, com retry individual em caso de falha. No
caminho, um bug real foi achado e corrigido ao vivo: chamadas fire-and-forget sem try/catch
dentro de `build()` podiam derrubar silenciosamente a renderização de partes não relacionadas da
tela (achado com 3 registros de teste de schema antigo) — ver DECISOES.md. Teste ao vivo final:
2 arquivos sincronizados e conferidos direto no Google Drive, na subpasta certa, com nome
determinístico.

**LLM compartilhado (`llm_shared`) também ficou real** (usado pelo Módulo 2 antigo e pelo Módulo
4 — o Módulo 2 novo, descrito acima, não usa LLM nenhum): `GeminiLlmDatasource` e
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

140 testes unitários no total (119 anteriores + 16 do módulo de comprovantes + 5 da conexão com
o Drive: cache de subpasta por categoria, status de sincronização por comprovante).

Sem SDK Flutter neste ambiente — nada foi compilado; tudo revisado como texto.
