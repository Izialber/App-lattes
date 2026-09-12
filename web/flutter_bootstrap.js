{{flutter_js}}
{{flutter_build_config}}
// Sem `serviceWorkerSettings`: o bootstrap padrão do Flutter registraria
// automaticamente `flutter_service_worker.js`, competindo pelo mesmo escopo
// com o service worker próprio do app (`sw.js`, registrado manualmente em
// index.html com política de cache customizada — ver web/sw.js). Registrar
// os dois causaria dois service workers disputando controle da página.
_flutter.loader.load({
  config: {
    // CanvasKit local (empacotado em build/web/canvaskit/) em vez do CDN
    // (www.gstatic.com): evita violar a CSP restritiva do app, evita
    // dependência de rede externa para o motor de renderização (alinhado ao
    // design offline-first do app) e funciona igual em qualquer subpasta,
    // pois é resolvido como caminho relativo ao <base href>.
    canvasKitBaseUrl: "canvaskit/",
  },
});
