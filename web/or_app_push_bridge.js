(function () {
  'use strict';
  const swPath = 'or_app_push_sw.js';

  function base64Key(value) {
    const padding = '='.repeat((4 - value.length % 4) % 4);
    const base64 = (value + padding).replace(/-/g, '+').replace(/_/g, '/');
    const raw = atob(base64);
    return Uint8Array.from(raw, (character) => character.charCodeAt(0));
  }

  async function registration() {
    if (!('serviceWorker' in navigator)) throw new Error('service_worker_unavailable');
    return navigator.serviceWorker.register(swPath, { scope: './' });
  }

  function randomToken(bytes) {
    const data = crypto.getRandomValues(new Uint8Array(bytes || 32));
    let binary = '';
    data.forEach((value) => { binary += String.fromCharCode(value); });
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  async function subscribe(vapidPublicKey) {
    if (!('Notification' in window) || !('PushManager' in window)) throw new Error('push_unavailable');
    const permission = Notification.permission === 'default'
      ? await Notification.requestPermission()
      : Notification.permission;
    if (permission !== 'granted') throw new Error('permission_' + permission);
    const worker = await registration();
    let subscription = await worker.pushManager.getSubscription();
    if (!subscription) {
      subscription = await worker.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64Key(vapidPublicKey),
      });
    }
    return JSON.stringify(subscription.toJSON());
  }

  async function request(url, method, token, body) {
    const headers = { accept: 'application/json' };
    if (token) headers.authorization = 'Bearer ' + token;
    if (body) headers['content-type'] = 'application/json';
    const response = await fetch(url, { method, headers, body: body || undefined, cache: 'no-store' });
    const text = await response.text();
    if (!response.ok) throw new Error('http_' + response.status + (text ? ':' + text.slice(0, 160) : ''));
    return text || '{}';
  }

  // Convert a pinned IANA wall clock to epoch milliseconds. Iteration handles
  // ordinary DST offsets without depending on the device's current zone.
  function wallTimeToEpoch(localDate, localTime, timeZone) {
    const parts = localDate.split('-').map(Number);
    const clock = localTime.split(':').map(Number);
    const target = Date.UTC(parts[0], parts[1] - 1, parts[2], clock[0], clock[1], 0, 0);
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
    });
    let guess = target;
    for (let index = 0; index < 4; index++) {
      const values = Object.fromEntries(formatter.formatToParts(new Date(guess)).map((part) => [part.type, part.value]));
      const represented = Date.UTC(+values.year, +values.month - 1, +values.day, +values.hour, +values.minute, +values.second);
      const difference = target - represented;
      guess += difference;
      if (difference === 0) break;
    }
    return guess;
  }

  window.orAppPush = {
    permission: () => 'Notification' in window ? Notification.permission : 'unsupported',
    timeZone: () => Intl.DateTimeFormat().resolvedOptions().timeZone || 'Etc/UTC',
    randomToken,
    subscribe,
    request,
    wallTimeToEpoch,
    serviceWorkerState: async () => {
      if (!('serviceWorker' in navigator)) return 'unsupported';
      const current = await navigator.serviceWorker.getRegistration(swPath);
      return current ? 'registered' : 'not_registered';
    },
  };
})();
