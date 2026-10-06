'use strict';

self.addEventListener('push', (event) => {
  let payload = { title: 'OR-APP', body: '通知があります。', tag: 'or-app', url: '/or_app/' };
  try {
    if (event.data) payload = Object.assign(payload, event.data.json());
  } catch (_) {}
  event.waitUntil(self.registration.showNotification(payload.title || 'OR-APP', {
    body: payload.body || '通知があります。',
    tag: payload.tag || 'or-app',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: payload.url || '/or_app/' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const destination = new URL(event.notification.data?.url || '/or_app/', self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin) {
        await client.focus();
        if ('navigate' in client && client.url !== destination) await client.navigate(destination);
        return;
      }
    }
    await clients.openWindow(destination);
  })());
});
