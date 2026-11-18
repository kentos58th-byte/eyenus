/* オフラインでも体験できるように、アプリ本体を端末に保存する。更新したら VERSION を上げる */
const VERSION = 'ainas-v33';
const CORE = ['./', 'index.html', 'manifest.webmanifest', 'js/three.min.js',
  'img/logo-white.png', 'img/mark.png', 'img/qr.png', 'img/story-1.jpg', 'img/story-2.jpg', 'img/story-3.jpg', 'img/story-4.jpg', 'img/tanaka-1.jpg', 'img/tanaka-2.jpg', 'img/tanaka-3.jpg', 'img/tanaka-4.jpg', 'img/sato-1.jpg', 'img/sato-2.jpg', 'img/sato-3.jpg', 'img/sato-4.jpg', 'img/end-1.jpg', 'img/end-2.jpg', 'img/end-3.jpg', 'img/end-4.jpg', 'audio/vent-story-1.mp3', 'audio/vent-story-2.mp3', 'audio/vent-story-3.mp3', 'audio/vent-story-4.mp3', 'audio/vent-bad-01.mp3', 'audio/vent-bad-02.mp3', 'audio/vent-bad-03.mp3', 'audio/vent-bad-04.mp3', 'audio/vent-bad-05.mp3', 'audio/vent-good-01.mp3', 'audio/vent-good-02.mp3', 'audio/vent-good-03.mp3', 'audio/vent-good-04.mp3', 'audio/vent-good-05.mp3', 'audio/vent-good-06.mp3', 'audio/vent-good-07.mp3', 'audio/vent-good-08.mp3', 'audio/vent-good-09.mp3', 'audio/bpsd-story-1.mp3', 'audio/bpsd-story-2.mp3', 'audio/bpsd-story-3.mp3', 'audio/bpsd-story-4.mp3', 'audio/bpsd-bad-01.mp3', 'audio/bpsd-bad-03.mp3', 'audio/bpsd-bad-04.mp3', 'audio/bpsd-bad-06.mp3', 'audio/bpsd-bad-08.mp3', 'audio/bpsd-bad-09.mp3', 'audio/bpsd-good-01.mp3', 'audio/bpsd-good-03.mp3', 'audio/bpsd-good-05.mp3', 'audio/bpsd-good-07.mp3', 'audio/bpsd-good-09.mp3', 'audio/bpsd-good-11.mp3', 'audio/bpsd-good-12.mp3', 'audio/bpsd-good-13.mp3', 'audio/bpsd-sato-01.mp3', 'audio/bpsd-sato-02.mp3', 'audio/bpsd-sato-03.mp3', 'audio/bpsd-sato-04.mp3', 'audio/bpsd-sato-05.mp3', 'audio/bpsd-sato-06.mp3', 'audio/bpsd-sato-07.mp3', 'audio/bpsd-sato-08.mp3', 'audio/bpsd-sato-09.mp3', 'audio/bpsd-sato-10.mp3', 'audio/bpsd-sato-11.mp3', 'audio/bpsd-bad-02.mp3', 'audio/bpsd-bad-05.mp3', 'audio/bpsd-bad-07.mp3', 'audio/bpsd-good-02.mp3', 'audio/bpsd-good-04.mp3', 'audio/bpsd-good-06.mp3', 'audio/bpsd-good-08.mp3', 'audio/bpsd-good-10.mp3', 'audio/bpsd-end-01.mp3', 'audio/bpsd-end-02.mp3', 'audio/bpsd-end-03.mp3', 'audio/bpsd-end-04.mp3',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(VERSION).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if(e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if(url.origin === location.origin){
    /* 本体：ネット優先（更新をすぐ反映）、つながらなければ保存版 */
    e.respondWith(fetch(e.request).then(r => { const copy = r.clone(); caches.open(VERSION).then(c => c.put(e.request, copy)); return r; })
      .catch(() => caches.match(e.request).then(r => r || caches.match('index.html'))));
  } else if(/fonts\.(googleapis|gstatic)\.com/.test(url.host)){
    /* フォント：保存版優先 */
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => { const copy = res.clone(); caches.open(VERSION).then(c => c.put(e.request, copy)); return res; })));
  }
});
