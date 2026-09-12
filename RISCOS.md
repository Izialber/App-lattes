# Riscos — Certificados Lattes

## 1. Custo de API (LLM)

O modelo é BYOK: o custo recai diretamente sobre o cartão/conta do usuário, não sobre um
orçamento centralizado do app. Riscos: (a) usuário não entende o custo por chamada e é
surpreendido pela fatura do provedor; (b) um loop de retry mal configurado na extração de
certificado pode multiplicar chamadas em caso de resposta fora do schema esperado.
Mitigação: exibir estimativa de custo por certificado/edital na tela de configuração de chave
(usando os preços públicos do provedor escolhido, atualizados periodicamente); limitar retries
de parsing de resposta LLM a no máximo 2 tentativas antes de pedir revisão manual.

## 2. Privacidade e LGPD

Documentos acadêmicos (diplomas, certificados, currículo Lattes) são dado pessoal, e em alguns
casos dado pessoal sensível (ex.: se um certificado mencionar necessidade de acessibilidade).
Riscos: (a) os bytes da imagem passam por um serviço de terceiro (LLM) sobre o qual o app não
tem controle de retenção; (b) o app não tem base legal própria para tratamento — o usuário é
o próprio controlador dos seus dados, mas a UX precisa deixar isso claro. Mitigação: tela de
consentimento explícita antes do primeiro envio a qualquer LLM, informando qual provedor
processa a imagem e linkando a política de privacidade dele; nenhum dado do usuário é
armazenado em infraestrutura própria do app (tudo fica no Drive/OneDrive dele); adicionar um
aviso permanente e não descartável na tela de configuração de BYOK.

## 3. Quota do Google Drive e Microsoft Graph

Ambas as APIs têm limites de taxa (requests/100s/usuário) e cota de armazenamento é a do
próprio usuário. Riscos: (a) upload em lote de muitos certificados de uma vez pode esbarrar em
rate limit e gerar uma onda de falhas simultâneas na fila; (b) usuário com Drive/OneDrive
cheio recebe erro de quota que pode ser confundido com falha do app. Mitigação: enviar a fila
com concorrência limitada (ex.: no máximo 2-3 uploads simultâneos) e backoff exponencial já
previsto (`package:retry`); mapear especificamente o erro HTTP 507/quota-exceeded para uma
mensagem clara ("seu Google Drive está cheio"), não uma falha genérica. Ver também item 9
(cota compartilhada por aplicativo, não só por usuário).

## 4. Memória no Safari iOS (e regulagem por RAM real no Android)

O risco central do projeto. Abas do Safari iOS são recicladas pelo sistema sob pressão de
memória sem aviso ao JavaScript em execução — o processo simplesmente reinicia. Riscos:
(a) merge de PDF do dossiê com muitos certificados de alta resolução estoura o teto antes que
o app consiga detectar; (b) o usuário perde a sessão inteira se o estado não estiver
persistido em disco (IndexedDB) a cada passo.

Mitigação, atualizada por decisão do usuário (ver DECISOES.md item 6): o teto de memória não
é mais uma única constante para todo o web.
- **iOS**: constante fixa de 350MB (revisada para baixo em relação à versão anterior deste
  documento, ~380MB) — o WebKit não expõe nenhuma API de memória do dispositivo, e todo
  navegador em iOS roda sobre WebKit por baixo, então o valor vale para "iOS" como um todo.
- **Android (Chrome/Chromium)**: `TaskRunnerWeb` lê `navigator.deviceMemory` (Device Memory
  API) e calcula o teto como 25% da RAM total relatada do aparelho, dentro de um piso
  (~220MB) e um teto (~1.5GB) absolutos — um Android com 8GB de RAM tem uma folga bem maior
  que um Android de entrada com 2GB, em vez de os dois levarem o mesmo teto conservador do
  iOS.
- **Estratégia de 3 níveis** (`DecidirEstrategiaDeMemoria`, com testes unitários): quando o
  dossiê inteiro não cabe de uma vez, o app tenta processar EM PARTES (lotes sequenciais,
  cada um virando um PDF intermediário antes da mesclagem final) em vez de já orientar o
  usuário a trocar de dispositivo. A degradação explícita (pedir para concluir no desktop) só
  acontece no caso residual em que nem o maior certificado isolado cabe no teto do
  dispositivo atual — nenhum tamanho de lote resolveria isso de qualquer forma.
- Independente da estratégia escolhida, todo estado de fluxo (fila, vínculos, dossiê em
  montagem, incluindo `loteAtual`/`totalDeLotes` durante a compilação em partes) é persistido
  em Hive/IndexedDB a cada mudança, nunca só em memória do provider Riverpod, para sobreviver
  a um recarregamento forçado pelo sistema.

Risco residual não eliminado: a fração de 25% usada no cálculo do Android e o tamanho de
lote (`TaskRunner.batchSizeBytesHint`, hoje 60% do teto) são valores iniciais conservadores,
não validados com dispositivos reais nem com o tamanho médio real de um PDF de certificado
digitalizado — ambos listados como pendência de calibração em DECISOES.md.

## 5. CORS nas chamadas ao LLM e ao cloud

Chamadas diretas do navegador para APIs de terceiros dependem da política de CORS de cada
provedor, que pode mudar sem aviso. Riscos: (a) a API da OpenAI é historicamente mais
restritiva para chamadas client-side do que a do Gemini — um bloqueio de CORS não aparece como
erro de negócio, aparece como falha de rede genérica difícil de diagnosticar para o usuário;
(b) Google Drive API e Microsoft Graph também aplicam CORS, mas são mais permissivos para
tokens OAuth de aplicações registradas corretamente. Mitigação: Gemini Flash como provedor
LLM padrão (CORS mais permissivo, ver DECISOES.md item 4); mensagem de erro específica quando
a falha tem assinatura de bloqueio de CORS (status 0 / `TypeError: Failed to fetch`),
orientando o usuário a tentar o outro provedor BYOK; documentar no ROADMAP_MOBILE.md que um
proxy serverless resolve isso de forma definitiva quando o projeto justificar o custo de
manter backend.

## 6. Perda de storage local (iOS)

Safari aplica ITP (Intelligent Tracking Prevention): dados de IndexedDB de um site não
instalado como PWA na tela de início podem ser apagados após 7 dias de inatividade. Riscos:
(a) usuário que só usa o app pelo navegador (sem instalar) perde tokens OAuth, chave BYOK e
fila de upload pendente sem aviso; (b) perda silenciosa é pior do que erro visível — o usuário
pode achar que os certificados foram enviados quando na verdade a fila foi apagada antes de
processar. Mitigação: banner permanente (não descartável de forma definitiva, só "lembrar
depois") pedindo para instalar o PWA na tela de início quando detectado Safari iOS sem modo
standalone; ao detectar que a fila de upload local está vazia mas havia sido populada
recentemente (heurística: existe um `lastKnownQueueSize` em um storage mais duradouro, como um
cookie de longa duração, maior que zero), avisar explicitamente "parte do seu progresso pode
ter sido perdida pelo navegador" em vez de assumir silenciosamente que está tudo enviado.

## 7. Upload iOS com nome/mimetype genéricos e HEIC

Já coberto em parte no módulo de captura: o Safari iOS pode reportar arquivos HEIC com
mimetype/extensão de JPEG. Risco adicional: se a conversão HEIC→JPEG falhar silenciosamente
(ex.: o navegador não conseguiu decodificar), a imagem "convertida" na verdade seria um HEIC
renomeado, e o LLM receberia um arquivo que não consegue interpretar, gerando erro confuso de
extração. Mitigação: verificar magic bytes ANTES e DEPOIS da tentativa de conversão (nunca
confiar em "a função rodou sem erro" como prova de sucesso); se a verificação pós-conversão
falhar, pedir explicitamente ao usuário para exportar a foto como JPEG pelo app Fotos do iOS
antes de tentar de novo, em vez de enviar HEIC ao LLM.

## 8. Risco de reprovação do dossiê pela banca

Risco de produto, não só técnico: editais não têm padronização, e uma interpretação
incorreta dos critérios de pontuação pelo LLM (ex.: confundir "máximo 2 títulos de mestrado"
com "máximo 2 títulos no total") pode levar a um dossiê que a banca rejeita, com consequência
real para o usuário em um concurso público. Mitigação: human-in-the-loop é obrigatório e não
contornável na arquitetura (não existe caminho de código de sugestão → compilação sem
checklist aprovado); a tela de checklist exibe o texto original extraído ao lado da
interpretação do LLM, para que o usuário compare com o edital fonte; incluir, na v1, um aviso
textual fixo na tela de compilação final: "Revise pessoalmente os critérios de pontuação no
edital original antes de enviar — a extração automática é um auxílio, não uma garantia."

## 9. Escala multiusuário: cota e verificação do app OAuth em produção

O app é multiusuário desde a concepção (qualquer pessoa loga com a própria conta e usa o
próprio Drive/OneDrive — decisão confirmada em 2026-09-12, embora já fosse o design original;
um terceiro provedor, iCloud Drive, chegou a ser avaliado nessa mesma data e foi descartado
pelo usuário — ver DECISOES.md). Riscos específicos de operar isso em produção, não cobertos
pelo item 3 (que trata da cota de ARMAZENAMENTO de cada usuário): (a) a cota de REQUISIÇÕES da Google
Drive API e do Microsoft Graph é por projeto/aplicativo registrado, compartilhada entre TODOS
os usuários do app — um app com muitos usuários simultâneos pode esgotar essa cota mesmo que
cada usuário individualmente esteja bem abaixo do próprio limite de armazenamento; (b) apps
Google OAuth em "modo de teste" ficam limitados a ~100 usuários listados manualmente — sem
publicar o app como "Externo/Produção" (o que pode exigir passar pelo processo de verificação
do Google para o escopo do Drive), o app trava para qualquer pessoa fora dessa lista;
(c) o(s) redirect URI(s) cadastrados no Google Cloud Console/Azure AD precisam corresponder
exatamente à URL final de produção (ex.: `https://izialber.com.br/certificados-lattes/`), então
esse cadastro só pode ser finalizado depois que o domínio de produção estiver definido.
Mitigação: solicitar aumento de cota de API preventivamente ao Google/Microsoft assim que
houver uma estimativa de usuários simultâneos; publicar os dois apps OAuth como "Externo" desde
o primeiro deploy de produção, mesmo com poucos usuários, para não precisar migrar depois;
monitorar erro HTTP 429/quota-exceeded no nível do app (não só por usuário) para diferenciar
"este usuário estourou o próprio limite" de "o app inteiro estourou a cota compartilhada".
