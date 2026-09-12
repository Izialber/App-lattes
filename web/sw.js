// Service worker com política de cache explícita (não o padrão gerado pelo
// `flutter build web`, para termos controle fino sobre o que é "network
// first" vs "cache first" — crítico porque o app precisa continuar
// funcionando offline no meio de um fluxo, mas NUNCA deve servir uma versão
// antiga do bundle Flutter depois que uma atualização foi publicada.

const CACHE_VERSION = 'certificados-lattes-v1';
const APP_SHELL_CACHE = `${CACHE_VERSION}-shell`;

// App shell: arquivos essenciais para o Flutter Web bootar mesmo offline.
// A lista de arquivos com hash (main.dart.js, assets) é gerada no momento do
// build (`flutter build web`) — aqui documentamos a estratégia, não os
// nomes de arquivo finais, que mudam a cada build.
// Caminhos relativos ao próprio sw.js (não absolutos a partir de "/"), para
// funcionar tanto na raiz do domínio quanto publicado em uma subpasta
// (ex.: /certificados-lattes/) sem precisar hardcodar o prefixo aqui.
const APP_SHELL_URLS = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_SHELL_CACHE).then((cache) => cache.addAll(APP_SHELL_URLS)),
  );
  // Não chama self.skipWaiting() automaticamente: uma atualização só deve
  // assumir controle quando o usuário não está no meio de um fluxo crítico
  // (upload em andamento, dossiê em compilação). A troca é sinalizada à UI
  // via postMessage e o usuário confirma o reload (ver ROADMAP_MOBILE.md /
  // DECISOES.md, "Atualização de versão em PWA instalado").
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('certificados-lattes-') && key !== APP_SHELL_CACHE)
          .map((key) => caches.delete(key)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Chamadas de API (Google, Microsoft Graph, LLM) NUNCA passam pelo cache
  // do service worker: precisam ir sempre à rede, e o tratamento de
  // offline/retry é responsabilidade da fila offline-first do app (Hive +
  // package:retry), não do service worker.
  const isApiCall =
    url.hostname.includes('googleapis.com') ||
    url.hostname.includes('graph.microsoft.com') ||
    url.hostname.includes('generativelanguage.googleapis.com') ||
    url.hostname.includes('api.openai.com') ||
    url.hostname.includes('login.microsoftonline.com') ||
    url.hostname.includes('accounts.google.com');

  if (isApiCall) {
    return; // deixa passar direto para a rede, sem interceptar
  }

  // App shell e assets do bundle Flutter: network-first com fallback para
  // cache. Isso evita servir um bundle antigo quando há rede disponível
  // (bug comum de "cache-first" em PWAs Flutter que trava usuários em
  // versões antigas), mas ainda funciona offline quando a rede cai no meio
  // do fluxo, que é o requisito central do projeto.
  event.respondWith(
    fetch(event.request)
      .then((networkResponse) => {
        const responseClone = networkResponse.clone();
        caches.open(APP_SHELL_CACHE).then((cache) => cache.put(event.request, responseClone));
        return networkResponse;
      })
      .catch(() => caches.match(event.request)),
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
