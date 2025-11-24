// 🌐 HiAudio Pro PWA Service Worker
// Progressive Web App機能とオフライン対応

const CACHE_NAME = 'hiaudio-pro-v1.0';
const STATIC_CACHE = 'hiaudio-static-v1.0';
const DYNAMIC_CACHE = 'hiaudio-dynamic-v1.0';

// キャッシュするリソース
const CACHE_URLS = [
  '/',
  '/index.html',
  '/web-receiver.html',
  '/manifest.json',
  // CSS・JSは inline なのでキャッシュ不要
];

// Install event - キャッシュ作成
self.addEventListener('install', (event) => {
  console.log('🔧 Service Worker: Installing...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('📦 Service Worker: Caching static files');
        return cache.addAll(CACHE_URLS);
      })
      .then(() => {
        console.log('✅ Service Worker: Installation complete');
        return self.skipWaiting(); // 即座にアクティブ化
      })
  );
});

// Activate event - 古いキャッシュ削除
self.addEventListener('activate', (event) => {
  console.log('⚡ Service Worker: Activating...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
              console.log('🗑️ Service Worker: Deleting old cache', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('✅ Service Worker: Activation complete');
        return self.clients.claim(); // すべてのクライアントを制御
      })
  );
});

// Fetch event - ネットワークリクエスト処理
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // HiAudio関連リクエストのみ処理
  if (url.origin === location.origin) {
    event.respondWith(handleFetch(request));
  }
});

// フェッチ処理 - Cache First Strategy
async function handleFetch(request) {
  try {
    // 1. キャッシュから検索
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      console.log('📦 Serving from cache:', request.url);
      return cachedResponse;
    }
    
    // 2. ネットワークから取得
    console.log('🌐 Fetching from network:', request.url);
    const networkResponse = await fetch(request);
    
    // 3. 動的キャッシュに保存（成功時のみ）
    if (networkResponse.status === 200) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
    
  } catch (error) {
    console.error('❌ Fetch failed:', error);
    
    // 4. フォールバック - オフライン表示
    if (request.destination === 'document') {
      return caches.match('/offline.html') || new Response(
        '<!DOCTYPE html><html><body><h1>🔌 Offline</h1><p>Network connection required.</p></body></html>',
        { headers: { 'Content-Type': 'text/html' } }
      );
    }
    
    throw error;
  }
}

// Message event - クライアントからの通信
self.addEventListener('message', (event) => {
  console.log('💬 Service Worker message:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'GET_CACHE_INFO') {
    caches.keys().then((cacheNames) => {
      event.ports[0].postMessage({
        caches: cacheNames,
        version: CACHE_NAME
      });
    });
  }
  
  if (event.data && event.data.type === 'CLEAR_CACHE') {
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => caches.delete(cacheName))
      );
    }).then(() => {
      event.ports[0].postMessage({ success: true });
    });
  }
});

// Background Sync - オフライン時のデータ送信
self.addEventListener('sync', (event) => {
  console.log('🔄 Background Sync:', event.tag);
  
  if (event.tag === 'hiaudio-sync') {
    event.waitUntil(syncHiAudioData());
  }
});

async function syncHiAudioData() {
  try {
    // オフライン時に蓄積されたデータを送信
    const cache = await caches.open(DYNAMIC_CACHE);
    // 実装: 蓄積されたメトリクスデータなどを送信
    console.log('🔄 Sync completed');
  } catch (error) {
    console.error('❌ Sync failed:', error);
  }
}

// Push notifications - 将来の拡張用
self.addEventListener('push', (event) => {
  console.log('📢 Push notification received:', event);
  
  const options = {
    body: 'HiAudio Pro の新機能が利用可能です',
    icon: '/icon-192.png',
    badge: '/badge-72.png',
    tag: 'hiaudio-update',
    actions: [
      {
        action: 'open',
        title: '開く'
      },
      {
        action: 'close',
        title: '閉じる'
      }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification('HiAudio Pro', options)
  );
});

// Notification click
self.addEventListener('notificationclick', (event) => {
  console.log('🔔 Notification clicked:', event);
  
  event.notification.close();
  
  if (event.action === 'open') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Error handling
self.addEventListener('error', (event) => {
  console.error('❌ Service Worker error:', event.error);
});

self.addEventListener('unhandledrejection', (event) => {
  console.error('❌ Service Worker unhandled rejection:', event.reason);
});

console.log('🚀 HiAudio Pro Service Worker loaded');