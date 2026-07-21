const CACHE_NAME = 'labbridge-pwa-v2';
const ASSETS = [
  '/',
  '/index.html',
  '/phone.html',
  '/manifest.json',
  '/qr.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jsqr/1.4.0/jsQR.min.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request).catch(() => caches.match(event.request))
  );
});
