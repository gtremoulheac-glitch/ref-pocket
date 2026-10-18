// Service worker : rend l'appli installable et garde l'interface en cache.
// Les données du jeu (Supabase) ne sont jamais mises en cache : elles viennent toujours du serveur.
const CACHE = "refmaster-v43";
const SHELL = ["./", "index.html", "config.js", "cartes.js", "cartes.css", "manifest.webmanifest",
  "icons/icon-192.png", "icons/icon-512.png", "icons/apple-touch-icon.png", "fonts/fonts.css",
  "fonts/bowlby-one-latin-400-normal.woff2", "fonts/figtree-latin-400-normal.woff2", "fonts/figtree-latin-700-normal.woff2", "fonts/figtree-latin-800-normal.woff2"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return; // Supabase, polices, CDN : réseau direct
  // Réseau d'abord (pour toujours avoir la dernière version), cache si hors ligne
  e.respondWith(
    fetch(e.request).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request).then(r => r || caches.match("index.html")))
  );
});
