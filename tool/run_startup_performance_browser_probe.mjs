import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';

const release = process.argv[2] ?? 'startup-v5-probe';
const output = process.argv[3] ?? 'build/startup-performance-probe.json';
const port = Number(process.argv[4] ?? '8775');
const debugPort = Number(process.argv[5] ?? '9345');
const buildRoot = process.argv[6] ?? 'build/web';
const candidateMode = (process.argv[7] ?? 'candidate') === 'candidate';
const cpuThrottleRate = Number(process.argv[8] ?? '1');
const cacheRunCount = Number(process.argv[9] ?? '4');
const networkLatencyMs = Number(process.argv[10] ?? '0');
const downloadKbps = Number(process.argv[11] ?? '0');
const appUrl = `http://127.0.0.1:${port}/or_app/`;
const chrome = process.env.OR_APP_CHROME ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const flutterBin = (process.env.PATH ?? '')
  .split(';')
  .find((entry) => existsSync(join(entry, 'flutter.bat')));
const dart = process.env.OR_APP_DART ?? (flutterBin
  ? join(flutterBin, 'cache', 'dart-sdk', 'bin', 'dart.exe')
  : 'dart');
const profile = await mkdtemp(join(tmpdir(), 'or-app-startup-v5-'));
let server;
let browser;

class Cdp {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
  }
  async open() {
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
    });
    this.socket.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id == null) {
        for (const listener of this.listeners.get(message.method) ?? []) {
          listener(message.params ?? {});
        }
        return;
      }
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      message.error ? pending.reject(new Error(JSON.stringify(message.error)))
        : pending.resolve(message.result);
    });
  }
  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }
  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  }
  close() { this.socket.close(); }
}

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function waitFor(label, callback, timeout = 120000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const value = await callback().catch(() => null);
    if (value) return value;
    await delay(100);
  }
  throw new Error(`${label} timed out`);
}
async function httpJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
  return response.json();
}
async function launch() {
  browser = spawn(chrome, [
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${profile}`,
    '--headless=new', '--disable-default-apps', '--disable-extensions',
    '--disable-sync', '--no-first-run', '--no-default-browser-check',
    '--window-size=390,844', 'about:blank',
  ], { stdio: 'ignore' });
  await waitFor('Chrome', () =>
    httpJson(`http://127.0.0.1:${debugPort}/json/version`).catch(() => null));
}
async function closeBrowser(cdp) {
  try { await cdp.send('Browser.close'); } catch (_) {}
  cdp.close();
  await waitFor('Chrome exit', () => browser?.exitCode != null, 30000)
    .catch(() => browser?.kill());
  await delay(250);
}
async function openPage() {
  const target = await httpJson(
    `http://127.0.0.1:${debugPort}/json/new?about:blank`,
    { method: 'PUT' },
  );
  const cdp = new Cdp(target.webSocketDebuggerUrl);
  await cdp.open();
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Network.enable');
  if (networkLatencyMs > 0 || downloadKbps > 0) {
    await cdp.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: networkLatencyMs,
      downloadThroughput: downloadKbps > 0
        ? (downloadKbps * 1024) / 8
        : -1,
      uploadThroughput: -1,
      connectionType: 'cellular4g',
    });
  }
  await cdp.send('Performance.enable');
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpuThrottleRate });
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `window.__orAppLongTasks = [];
      try {
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            window.__orAppLongTasks.push({
              startMs: Math.round(entry.startTime),
              durationMs: Math.round(entry.duration)
            });
            if (window.__orAppLongTasks.length > 32) {
              window.__orAppLongTasks.shift();
            }
          }
        }).observe({ type: 'longtask', buffered: true });
      } catch (_) {}`,
  });
  return cdp;
}
async function measure(label) {
  await launch();
  const cdp = await openPage();
  const requests = new Map();
  cdp.on('Network.requestWillBeSent', ({ requestId, request, timestamp, type }) => {
    requests.set(requestId, {
      url: new URL(request.url).pathname,
      type,
      requestTimestamp: timestamp,
    });
  });
  cdp.on('Network.responseReceived', ({ requestId, response, timestamp }) => {
    const record = requests.get(requestId);
    if (!record) return;
    Object.assign(record, {
      responseTimestamp: timestamp,
      status: response.status,
      fromDiskCache: response.fromDiskCache,
      fromServiceWorker: response.fromServiceWorker,
      protocol: response.protocol,
      mimeType: response.mimeType,
      encodedDataLength: response.encodedDataLength,
    });
  });
  cdp.on('Network.loadingFinished', ({ requestId, timestamp, encodedDataLength }) => {
    const record = requests.get(requestId);
    if (!record) return;
    Object.assign(record, { finishedTimestamp: timestamp, encodedDataLength });
  });
  await cdp.send('Page.navigate', { url: appUrl });
  const timing = await waitFor('runApp complete', () => cdp.evaluate(`
    window.__orAppStartupTiming?.runAppCompleteMs
      ? JSON.parse(JSON.stringify(window.__orAppStartupTiming))
      : null
  `));
  const resources = await cdp.evaluate(`performance.getEntriesByType('resource')
    .filter((entry) => /canvaskit/i.test(entry.name))
    .map((entry) => ({
      name: new URL(entry.name).pathname,
      startMs: Math.round(entry.startTime),
      durationMs: Math.round(entry.duration),
      transferBytes: entry.transferSize,
      decodedBytes: entry.decodedBodySize
    }))`);
  const mainRequests = await cdp.evaluate(`performance.getEntriesByType('resource')
    .filter((entry) => entry.name.includes('main.dart.js'))
    .map((entry) => entry.name)`);
  const longTasks = await cdp.evaluate(`window.__orAppLongTasks ?? []`);
  const metricsResult = await cdp.send('Performance.getMetrics');
  const performanceMetrics = Object.fromEntries(
    metricsResult.metrics
      .filter(({ name }) => [
        'TaskDuration', 'ScriptDuration', 'LayoutDuration',
        'RecalcStyleDuration', 'JSHeapUsedSize', 'JSHeapTotalSize',
      ].includes(name))
      .map(({ name, value }) => [name, value]),
  );
  const surface = await cdp.evaluate(`(() => {
    const host = document.querySelector('#or-app-preflutter');
    return {
    hostVisibility: host ? getComputedStyle(host).visibility : 'absent',
    flutterViewCount: document.querySelectorAll('flutter-view').length,
    sceneHostCount: document.querySelectorAll('flt-scene-host').length
  }; })()`);
  if (candidateMode && resources.some((entry) =>
    !entry.name.startsWith('/or_app/canvaskit/'))) {
    throw new Error(`CanvasKit escaped the application origin: ${JSON.stringify(resources)}`);
  }
  if (mainRequests.length !== 1 || !mainRequests[0].includes(`or_app_release=${release}`)) {
    throw new Error(`Release-matched main bundle contract failed: ${mainRequests}`);
  }
  if (candidateMode &&
      (surface.hostVisibility !== 'absent' || surface.flutterViewCount !== 1)) {
    throw new Error(`Pre-Flutter transition failed: ${JSON.stringify(surface)}`);
  }
  await closeBrowser(cdp);
  return {
    label,
    cpuThrottleRate,
    timing,
    resources,
    networkRequests: [...requests.values()],
    mainRequests,
    longTasks,
    performanceMetrics,
    surface,
  };
}

try {
  server = spawn(dart, [
    'tool/startup_performance_probe_server.dart', String(port), release, buildRoot,
  ], {
    stdio: 'ignore',
  });
  await waitFor('server', async () => (await fetch(appUrl).catch(() => null))?.ok);
  const runs = [];
  runs.push(await measure('cold'));
  for (let index = 1; index <= cacheRunCount; index++) {
    runs.push(await measure(`cache_preserved_${index}`));
  }
  await mkdir(dirname(output), { recursive: true });
  await writeFile(output, JSON.stringify({ release, appUrl, runs }, null, 2));
  console.log(JSON.stringify({ output, runs }, null, 2));
} finally {
  browser?.kill();
  server?.kill();
  await rm(profile, { recursive: true, force: true }).catch(() => {});
}
