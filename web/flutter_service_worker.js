// Minimal Flutter Service Worker
// This is a stub service worker that prevents Flutter from timing out
// while waiting for service worker initialization

self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event) => {
  // Pass through all requests - no caching
  event.respondWith(fetch(event.request));
});

console.log('[Service Worker] Loaded');
