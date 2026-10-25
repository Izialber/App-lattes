# Plano de testes — próxima sessão

Escrito em 2026-10-24 para retomar os testes numa sessão nova. Para começar, basta dizer
**"segue o PLANO_TESTES.md"**. O Claude lê este arquivo e começa pelo primeiro item ainda
pendente. Marque cada item com `[x]` quando terminar.

## Onde o projeto está (2026-10-24)

Testado ao vivo e funcionando (detalhes em `DECISOES.md`, entradas de 2026-10-24):

- Login Google com código de convite, aba "Usuários" do admin.
- Sincronização com o Drive: 29 comprovantes, sem pasta duplicada.
- Montar Dossiê de ponta a ponta com a Groq e o Anexo IV do edital. O PDF final inclui os
  comprovantes em PDF.
- Anexar vários de uma vez com "Escolher arquivos": 10 de 10 arquivos classificados certo.
- Suíte de testes: 180 passando.

Ao fim da sessão de 2026-10-24, tudo foi commitado. Se o push final não tiver sido feito, a
`main` local estará 2 commits à frente do GitHub (este plano e a correção do travessão). Nesse
caso, o primeiro passo é `git push origin main`, que também publica o site.

## Antes de começar (o Claude faz)

1. `git status` e `git log --oneline -3`. Conferir se a `main` ainda bate com `origin/main`.
2. Abrir o app no **Claude in Chrome**, não no painel do navegador do app. O painel não consegue
   escolher arquivos; o Chrome consegue (ver "Truques" abaixo).
3. Antes de qualquer teste ao vivo depois de um deploy, desregistrar o service worker e limpar o
   cache de arquivos. Senão o Chrome continua rodando a versão antiga:
   ```js
   for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();
   for (const k of await caches.keys()) await caches.delete(k);
   ```
   Isso não apaga o currículo nem os comprovantes, que ficam no IndexedDB.

## Testes, em ordem

### 1. [ ] "Escolher uma pasta" no anexo em lote — **você faz, manual**
A automação não preenche seletor de pasta.
- Comprovantes → "Anexar vários" → "Escolher uma pasta (computador)" → escolher
  `Downloads/Diplomas - Certificados`.
- **Esperado:**
  - aviso dos formatos não aceitos (`.msg`, `.docx`, `.xlsx`);
  - os ~29 já anexados aparecem em "Descartados" como duplicata;
  - os sem entrada no Lattes vão para "Sem entrada";
  - nada é anexado sem você confirmar.
- Bom teste de volume: a pasta tem uns 100 arquivos, o que dá 2 lotes de chamadas à Groq.
  Se a Groq estourar o limite, o app deve cair na heurística local e mostrar um aviso.
- Diga ao Claude o que apareceu. Ele registra no `DECISOES.md`.

### 2. [x] Fallback do anexo em lote sem IA — junto com o item 3 ou 4
Verificado em 2026-10-24: só selecionar a aba de outro provedor em Configurações NÃO troca o
provedor ativo. Ele só muda ao "Salvar e testar conexão" com uma chave válida. Então não dá
para forçar a falha da IA sem uma chave.
- **Quando fazer:** logo depois de salvar a chave do Gemini ou da Anthropic (itens 3 e 4). Antes,
  revogar ou trocar essa chave no site do provedor por uma inválida, ou testar sem rede (modo
  avião depois de abrir a tela de revisão não serve: a sugestão roda ao escolher os arquivos).
  Alternativa mais simples: um lote de ~100 arquivos com a Groq pode estourar o limite por
  minuto no 2º lote. O item 1 já cobre isso.
- **Esperado:** aviso "confira com mais atenção" com a mensagem real do provedor, e sugestões
  feitas pelo nome do arquivo.
- Ao final, deixar o provedor que você escolher ativo.

### 3. [x] Dossiê com o edital INTEIRO via Gemini — precisa de você
- **Você:** pegar uma chave em https://aistudio.google.com/apikey, colar em Configurações →
  Gemini Flash → "Salvar e testar conexão". O Claude não digita chaves.
- **Claude:** Montar dossiê → enviar
  `~/Downloads/edital_4.2026_professor_substituto_2026_versao_consolidada_-_10-04.pdf`.
  O arquivo precisa ser copiado antes para uma pasta que a sessão pode ler, porque o upload do
  Chrome recusa a raiz de Downloads.
- **Esperado:** os ~17 itens do Anexo IV (pág. 22) extraídos com os máximos certos. A Groq só
  trouxe 7, com máximos errados. Comparar com o texto da pág. 22.
- Depois: aprovar alguns vínculos com critério que faça sentido (ex.: as especializações em
  "Especialização 360 a 600h"), compilar e conferir o PDF (sumário e páginas).

### 4. [ ] Claude Haiku (Anthropic) com chave real — precisa de você
- **Você:** colar uma chave da Anthropic em Configurações → Claude Haiku → salvar e testar.
- **Claude:** repetir o dossiê com o Anexo IV e o edital inteiro. Comparar a qualidade com a
  Gemini e a Groq.
- Ao final, decidir com você qual provedor deixar ativo.

### 5. [ ] Login por e-mail e senha de um usuário comum — precisa de você no início
- **Você:** entrar em `/admin/codigos` com a senha de admin (redefinida em 2026-10-24).
- **Claude:** gerar um código, abrir uma janela anônima (ou deslogar) e criar uma conta de teste
  pelo "Criar conta" com esse código. Usar e-mail de teste do tipo `teste-...@example.com`.
- **Esperado:**
  - a conta entra;
  - aparece na aba "Usuários";
  - o código não pode ser reusado;
  - deslogar e logar de novo funciona;
  - a sessão de admin (app Firebase separado) não derruba a sessão comum, nem o contrário.

### 6. [ ] Celular (Safari iOS / Chrome Android) — **você faz, manual**
Requisito original do projeto e nunca testado ao vivo:
- login Google por redirect;
- anexar foto pela câmera (incluindo HEIC no iPhone);
- sincronizar com o Drive;
- compilar um dossiê pequeno.

Anote o que quebrar.

### 7. [ ] Completar os comprovantes que faltam — você decide
19 entradas ainda sem arquivo: experiências profissionais, produções, mestrado em andamento e
alguns eventos. Ou você indica os arquivos, ou as entradas ficam sem comprovante.

## Resultados de 2026-10-24 (noite)

- **Item 3 (Gemini, edital inteiro):** os 18 itens do Anexo IV vieram certos (pontos e
  quantidade máxima). Só falta o teto de 20 pts da experiência. Levou ~3 min. Dossiê com 5
  aprovados compilou: 21 págs., sumário com acentos certos. Dropdown com `initialValue` + key
  funcionou ao vivo.
- **Bug achado e corrigido (não publicado):** a sugestão de critério do dossiê usava `\W+`, que
  quebra palavras acentuadas ("magistério" casava com "Rio de Janeiro"). Agora usa
  `palavrasSignificativas`.
- **Item 2 (fallback):** com chave inválida, o aviso trouxe a mensagem real do Gemini e as
  sugestões vieram pelo nome. Chave original restaurada depois.
- **Bug achado e corrigido (não publicado):** no fallback, arquivo já anexado caía em "Sem
  entrada" em vez de "Descartados". Agora arquivo com nome já anexado vai direto para a entrada
  dele e não vai ao LLM.
- **Gemini lento:** `gemini-flash-latest` = `gemini-3.8-flash`. Uma pergunta trivial levou 81 s
  (só 253 tokens de raciocínio) e houve 503 "high demand". O gargalo é a capacidade do Google, não
  o raciocínio. O timeout de 90 s está no limite. Avaliar fixar um modelo mais estável ou aumentar
  o timeout. `thinkingLevel: minimal` dá 400 nesse modelo.
- O provedor ativo agora é o Gemini. Ele foi gravado direto no armazenamento, porque o "Salvar e
  testar" não tinha trocado o provedor. Investigar: na tela, trocar de aba também não mostra se
  aquele provedor já tem chave salva.

## Feito sem você em 2026-10-24 (noite), tudo publicado e testado

- **Sugestão de critério no dossiê** (acentos) e **lote com arquivo já anexado**: conferido ao
  vivo. "Mind The Sec" e "Autocad 3D" não recebem mais a sugestão de magistério.
- **Configurações**: mostra "Em uso agora: X", avisa se a aba escolhida já tem chave salva e
  oferece "Usar a chave salva do X" sem colar de novo. Testado ao vivo (Gemini → Groq → Gemini).
  Explica o mistério de antes: a chave do Gemini estava salva desde 2026-10-02, e o "Salvar e
  testar" de hoje provavelmente falhou por causa do 503 do Gemini, então nada foi gravado.
- **Gemini/Anthropic**: repetem até 3 vezes em 503/529 (alta demanda). O timeout de resposta
  passou de 90 s para 180 s.
- **Compilação em partes** implementada (ver DECISOES.md). Comparada com PDFs reais: mesmas 46
  páginas, mesmo texto e mesmo tamanho de página que a mesclagem direta. Não dá para forçar ao
  vivo no desktop.
- **Groq**: a causa de "poucos critérios" era o `gpt-oss-20b` gastar os 2048 tokens de saída
  raciocinando. Com `reasoning_effort: low` + 4096 tokens + prompt novo, extraiu **18 de 18**
  itens do Anexo IV ao vivo, em menos de 10 s, com todos os máximos certos (inclusive
  experiência máx. 16 e especialização >600h = 4 pts). O edital inteiro ainda passa do limite
  gratuito (8K tokens/min); a mensagem manda trocar para o Gemini, agora sem o "Bad state:" na
  frente.
- **Dropdown** (`initialValue` + key): retestado ao vivo, inclusive trocando uma sugestão que já
  vinha preenchida.

## Trabalho de código pendente (pedir à parte)

- **Limpeza**: apagar as branches `backup-main-2026-10-24` e `publicar-sem-lote` (e a worktree
  temporária dela, se ainda existir; `git worktree prune`). Precisa da sua confirmação.
- **Groq com edital inteiro**: mandar ao LLM só as páginas da tabela de pontuação. Teste rápido:
  exigir "pontuação" + "títulos" na mesma página seleciona 6 de 29 páginas (~22 mil caracteres),
  o que ainda passa do limite. Precisaria ordenar as páginas por densidade de "ponto(s)". Risco
  de perder critério descrito em texto corrido.
- **Progresso "lote X de Y"** na tela de compilação: o repositório já grava, mas a tela só recebe
  o estado no fim.
- **Teto de 20 pts por grupo** (experiência): o modelo `CriterioPontuacao` não tem limite por
  grupo, só por item.
- **Sugestão de critério por categoria do Lattes**: a heurística só compara palavras. Uma pós
  lato sensu poderia ir direto para "Especialização", e um artigo para "Publicação de artigo".

## Truques que funcionaram (para o Claude)

- **Upload de arquivo no app Flutter pelo Claude in Chrome**: antes de clicar no botão de
  upload, rodar no console
  ```js
  const orig = HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click = function () {
    if (this.type === 'file') { this.style.display = 'block'; if (!this.isConnected) document.body.appendChild(this); return; }
    return orig.call(this);
  };
  ```
  Depois clicar no botão do app, achar o `input type=file` com `find` e usar `file_upload`.
  Antes de cada novo upload, remover os inputs antigos
  (`document.querySelectorAll('input[type=file]').forEach(e => e.remove())`). Se a página
  recarregar, o patch some e precisa rodar de novo.
- **Pastas que o `file_upload` aceita**: as da sessão (projeto, `Downloads/Diplomas -
  Certificados` quando adicionada, scratchpad). A raiz de `Downloads` não é aceita: copie o
  arquivo antes.
- **Extrair só uma página de um PDF no Mac** (sem Python), com o PDFKit:
  ```swift
  import PDFKit
  let a = CommandLine.arguments  // swift extrair.swift entrada.pdf saida.pdf 22
  let doc = PDFDocument(url: URL(fileURLWithPath: a[1]))!, out = PDFDocument()
  for (j, p) in a[3].split(separator: ",").enumerated() { out.insert(doc.page(at: Int(p)! - 1)!, at: j) }
  out.write(to: URL(fileURLWithPath: a[2]))
  ```
- **Rodar os testes** (não dá num comando só):
  ```bash
  F=~/development/flutter/bin/flutter
  VMF=($(find test -name "*_test.dart" | grep -v -e certificate_upload_datasource_test -e llm_shared_providers_test | sort))
  $F test "${VMF[@]}"
  $F test --platform chrome test/features/certificate_capture/data/datasources/certificate_upload_datasource_test.dart test/features/llm_shared/presentation/providers/llm_shared_providers_test.dart
  ```
- **Deploy**: o push na `main` dispara o build no Cloudflare Pages, que fica no ar em ~2 min.
  Para saber quando, procurar no `main.dart.js` publicado uma string nova do código.
- **Conferir dados do app sem baixar nada**: o IndexedDB tem `comprovantes_metadata`,
  `dossie_pdf_final` etc. Os valores são Hive em binário; ler com `TextDecoder` e regex.
