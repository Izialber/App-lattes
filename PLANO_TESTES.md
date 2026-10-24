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

A `main` local e o GitHub estão iguais (`2a59769`). Não há nada pendente de commit.

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

### 2. [ ] Fallback do anexo em lote sem IA — Claude faz
- Em Configurações, escolher um provedor **sem chave salva** (ex.: GPT-4o mini), sem salvar
  nada. Se a troca exigir salvar, pular este item e anotar.
- Repetir o lote com os 10 arquivos do teste de 2026-10-24 (lista no `DECISOES.md`).
- **Esperado:** aviso "confira com mais atenção" e sugestões feitas pelo nome do arquivo.
- Ao final, voltar o provedor para **Groq**.

### 3. [ ] Dossiê com o edital INTEIRO via Gemini — precisa de você
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

## Trabalho de código pendente (não é teste — pedir à parte)

- **Compilação em partes** (`EstrategiaMesclagemDossie.emPartes`) para dossiês grandes demais
  para a memória. Viável agora com a mesma técnica do Syncfusion de `PdfMergeDatasource`.
- **Sumário sem travessão**: a fonte padrão (Helvetica/WinAnsi) não tem "—". Trocar o caractere
  ou embutir uma fonte TTF.
- **Groq extrai poucos critérios**: talvez melhorar o prompt de `LlmEditalDatasource`, ou deixar
  a Groq só para editais curtos.
- **Limpeza**: apagar as branches `backup-main-2026-10-24` e `publicar-sem-lote` (e a worktree
  temporária dela, se ainda existir; `git worktree prune`).

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
