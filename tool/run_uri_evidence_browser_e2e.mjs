import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const expectedUri = 'http://or-app.invalid:bad/path?probe=%25#uri-evidence-v2';
const expectedRelease = process.argv[2] ?? 'uri-evidence-e2e';
const port = Number(process.argv[3] ?? '8766');
const debugPort = Number(process.argv[4] ?? '9336');
const origin = `http://127.0.0.1:${port}`;
const appUrl = `${origin}/or_app/`;
const diagnosticsUrl = `${appUrl}#/system/diagnostics/dashboard`;
const chrome = process.env.OR_APP_CHROME ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const flutterBin = (process.env.PATH ?? '')
  .split(';')
  .find((entry) => existsSync(join(entry, 'flutter.bat')));
const dart = process.env.OR_APP_DART ?? (flutterBin
  ? join(flutterBin, 'cache', 'dart-sdk', 'bin', 'dart.exe')
  : 'dart');
const profile = await mkdtemp(join(tmpdir(), 'or-app-uri-evidence-'));
let server;
let activeBrowser;
let activePage;

class Cdp {
  constructor(url) {
    this.socket = new WebSocket(url);
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
  }

  async open() {
    await new Promise((resolve, reject) => {
      this.socket.addEventListener('open', resolve, { once: true });
      this.socket.addEventListener('error', reject, { once: true });
    });
    this.socket.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id != null) {
        const pending = this.pending.get(message.id);
        if (!pending) return;
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(JSON.stringify(message.error)));
        else pending.resolve(message.result);
        return;
      }
      this.events.push(message);
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out`));
      }, 30000);
      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression, awaitPromise = true) {
    const result = await this.send('Runtime.evaluate', {
      expression,
      awaitPromise,
      returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.text ?? 'Runtime evaluation failed');
    }
    return result.result.value;
  }

  close() {
    this.socket.close();
  }
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitFor(label, callback, timeoutMs = 120000) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const result = await callback();
      if (result) return result;
    } catch (error) {
      lastError = error;
    }
    await delay(250);
  }
  throw new Error(`${label} timed out${lastError ? `: ${lastError}` : ''}`);
}

async function httpJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  return response.json();
}

async function launchBrowser() {
  const process = spawn(chrome, [
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${profile}`,
    '--headless=new',
    '--disable-background-networking',
    '--disable-default-apps',
    '--disable-extensions',
    '--disable-sync',
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=800,2000',
    'about:blank',
  ], { stdio: ['ignore', 'pipe', 'pipe'] });
  const version = await waitFor('Chrome CDP endpoint', () =>
    httpJson(`http://127.0.0.1:${debugPort}/json/version`).catch(() => null));
  return { process, version };
}

async function openPage(url) {
  const target = await httpJson(
    `http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(url)}`,
    { method: 'PUT' },
  );
  const cdp = new Cdp(target.webSocketDebuggerUrl);
  await cdp.open();
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Network.enable');
  await cdp.send('Browser.grantPermissions', {
    origin,
    permissions: ['clipboardReadWrite', 'clipboardSanitizedWrite'],
  });
  await waitFor('explicit browser URL', async () =>
    (await cdp.evaluate('location.href')) === url);
  return cdp;
}

async function closeBrowser(cdp, browser) {
  try {
    await cdp.send('Browser.close');
  } catch (_) {}
  cdp.close();
  try {
    await waitFor('Chrome process exit', () => browser.process.exitCode != null, 30000);
  } catch (error) {
    browser.process.kill();
    throw error;
  }
}

function decodeUtf16Le(encoded) {
  const bytes = Buffer.from(encoded, 'base64');
  const units = [];
  for (let index = 0; index < bytes.length; index += 2) {
    units.push(bytes[index] | (bytes[index + 1] << 8));
  }
  return String.fromCharCode(...units);
}

function verifyIncident(incident) {
  if (incident.schemaVersion !== 2) throw new Error('Incident schema mismatch');
  if (!String(incident.incidentId).startsWith('uri-incident-')) {
    throw new Error('Incident identifier missing');
  }
  if (incident.captureCompleteness !== 'engine_input_captured') {
    throw new Error(`Incomplete capture: ${incident.captureCompleteness}`);
  }
  if (!['platform_message_response_error', 'window_error'].includes(incident.trigger)) {
    throw new Error(`Unexpected trigger: ${incident.trigger}`);
  }
  const expectedCorrelation = incident.trigger === 'platform_message_response_error'
    ? 'platform_response_error'
    : 'closest_preceding_message_unconfirmed';
  if (incident.correlation !== expectedCorrelation) {
    throw new Error(`Unexpected correlation: ${incident.correlation}`);
  }
  const message = incident.relatedPlatformMessage;
  if (message?.channel !== 'flutter/navigation') throw new Error('Wrong boundary');
  if (message?.method !== 'routeInformationUpdated') throw new Error('Wrong method');
  if (message?.rawUri !== expectedUri) throw new Error('Raw URI mismatch');
  if (decodeUtf16Le(message.rawUriUtf16LeBase64) !== expectedUri) {
    throw new Error('Reversible URI encoding mismatch');
  }
  if (message.collectorParseResult !== 'format_exception') {
    throw new Error('Collector did not observe FormatException');
  }
  if (incident.build?.appReleaseCommit !== expectedRelease) {
    throw new Error(`Release mismatch: ${incident.build?.appReleaseCommit}`);
  }
  if (!incident.sessionId || !incident.timestamp || !message.navigationEventId) {
    throw new Error('Session/timestamp correlation missing');
  }
  const errorType = incident.error?.type ?? incident.error?.errorType;
  const errorMessage = incident.error?.message ?? incident.error?.errorMessage;
  if (!errorType || !errorMessage) {
    throw new Error('Exception metadata missing');
  }
}

async function readPersistentEvidence(cdp) {
  return waitFor('persistent URI incident', async () => {
    const raw = await cdp.evaluate(
      `localStorage.getItem('or_app.uri_exception_evidence.v2')`,
    );
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed.incidents?.length ? parsed : null;
  });
}

async function verifyLoadedBuild(cdp) {
  const loadedUrl = await cdp.evaluate('location.href');
  if (loadedUrl !== appUrl && loadedUrl !== diagnosticsUrl) {
    throw new Error(`Unexpected page URL: ${loadedUrl}`);
  }
  const entries = await waitFor('release-matched main bundle', async () => {
    const values = await cdp.evaluate(`performance.getEntriesByType('resource')
      .map((entry) => entry.name)
      .filter((name) => name.includes('main.dart.js'))`);
    return values.length ? values : null;
  });
  if (!entries.some((value) => value.includes(`or_app_release=${expectedRelease}`))) {
    throw new Error(`Release token absent from main bundle request: ${entries}`);
  }
}

async function enableSemanticsAndCopy(cdp) {
  await cdp.evaluate(`(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder) placeholder.click();
    return true;
  })()`);
  const clicked = await clickButtonWithScroll(cdp, 'COPY URI EVIDENCE');
  if (!clicked) throw new Error('URI evidence copy control was not activated');
  return waitFor('URI evidence clipboard export', () =>
    cdp.evaluate('navigator.clipboard.readText()').then((value) =>
      value?.includes('OR-APP URI EXCEPTION EVIDENCE') ? value : null));
}

async function clickButtonWithScroll(cdp, label) {
  let attempts = 0;
  return waitFor(label, async () => {
    attempts++;
    if (await clickAccessibilityNode(cdp, label)) {
      console.log(`Activated: ${label}`);
      return true;
    }
    if (attempts === 1 || attempts % 20 === 0) {
      await cdp.send('Accessibility.enable');
      const tree = await cdp.send('Accessibility.getFullAXTree');
      const visible = tree.nodes
        .filter((node) => ['button', 'menuitem'].includes(node.role?.value))
        .map((node) => String(node.name?.value ?? ''));
      console.log(`Waiting for ${label}; visible controls: ${JSON.stringify(visible)}`);
    }
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseWheel',
      x: 200,
      y: 500,
      deltaX: 0,
      deltaY: 600,
    });
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ x: 400, y: 500 }],
    });
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{ x: 400, y: 120 }],
    });
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
    await cdp.send('Input.dispatchKeyEvent', {
      type: 'keyDown',
      key: 'End',
      code: 'End',
      windowsVirtualKeyCode: 35,
    });
    await cdp.send('Input.dispatchKeyEvent', {
      type: 'keyUp',
      key: 'End',
      code: 'End',
      windowsVirtualKeyCode: 35,
    });
    return false;
  });
}

async function clickAccessibilityNode(cdp, label) {
  await cdp.send('Accessibility.enable');
  await cdp.send('DOM.enable');
  const tree = await cdp.send('Accessibility.getFullAXTree');
  const candidates = tree.nodes.filter((candidate) =>
    ['button', 'menuitem'].includes(candidate.role?.value));
  const node = candidates.find((candidate) =>
    String(candidate.name?.value ?? '').trim() === label) ??
    candidates.find((candidate) =>
      String(candidate.name?.value ?? '').includes(label));
  if (!node?.backendDOMNodeId) return false;
  const box = await cdp.send('DOM.getBoxModel', {
    backendNodeId: node.backendDOMNodeId,
  });
  const quad = box.model.content;
  const x = (Math.min(quad[0], quad[2], quad[4], quad[6]) +
    Math.max(quad[0], quad[2], quad[4], quad[6])) / 2;
  const y = (Math.min(quad[1], quad[3], quad[5], quad[7]) +
    Math.max(quad[1], quad[3], quad[5], quad[7])) / 2;
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mouseMoved',
    x,
    y,
  });
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mousePressed',
    x,
    y,
    button: 'left',
    buttons: 1,
    clickCount: 1,
  });
  await delay(100);
  await cdp.send('Input.dispatchMouseEvent', {
    type: 'mouseReleased',
    x,
    y,
    button: 'left',
    buttons: 0,
    clickCount: 1,
  });
  return true;
}

async function passFontFallbackGateIfPresent(cdp) {
  await cdp.evaluate(`(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder) placeholder.click();
    return true;
  })()`);
  let previousButtons = '';
  await waitFor('diagnostics UI or font fallback gate', async () => {
    await cdp.send('Accessibility.enable');
    const tree = await cdp.send('Accessibility.getFullAXTree');
    const buttonNames = tree.nodes
      .filter((node) => node.role?.value === 'button')
      .map((node) => String(node.name?.value ?? ''));
    const buttonSummary = JSON.stringify(buttonNames);
    if (buttonSummary !== previousButtons) {
      console.log(`Accessibility buttons: ${buttonSummary}`);
      previousButtons = buttonSummary;
    }
    if (buttonNames.some((name) => name.includes('COPY URI EVIDENCE'))) {
      return true;
    }
    if (!buttonNames.some((name) => name.includes('CONTINUE WITH SYSTEM FONT'))) {
      return false;
    }
    const clicked = await clickAccessibilityNode(
      cdp,
      'CONTINUE WITH SYSTEM FONT',
    );
    if (!clicked) {
      throw new Error('Font fallback gate was visible but not actionable');
    }
    console.log('Activated: CONTINUE WITH SYSTEM FONT');
    await waitFor('font fallback gate release', async () => {
      const updated = await cdp.send('Accessibility.getFullAXTree');
      return !updated.nodes.some((node) =>
        node.role?.value === 'button' &&
        String(node.name?.value ?? '').includes('CONTINUE WITH SYSTEM FONT'));
    });
    return true;
  });
}

try {
  console.log(`Starting probe server at ${appUrl}`);
  server = spawn(dart, [
    'tool/uri_evidence_probe_server.dart',
    String(port),
    expectedRelease,
  ], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  await waitFor('probe HTTP server', async () => {
    const response = await fetch(appUrl).catch(() => null);
    return response?.ok;
  }, 30000);

  console.log('Launching first isolated browser session');
  const firstBrowser = activeBrowser = await launchBrowser();
  const firstPage = activePage = await openPage(appUrl);
  console.log('Verifying injection build identity');
  await verifyLoadedBuild(firstPage);
  console.log('Waiting for same-boundary persistent incident');
  const firstEvidence = await readPersistentEvidence(firstPage);
  const firstIncident = firstEvidence.incidents.find((incident) =>
    incident.build?.appReleaseCommit === expectedRelease);
  if (!firstIncident) {
    throw new Error(`Injection incident was not persisted for ${expectedRelease}: ${
      JSON.stringify(firstEvidence.incidents.map((incident) => ({
        release: incident.build?.appReleaseCommit,
        trigger: incident.trigger,
        uri: incident.relatedPlatformMessage?.rawUri,
      })))} `);
  }
  verifyIncident(firstIncident);
  const firstIncidentId = firstIncident.incidentId;
  await closeBrowser(firstPage, firstBrowser);
  activeBrowser = null;
  activePage = null;

  console.log('Launching second browser process with the same profile');
  const secondBrowser = activeBrowser = await launchBrowser();
  const secondPage = activePage = await openPage(appUrl);
  await verifyLoadedBuild(secondPage);
  await passFontFallbackGateIfPresent(secondPage);
  console.log('Application initialization gate passed');
  const restartedEvidence = await readPersistentEvidence(secondPage);
  const retained = restartedEvidence.incidents.find(
    (incident) => incident.incidentId === firstIncidentId,
  );
  if (!retained) throw new Error('Incident did not survive browser restart');
  verifyIncident(retained);

  console.log('Verifying SYSTEM DASHBOARD DIAGNOSTICS export UI');
  const exportedText = await enableSemanticsAndCopy(secondPage);
  const exported = JSON.parse(exportedText);
  if (exported.schemaVersion !== 2 || exported.captureOperational !== true) {
    throw new Error('SYSTEM export envelope mismatch');
  }
  const exportedIncident = exported.incidents.find(
    (incident) => incident.incidentId === firstIncidentId,
  );
  if (!exportedIncident) throw new Error('Retained incident absent from SYSTEM export');
  verifyIncident(exportedIncident);

  console.log(JSON.stringify({
    status: 'PASS',
    browserUrl: diagnosticsUrl,
    browser: secondBrowser.version.Browser,
    release: expectedRelease,
    incidentId: firstIncidentId,
    captureBoundary: exportedIncident.relatedPlatformMessage.channel,
    method: exportedIncident.relatedPlatformMessage.method,
    rawUri: exportedIncident.relatedPlatformMessage.rawUri,
    recoveredUri: decodeUtf16Le(
      exportedIncident.relatedPlatformMessage.rawUriUtf16LeBase64,
    ),
    persistedAcrossBrowserRestart: true,
    exportedThroughSystemDiagnostics: true,
  }, null, 2));
  await closeBrowser(secondPage, secondBrowser);
  activeBrowser = null;
  activePage = null;
} finally {
  if (activePage && activeBrowser) {
    try {
      await closeBrowser(activePage, activeBrowser);
    } catch (_) {
      activeBrowser.process.kill();
    }
  }
  if (server && server.exitCode == null) server.kill();
  try {
    await rm(profile, {
      recursive: true,
      force: true,
      maxRetries: 20,
      retryDelay: 250,
    });
  } catch (error) {
    console.error(`Temporary browser profile cleanup warning: ${error}`);
  }
}
