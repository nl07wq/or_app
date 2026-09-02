(() => {
  'use strict';

  const root = new URL('assets/food_input/', document.baseURI);
  const paths = {
    tesseract: new URL('ocr/tesseract.min.js', root).href,
    worker: new URL('ocr/worker.min.js', root).href,
    core: new URL('ocr/core/', root).href,
    language: new URL('ocr/lang/', root).href,
    paddleModule: new URL('paddle/paddleocr-engine.mjs', root).href,
    paddleWasm: new URL('paddle/wasm/', root).href,
    paddleDetectionModel: new URL(
      'paddle/models/PP-OCRv5_mobile_det_onnx_infer.tar',
      root,
    ).href,
    paddleRecognitionModel: new URL(
      'paddle/models/PP-OCRv5_mobile_rec_onnx_infer.tar',
      root,
    ).href,
    paddleWorker: new URL(
      'paddle/assets/worker-entry-C9UNuyOJ.js',
      root,
    ).href,
    paddleWasmStandard: new URL(
      'paddle/wasm/ort-wasm-simd-threaded.wasm',
      root,
    ).href,
    paddleWasmJsep: new URL(
      'paddle/wasm/ort-wasm-simd-threaded.jsep.wasm',
      root,
    ).href,
    zxing: new URL('barcode/zxing-browser.min.js', root).href,
  };
  const loadedScripts = new Map();
  let workerPromise;
  let workerInstance;
  let ocrQueue = Promise.resolve();
  let paddleModulePromise;
  let paddleWorkerPromise;
  let paddleWorkerInstance;
  let paddleQueue = Promise.resolve();
  let paddleRuntimeLoadCount = 0;
  let paddleModelLoadCount = 0;
  let lastPaddleDiagnostics;
  let activePaddleDiagnostics;
  let paddleDiagnosticSequence = 0;
  let paddleDiagnosticPanel;
  let barcodeDetectorPromise;
  let barcodeReaderPromise;
  const ocrPassSeparator = '\u001e';
  const ocrGuide = Object.freeze({ left: 0.04, top: 0.10, width: 0.92, height: 0.80 });
  const packageGuide = Object.freeze({ left: 0.02, top: 0.06, width: 0.96, height: 0.88 });
  const frameQualityThreshold = Object.freeze({
    minBrightness: 28,
    maxBrightness: 232,
    minContrast: 16,
    minSharpness: 5,
    minEdgeDensity: 0.012,
  });
  let lastCaptureDiagnostics;
  let lastPhotoDiagnostics;
  let lastStructuredDiagnostics;
  let activeNutritionPipelineDiagnostics;

  const paddleStageNames = Object.freeze({
    P0: 'engine-selected',
    P1: 'runtime-import-start',
    P2: 'runtime-import-success',
    P3: 'worker-initialization',
    P4: 'worker-ready',
    P5: 'onnx-runtime-initialization',
    P6: 'onnx-runtime-ready',
    P7: 'detection-model-fetch',
    P8: 'detection-model-fetch-success',
    P9: 'detection-session-create',
    P10: 'detection-session-ready',
    P11: 'recognition-model-fetch',
    P12: 'recognition-model-fetch-success',
    P13: 'recognition-session-create',
    P14: 'recognition-session-ready',
    P15: 'image-decode-start',
    P16: 'image-decode-success',
    P17: 'preprocess-start',
    P18: 'preprocess-success',
    P19: 'detection-inference-start',
    P20: 'detection-inference-success',
    P21: 'detected-boxes-available',
    P22: 'recognition-inference-start',
    P23: 'recognition-inference-success',
    P24: 'ocr-blocks-available',
    P25: 'common-result-mapping',
    P26: 'nutrition-mapping',
    P27: 'candidate-returned-to-dart',
    P28: 'review-ui',
  });

  function diagnosticNow() {
    return typeof performance !== 'undefined' && performance.now
      ? performance.now()
      : Date.now();
  }

  function requestedOcrEngine(engineOverride) {
    const queryEngine = typeof location === 'undefined'
      ? null
      : new URLSearchParams(location.search).get('orOcrEngine');
    const developerEngine = window.__OR_APP_OCR_ENGINE__ || queryEngine;
    if (developerEngine === 'paddle' || developerEngine === 'tesseract') {
      return developerEngine;
    }
    if (engineOverride === 'paddle' || engineOverride === 'tesseract') {
      return engineOverride;
    }
    return 'tesseract';
  }

  function memorySnapshot() {
    const memory = typeof performance !== 'undefined' && performance.memory;
    if (!memory) return { available: false };
    return {
      available: true,
      usedJSHeapSize: Number(memory.usedJSHeapSize) || null,
      totalJSHeapSize: Number(memory.totalJSHeapSize) || null,
      jsHeapSizeLimit: Number(memory.jsHeapSizeLimit) || null,
    };
  }

  function runtimeCapabilities() {
    return {
      userAgent: typeof navigator === 'undefined' ? null : navigator.userAgent,
      webAssembly: typeof WebAssembly === 'object',
      worker: typeof Worker === 'function',
      crossOriginIsolated: Boolean(globalThis.crossOriginIsolated),
      hardwareConcurrency: typeof navigator === 'undefined'
        ? null
        : navigator.hardwareConcurrency || null,
      deviceMemory: typeof navigator === 'undefined'
        ? null
        : navigator.deviceMemory || null,
      performanceMemory: memorySnapshot(),
      requestedBackend: 'wasm',
      numThreads: 1,
      simdRequested: true,
      recognitionBatchSize: 'library-default',
      tensorDimensions: 'not-exposed-by-public-worker-api',
      expectedModelAssetBytes: {
        detection: 4843520,
        recognition: 16701440,
      },
      webGpuAvailable: typeof navigator !== 'undefined' &&
        Boolean(navigator.gpu),
    };
  }

  function startPaddleDiagnostics(
    source,
    dimensions = {},
    engineOverride = null,
  ) {
    const requestedEngine = requestedOcrEngine(engineOverride);
    const resolvedEngine = selectedOcrEngine('nutrition', engineOverride);
    activePaddleDiagnostics = {
      diagnosticVersion: 1,
      runId: ++paddleDiagnosticSequence,
      source,
      startedAt: new Date().toISOString(),
      requestedEngine,
      resolvedEngine,
      actualExecutedEngine: null,
      state: 'running',
      currentStage: 'P0',
      failureStage: null,
      failureCategory: null,
      errorName: null,
      safeErrorMessage: null,
      watchdogFired: false,
      dimensions: {
        sourceWidth: Number(dimensions.width) || null,
        sourceHeight: Number(dimensions.height) || null,
        estimatedImageBufferBytes:
          Number(dimensions.width) * Number(dimensions.height) * 4 || null,
      },
      assets: {},
      stages: [],
      runtime: runtimeCapabilities(),
      standaloneChecks: {
        detectionOnly: {
          available: false,
          reason: 'PaddleOCR.js public worker API exposes combined predict only',
        },
        recognitionOnly: {
          available: false,
          reason: 'PaddleOCR.js public worker API exposes combined predict only',
        },
      },
    };
    recordPaddleStage('P0', 'success', {
      requestedEngine,
      resolvedEngine,
    });
    lastPaddleDiagnostics = activePaddleDiagnostics;
    updatePaddleDiagnosticPanel('LOADING');
    return activePaddleDiagnostics;
  }

  function ensurePaddleDiagnostics(
    source,
    dimensions,
    force = false,
    engineOverride = null,
  ) {
    if (force || !activePaddleDiagnostics ||
        activePaddleDiagnostics.state !== 'running') {
      return startPaddleDiagnostics(source, dimensions, engineOverride);
    }
    if (dimensions) {
      activePaddleDiagnostics.dimensions.sourceWidth =
        Number(dimensions.width) || null;
      activePaddleDiagnostics.dimensions.sourceHeight =
        Number(dimensions.height) || null;
      activePaddleDiagnostics.dimensions.estimatedImageBufferBytes =
        Number(dimensions.width) * Number(dimensions.height) * 4 || null;
    }
    return activePaddleDiagnostics;
  }

  function recordPaddleStage(stageId, status, details = {}) {
    if (!activePaddleDiagnostics) return null;
    const at = diagnosticNow();
    const event = {
      stageId,
      stageName: paddleStageNames[stageId] || 'unknown',
      status,
      atMs: Math.round(at * 10) / 10,
      ...(status === 'started'
        ? { startTimeMs: Math.round(at * 10) / 10 }
        : { endTimeMs: Math.round(at * 10) / 10 }),
      ...details,
    };
    activePaddleDiagnostics.currentStage = stageId;
    activePaddleDiagnostics.stages.push(event);
    lastPaddleDiagnostics = activePaddleDiagnostics;
    return event;
  }

  async function tracePaddleStage(stageId, action, details = {}) {
    const started = diagnosticNow();
    recordPaddleStage(stageId, 'started', details);
    try {
      const value = await action();
      recordPaddleStage(stageId, 'success', {
        ...details,
        durationMs: Math.round(diagnosticNow() - started),
      });
      return value;
    } catch (error) {
      recordPaddleStage(stageId, 'failure', {
        ...details,
        durationMs: Math.round(diagnosticNow() - started),
      });
      throw error;
    }
  }

  function safeErrorMessage(error) {
    const message = String(error && error.message || 'Paddle OCR failed')
      .replace(/[\r\n]+/g, ' ')
      .trim();
    return message.slice(0, 240);
  }

  function classifyPaddleFailure(error, stageId) {
    const message = safeErrorMessage(error).toLowerCase();
    if (message.includes('timed out')) return 'CLASS I';
    if (message.includes('out of memory') || message.includes('memory') ||
        message.includes('wasm trap')) return 'CLASS H';
    if (message.includes('worker')) return 'CLASS C';
    if (message.includes('wasm') || message.includes('onnx') ||
        message.includes('webassembly')) return 'CLASS D';
    if (message.includes('model') || message.includes('session')) return 'CLASS E';
    if (['P1', 'P2', 'P7', 'P8', 'P11', 'P12'].includes(stageId)) {
      return 'CLASS B';
    }
    if (['P3', 'P4'].includes(stageId)) return 'CLASS C';
    if (['P5', 'P6', 'P9', 'P10', 'P13', 'P14'].includes(stageId)) {
      return 'CLASS D';
    }
    if (['P19', 'P20', 'P21'].includes(stageId)) return 'CLASS F';
    if (['P22', 'P23', 'P24'].includes(stageId)) return 'CLASS G';
    return 'CLASS J';
  }

  function paddleFailureCode(error, stageId) {
    const message = safeErrorMessage(error).toLowerCase();
    if (message.includes('timed out')) return 'TIMEOUT-UNKNOWN';
    return ({
      P1: 'LOAD-MODULE',
      P2: 'LOAD-MODULE',
      P3: 'WORKER-INIT',
      P4: 'WORKER-RUNTIME',
      P5: 'ONNX-INIT',
      P6: 'ONNX-INIT',
      P7: 'MODEL-FETCH-DET',
      P8: 'MODEL-FETCH-DET',
      P9: 'MODEL-SESSION-DET',
      P10: 'MODEL-SESSION-DET',
      P11: 'MODEL-FETCH-REC',
      P12: 'MODEL-FETCH-REC',
      P13: 'MODEL-SESSION-REC',
      P14: 'MODEL-SESSION-REC',
      P15: 'IMAGE-DECODE',
      P16: 'IMAGE-DECODE',
      P17: 'PREPROCESS',
      P18: 'PREPROCESS',
      P19: 'DETECTION-INFERENCE',
      P20: 'DETECTION-INFERENCE',
      P21: 'DETECTION-INFERENCE',
      P22: 'RECOGNITION-INFERENCE',
      P23: 'RECOGNITION-INFERENCE',
      P24: 'RECOGNITION-INFERENCE',
    })[stageId] || 'POC-IMPLEMENTATION';
  }

  function failPaddleDiagnostics(error, stageId) {
    if (!activePaddleDiagnostics) return;
    if (!stageId && activePaddleDiagnostics.state === 'failed' &&
        activePaddleDiagnostics.failureStage) return;
    const failureStage = stageId || activePaddleDiagnostics.currentStage;
    activePaddleDiagnostics.state = 'failed';
    activePaddleDiagnostics.failureStage = failureStage;
    activePaddleDiagnostics.failureCategory = classifyPaddleFailure(
      error,
      failureStage,
    );
    activePaddleDiagnostics.errorCategory = paddleFailureCode(
      error,
      failureStage,
    );
    activePaddleDiagnostics.errorName = String(error && error.name || 'Error');
    activePaddleDiagnostics.safeErrorMessage = safeErrorMessage(error);
    activePaddleDiagnostics.endedAt = new Date().toISOString();
    activePaddleDiagnostics.memoryAfter = memorySnapshot();
    activePaddleDiagnostics.resources = paddleResourceTelemetry();
    lastPaddleDiagnostics = activePaddleDiagnostics;
    updatePaddleDiagnosticPanel(
      `FAILED: ${failureStage} ${activePaddleDiagnostics.failureCategory}`,
    );
  }

  function completePaddleDiagnostics() {
    if (!activePaddleDiagnostics) return;
    activePaddleDiagnostics.state = 'ready';
    activePaddleDiagnostics.endedAt = new Date().toISOString();
    activePaddleDiagnostics.memoryAfter = memorySnapshot();
    activePaddleDiagnostics.resources = paddleResourceTelemetry();
    const wasmResource = activePaddleDiagnostics.resources.find(
      (resource) => resource.url.endsWith('.wasm'),
    );
    activePaddleDiagnostics.runtime.wasmVariant = wasmResource
      ? wasmResource.url.split('/').pop()
      : 'not-observable';
    lastPaddleDiagnostics = activePaddleDiagnostics;
    updatePaddleDiagnosticPanel('READY');
  }

  function paddleResourceTelemetry() {
    if (typeof performance === 'undefined' ||
        !performance.getEntriesByType) return [];
    return performance.getEntriesByType('resource')
      .filter((entry) => String(entry.name).includes('/food_input/paddle/'))
      .map((entry) => ({
        url: String(entry.name),
        durationMs: Math.round(Number(entry.duration) || 0),
        transferSize: Number(entry.transferSize) || null,
        encodedBodySize: Number(entry.encodedBodySize) || null,
        responseStatus: Number(entry.responseStatus) || null,
      }));
  }

  async function probePaddleAsset(key, url, stageId) {
    const probe = window.__OR_APP_PADDLE_ASSET_PROBE__ ||
      ((assetUrl) => fetch(assetUrl, { method: 'HEAD', cache: 'no-store' }));
    const started = diagnosticNow();
    let response;
    try {
      response = await tracePaddleStage(stageId, async () => {
        const value = await probe(url);
        if (!value || !value.ok) {
          const status = Number(value && value.status) || 0;
          const error = new Error(
            `${key} returned HTTP ${status || 'unknown'}`,
          );
          error.name = 'PaddleAssetError';
          error.status = status;
          throw error;
        }
        return value;
      }, {
        assetKey: key,
        assetUrl: url,
      });
    } catch (error) {
      if (activePaddleDiagnostics) {
        activePaddleDiagnostics.assets[key] = {
          url,
          status: Number(error && error.status) || null,
          ok: false,
          durationMs: Math.round(diagnosticNow() - started),
        };
      }
      throw error;
    }
    const headers = response && response.headers;
    const status = Number(response && response.status) || 0;
    const asset = {
      url,
      sameOrigin: typeof location === 'undefined'
        ? null
        : new URL(url).origin === location.origin,
      status,
      ok: Boolean(response && response.ok),
      mimeType: headers && headers.get ? headers.get('content-type') : null,
      contentLength: headers && headers.get
        ? Number(headers.get('content-length')) || null
        : null,
      durationMs: Math.round(diagnosticNow() - started),
    };
    activePaddleDiagnostics.assets[key] = asset;
    return asset;
  }

  function loadScript(url) {
    if (loadedScripts.has(url)) return loadedScripts.get(url);
    const promise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error(`Failed to load ${url}`));
      document.head.appendChild(script);
    });
    loadedScripts.set(url, promise);
    return promise;
  }

  function selectedOcrEngine(mode = 'nutrition', engineOverride = null) {
    if (mode !== 'nutrition') return 'tesseract';
    return requestedOcrEngine(engineOverride) === 'paddle'
      ? 'paddle'
      : 'tesseract';
  }

  function updatePaddleDiagnosticPanel(status, engineOverride = null) {
    const paddleSession = engineOverride === 'paddle' ||
      activePaddleDiagnostics?.resolvedEngine === 'paddle';
    if ((!paddleSession && selectedOcrEngine('nutrition') !== 'paddle') ||
        typeof document === 'undefined' || !document.body ||
        typeof document.createElement !== 'function') return;
    if (!paddleDiagnosticPanel) {
      const panel = document.createElement('div');
      panel.id = 'or-app-paddle-diagnostics';
      Object.assign(panel.style, {
        position: 'fixed',
        left: 'max(8px, env(safe-area-inset-left))',
        bottom: 'max(8px, env(safe-area-inset-bottom))',
        zIndex: '2147483647',
        maxWidth: 'calc(100vw - 16px)',
        padding: '8px',
        borderRadius: '8px',
        background: 'rgba(17, 24, 39, 0.94)',
        color: '#fff',
        font: '12px system-ui, sans-serif',
        boxSizing: 'border-box',
      });
      const label = document.createElement('div');
      label.dataset.role = 'paddle-status';
      label.style.marginBottom = '6px';
      const copy = document.createElement('button');
      copy.type = 'button';
      copy.textContent = 'COPY DIAGNOSTICS';
      copy.style.marginRight = '6px';
      copy.onclick = () => copyPaddleDiagnostics();
      const small = document.createElement('button');
      small.type = 'button';
      small.textContent = 'RUN SMALL TEST';
      small.onclick = () => runPaddleSmallFixtureDiagnostic();
      panel.append(label, copy, small);
      document.body.appendChild(panel);
      paddleDiagnosticPanel = panel;
    }
    const label = paddleDiagnosticPanel.querySelector(
      '[data-role="paddle-status"]',
    );
    if (label) label.textContent = `PADDLE PoC  ${status}`;
  }

  function paddleDiagnosticsSnapshot() {
    return lastPaddleDiagnostics
      ? JSON.parse(JSON.stringify(lastPaddleDiagnostics))
      : null;
  }

  async function copyPaddleDiagnostics() {
    const text = JSON.stringify(paddleDiagnosticsSnapshot(), null, 2);
    if (typeof navigator !== 'undefined' && navigator.clipboard &&
        navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
      updatePaddleDiagnosticPanel('DIAGNOSTICS COPIED');
      return true;
    }
    if (typeof document === 'undefined' || !document.body) return false;
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    const copied = document.execCommand && document.execCommand('copy');
    area.remove();
    updatePaddleDiagnosticPanel(copied ? 'DIAGNOSTICS COPIED' : 'COPY FAILED');
    return Boolean(copied);
  }

  async function runPaddleSmallFixtureDiagnostic() {
    if (typeof document === 'undefined' ||
        typeof document.createElement !== 'function') return null;
    const canvas = document.createElement('canvas');
    canvas.width = 640;
    canvas.height = 360;
    const context = canvas.getContext('2d', { alpha: false });
    context.fillStyle = '#fff';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = '#111';
    context.font = '24px sans-serif';
    const lines = [
      '栄養成分表示 100g当たり',
      'エネルギー 201kcal',
      'たんぱく質 2.3g',
      '脂質 12.4g',
      '炭水化物 21.5g',
    ];
    lines.forEach((line, index) => context.fillText(line, 24, 48 + index * 54));
    return recognizePaddleNutrition(canvas, 'small-fixture', false);
  }

  async function paddleWorker() {
    if (!paddleWorkerPromise) {
      paddleWorkerPromise = (async () => {
        paddleRuntimeLoadCount += 1;
        const injectedFactory = window.__OR_APP_PADDLE_FACTORY__;
        await probePaddleAsset('runtime-module', paths.paddleModule, 'P1');
        if (!injectedFactory && !paddleModulePromise) {
          paddleModulePromise = tracePaddleStage(
            'P2',
            () => import(paths.paddleModule),
            { assetUrl: paths.paddleModule },
          );
        }
        const PaddleOCR = injectedFactory
          ? { create: injectedFactory }
          : (await paddleModulePromise).PaddleOCR;
        if (injectedFactory) {
          recordPaddleStage('P2', 'success', { injectedFactory: true });
        }
        await probePaddleAsset('worker-script', paths.paddleWorker, 'P3');
        await probePaddleAsset('wasm-standard', paths.paddleWasmStandard, 'P5');
        await probePaddleAsset('wasm-jsep', paths.paddleWasmJsep, 'P5');
        await probePaddleAsset(
          'detection-model',
          paths.paddleDetectionModel,
          'P7',
        );
        recordPaddleStage('P8', 'success', {
          assetUrl: paths.paddleDetectionModel,
        });
        await probePaddleAsset(
          'recognition-model',
          paths.paddleRecognitionModel,
          'P11',
        );
        recordPaddleStage('P12', 'success', {
          assetUrl: paths.paddleRecognitionModel,
        });
        const startedAt = performance.now();
        recordPaddleStage('P9', 'started', {
          note: 'combined Paddle worker initialization',
        });
        recordPaddleStage('P13', 'started', {
          note: 'combined Paddle worker initialization',
        });
        const worker = await tracePaddleStage('P5', () => PaddleOCR.create({
          lang: 'ch',
          ocrVersion: 'PP-OCRv5',
          worker: injectedFactory ? true : {
            createWorker: () => {
              const workerStarted = diagnosticNow();
              recordPaddleStage('P3', 'started', {
                assetUrl: paths.paddleWorker,
              });
              const instance = new Worker(paths.paddleWorker, { type: 'module' });
              instance.addEventListener('error', (event) => {
                const error = new Error(event.message || 'Paddle worker error');
                error.name = 'PaddleWorkerError';
                recordPaddleStage('P3', 'failure', {
                  durationMs: Math.round(diagnosticNow() - workerStarted),
                  assetUrl: paths.paddleWorker,
                });
                failPaddleDiagnostics(error, 'P3');
              });
              instance.addEventListener('messageerror', () => {
                const error = new Error('Paddle worker message could not be decoded');
                error.name = 'PaddleWorkerMessageError';
                failPaddleDiagnostics(error, 'P3');
              });
              recordPaddleStage('P3', 'success', {
                durationMs: Math.round(diagnosticNow() - workerStarted),
                assetUrl: paths.paddleWorker,
              });
              return instance;
            },
          },
          textDetectionModelName: 'PP-OCRv5_mobile_det',
          textDetectionModelAsset: { url: paths.paddleDetectionModel },
          textRecognitionModelName: 'PP-OCRv5_mobile_rec',
          textRecognitionModelAsset: { url: paths.paddleRecognitionModel },
          ortOptions: {
            backend: 'wasm',
            wasmPaths: paths.paddleWasm,
            numThreads: 1,
            simd: true,
          },
        }), {
          combinedInitialization: true,
          backend: 'wasm',
          numThreads: 1,
        });
        paddleModelLoadCount += 1;
        paddleWorkerInstance = worker;
        activePaddleDiagnostics.actualExecutedEngine = 'paddle';
        activePaddleDiagnostics.runtimeVersion = '0.4.2';
        activePaddleDiagnostics.model =
          'PP-OCRv5_mobile_det + PP-OCRv5_mobile_rec';
        activePaddleDiagnostics.initializationMs =
          Math.round(performance.now() - startedAt);
        activePaddleDiagnostics.initialization = worker.getInitializationSummary();
        recordPaddleStage('P4', 'success');
        recordPaddleStage('P6', 'success', {
          initialization: activePaddleDiagnostics.initialization,
          combinedInitializationMs: activePaddleDiagnostics.initializationMs,
        });
        recordPaddleStage('P10', 'success', {
          combinedInitialization: true,
          combinedInitializationMs: activePaddleDiagnostics.initializationMs,
        });
        recordPaddleStage('P14', 'success', {
          combinedInitialization: true,
          combinedInitializationMs: activePaddleDiagnostics.initializationMs,
        });
        return worker;
      })().catch((error) => {
        paddleWorkerPromise = undefined;
        paddleWorkerInstance = undefined;
        failPaddleDiagnostics(error);
        throw error;
      });
    } else if (activePaddleDiagnostics && paddleWorkerInstance) {
      activePaddleDiagnostics.actualExecutedEngine = 'paddle';
      for (const stageId of ['P2', 'P4', 'P6', 'P10', 'P14']) {
        recordPaddleStage(stageId, 'success', { cached: true });
      }
    }
    return paddleWorkerPromise;
  }

  async function resetPaddleWorker() {
    const worker = paddleWorkerInstance;
    paddleWorkerPromise = undefined;
    paddleWorkerInstance = undefined;
    if (worker) {
      try {
        await worker.dispose();
      } catch (_) {
        // The worker may already have stopped after a runtime failure.
      }
    }
  }

  function recognizePaddlePass(canvas, source = 'capture', reuseRun = false) {
    const recognize = async () => {
      ensurePaddleDiagnostics(source, canvas, !reuseRun, 'paddle');
      if (!activePaddleDiagnostics.stages.some(
        (stage) => stage.stageId === 'P15',
      )) {
        recordPaddleStage('P15', 'success', { providedCanvas: true });
        recordPaddleStage('P16', 'success', {
          decodedWidth: Number(canvas.width) || null,
          decodedHeight: Number(canvas.height) || null,
          providedCanvas: true,
        });
        recordPaddleStage('P17', 'success', { providedCanvas: true });
        recordPaddleStage('P18', 'success', {
          ocrWidth: Number(canvas.width) || null,
          ocrHeight: Number(canvas.height) || null,
          providedCanvas: true,
        });
      }
      const worker = await paddleWorker();
      const startedAt = performance.now();
      let timeout;
      let result;
      try {
        recordPaddleStage('P19', 'started', {
          sourceWidth: Number(canvas.width) || null,
          sourceHeight: Number(canvas.height) || null,
        });
        recordPaddleStage('P22', 'started', {
          note: 'Paddle predict performs detection then recognition',
        });
        [result] = await Promise.race([
          worker.predict(canvas),
          new Promise((_, reject) => {
            timeout = setTimeout(
              () => {
                if (activePaddleDiagnostics) {
                  activePaddleDiagnostics.watchdogFired = true;
                }
                reject(new Error('Paddle OCR recognition timed out'));
              },
              25000,
            );
          }),
        ]);
      } catch (error) {
        failPaddleDiagnostics(error);
        await resetPaddleWorker();
        throw error;
      } finally {
        clearTimeout(timeout);
      }
      const durationMs = Math.round(performance.now() - startedAt);
      activePaddleDiagnostics.dimensions.sourceWidth = result.image.width;
      activePaddleDiagnostics.dimensions.sourceHeight = result.image.height;
      activePaddleDiagnostics.durationMs = durationMs;
      activePaddleDiagnostics.detectedTextCount = result.metrics.detectedBoxes;
      activePaddleDiagnostics.recognizedTextCount = result.metrics.recognizedCount;
      activePaddleDiagnostics.detectionMs = Math.round(result.metrics.detMs);
      activePaddleDiagnostics.recognitionMs = Math.round(result.metrics.recMs);
      activePaddleDiagnostics.confidence = result.items.map((item) => item.score);
      activePaddleDiagnostics.inferenceRuntime = result.runtime;
      recordPaddleStage('P20', 'success', {
        durationMs: Math.round(result.metrics.detMs),
      });
      recordPaddleStage('P21', 'success', {
        detectedBoxes: result.metrics.detectedBoxes,
      });
      recordPaddleStage('P23', 'success', {
        durationMs: Math.round(result.metrics.recMs),
      });
      recordPaddleStage('P24', 'success', {
        recognizedBlocks: result.metrics.recognizedCount,
        cropCount: result.metrics.detectedBoxes,
      });
      return {
        engineId: 'paddle',
        text: result.items.map((item) => item.text).join('\n'),
        items: result.items,
        source: result.image,
        durationMs,
        runtime: result.runtime,
      };
    };
    const result = paddleQueue.then(recognize, recognize);
    paddleQueue = result.catch(() => {});
    return result;
  }

  function selectImage(preferCamera) {
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      // The gallery path intentionally leaves `capture` unset. iOS/Safari
      // owns any extra choices in its native file-source sheet; the app never
      // routes a PHOTO LIBRARY selection through camera capture itself.
      if (preferCamera) input.setAttribute('capture', 'environment');
      input.style.display = 'none';
      document.body.appendChild(input);
      let finished = false;
      let focusTimer;
      const finish = (value) => {
        if (finished) return;
        finished = true;
        clearTimeout(focusTimer);
        window.removeEventListener('focus', onFocus);
        input.remove();
        resolve(value);
      };
      const onFocus = () => {
        focusTimer = setTimeout(() => {
          if (!input.files || input.files.length === 0) finish(null);
        }, 1000);
      };
      window.addEventListener('focus', onFocus, { once: true });
      input.addEventListener('change', () => {
        const file = input.files && input.files[0];
        if (!file) return finish(null);
        const reader = new FileReader();
        reader.onload = () => finish(String(reader.result));
        reader.onerror = () => finish(null);
        reader.readAsDataURL(file);
      }, { once: true });
      input.click();
    });
  }

  async function ocrWorker() {
    if (!workerPromise) {
      workerPromise = (async () => {
        await loadScript(paths.tesseract);
        workerInstance = await Tesseract.createWorker('jpn', 1, {
          workerPath: paths.worker,
          corePath: paths.core,
          langPath: paths.language,
          gzip: true,
          cacheMethod: 'none',
        });
        return workerInstance;
      })();
    }
    return workerPromise;
  }

  async function resetOcrWorker() {
    const worker = workerInstance;
    workerPromise = undefined;
    workerInstance = undefined;
    if (worker) {
      try {
        await worker.terminate();
      } catch (_) {
        // The worker may already have stopped after a runtime failure.
      }
    }
  }

  function recognizePass(dataUrl, {
    outputs,
    whitelist,
    pageSegmentationMode,
  } = {}) {
    const recognize = async () => {
      const worker = await ocrWorker();
      let timeout;
      try {
        if (whitelist || pageSegmentationMode) {
          await worker.setParameters({
            ...(whitelist ? { tessedit_char_whitelist: whitelist } : {}),
            ...(pageSegmentationMode ? {
              tessedit_pageseg_mode: String(pageSegmentationMode),
            } : {}),
          });
        }
        const result = await Promise.race([
          worker.recognize(dataUrl, {}, outputs),
          new Promise((_, reject) => {
            timeout = setTimeout(
              () => reject(new Error('OCR recognition timed out')),
              25000,
            );
          }),
        ]);
        return result.data;
      } catch (error) {
        await resetOcrWorker();
        throw error;
      } finally {
        clearTimeout(timeout);
        if ((whitelist || pageSegmentationMode) && workerInstance === worker) {
          await worker.setParameters({
            ...(whitelist ? { tessedit_char_whitelist: '' } : {}),
            ...(pageSegmentationMode ? { tessedit_pageseg_mode: '3' } : {}),
          });
        }
      }
    };
    const result = ocrQueue.then(recognize, recognize);
    ocrQueue = result.catch(() => {});
    return result;
  }

  async function recognizeSinglePass(dataUrl) {
    const data = await recognizePass(dataUrl);
    return data.text || '';
  }

  const recognizeLayoutPass = (dataUrl) => recognizePass(dataUrl, {
    outputs: { text: true, tsv: true },
  });

  async function imageMetadata(dataUrl) {
    const response = await fetch(dataUrl);
    const buffer = await (await response.blob()).arrayBuffer();
    const view = new DataView(buffer);
    const metadata = { width: null, height: null, orientation: 1 };
    if (view.byteLength < 4 || view.getUint16(0) !== 0xffd8) return metadata;
    let offset = 2;
    while (offset + 4 <= view.byteLength) {
      const marker = view.getUint16(offset);
      offset += 2;
      if ((marker & 0xff00) !== 0xff00 || marker === 0xffd9) break;
      const length = view.getUint16(offset);
      if (length < 2 || offset + length > view.byteLength) break;
      const dataOffset = offset + 2;
      if ([0xffc0, 0xffc1, 0xffc2, 0xffc3, 0xffc5, 0xffc6, 0xffc7,
        0xffc9, 0xffca, 0xffcb, 0xffcd, 0xffce, 0xffcf].includes(marker)) {
        metadata.height = view.getUint16(dataOffset + 1);
        metadata.width = view.getUint16(dataOffset + 3);
      }
      if (marker === 0xffe1 && length >= 16 &&
          view.getUint32(dataOffset) === 0x45786966) {
        const tiff = dataOffset + 6;
        const little = view.getUint16(tiff) === 0x4949;
        const ifd = tiff + view.getUint32(tiff + 4, little);
        if (ifd + 2 <= view.byteLength) {
          const entries = view.getUint16(ifd, little);
          for (let index = 0; index < entries; index += 1) {
            const entry = ifd + 2 + index * 12;
            if (entry + 12 > view.byteLength) break;
            if (view.getUint16(entry, little) === 0x0112) {
              metadata.orientation = view.getUint16(entry + 8, little);
              break;
            }
          }
        }
      }
      offset += length;
    }
    return metadata;
  }

  function ocrGeometry(width, height, guide) {
    const sourceX = Math.round(width * guide.left);
    const sourceY = Math.round(height * guide.top);
    const sourceWidth = Math.max(1, Math.round(width * guide.width));
    const sourceHeight = Math.max(1, Math.round(height * guide.height));
    const maxLongEdge = 2560;
    const resizeTargetLongEdge = 2048;
    const maximumUpscale = 2;
    const sourceLongEdge = Math.max(sourceWidth, sourceHeight);
    const downscale = Math.min(1, maxLongEdge / sourceLongEdge);
    const upscale = sourceLongEdge < resizeTargetLongEdge
      ? Math.min(maximumUpscale, resizeTargetLongEdge / sourceLongEdge)
      : 1;
    const scale = downscale < 1 ? downscale : upscale;
    return {
      sourceX,
      sourceY,
      sourceWidth,
      sourceHeight,
      inputWidth: Math.max(1, Math.round(sourceWidth * scale)),
      inputHeight: Math.max(1, Math.round(sourceHeight * scale)),
      resizeScale: scale,
      resizeMethod: scale === 1
        ? 'none'
        : scale < 1
          ? 'canvas-downscale'
          : 'canvas-image-smoothing-upscale',
    };
  }

  function canvasFromImage(dataUrl, mode) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = async () => {
        const metadata = await imageMetadata(dataUrl).catch(() => ({
          width: null,
          height: null,
          orientation: 1,
        }));
        const guide = mode === 'nutrition' ? ocrGuide : packageGuide;
        const geometry = ocrGeometry(
          image.naturalWidth,
          image.naturalHeight,
          guide,
        );
        // Keep one unscaled canvas for nutrition discovery. A detected table
        // is subsequently cropped from these decoded pixels, never from an
        // already compressed OCR variant.
        const sourceCanvas = document.createElement('canvas');
        sourceCanvas.width = geometry.sourceWidth;
        sourceCanvas.height = geometry.sourceHeight;
        const sourceContext = sourceCanvas.getContext('2d', { alpha: false });
        sourceContext.drawImage(
          image,
          geometry.sourceX,
          geometry.sourceY,
          geometry.sourceWidth,
          geometry.sourceHeight,
          0,
          0,
          sourceCanvas.width,
          sourceCanvas.height,
        );
        const canvas = document.createElement('canvas');
        canvas.width = geometry.inputWidth;
        canvas.height = geometry.inputHeight;
        const context = canvas.getContext('2d', { alpha: false });
        context.imageSmoothingEnabled = true;
        if ('imageSmoothingQuality' in context) {
          context.imageSmoothingQuality = 'high';
        }
        // Preserve the original single resample for the normal fallback path.
        // `sourceCanvas` above exists only so an accepted discovery crop can
        // be taken from decoded pixels without a repeated JPEG/canvas chain.
        context.drawImage(
          image,
          geometry.sourceX,
          geometry.sourceY,
          geometry.sourceWidth,
          geometry.sourceHeight,
          0,
          0,
          canvas.width,
          canvas.height,
        );
        canvas.__orNutritionSourceCanvas = sourceCanvas;
        canvas.__orNutritionGuideGeometry = geometry;
        lastPhotoDiagnostics = {
          mode,
          originalWidth: metadata.width,
          originalHeight: metadata.height,
          decodedWidth: image.naturalWidth,
          decodedHeight: image.naturalHeight,
          orientation: metadata.orientation,
          orientationAppliedByDecoder:
            metadata.orientation >= 5 && metadata.orientation <= 8
              ? image.naturalWidth === metadata.height && image.naturalHeight === metadata.width
              : true,
          imageFormat: String(dataUrl).slice(5, String(dataUrl).indexOf(';')),
          cropX: geometry.sourceX,
          cropY: geometry.sourceY,
          cropWidth: geometry.sourceWidth,
          cropHeight: geometry.sourceHeight,
          preResizeWidth: geometry.sourceWidth,
          preResizeHeight: geometry.sourceHeight,
          inputWidth: canvas.width,
          inputHeight: canvas.height,
          resizeScale: geometry.resizeScale,
          resizeMethod: geometry.resizeMethod,
          passCount: 0,
          passDurationsMs: [],
          autoNutritionCrop: {
            status: 'FALLBACK_ORIGINAL',
            rect: null,
            reason: mode === 'nutrition'
              ? 'nutrition-discovery-not-run'
              : 'not-nutrition-mode',
          },
        };
        resolve(canvas);
      };
      image.onerror = reject;
      image.src = dataUrl;
    });
  }

  function resizedOcrCanvas(source) {
    const sourceLongEdge = Math.max(source.width, source.height);
    const scale = sourceLongEdge > 2560
      ? 2560 / sourceLongEdge
      : sourceLongEdge < 2048
        ? Math.min(2, 2048 / sourceLongEdge)
        : 1;
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(source.width * scale));
    canvas.height = Math.max(1, Math.round(source.height * scale));
    const context = canvas.getContext('2d', { alpha: false });
    context.imageSmoothingEnabled = true;
    if ('imageSmoothingQuality' in context) context.imageSmoothingQuality = 'high';
    context.drawImage(source, 0, 0, canvas.width, canvas.height);
    return canvas;
  }

  function nutritionHeadingWord(word) {
    const normalized = normalizeOcrToken(word.text);
    return normalized.includes('栄養成分表示') || normalized.includes('栄養成分') ||
      normalized.includes('栄養表示');
  }

  function clampNutritionRect(rect, width, height) {
    const left = Math.max(0, Math.floor(rect.left));
    const top = Math.max(0, Math.floor(rect.top));
    const right = Math.min(width, Math.ceil(rect.right));
    const bottom = Math.min(height, Math.ceil(rect.bottom));
    if (right - left < 32 || bottom - top < 32) return null;
    return { left, top, right, bottom, width: right - left, height: bottom - top };
  }

  // This is deliberately only a geometry discovery stage. It accepts no
  // nutrition values and does not alter later ownership/consensus decisions.
  function nutritionRegionFromDiscovery(canvas, tsv) {
    const words = tsvWords(tsv);
    const groups = lineGroups(words);
    const anchors = nutritionAnchors(groups);
    const values = numericValues(groups).filter((value) =>
      value.unit === 'g' || value.unit === 'mg' || value.unit === 'kcal',
    );
    const fields = new Set(anchors.map((anchor) => anchor.field));
    const headings = words.filter(nutritionHeadingWord);
    if (fields.size < 2 || values.length < 2) {
      return { status: 'FALLBACK_ORIGINAL', rect: null, reason: 'insufficient-nutrition-row-cluster' };
    }
    const evidence = [...anchors, ...values];
    const evidenceBox = boxForWords(evidence);
    const rowHeight = Math.max(
      12,
      ...evidence.map((item) => Number(item.height) || 0),
    );
    const nearbyHeadings = headings.filter((heading) =>
      heading.top + heading.height >= evidenceBox.top - rowHeight * 3 &&
      heading.top <= evidenceBox.bottom + rowHeight,
    );
    const included = [...evidence, ...nearbyHeadings];
    const box = boxForWords(included);
    const paddingX = Math.max(rowHeight * 1.6, box.width * 0.08);
    const paddingY = Math.max(rowHeight * 1.25, box.height * 0.08);
    const rect = clampNutritionRect({
      left: box.left - paddingX,
      top: box.top - paddingY,
      right: box.right + paddingX,
      bottom: box.bottom + paddingY,
    }, canvas.width, canvas.height);
    if (!rect || rect.width * rect.height >= canvas.width * canvas.height * 0.985) {
      return { status: 'FALLBACK_ORIGINAL', rect: null, reason: 'region-not-smaller-than-source' };
    }
    return {
      status: 'APPLIED',
      rect,
      reason: nearbyHeadings.length
        ? 'nutrition-header+row-cluster'
        : 'nutrition-label+value-row-cluster',
    };
  }

  function cropNutritionCanvas(canvas, region) {
    const source = canvas.__orNutritionSourceCanvas || canvas;
    const guide = canvas.__orNutritionGuideGeometry || {
      sourceX: 0, sourceY: 0, sourceWidth: source.width, sourceHeight: source.height,
    };
    const scaleX = source.width / canvas.width;
    const scaleY = source.height / canvas.height;
    const sourceRect = clampNutritionRect({
      left: region.left * scaleX,
      top: region.top * scaleY,
      right: region.right * scaleX,
      bottom: region.bottom * scaleY,
    }, source.width, source.height);
    if (!sourceRect) return null;
    const croppedSource = document.createElement('canvas');
    croppedSource.width = sourceRect.width;
    croppedSource.height = sourceRect.height;
    croppedSource.getContext('2d', { alpha: false }).drawImage(
      source,
      sourceRect.left,
      sourceRect.top,
      sourceRect.width,
      sourceRect.height,
      0,
      0,
      croppedSource.width,
      croppedSource.height,
    );
    const cropped = resizedOcrCanvas(croppedSource);
    cropped.__orNutritionSourceCanvas = croppedSource;
    cropped.__orNutritionGuideGeometry = {
      sourceX: guide.sourceX + sourceRect.left,
      sourceY: guide.sourceY + sourceRect.top,
      sourceWidth: sourceRect.width,
      sourceHeight: sourceRect.height,
    };
    return { canvas: cropped, sourceRect, guide: cropped.__orNutritionGuideGeometry };
  }

  async function prepareNutritionCanvasForOcr(canvas) {
    try {
      const discovery = await recognizeLayoutPass(canvas.toDataURL('image/jpeg', 0.9));
      const candidate = nutritionRegionFromDiscovery(canvas, discovery.tsv || '');
      if (candidate.status !== 'APPLIED') {
        if (lastPhotoDiagnostics) lastPhotoDiagnostics.autoNutritionCrop = candidate;
        return canvas;
      }
      const cropped = cropNutritionCanvas(canvas, candidate.rect);
      if (!cropped) {
        if (lastPhotoDiagnostics) {
          lastPhotoDiagnostics.autoNutritionCrop = {
            status: 'FALLBACK_ORIGINAL', rect: null, reason: 'invalid-crop-geometry',
          };
        }
        return canvas;
      }
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.autoNutritionCrop = {
          status: 'APPLIED',
          rect: {
            x: cropped.guide.sourceX, y: cropped.guide.sourceY,
            width: cropped.guide.sourceWidth, height: cropped.guide.sourceHeight,
          },
          reason: candidate.reason,
        };
        lastPhotoDiagnostics.cropX = cropped.guide.sourceX;
        lastPhotoDiagnostics.cropY = cropped.guide.sourceY;
        lastPhotoDiagnostics.cropWidth = cropped.guide.sourceWidth;
        lastPhotoDiagnostics.cropHeight = cropped.guide.sourceHeight;
        lastPhotoDiagnostics.preResizeWidth = cropped.guide.sourceWidth;
        lastPhotoDiagnostics.preResizeHeight = cropped.guide.sourceHeight;
        lastPhotoDiagnostics.inputWidth = cropped.canvas.width;
        lastPhotoDiagnostics.inputHeight = cropped.canvas.height;
        lastPhotoDiagnostics.resizeScale = cropped.canvas.width /
          Math.max(1, cropped.guide.sourceWidth);
        lastPhotoDiagnostics.resizeMethod = 'nutrition-discovery-crop+canvas-resize';
      }
      return cropped.canvas;
    } catch (_) {
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.autoNutritionCrop = {
          status: 'FALLBACK_ORIGINAL', rect: null, reason: 'discovery-ocr-unavailable',
        };
      }
      return canvas;
    }
  }

  function processedVariant(source, contrast) {
    const canvas = document.createElement('canvas');
    canvas.width = source.width;
    canvas.height = source.height;
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(source, 0, 0);
    const image = context.getImageData(0, 0, canvas.width, canvas.height);
    for (let index = 0; index < image.data.length; index += 4) {
      const luminance =
        image.data[index] * 0.299 +
        image.data[index + 1] * 0.587 +
        image.data[index + 2] * 0.114;
      const value = Math.max(0, Math.min(255, (luminance - 128) * contrast + 128));
      image.data[index] = value;
      image.data[index + 1] = value;
      image.data[index + 2] = value;
    }
    context.putImageData(image, 0, 0);
    return canvas.toDataURL('image/png');
  }

  function thresholdVariant(source, threshold = 170) {
    const canvas = document.createElement('canvas');
    canvas.width = source.width;
    canvas.height = source.height;
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(source, 0, 0);
    const image = context.getImageData(0, 0, canvas.width, canvas.height);
    for (let index = 0; index < image.data.length; index += 4) {
      const luminance = image.data[index] * 0.299 + image.data[index + 1] * 0.587 + image.data[index + 2] * 0.114;
      const value = luminance < threshold ? 0 : 255;
      image.data[index] = value;
      image.data[index + 1] = value;
      image.data[index + 2] = value;
    }
    context.putImageData(image, 0, 0);
    return canvas.toDataURL('image/png');
  }

  function ocrVariants(canvas, mode) {
    return [
      { name: 'original', dataUrl: canvas.toDataURL('image/jpeg', 0.94) },
      { name: 'grayscale', dataUrl: processedVariant(canvas, 1) },
      {
        name: 'moderate-contrast',
        dataUrl: processedVariant(canvas, mode === 'nutrition' ? 1.35 : 1.22),
      },
    ];
  }

  const nutritionLabels = Object.freeze({
    energy: ['エネルギー', '熱量'],
    protein: ['たんぱく質', 'タンパク質', '蛋白質'],
    fat: ['脂質'],
    carbohydrate: ['炭水化物'],
    sugar: ['糖質'],
    fiber: ['食物繊維'],
    salt: ['食塩相当量'],
  });
  const nutritionBasisAliases = Object.freeze([
    '製品1個あたり',
    '1個あたり',
    '100gあたり',
    '100mlあたり',
    '1包装あたり',
  ]);
  const structuredMarker = '[[OR_STRUCTURED_NUTRITION]]\n';
  const decisionMarker = '\n[[OR_OCR_DECISIONS]]\n';
  const nutritionBasisPattern =
    /(?:製品\s*)?(?:100\s*(?:g|m[lL])|(?:\d+\s*)?(?:包装|袋|個|本|枚|食)(?:\s*\d+(?:[.,]\d+)?\s*(?:g|m[lL]))?)\s*(?:当たり|あたり)/i;

  function normalizeOcrToken(value) {
    return String(value || '')
      .replace(/[ \t　]/g, '')
      .replace(/．/g, '.')
      .replace(/，/g, ',')
      .replace(/[Ａ-Ｚａ-ｚ]/g, (letter) =>
        String.fromCharCode(letter.charCodeAt(0) - 0xfee0),
      )
      .replace(/[０-９]/g, (digit) =>
        String.fromCharCode(digit.charCodeAt(0) - 0xff10 + 0x30),
      )
      .replace(/ｇ/gi, 'g');
  }

  function editDistance(first, second) {
    const left = [...String(first || '')];
    const right = [...String(second || '')];
    const previous = Array.from({ length: right.length + 1 }, (_, index) => index);
    for (let row = 1; row <= left.length; row += 1) {
      const current = [row];
      for (let column = 1; column <= right.length; column += 1) {
        current[column] = Math.min(
          current[column - 1] + 1,
          previous[column] + 1,
          previous[column - 1] + (left[row - 1] === right[column - 1] ? 0 : 1),
        );
      }
      previous.splice(0, previous.length, ...current);
    }
    return previous[right.length];
  }

  function recoveryConfidenceValue(status) {
    return status === 'EXACT' ? 1 :
      status === 'RECOVERED_HIGH' ? 0.86 :
        status === 'RECOVERED_MEDIUM' ? 0.64 : 0;
  }

  function recoverUnit(rawSuffix) {
    const raw = String(rawSuffix || '');
    const normalized = normalizeOcrToken(raw).toLowerCase();
    const exact = /^(kcal|mg|g|ml)$/.exec(normalized);
    if (exact) {
      const canonicalRaw = raw.replace(/[ \t　]/g, '').toLowerCase();
      const status = canonicalRaw === exact[1] ? 'EXACT' : 'RECOVERED_HIGH';
      return {
        unit: exact[1],
        status,
        recoveryMethod: status === 'EXACT' ? 'exact-unit' : 'safe-unit-normalization',
        recoveryConfidence: recoveryConfidenceValue(status),
        ambiguity: null,
      };
    }
    const fuzzyVariants = [
      normalized,
      normalized.replace(/[^a-z]/g, ''),
      normalized.replace(/[^a-z]/g, '').replace(/(.)\1+/g, '$1'),
    ];
    const distance = Math.min(...fuzzyVariants.map((candidate) =>
      editDistance(candidate, 'kcal'),
    ));
    if (normalized.length >= 3 && normalized.length <= 7 &&
        distance <= 2 && /k/i.test(normalized) && /l/i.test(normalized)) {
      const status = distance === 1 ? 'RECOVERED_HIGH' : 'RECOVERED_MEDIUM';
      return {
        unit: 'kcal',
        status,
        recoveryMethod: 'limited-fuzzy-unit',
        recoveryConfidence: recoveryConfidenceValue(status),
        ambiguity: null,
      };
    }
    return {
      unit: null,
      status: 'REJECTED',
      recoveryMethod: null,
      recoveryConfidence: 0,
      ambiguity: raw ? 'unsupported-or-ambiguous-unit' : null,
    };
  }

  function recoverNumericToken(rawToken) {
    const raw = String(rawToken || '');
    const normalized = normalizeOcrToken(raw)
      .replace(/(\d),(?=\d)/g, '$1.');
    const ambiguousSpan = /\d[OolI@][\d.]/i.test(normalized) ||
      /\d[\d.]*[OolI@][\d.]*\d/i.test(normalized) ||
      /^\D*\d+(?:\.\d+)?@(?=[a-z])/i.test(normalized);
    if (ambiguousSpan) {
      return {
        rawToken: raw,
        normalizedToken: normalized,
        normalizationCandidates: [],
        candidateType: 'AMBIGUOUS_NUMERIC',
        numericValue: null,
        unit: null,
        unitStatus: 'REJECTED',
        recoveryMethod: 'ambiguous-character-preserved',
        recoveryConfidence: 0,
        ambiguity: 'multiple-plausible-character-interpretations',
      };
    }
    const numeric = /\d+(?:\.\d+)?/.exec(normalized);
    if (!numeric) return null;
    const value = Number(numeric[0]);
    if (!Number.isFinite(value) || value < 0) return null;
    const suffix = normalized.slice(numeric.index + numeric[0].length)
      .replace(/^[^A-Za-zａ-ｚＡ-Ｚ]+/, '');
    const unit = recoverUnit(suffix);
    const unitlessToken = /^\d+(?:\.\d+)?$/.test(normalized);
    const safeNumericSubstring = /^[^\d@]*\d+(?:\.\d+)?[^\d@]*$/.test(normalized);
    if (!unit.unit && !unitlessToken && !safeNumericSubstring) return null;
    if (!unit.unit) {
      const exactToken = /^\d+(?:\.\d+)?$/.test(raw.trim());
      return {
        rawToken: raw,
        normalizedToken: normalized,
        normalizationCandidates: normalized === raw ? [] : [normalized],
        candidateType: 'NUMERIC_WITHOUT_UNIT',
        numericValue: value,
        unit: null,
        unitStatus: 'MISSING',
        recoveryMethod: exactToken
          ? 'exact-unitless-numeric'
          : 'safe-numeric-substring-unitless',
        recoveryConfidence: exactToken ? 0.75 : 0.64,
        ambiguity: 'unit-not-observed',
      };
    }
    const exactToken = /^(\d+(?:\.\d+)?)\s*(kcal|mg|g|ml)$/i.test(raw.trim());
    const status = exactToken && unit.status === 'EXACT' ? 'EXACT' :
      unit.status === 'RECOVERED_MEDIUM' ? 'RECOVERED_MEDIUM' : 'RECOVERED_HIGH';
    return {
      rawToken: raw,
      normalizedToken: normalized,
      normalizationCandidates: normalized === raw ? [] : [normalized],
      candidateType: 'NUMERIC_WITH_UNIT',
      numericValue: value,
      unit: unit.unit,
      unitStatus: unit.status,
      recoveryMethod: exactToken
        ? 'exact-numeric-unit'
        : `numeric-substring+${unit.recoveryMethod}`,
      recoveryConfidence: Math.min(
        recoveryConfidenceValue(status),
        unit.recoveryConfidence,
      ),
      ambiguity: unit.ambiguity,
    };
  }

  function tsvWords(tsv) {
    if (!tsv) return [];
    const rows = String(tsv).split(/\r?\n/).slice(1);
    const words = [];
    for (const row of rows) {
      const columns = row.split('\t');
      if (columns.length < 12 || columns[0] !== '5') continue;
      const text = columns.slice(11).join('\t').trim();
      if (!text) continue;
      words.push({
        lineKey: columns.slice(1, 5).join(':'),
        left: Number(columns[6]),
        top: Number(columns[7]),
        width: Number(columns[8]),
        height: Number(columns[9]),
        confidence: Number(columns[10]),
        text,
      });
    }
    return words.filter((word) =>
      [word.left, word.top, word.width, word.height].every(Number.isFinite),
    );
  }

  function paddleItemBox(item) {
    const points = Array.isArray(item.poly) ? item.poly : [];
    const xs = points.map((point) => Number(point.x ?? point[0]));
    const ys = points.map((point) => Number(point.y ?? point[1]));
    if (!xs.length || ![...xs, ...ys].every(Number.isFinite)) return null;
    const left = Math.min(...xs);
    const top = Math.min(...ys);
    const right = Math.max(...xs);
    const bottom = Math.max(...ys);
    return {
      left,
      top,
      width: Math.max(1, right - left),
      height: Math.max(1, bottom - top),
    };
  }

  function paddleTokenRanges(text) {
    if (/栄養成分表示|当たり/.test(String(text || ''))) {
      return [{ text: String(text || ''), start: 0, end: String(text || '').length }];
    }
    const tokenPattern = new RegExp(
      `${Object.values(nutritionLabels).flat().join('|')}|` +
      String.raw`\d+(?:[.,]\d+)?\s*(?:kcal|mg|g|m[lL])`,
      'gi',
    );
    const ranges = [...String(text || '').matchAll(tokenPattern)].map((match) => ({
      text: match[0],
      start: match.index,
      end: match.index + match[0].length,
    }));
    return ranges.length ? ranges : [{ text: String(text || ''), start: 0, end: text.length }];
  }

  function paddleWords(items) {
    const rows = [];
    for (const item of items || []) {
      const box = paddleItemBox(item);
      const text = String(item.text || '').trim();
      if (!box || !text) continue;
      let row = rows.find((candidate) =>
        Math.abs(candidate.centerY - (box.top + box.height / 2)) <=
          Math.max(candidate.height, box.height) * 0.65,
      );
      if (!row) {
        row = { id: rows.length + 1, centerY: box.top + box.height / 2, height: box.height };
        rows.push(row);
      }
      for (const token of paddleTokenRanges(text)) {
        const length = Math.max(1, text.length);
        const left = box.left + box.width * token.start / length;
        const right = box.left + box.width * token.end / length;
        row.centerY = (row.centerY + box.top + box.height / 2) / 2;
        row.height = Math.max(row.height, box.height);
        if (!row.words) row.words = [];
        row.words.push({
          lineKey: `paddle:${row.id}`,
          left,
          top: box.top,
          width: Math.max(1, right - left),
          height: box.height,
          confidence: Number(item.score) * 100,
          text: token.text,
        });
      }
    }
    return rows.flatMap((row) => row.words || []);
  }

  function lineGroups(words) {
    const groups = new Map();
    for (const word of words) {
      if (!groups.has(word.lineKey)) groups.set(word.lineKey, []);
      groups.get(word.lineKey).push(word);
    }
    return [...groups.entries()].map(([lineKey, lineWords]) => ({
      lineKey,
      words: lineWords.sort((a, b) => a.left - b.left),
    }));
  }

  function boxForWords(words) {
    const left = Math.min(...words.map((word) => word.left));
    const top = Math.min(...words.map((word) => word.top));
    const right = Math.max(...words.map((word) => word.left + word.width));
    const bottom = Math.max(...words.map((word) => word.top + word.height));
    return { left, top, right, bottom, width: right - left, height: bottom - top };
  }

  function labelRecovery(rawText, confidence = null) {
    const normalized = normalizeOcrToken(rawText)
      .replace(/[：:・。、()（）\[\]]/g, '');
    let best = null;
    for (const [field, aliases] of Object.entries(nutritionLabels)) {
      for (const alias of aliases) {
        if (normalized === alias || normalized.includes(alias)) {
          return {
            field,
            alias,
            status: normalized === alias ? 'EXACT' : 'RECOVERED_HIGH',
            recoveryMethod: normalized === alias
              ? 'exact-label'
              : 'safe-normalized-label-within-token',
            recoveryConfidence: normalized === alias ? 1 : 0.9,
            ambiguity: null,
          };
        }
        if (alias.length <= 2 || normalized.length < alias.length - 1 ||
            normalized.length > alias.length + 2) continue;
        const distance = editDistance(normalized, alias);
        const allowed = Math.max(1, Math.floor(alias.length * 0.25));
        if (distance > allowed) continue;
        const similarity = 1 - distance / Math.max(normalized.length, alias.length);
        const confidenceFactor = Number.isFinite(Number(confidence))
          ? Math.max(0.5, Math.min(1, Number(confidence) / 100))
          : 0.8;
        const score = similarity * confidenceFactor;
        const status = score >= 0.72 ? 'RECOVERED_HIGH' : 'RECOVERED_MEDIUM';
        const candidate = {
          field,
          alias,
          status,
          recoveryMethod: 'limited-fuzzy-label',
          recoveryConfidence: Math.round(score * 100) / 100,
          ambiguity: null,
          distance,
        };
        if (!best || candidate.recoveryConfidence > best.recoveryConfidence) {
          best = candidate;
        } else if (candidate.recoveryConfidence === best.recoveryConfidence &&
            candidate.field !== best.field) {
          best = { ...best, status: 'REJECTED', ambiguity: 'equal-label-candidates' };
        }
      }
    }
    return best && best.status !== 'REJECTED' ? best : null;
  }

  function nutritionLabelConfusionRecovery(rawText, selected, group) {
    const normalized = normalizeOcrToken(rawText);
    if (normalized === 'エネルキー' || normalized === 'エネルキギー') {
      return {
        field: 'energy',
        alias: 'エネルギー',
        status: 'RECOVERED_MEDIUM',
        recoveryMethod: 'nutrition-energy-label-confusion',
        recoveryConfidence: normalized === 'エネルキー' ? 0.7 : 0.65,
        ambiguity: null,
        contextEvidence: ['nutrition-label-reader', 'bounded-energy-label-confusion'],
      };
    }
    if (normalized === 'たんばぱく質' || normalized === 'たんぱく算' ||
        normalized === 'たんばく質') {
      return {
        field: 'protein',
        alias: 'たんぱく質',
        status: normalized === 'たんばぱく質' || normalized === 'たんばく質'
          ? 'RECOVERED_HIGH' : 'RECOVERED_MEDIUM',
        recoveryMethod: 'nutrition-protein-label-confusion',
        recoveryConfidence: normalized === 'たんばぱく質' ? 0.78 :
          normalized === 'たんばく質' ? 0.74 : 0.62,
        ambiguity: null,
        contextEvidence: ['nutrition-label-reader', 'japanese-nutrition-label'],
      };
    }
    if (normalized === '大水化物') {
      const selectedBox = boxForWords(selected);
      const hasSameRowNumericEvidence = group.words.some((word) => {
        if (word.left < selectedBox.right - 2) return false;
        const numeric = recoverNumericToken(word.text);
        return numeric && (numeric.numericValue != null || numeric.ambiguity);
      });
      if (!hasSameRowNumericEvidence) return null;
      return {
        field: 'carbohydrate',
        alias: '炭水化物',
        status: 'RECOVERED_MEDIUM',
        recoveryMethod: 'nutrition-carbohydrate-label-confusion',
        recoveryConfidence: 0.66,
        ambiguity: null,
        contextEvidence: ['same-row-nutrition-value', 'nutrition-layout'],
      };
    }
    if (normalized !== '肥質' && normalized !== '脂賞') return null;
    const selectedBox = boxForWords(selected);
    const hasSameRowGramEvidence = group.words.some((word) => {
      if (word.left < selectedBox.right - 2) return false;
      const numeric = recoverNumericToken(word.text);
      return numeric?.unit === 'g' && !numeric.ambiguity;
    });
    if (!hasSameRowGramEvidence) return null;
    return {
      field: 'fat',
      alias: '脂質',
      status: 'RECOVERED_MEDIUM',
      recoveryMethod: 'nutrition-label-confusion',
      recoveryConfidence: 0.68,
      ambiguity: null,
      contextEvidence: ['same-row-g-value', 'nutrition-layout'],
    };
  }

  function nutritionAnchors(groups) {
    const anchors = [];
    for (const group of groups) {
      const normalizedWords = group.words.map((word) => normalizeOcrToken(word.text));
      const joined = normalizedWords.join('');
      for (const [field, aliases] of Object.entries(nutritionLabels)) {
        for (const alias of aliases) {
          const start = joined.indexOf(alias);
          if (start < 0) continue;
          let cursor = 0;
          const matched = [];
          for (let index = 0; index < group.words.length; index += 1) {
            const end = cursor + normalizedWords[index].length;
            if (end > start && cursor < start + alias.length) matched.push(group.words[index]);
            cursor = end;
          }
          if (matched.length) {
            const matchedNormalized = matched
              .map((word) => normalizeOcrToken(word.text))
              .join('');
            const exactLabel = matchedNormalized === alias;
            anchors.push({
              field,
              alias,
              rawText: matched.map((word) => word.text).join(' '),
              status: exactLabel ? 'EXACT' : 'RECOVERED_HIGH',
              recoveryMethod: exactLabel
                ? 'exact-label'
                : 'safe-normalized-label-within-line',
              recoveryConfidence: exactLabel ? 1 : 0.9,
              ambiguity: null,
              lineKey: group.lineKey,
              confidence: averageConfidence(matched),
              ...boxForWords(matched),
            });
          }
          break;
        }
      }
      for (let index = 0; index < group.words.length; index += 1) {
        for (const count of [1, 2, 3, 4, 5]) {
          const selected = group.words.slice(index, index + count);
          if (selected.length !== count) continue;
          const rawText = selected.map((word) => word.text).join('');
          const recovered = nutritionLabelConfusionRecovery(rawText, selected, group) ||
            labelRecovery(rawText, averageConfidence(selected));
          if (!recovered || anchors.some((anchor) =>
            anchor.field === recovered.field && anchor.lineKey === group.lineKey,
          )) continue;
          anchors.push({
            ...recovered,
            rawText,
            lineKey: group.lineKey,
            confidence: averageConfidence(selected),
            ...boxForWords(selected),
          });
        }
      }
    }
    return anchors;
  }

  function numericValues(groups) {
    const values = [];
    for (const group of groups) {
      for (let index = 0; index < group.words.length; index += 1) {
        for (const count of [1, 2]) {
          const selected = group.words.slice(index, index + count);
          if (selected.length !== count) continue;
          if (count === 2 && labelRecovery(selected[0].text, selected[0].confidence)) {
            continue;
          }
          // Do not let a trailing fragment of a Japanese label absorb the
          // adjacent value into one synthetic numeric token. The value token
          // remains independently observable and keeps its real geometry.
          if (count === 2 && /[\u3040-\u30ff\u3400-\u9fff]/.test(selected[0].text) &&
              !recoverNumericToken(selected[0].text)) {
            continue;
          }
          const rawToken = selected.map((word) => word.text).join('');
          const recovered = recoverNumericToken(rawToken);
          if (!recovered) continue;
          values.push({
            value: recovered.numericValue,
            unit: recovered.unit,
            rawToken,
            normalizedToken: recovered.normalizedToken,
            normalizationCandidates: recovered.normalizationCandidates,
            candidateType: recovered.candidateType,
            unitStatus: recovered.unitStatus,
            recoveryMethod: recovered.recoveryMethod,
            recoveryConfidence: recovered.recoveryConfidence,
            ambiguity: recovered.ambiguity,
            lineKey: group.lineKey,
            ocrConfidence: averageConfidence(selected),
            ...boxForWords(selected),
          });
        }
      }
    }
    return values.filter((value, index, all) =>
      all.findIndex((candidate) =>
        candidate.lineKey === value.lineKey && candidate.left === value.left &&
        candidate.value === value.value && candidate.unit === value.unit &&
        candidate.ambiguity === value.ambiguity,
      ) === index,
    );
  }

  function unitEvidenceRank(value) {
    return value.unitStatus === 'EXACT' ? 4 :
      value.unitStatus === 'RECOVERED_HIGH' ? 3 :
        value.unitStatus === 'RECOVERED_MEDIUM' ? 2 :
          value.unitStatus === 'MISSING' ? 1 : 0;
  }

  function sameSemanticObservation(left, right) {
    if (left.lineKey !== right.lineKey || left.value !== right.value) return false;
    const leftRight = left.left + left.width;
    const rightRight = right.left + right.width;
    const overlaps = Math.min(leftRight, rightRight) >= Math.max(left.left, right.left);
    return overlaps || Math.abs(left.left - right.left) <= 3 ||
      Math.abs(leftRight - rightRight) <= 3;
  }

  function collapseSemanticObservations(values) {
    const observations = [];
    for (const value of values) {
      const existing = observations.find((observation) =>
        sameSemanticObservation(observation.representative, value),
      );
      if (existing) {
        existing.rawCandidates.push(value);
        if (unitEvidenceRank(value) > unitEvidenceRank(existing.representative) ||
            (unitEvidenceRank(value) === unitEvidenceRank(existing.representative) &&
              value.recoveryConfidence > existing.representative.recoveryConfidence)) {
          existing.representative = value;
        }
        continue;
      }
      observations.push({ representative: value, rawCandidates: [value] });
    }
    return observations.map((observation) => {
      const representative = observation.representative;
      const suppressed = observation.rawCandidates.filter((candidate) =>
        candidate !== representative,
      );
      return {
        ...representative,
        semanticObservation: true,
        supportingRawTokens: observation.rawCandidates.map((candidate) => candidate.rawToken),
        rawCandidateCount: observation.rawCandidates.length,
        duplicateCollapseReason: suppressed.length
          ? unitEvidenceRank(representative) === 4
            ? 'same-value-same-geometry; exact-compatible-unit-preferred'
            : 'same-value-same-geometry; stronger-unit-evidence-preferred'
          : null,
        suppressedCandidates: suppressed.map((candidate) => ({
          rawToken: candidate.rawToken,
          value: candidate.value,
          unit: candidate.unit,
          unitStatus: candidate.unitStatus,
          rejectedCandidateReason: 'duplicate-weaker-unit-evidence',
        })),
      };
    });
  }

  const targetNutritionFields = ['energy', 'protein', 'fat', 'carbohydrate'];
  const nutritionOwnershipFields = [
    ...targetNutritionFields,
    'sugar',
    'fiber',
    'salt',
  ];

  function compatibleValue(field, value) {
    if (!Number.isFinite(value.value) ||
        (value.ambiguity && value.ambiguity !== 'unit-not-observed')) {
      return false;
    }
    if (value.candidateType === 'NUMERIC_WITHOUT_UNIT') return true;
    return field === 'energy' ? value.unit === 'kcal' : value.unit === 'g';
  }

  function relationshipScore(anchor, value, headerAnchors) {
    const anchorCenter = (anchor.left + anchor.right) / 2;
    const valueCenter = (value.left + value.right) / 2;
    const anchorMiddle = (anchor.top + anchor.bottom) / 2;
    const valueMiddle = (value.top + value.bottom) / 2;
    const verticalOverlap =
      Math.min(anchor.bottom, value.bottom) - Math.max(anchor.top, value.top);
    if (anchor.lineKey === value.lineKey &&
        value.left >= anchor.right - 6) {
      return value.left - anchor.right;
    }
    if (verticalOverlap >= -Math.max(anchor.height, value.height) * 0.2 &&
        value.left >= anchor.right - 6) {
      return 500 + Math.abs(valueMiddle - anchorMiddle) * 10 +
        value.left - anchor.right;
    }
    if (headerAnchors.length >= 3 && value.top >= anchor.bottom) {
      const ordered = [...headerAnchors].sort((a, b) => a.left - b.left);
      const index = ordered.indexOf(anchor);
      const lower = index === 0 ? 0 : (ordered[index - 1].right + anchor.left) / 2;
      const upper = index === ordered.length - 1
        ? Infinity
        : (anchor.right + ordered[index + 1].left) / 2;
      if (valueCenter >= lower && valueCenter < upper) {
        return 1000 + value.top - anchor.bottom;
      }
    }
    if (value.top >= anchor.bottom - 4 &&
        value.top <= anchor.bottom + anchor.height * 2.6 &&
        Math.abs(valueCenter - anchorCenter) <= Math.max(anchor.width, value.width) * 1.5) {
      return 2000 + value.top - anchor.bottom + Math.abs(valueCenter - anchorCenter);
    }
    return Infinity;
  }

  function mapAnchorValues(anchors, values) {
    const mapped = new Map();
    const used = new Set();
    const headerAnchors = anchors.filter((anchor) =>
      targetNutritionFields.includes(anchor.field) &&
      anchors.filter((candidate) => candidate.lineKey === anchor.lineKey).length >= 3,
    );
    for (const anchor of anchors.filter((value) => targetNutritionFields.includes(value.field))) {
      const ranked = values
        .map((value, index) => ({
          value,
          index,
          score: compatibleValue(anchor.field, value)
            ? relationshipScore(anchor, value, headerAnchors)
            : Infinity,
        }))
        .filter((entry) => Number.isFinite(entry.score) && !used.has(entry.index))
        .sort((a, b) =>
          a.score - b.score ||
          unitEvidenceRank(b.value) - unitEvidenceRank(a.value) ||
          b.value.recoveryConfidence - a.value.recoveryConfidence,
        );
      const best = ranked[0];
      if (!best) continue;
      const competingAnchors = anchors.filter((candidate) =>
        compatibleValue(candidate.field, best.value) &&
        relationshipScore(candidate, best.value, headerAnchors) < best.score,
      );
      if (competingAnchors.length) continue;
      const sameLine = anchor.lineKey === best.value.lineKey;
      const rightOfLabel = best.value.left >= anchor.right - 6;
      const anchorMiddle = (anchor.top + anchor.bottom) / 2;
      const valueMiddle = (best.value.top + best.value.bottom) / 2;
      const verticalDistance = Math.abs(valueMiddle - anchorMiddle);
      const horizontalDistance = best.value.left - anchor.right;
      // A value directly below one of several detected header columns is a
      // bounded table relationship, not a distant nearest-label guess.
      const headerColumnMapping = headerAnchors.includes(anchor) &&
        best.score >= 1000 && best.score < 2000;
      const geometryConfidence = sameLine && rightOfLabel
        ? 'HIGH'
        : best.score < 1000 || headerColumnMapping ? 'MEDIUM' : 'LOW';
      // A distant value can remain diagnostic/review evidence, but it cannot
      // become a mapped field merely because it is the least distant token.
      if (geometryConfidence === 'LOW') continue;
      const sameGeometryAlternative = ranked.find((entry) =>
        entry !== best && entry.score === best.score &&
        entry.value.value === best.value.value,
      );
      mapped.set(anchor.field, {
        ...best.value,
        mappingStatus: 'MAPPED',
        selectionReason: best.value.duplicateCollapseReason ||
          (sameGeometryAlternative &&
            unitEvidenceRank(best.value) > unitEvidenceRank(sameGeometryAlternative.value)
            ? 'same-value-same-geometry; exact-compatible-unit-preferred'
            : 'lowest-compatible-relationship-score'),
        geometry: {
          sameLine,
          rightOfLabel,
          verticalDistance: Math.round(verticalDistance * 100) / 100,
          horizontalDistance: Math.round(horizontalDistance * 100) / 100,
          relationScore: Math.round(best.score * 100) / 100,
          unitCompatibility: best.value.unit
            ? true
            : 'MISSING',
          geometryConfidence,
        },
        labelEvidence: {
          rawText: anchor.rawText || anchor.alias,
          candidate: anchor.alias,
          status: anchor.status || 'EXACT',
          recoveryMethod: anchor.recoveryMethod || 'exact-label',
          recoveryConfidence: anchor.recoveryConfidence ?? 1,
        },
      });
      used.add(best.index);
    }
    return mapped;
  }

  function nutritionWordDiagnostics(words) {
    return words.map((word) => ({
      rawToken: word.text,
      normalizedToken: normalizeOcrToken(word.text),
      confidence: Number.isFinite(word.confidence) ? word.confidence : null,
      boundingBox: {
        left: word.left,
        top: word.top,
        width: word.width,
        height: word.height,
      },
      lineKey: word.lineKey,
    }));
  }

  function labelDiagnostics(groups, anchors) {
    const fields = [
      'basis',
      'energy',
      'protein',
      'fat',
      'carbohydrate',
      'sugar',
      'fiber',
      'salt',
    ];
    const labels = fields.map((field) => {
      const anchor = anchors.find((candidate) => candidate.field === field);
      if (!anchor) {
        return {
          field,
          detected: false,
          matchedRawText: null,
          status: 'REJECTED',
          matchingRule: 'exact, safe-normalized, then limited-fuzzy label recovery',
        };
      }
      return {
        field,
        detected: true,
        matchedAlias: anchor.alias,
        matchedRawText: anchor.rawText || anchor.alias,
        status: anchor.status || 'EXACT',
        matchingRule: anchor.recoveryMethod || 'exact-label',
        recoveryConfidence: anchor.recoveryConfidence ?? 1,
        ambiguity: anchor.ambiguity || null,
        contextEvidence: anchor.contextEvidence || [],
        confidence: anchor.confidence ?? null,
        boundingBox: {
          left: anchor.left,
          top: anchor.top,
          width: anchor.width,
          height: anchor.height,
        },
      };
    });
    const basisGroup = groups.find((group) =>
      recoverNutritionBasis(group.words.map((word) => word.text).join(' ')),
    );
    if (basisGroup) {
      const box = boxForWords(basisGroup.words);
      const rawText = basisGroup.words.map((word) => word.text).join(' ');
      const basis = recoverNutritionBasis(rawText);
      labels[0] = {
        field: 'basis',
        detected: true,
        matchedAlias: basis?.basis || null,
        matchedRawText: rawText,
        status: basis?.status || 'RECOVERED_HIGH',
        matchingRule: basis?.recoveryMethod || 'basis-pattern',
        recoveryConfidence: basis?.recoveryConfidence ?? 0.9,
        ambiguity: null,
        confidence: averageConfidence(basisGroup.words),
        boundingBox: {
          left: box.left,
          top: box.top,
          width: box.width,
          height: box.height,
        },
      };
    }
    return labels;
  }

  function recoverNutritionBasis(rawText) {
    const raw = String(rawText || '');
    const normalized = normalizeOcrToken(raw).toLowerCase();
    for (const alias of nutritionBasisAliases) {
      const normalizedAlias = normalizeOcrToken(alias).toLowerCase();
      if (normalized.includes(normalizedAlias)) {
        return {
          rawText: raw,
          basis: alias,
          status: raw.includes(alias) ? 'EXACT' : 'RECOVERED_HIGH',
          recoveryMethod: raw.includes(alias)
            ? 'exact-basis'
            : 'safe-basis-normalization',
          recoveryConfidence: raw.includes(alias) ? 1 : 0.9,
        };
      }
    }
    const match = normalized.match(nutritionBasisPattern);
    return match ? {
      rawText: raw,
      basis: match[0],
      status: 'RECOVERED_HIGH',
      recoveryMethod: 'formal-basis-pattern',
      recoveryConfidence: 0.86,
    } : null;
  }

  function averageConfidence(words) {
    const values = words
      .map((word) => Number(word.confidence))
      .filter(Number.isFinite);
    if (!values.length) return null;
    let total = 0;
    for (const value of values) total += value;
    return Math.round(total / values.length * 100) / 100;
  }

  function nearestAnchorDiagnostic(value, anchors) {
    const ranked = anchors.map((anchor) => ({
      anchor,
      score: compatibleValue(anchor.field, value)
        ? relationshipScore(anchor, value, anchors)
        : Infinity,
    })).filter((entry) => Number.isFinite(entry.score))
      .sort((a, b) => a.score - b.score);
    if (!ranked.length) return { nearestLabel: null, relationScore: null };
    return {
      nearestLabel: ranked[0].anchor.field,
      nearestLabelSourcePass: ranked[0].anchor.sourcePass || null,
      relationScore: Math.round(ranked[0].score * 100) / 100,
    };
  }

  function structuredMappingDiagnostics(anchors, values, mapped) {
    return targetNutritionFields.map((field) => {
      const anchor = anchors.find((candidate) => candidate.field === field);
      const candidates = anchor
        ? values.map((value) => ({
            value: value.value,
            unit: value.unit,
            score: compatibleValue(field, value)
              ? relationshipScore(anchor, value, anchors)
              : null,
          })).filter((candidate) => Number.isFinite(candidate.score))
            .sort((a, b) => a.score - b.score)
        : [];
      const selected = mapped.get(field);
      return {
        field,
        candidateCount: candidates.length,
        selectedCandidate: selected
          ? {
              value: selected.value,
              unit: selected.unit,
              rawToken: selected.rawToken,
              unitStatus: selected.unitStatus,
              label: selected.labelEvidence,
              geometry: selected.geometry,
              supportingRawTokens: selected.supportingRawTokens || [selected.rawToken],
            }
          : null,
        selectionReason: selected?.selectionReason || null,
        rejectedCandidates: selected?.suppressedCandidates || candidates.slice(selected ? 1 : 0),
        confidenceRule: 'row-alignment, right-of-label, distance, unit, and recovery evidence',
      };
    });
  }

  function numericDiagnostic(value, anchors) {
    return {
      rawToken: value.rawToken,
      normalizedToken: value.normalizedToken,
      normalizationCandidates: value.normalizationCandidates,
      candidateType: value.candidateType,
      numericValue: value.value,
      unit: value.unit,
      unitStatus: value.unitStatus,
      sourcePass: value.sourcePass || null,
      ocrConfidence: value.ocrConfidence,
      recoveryMethod: value.recoveryMethod,
      recoveryConfidence: value.recoveryConfidence,
      ambiguity: value.ambiguity,
      boundingBox: {
        left: value.left,
        top: value.top,
        width: value.width,
        height: value.height,
      },
      ...nearestAnchorDiagnostic(value, anchors),
    };
  }

  function analyzeNutritionWords(words, sourcePass) {
    const groups = lineGroups(words);
    const anchors = nutritionAnchors(groups).map((anchor) => ({
      ...anchor,
      sourcePass,
    }));
    const values = numericValues(groups).map((value) => ({
      ...value,
      sourcePass,
    }));
    const semanticValues = collapseSemanticObservations(values);
    const mapped = mapAnchorValues(anchors, semanticValues);
    return {
      sourcePass,
      groups,
      anchors,
      values,
      semanticValues,
      mapped,
      localEvidence: [],
      localRefinement: [],
    };
  }

  function matchesMappedValue(mapped, value) {
    return mapped?.rawToken === value.rawToken && mapped?.left === value.left;
  }

  function ownershipForValue(analysis, value) {
    const headerAnchors = analysis.anchors.filter((candidate) =>
      nutritionOwnershipFields.includes(candidate.field) &&
      analysis.anchors.filter((item) => item.lineKey === candidate.lineKey).length >= 3,
    );
    const ranked = analysis.anchors
      .filter((anchor) => nutritionOwnershipFields.includes(anchor.field))
      .map((anchor) => ({
        anchor,
        score: (value.ambiguity && value.value == null) || compatibleValue(anchor.field, value)
          ? relationshipScore(anchor, value, headerAnchors)
          : Infinity,
      }))
      .filter((entry) => Number.isFinite(entry.score))
      .sort((left, right) => left.score - right.score);
    const nearest = ranked[0] || null;
    if (value.ambiguity && value.value == null) {
      return {
        candidateField: nearest?.anchor.field || null,
        nearestLabel: nearest?.anchor.field || null,
        nearestLabelSourcePass: nearest?.anchor.sourcePass || null,
        ownershipStatus: nearest ? 'AMBIGUOUS_UNOWNED' : 'AMBIGUOUS_UNOWNED',
        ownershipReason: 'ambiguous-numeric-evidence-is-not-a-confirmed-value',
        conflictEligible: false,
        relationScore: nearest ? Math.round(nearest.score * 100) / 100 : null,
        anchor: nearest?.anchor || null,
      };
    }
    if (!nearest) {
      return {
        candidateField: null,
        nearestLabel: null,
        nearestLabelSourcePass: null,
        ownershipStatus: 'UNMAPPED_RETAINED',
        ownershipReason: 'no-pass-local-compatible-label-relationship',
        conflictEligible: false,
        relationScore: null,
        anchor: null,
      };
    }
    const anchor = nearest.anchor;
    const sameLine = anchor.lineKey === value.lineKey;
    const rightOfLabel = value.left >= anchor.right - 6;
    const geometryConfidence = sameLine && rightOfLabel
      ? 'HIGH'
      : nearest.score < 1000 ? 'MEDIUM' : 'LOW';
    const mapped = analysis.mapped.get(anchor.field);
    const mappingStatus = matchesMappedValue(mapped, value)
      ? 'MAPPED'
      : geometryConfidence === 'LOW'
        ? 'UNMAPPED_RETAINED'
        : 'OWNED_REVIEW';
    return {
      candidateField: anchor.field,
      nearestLabel: anchor.field,
      nearestLabelSourcePass: anchor.sourcePass || null,
      ownershipStatus: mappingStatus,
      ownershipReason: mappingStatus === 'MAPPED'
        ? 'selected-by-pass-local-geometry-mapping'
        : mappingStatus === 'OWNED_REVIEW'
          ? 'pass-local-label-affinity-with-review-only-evidence'
          : 'low-geometry-pass-local-label-affinity',
      conflictEligible: mappingStatus === 'MAPPED' || mappingStatus === 'OWNED_REVIEW',
      relationScore: Math.round(nearest.score * 100) / 100,
      anchor,
    };
  }

  function fieldOwnershipDiagnostics(analyses) {
    return analyses.flatMap((analysis) => analysis.values.map((value) => {
      const ownership = ownershipForValue(analysis, value);
      const anchor = ownership.anchor;
      const sameLine = Boolean(anchor) && anchor.lineKey === value.lineKey;
      const rightOfLabel = Boolean(anchor) && value.left >= anchor.right - 6;
      const verticalDistance = anchor
        ? Math.round(Math.abs((value.top + value.bottom - anchor.top - anchor.bottom) / 2) * 100) / 100
        : null;
      const horizontalDistance = anchor
        ? Math.round((value.left - anchor.right) * 100) / 100
        : null;
      return {
        field: ownership.candidateField,
        value: value.value,
        unit: value.unit,
        unitStatus: value.unitStatus,
        rawToken: value.rawToken,
        supportingRawTokens: value.supportingRawTokens || [value.rawToken],
        sourcePass: value.sourcePass,
        candidateField: ownership.candidateField,
        ownerField: ownership.candidateField,
        nearestLabel: ownership.nearestLabel,
        nearestLabelSourcePass: ownership.nearestLabelSourcePass,
        sameLine,
        rightOfLabel,
        verticalDistance,
        horizontalDistance,
        relationScore: ownership.relationScore,
        geometryConfidence: sameLine && rightOfLabel
          ? 'HIGH'
          : ownership.relationScore != null && ownership.relationScore < 1000
            ? 'MEDIUM'
            : 'LOW',
        ownershipStatus: ownership.ownershipStatus,
        ownershipReason: ownership.ownershipReason,
        conflictEligible: ownership.conflictEligible,
        excludedFromConflict: !ownership.conflictEligible,
        exclusionReason: ownership.conflictEligible
          ? null
          : ownership.ownershipReason,
        labelEvidence: anchor ? {
          rawText: anchor.rawText || anchor.alias,
          candidate: anchor.alias,
          status: anchor.status || 'EXACT',
          recoveryMethod: anchor.recoveryMethod || 'exact-label',
          recoveryConfidence: anchor.recoveryConfidence ?? 1,
        } : null,
      };
    }));
  }

  function evidenceForField(analysis, field) {
    const fullEvidence = analysis.semanticValues.map((value) => {
      const ownership = ownershipForValue(analysis, value);
      if (ownership.candidateField !== field) return null;
      const anchor = ownership.anchor;
      if (!anchor || !compatibleValue(field, value)) return null;
      const sameLine = anchor.lineKey === value.lineKey;
      const rightOfLabel = value.left >= anchor.right - 6;
      const anchorMiddle = (anchor.top + anchor.bottom) / 2;
      const valueMiddle = (value.top + value.bottom) / 2;
      return {
        ...value,
        mappingStatus: ownership.ownershipStatus,
        ownershipStatus: ownership.ownershipStatus,
        ownershipReason: ownership.ownershipReason,
        conflictEligible: ownership.conflictEligible,
        geometry: {
          sameLine,
          rightOfLabel,
          verticalDistance: Math.round(Math.abs(valueMiddle - anchorMiddle) * 100) / 100,
          horizontalDistance: Math.round((value.left - anchor.right) * 100) / 100,
          relationScore: ownership.relationScore,
          unitCompatibility: value.unit ? true : 'MISSING',
          geometryConfidence: sameLine && rightOfLabel
            ? 'HIGH'
            : ownership.relationScore < 1000 ? 'MEDIUM' : 'LOW',
        },
        labelEvidence: {
          rawText: anchor.rawText || anchor.alias,
          candidate: anchor.alias,
          status: anchor.status || 'EXACT',
          recoveryMethod: anchor.recoveryMethod || 'exact-label',
          recoveryConfidence: anchor.recoveryConfidence ?? 1,
          contextEvidence: anchor.contextEvidence || [],
        },
      };
    }).filter(Boolean);
    const localEvidence = (analysis.localEvidence || []).filter((item) =>
      item.targetField === field,
    );
    return [...fullEvidence, ...localEvidence];
  }

  function ambiguousEvidenceForField(analysis, field) {
    return analysis.values.filter((item) => {
      if (!item.ambiguity) return false;
      const ownership = ownershipForValue(analysis, item);
      return ownership.candidateField === field;
    });
  }

  function ambiguousEvidenceRelatesTo(candidate, ambiguous) {
    const normalized = String(ambiguous.normalizedToken || ambiguous.rawToken || '');
    if (!normalized.includes('@')) return false;
    const suffix = normalized.split('@').pop().replace(/[^\d.]/g, '');
    const candidateText = String(candidate.value);
    return suffix.length >= 2 && candidateText.endsWith(suffix);
  }

  function chooseRepresentative(items) {
    return [...items].sort((left, right) =>
      (right.mappingStatus === 'MAPPED' ? 1 : 0) -
        (left.mappingStatus === 'MAPPED' ? 1 : 0) ||
      unitEvidenceRank(right) - unitEvidenceRank(left) ||
      right.recoveryConfidence - left.recoveryConfidence,
    )[0];
  }

  function consensusForAnalyses(analyses) {
    const fields = {};
    for (const field of targetNutritionFields) {
      const evidence = analyses.flatMap((analysis) => evidenceForField(analysis, field));
      const conflictEligibleEvidence = evidence.filter((item) => item.conflictEligible);
      const ambiguousEvidence = analyses.flatMap((analysis) =>
        ambiguousEvidenceForField(analysis, field),
      );
      const byValue = new Map();
      for (const item of conflictEligibleEvidence) {
        const key = `${item.value}|${item.unit}`;
        if (!byValue.has(key)) byValue.set(key, new Map());
        const perPass = byValue.get(key);
        const existing = perPass.get(item.sourcePass);
        if (!existing || chooseRepresentative([existing, item]) === item) {
          perPass.set(item.sourcePass, item);
        }
      }
      const clusters = [...byValue.values()].map((perPass) => {
        const observations = [...perPass.values()];
        const representative = chooseRepresentative(observations);
        const relatedAmbiguousPasses = [...new Set(ambiguousEvidence
          .filter((item) => ambiguousEvidenceRelatesTo(representative, item))
          .map((item) => item.sourcePass))];
        return {
          value: representative.value,
          unit: representative.unit,
          observations,
          representative,
          supportingPasses: observations.map((item) => item.sourcePass),
          relatedAmbiguousPasses,
          score: observations.length * 10 +
            observations.filter((item) => item.mappingStatus === 'MAPPED').length * 2 +
            relatedAmbiguousPasses.length * 4 + unitEvidenceRank(representative),
        };
      }).sort((left, right) => right.score - left.score);
      const conflict = clusters.length > 1;
      const selectedCluster = !conflict
        ? clusters[0] || null
        : clusters.length >= 2 && clusters[0].score > clusters[1].score
          ? clusters[0]
          : null;
      const selected = selectedCluster?.representative || null;
      const supportCount = selectedCluster?.supportingPasses.length || 0;
      const exactEvidence = Boolean(selected) &&
        selected.labelEvidence?.status === 'EXACT' &&
        selected.unitStatus === 'EXACT' &&
        selected.recoveryMethod === 'exact-numeric-unit';
      const highGeometry = selected?.geometry?.geometryConfidence === 'HIGH';
      const reliableRecovery = Boolean(selected) &&
        (selected.labelEvidence?.recoveryConfidence ?? 0) >= 0.7 &&
        (selected.recoveryConfidence ?? 0) >= 0.6 &&
        (!Number.isFinite(selected.ocrConfidence) || selected.ocrConfidence >= 50);
      const missingUnitEvidence = selected?.candidateType === 'NUMERIC_WITHOUT_UNIT';
      const outlierClusters = selectedCluster
        ? clusters.filter((cluster) => cluster !== selectedCluster &&
          cluster.score < selectedCluster.score)
        : [];
      let conflictingPassCount = 0;
      for (const cluster of clusters) {
        if (cluster !== selectedCluster) {
          conflictingPassCount += cluster.supportingPasses.length;
        }
      }
      const finalConfidence = !selected
        ? ambiguousEvidence.length ? 'LOW' : 'NONE'
        : conflict || missingUnitEvidence || selected.mappingStatus !== 'MAPPED'
          ? 'MEDIUM'
          : highGeometry && reliableRecovery && (supportCount >= 2 || exactEvidence)
            ? 'HIGH'
            : 'MEDIUM';
      fields[field] = {
        field,
        value: selected?.value ?? null,
        unit: selected?.unit ?? null,
        unitStatus: selected?.unitStatus ?? null,
        confidence: finalConfidence,
        source: selected?.source === 'LOCAL_REFINEMENT' ? 'LOCAL_REFINEMENT' :
          selected && (!exactEvidence || missingUnitEvidence) ? 'RECOVERED_OCR' :
            selected ? 'EXACT_OCR' : null,
        reviewRequired: finalConfidence !== 'HIGH' || conflict,
        supportingPasses: selectedCluster?.supportingPasses || [],
        supportingPassCount: supportCount,
        conflictingPassCount,
        ambiguousRelatedPassCount: selectedCluster?.relatedAmbiguousPasses.length || 0,
        agreement: `${supportCount}/${analyses.length}`,
        conflict,
        consensusStatus: conflict
          ? selected ? 'CONFLICT_REVIEW_CANDIDATE' : 'CONFLICT'
          : selected?.mappingStatus === 'MAPPED' ? 'AGREED_MAPPED' : 'PRE_MAPPING_RETAINED',
        conflictingCandidates: clusters.map((cluster) => ({
          value: cluster.value,
          unit: cluster.unit,
          passes: cluster.supportingPasses,
          relatedAmbiguousPasses: cluster.relatedAmbiguousPasses,
          mappingStatuses: cluster.observations.map((item) => item.mappingStatus),
          ownershipStatuses: cluster.observations.map((item) => item.ownershipStatus),
          conflictEligible: cluster.observations.every((item) => item.conflictEligible),
          status: cluster === selectedCluster
            ? 'SELECTED_REVIEW_CANDIDATE'
            : outlierClusters.includes(cluster)
              ? 'DOWNRANKED_SINGLE_PASS_OUTLIER'
              : 'CONFLICTING_CANDIDATE',
        })),
        decision: finalConfidence === 'HIGH' && !conflict
          ? 'AUTO_FILL_ALLOWED'
          : selected || conflict
            ? 'REVIEW_REQUIRED'
            : finalConfidence === 'LOW'
              ? 'CANDIDATE_ONLY'
              : 'NOT_AVAILABLE',
        decisionReason: selected?.selectionReason ||
          (conflict ? 'cross-pass-conflict; review-required' :
            ambiguousEvidence.length ? 'ambiguous-numeric-evidence-only' :
              'no-compatible-observed-evidence'),
        selectedEvidence: selected || ambiguousEvidence[0] || null,
        rawTokens: selectedCluster?.observations
          .flatMap((item) => item.supportingRawTokens || [item.rawToken]) ||
          ambiguousEvidence.map((item) => item.rawToken),
        excludedEvidence: evidence.filter((item) => !item.conflictEligible).map((item) => ({
          value: item.value,
          unit: item.unit,
          rawToken: item.rawToken,
          sourcePass: item.sourcePass,
          ownershipStatus: item.ownershipStatus,
          exclusionReason: item.ownershipReason,
        })),
      };
    }
    return fields;
  }

  function nutritionConsistency(fields) {
    const energy = fields.energy?.value;
    const protein = fields.protein?.value;
    const fat = fields.fat?.value;
    const carbohydrate = fields.carbohydrate?.value;
    if (![energy, protein, fat, carbohydrate].every(Number.isFinite)) {
      return {
        evaluated: false,
        support: null,
        reason: 'all energy and P/F/C evidence is required; no value is generated',
      };
    }
    const estimate = protein * 4 + fat * 9 + carbohydrate * 4;
    const difference = Math.abs(energy - estimate);
    const tolerance = Math.max(20, estimate * 0.15);
    return {
      evaluated: true,
      energyCandidate: energy,
      macroEstimatedEnergy: Math.round(estimate * 10) / 10,
      difference: Math.round(difference * 10) / 10,
      tolerance: Math.round(tolerance * 10) / 10,
      support: difference <= tolerance,
      valueGenerated: false,
      reason: difference <= tolerance
        ? 'existing OCR values are mutually supportive'
        : 'existing OCR values are inconsistent; values are not corrected',
    };
  }

  function bridgeSelectedEvidence(value) {
    if (!value) return null;
    return {
      value: value.value,
      unit: value.unit,
      unitStatus: value.unitStatus,
      rawToken: value.rawToken,
      sourcePass: value.sourcePass,
      candidateType: value.candidateType,
      ambiguity: value.ambiguity,
      geometry: value.geometry || null,
      labelEvidence: value.labelEvidence ? {
        status: value.labelEvidence.status,
        recoveryMethod: value.labelEvidence.recoveryMethod,
        recoveryConfidence: value.labelEvidence.recoveryConfidence,
      } : null,
      ownershipStatus: value.ownershipStatus || null,
      ownershipReason: value.ownershipReason || null,
      conflictEligible: value.conflictEligible ?? null,
    };
  }

  function applyNutritionConsistency(fields, consistency) {
    for (const decision of Object.values(fields)) {
      decision.consistencySupport = consistency.evaluated
        ? consistency.support
        : null;
      if (consistency.evaluated && !consistency.support &&
          decision.value != null && decision.confidence === 'HIGH') {
        decision.confidence = 'MEDIUM';
        decision.reviewRequired = true;
        decision.decision = 'REVIEW_REQUIRED';
      }
    }
    return fields;
  }

  function layoutPattern(anchors, mapped) {
    const target = anchors.filter((anchor) => targetNutritionFields.includes(anchor.field));
    if (target.some((anchor) =>
      target.filter((candidate) => candidate.lineKey === anchor.lineKey).length >= 3,
    )) return 'header-value-row';
    const sameLine = [...mapped.entries()].filter(([field, value]) => {
      const anchor = target.find((candidate) => candidate.field === field);
      return anchor && anchor.lineKey === value.lineKey;
    });
    if (sameLine.length >= 3) {
      const valueLefts = sameLine.map(([, value]) => value.left);
      return Math.max(...valueLefts) - Math.min(...valueLefts) <= 24
        ? 'two-column-table'
        : 'vertical-list';
    }
    const belowLabel = [...mapped.entries()].filter(([field, value]) => {
      const anchor = target.find((candidate) => candidate.field === field);
      return anchor && value.top >= anchor.bottom - 4;
    });
    if (belowLabel.length >= 3) return 'boxed-wrapped';
    if (target.length >= 3) return 'two-column-table';
    return 'boxed-wrapped';
  }

  function roiCanvas(source, region) {
    const left = Math.max(0, Math.round(region.left));
    const top = Math.max(0, Math.round(region.top));
    const right = Math.min(source.width, Math.round(region.right));
    const bottom = Math.min(source.height, Math.round(region.bottom));
    if (right <= left || bottom <= top) return null;
    const canvas = document.createElement('canvas');
    canvas.width = right - left;
    canvas.height = bottom - top;
    canvas.getContext('2d', { alpha: false }).drawImage(
      source,
      left,
      top,
      canvas.width,
      canvas.height,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    return canvas;
  }

  function scaledRoiCanvas(source, scale) {
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(source.width * scale));
    canvas.height = Math.max(1, Math.round(source.height * scale));
    const context = canvas.getContext('2d', { alpha: false });
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = 'high';
    context.drawImage(source, 0, 0, canvas.width, canvas.height);
    return canvas;
  }

  // The full-pass numeric boxes are used only to find the value *column* of
  // an already identified nutrition table. They never become field evidence
  // here: the bounded crop is still re-read from pixels and must pass the
  // target-row ownership check below.
  function valueSideBounds(canvas, analysis, anchor) {
    const labelRights = analysis.anchors
      .filter((candidate) => targetNutritionFields.includes(candidate.field))
      .map((candidate) => candidate.right)
      .filter(Number.isFinite);
    const labelEdge = labelRights.length ? Math.min(...labelRights) : anchor.right;
    const valueBoxes = (analysis.values || []).filter((value) =>
      Number.isFinite(value.left) && Number.isFinite(value.width) &&
      value.left >= labelEdge - Math.max(8, anchor.width * 0.08),
    );
    const edgePadding = Math.max(8, anchor.width * 0.06);
    if (valueBoxes.length) {
      const left = Math.max(anchor.right + edgePadding,
        Math.min(...valueBoxes.map((value) => value.left)) - edgePadding);
      const right = Math.min(canvas.width,
        Math.max(...valueBoxes.map((value) => value.left + value.width)) + edgePadding * 2);
      if (right - left >= 16) return { left, right, method: 'observed-value-column' };
    }
    return {
      left: Math.min(canvas.width - 1, anchor.right + edgePadding),
      right: Math.max(anchor.right + edgePadding + 1,
        canvas.width - Math.max(4, canvas.width * 0.015)),
      method: 'label-right-conservative',
    };
  }

  function refinementRegions(canvas, analysis, field, triggerReason, anchorOverride = null) {
    const anchor = anchorOverride || refinementAnchor(analysis, field);
    if (!anchor) return [];
    const rowBand = nutritionRowBand(canvas, analysis, anchor, field);
    // OCR label boxes can be taller than their visual baseline. Keep the
    // bounded lower-row edge, but include a small amount above that box so
    // the top of the target value glyph is not clipped.
    const valueTop = Math.max(0, Math.min(
      rowBand.top,
      anchor.top - anchor.height * 0.18,
    ));
    const valueSide = valueSideBounds(canvas, analysis, anchor);
    const regions = [{
      regionType: 'LABEL_RIGHT_VALUE',
      triggerReason,
      left: valueSide.left,
      top: valueTop,
      right: valueSide.right,
      bottom: rowBand.bottom,
      rowBand,
      valueSideMethod: valueSide.method,
    }, {
      regionType: 'VERTICAL_ROW_REGION',
      triggerReason,
      left: Math.max(0, anchor.left - anchor.width * 0.25),
      top: valueTop,
      right: canvas.width,
      bottom: rowBand.bottom,
      rowBand,
    }];
    const headers = analysis.anchors.filter((candidate) =>
      targetNutritionFields.includes(candidate.field) && candidate.lineKey === anchor.lineKey,
    ).sort((left, right) => left.left - right.left);
    if (headers.length >= 3) {
      const index = headers.indexOf(anchor);
      const left = index === 0 ? Math.max(0, anchor.left - anchor.width * 0.15) :
        (headers[index - 1].right + anchor.left) / 2;
      const right = index === headers.length - 1 ? Math.min(canvas.width,
        anchor.right + anchor.width * 1.25) : (anchor.right + headers[index + 1].left) / 2;
      regions.push({
        regionType: 'HORIZONTAL_HEADER_COLUMN',
        triggerReason,
        left,
        top: anchor.bottom,
        right,
        bottom: anchor.bottom + Math.max(anchor.height * 2.8, 80),
      });
    }
    return regions;
  }

  // Nutrition rows are defined from pass-local label centres. A local OCR
  // crop is only useful if it cannot silently borrow the value from a
  // neighbouring row. Horizontal header tables deliberately fall back to a
  // conservative label-height band; their value cells are handled by the
  // dedicated header-column refinement below.
  function nutritionRowBand(canvas, analysis, anchor, field) {
    const sameLineHeaders = analysis.anchors.filter((candidate) =>
      targetNutritionFields.includes(candidate.field) &&
      candidate.lineKey === anchor.lineKey,
    );
    if (sameLineHeaders.length >= 3) {
      const margin = Math.max(3, anchor.height * 0.18);
      return {
        top: Math.max(0, anchor.top - margin),
        bottom: Math.min(canvas.height, anchor.bottom + margin),
        method: 'conservative-label-height',
      };
    }
    const rows = orderedNutritionRows(analysis, anchor, field);
    const targetIndex = rows.findIndex((candidate) => candidate.field === field);
    if (targetIndex < 0 || rows.length < 2) {
      const margin = Math.max(3, anchor.height * 0.18);
      return {
        top: Math.max(0, anchor.top - margin),
        bottom: Math.min(canvas.height, anchor.bottom + margin),
        method: 'conservative-label-height',
      };
    }
    const target = rows[targetIndex];
    const center = target.center;
    const above = rows[targetIndex - 1];
    const below = rows[targetIndex + 1];
    if (!above || !below) {
      const margin = Math.max(3, anchor.height * 0.22);
      return {
        top: Math.max(0, anchor.top - margin),
        bottom: Math.min(canvas.height, anchor.bottom + margin),
        method: 'conservative-edge-label-height',
      };
    }
    const spacing = [
      center - above.center,
      below.center - center,
    ].filter((value) => value > 2);
    const typicalSpacing = spacing.length
      ? spacing.reduce((sum, value) => sum + value, 0) / spacing.length
      : Math.max(anchor.height * 1.4, 16);
    const margin = Math.max(2, Math.min(anchor.height * 0.2, typicalSpacing * 0.12));
    const top = above
      ? (above.center + center) / 2 + margin
      : center - typicalSpacing / 2 + margin;
    const bottom = below
      ? (center + below.center) / 2 - margin
      : center + typicalSpacing / 2 - margin;
    return {
      top: Math.max(0, Math.min(top, anchor.top)),
      bottom: Math.min(canvas.height, Math.max(bottom, anchor.bottom)),
      method: 'neighbor-label-midpoints',
    };
  }

  function orderedNutritionRows(analysis, anchor, targetField) {
    const direct = new Map();
    for (const candidate of analysis.anchors) {
      if (!targetNutritionFields.includes(candidate.field) || direct.has(candidate.field)) continue;
      direct.set(candidate.field, {
        ...candidate,
        center: candidate.top + candidate.height / 2,
      });
    }
    direct.set(targetField, {
      ...anchor,
      center: anchor.top + anchor.height / 2,
    });
    // Missing labels between two recognised nutrient rows have a known row
    // position, but not a value. Their virtual centres are used only as crop
    // boundaries so an adjacent row cannot leak into a local value read.
    for (let index = 0; index < targetNutritionFields.length; index += 1) {
      const field = targetNutritionFields[index];
      if (direct.has(field)) continue;
      const before = targetNutritionFields.slice(0, index).reverse()
        .map((candidate) => ({ field: candidate, anchor: direct.get(candidate) }))
        .find((candidate) => candidate.anchor);
      const after = targetNutritionFields.slice(index + 1)
        .map((candidate) => ({ field: candidate, anchor: direct.get(candidate) }))
        .find((candidate) => candidate.anchor);
      if (!before || !after || after.anchor.center <= before.anchor.center) continue;
      const beforeIndex = targetNutritionFields.indexOf(before.field);
      const afterIndex = targetNutritionFields.indexOf(after.field);
      const ratio = (index - beforeIndex) / (afterIndex - beforeIndex);
      direct.set(field, {
        field,
        center: before.anchor.center + (after.anchor.center - before.anchor.center) * ratio,
        height: Math.max(before.anchor.height, after.anchor.height),
        virtual: true,
      });
    }
    return [...direct.values()].sort((left, right) => left.center - right.center);
  }

  function localRowOwnership(value, rowBand) {
    if (!rowBand || !Number.isFinite(value.top) || !Number.isFinite(value.height)) {
      return 'AMBIGUOUS_ROW';
    }
    const top = value.top;
    const bottom = value.top + value.height;
    const center = top + value.height / 2;
    if (center >= rowBand.top && center <= rowBand.bottom &&
        top >= rowBand.top - 1 && bottom <= rowBand.bottom + 1) {
      return 'SAME_TARGET_ROW';
    }
    if (bottom >= rowBand.top && top <= rowBand.bottom) return 'AMBIGUOUS_ROW';
    const distance = center < rowBand.top ? rowBand.top - center : center - rowBand.bottom;
    return distance <= Math.max(value.height * 1.5, 18)
      ? 'ADJACENT_ROW' : 'OUTSIDE_TARGET_ROW';
  }

  function localCandidateFromWords(words, field, rowBand) {
    const compatibleUnit = field === 'energy' ? 'kcal' : 'g';
    const values = numericValues(lineGroups(words)).map((value) => ({
      ...value,
      rowOwnership: localRowOwnership(value, rowBand),
    }));
    const sameRow = values.filter((value) =>
      value.rowOwnership === 'SAME_TARGET_ROW' && !value.ambiguity &&
      (value.unit === compatibleUnit || value.unit === null),
    );
    const distinct = sameRow.filter((value, index, all) => all.findIndex((other) =>
      other.value === value.value && other.unit === value.unit,
    ) === index);
    return {
      candidate: distinct.length === 1 ? distinct[0] : null,
      values,
    };
  }

  function localRecognitionVariants(roi, regionType) {
    const numericWhitelist = '0123456789.,kcalg';
    // A small, deterministic ensemble for a bounded value-side row. Its
    // observations are correlated: agreement improves recognition metadata,
    // not cross-pass consensus support.
    if (regionType === 'LABEL_RIGHT_VALUE') {
      const enlarged = scaledRoiCanvas(roi, 2);
      return [{
        id: 'ORIGINAL_PSM3', dataUrl: roi.toDataURL('image/png'), scale: 1,
        pageSegmentationMode: 3, preprocessing: 'original',
      }, {
        id: 'GRAYSCALE_2X_PSM6', dataUrl: processedVariant(enlarged, 1.35), scale: 2,
        pageSegmentationMode: 6, preprocessing: 'grayscale-contrast-1.35',
      }, {
        id: 'THRESHOLD_2X_PSM7', dataUrl: thresholdVariant(enlarged), scale: 2,
        pageSegmentationMode: 7, preprocessing: 'threshold-170',
      }].map((variant) => ({ ...variant, whitelist: numericWhitelist }));
    }
    return [{
      id: 'ORIGINAL_PSM3', dataUrl: roi.toDataURL('image/png'), scale: 1,
      pageSegmentationMode: 3, preprocessing: 'original', whitelist: numericWhitelist,
    }];
  }

  function selectLocalVariantCandidate(observations) {
    const candidates = observations.filter((item) => item.local.candidate).map((item) => ({
      ...item.local.candidate,
      variant: item.variant.id,
      variantOrder: item.variantOrder,
    }));
    const keys = [...new Set(candidates.map((candidate) =>
      `${candidate.value}|${candidate.unit || ''}`,
    ))];
    if (keys.length !== 1) return { candidate: null, agreement: 0, winningVariant: null };
    const [candidate] = candidates.sort((left, right) => {
      const unitScore = (item) => item.unit ? 0 : 1;
      return unitScore(left) - unitScore(right) || left.variantOrder - right.variantOrder;
    });
    return {
      candidate,
      agreement: candidates.length,
      winningVariant: candidate.variant,
    };
  }

  function refinementAnchor(analysis, field) {
    const direct = analysis.anchors.find((candidate) => candidate.field === field);
    if (direct) return direct;
    const index = targetNutritionFields.indexOf(field);
    const before = [...analysis.anchors].filter((anchor) =>
      targetNutritionFields.indexOf(anchor.field) < index,
    ).sort((left, right) => right.top - left.top)[0];
    const after = [...analysis.anchors].filter((anchor) =>
      targetNutritionFields.indexOf(anchor.field) > index,
    ).sort((left, right) => left.top - right.top)[0];
    if (!before || !after || after.top <= before.top) return null;
    const beforeIndex = targetNutritionFields.indexOf(before.field);
    const afterIndex = targetNutritionFields.indexOf(after.field);
    const ratio = (index - beforeIndex) / (afterIndex - beforeIndex);
    const height = Math.max(before.height, after.height);
    const top = before.top + (after.top - before.top) * ratio;
    const canonical = {
      energy: 'エネルギー', protein: 'たんぱく質', fat: '脂質', carbohydrate: '炭水化物',
    }[field];
    return {
      field,
      alias: canonical,
      rawText: null,
      status: 'RECOVERED_MEDIUM',
      recoveryMethod: 'nutrition-table-row-structure',
      recoveryConfidence: 0.6,
      contextEvidence: ['bounded-between-neighbor-nutrition-rows'],
      lineKey: `inferred-row:${field}`,
      left: Math.min(before.left, after.left),
      right: Math.max(before.right, after.right),
      top,
      bottom: top + height,
      width: Math.max(before.width, after.width),
      height,
    };
  }

  async function localRefinementFromRegions(
    canvas,
    analysis,
    field,
    triggerReason,
    anchorOverride = null,
  ) {
    const attempts = [];
    for (const region of refinementRegions(
      canvas,
      analysis,
      field,
      triggerReason,
      anchorOverride,
    )) {
      const roi = roiCanvas(canvas, region);
      if (!roi || roi.width < 8 || roi.height < 8) continue;
      const cropRect = {
        x: Math.max(0, Math.round(region.left)),
        y: Math.max(0, Math.round(region.top)),
        width: roi.width,
        height: roi.height,
      };
      const observations = [];
      for (const [variantOrder, variant] of localRecognitionVariants(roi, region.regionType).entries()) {
        const data = await recognizePass(variant.dataUrl, {
          outputs: { text: true, tsv: true },
          whitelist: variant.whitelist,
          pageSegmentationMode: variant.pageSegmentationMode,
        });
        const words = tsvWords(data.tsv || '').map((word) => ({
          ...word,
          left: word.left / variant.scale + cropRect.x,
          top: word.top / variant.scale + cropRect.y,
          width: word.width / variant.scale,
          height: word.height / variant.scale,
        }));
        observations.push({
          variant,
          variantOrder,
          data,
          words,
          local: localCandidateFromWords(words, field, region.rowBand),
        });
      }
      // TSV geometry is required for a field-owned local value. Raw text can
      // still be retained for diagnostics, but never promoted without a row
      // ownership decision.
      const selected = selectLocalVariantCandidate(observations);
      const candidate = selected.candidate;
      const primary = observations[0];
      const allValues = observations.flatMap((item) => item.local.values.map((value) => ({
        ...value, variant: item.variant.id,
      })));
      attempts.push({
        source: 'LOCAL_REFINEMENT',
        sourcePass: analysis.sourcePass,
        refinementPass: `${analysis.sourcePass}:${region.regionType}`,
        targetField: field,
        refinementAnchor: anchorOverride || refinementAnchor(analysis, field),
        regionType: region.regionType,
        triggerReason: region.triggerReason,
        cropRect,
        sourceImageDimensions: { width: canvas.width, height: canvas.height },
        ocrInputDimensions: { width: roi.width, height: roi.height },
        preprocessing: {
          whitelist: '0123456789.,kcalg',
          variant: selected.winningVariant || primary.variant.id,
          variantCount: observations.length,
          valueSideMethod: region.valueSideMethod || null,
        },
        cropPreviewDataUrl: roi.toDataURL('image/jpeg', 0.9),
        rawOcrText: String(primary.data.text || ''),
        rawTokens: primary.words.map((word) => word.text),
        variantObservations: observations.map((item) => ({
          variant: item.variant.id,
          scale: item.variant.scale,
          pageSegmentationMode: item.variant.pageSegmentationMode,
          preprocessing: item.variant.preprocessing,
          rawOcrText: String(item.data.text || ''),
          rawTokens: item.words.map((word) => word.text),
        })),
        numericValue: candidate?.value ?? null,
        unit: candidate?.unit ?? null,
        unitStatus: candidate?.unitStatus ?? null,
        candidateGeometry: candidate ? {
          left: candidate.left,
          top: candidate.top,
          width: candidate.width,
          height: candidate.height,
        } : null,
        rowOwnership: candidate?.rowOwnership ||
          (allValues.length === 1 ? allValues[0].rowOwnership : 'AMBIGUOUS_ROW'),
        rowBand: region.rowBand || null,
        retainedCandidates: allValues.map((value) => ({
          value: value.value,
          unit: value.unit,
          rawToken: value.rawToken,
          rowOwnership: value.rowOwnership,
          variant: value.variant,
        })),
        variantAgreement: selected.agreement,
        ocrConfidence: null,
        resultStatus: candidate ? 'OBSERVED_SAME_TARGET_ROW_NUMERIC' :
          'NO_UNIQUE_SAME_TARGET_ROW_VALUE',
      });
    }
    return attempts;
  }

  function tableValueRegion(canvas, analysis) {
    const header = analysis.groups.find((group) =>
      normalizeOcrToken(group.words.map((word) => word.text).join(''))
        .includes('栄養成分表示'),
    );
    if (!header) return null;
    const box = boxForWords(header.words);
    return {
      regionType: 'TABLE_VALUE_ROW_REGION',
      triggerReason: 'nutrition-table-header-without-structured-values',
      left: Math.max(0, box.left - box.width * 0.15),
      top: Math.max(0, box.top - box.height * 0.35),
      right: Math.min(canvas.width, Math.max(box.right + box.width * 1.5, canvas.width * 0.92)),
      bottom: Math.min(canvas.height, box.bottom + Math.max(box.height * 6.5, canvas.height * 0.42)),
    };
  }

  // A missing field is eligible for another bounded pixel read only when the
  // *same OCR pass* already establishes a nutrition-table structure. This is
  // deliberately a trigger aid, not label recovery or value ownership: every
  // value still has to pass SAME_TARGET_ROW and the normal decision gates.
  function missingFieldRefinementCandidate(canvas, analysis, field) {
    const majorAnchors = analysis.anchors.filter((anchor) =>
      targetNutritionFields.includes(anchor.field),
    );
    const heading = analysis.groups.some((group) =>
      normalizeOcrToken(group.words.map((word) => word.text).join(''))
        .includes('栄養成分表示'),
    );
    const anchor = refinementAnchor(analysis, field);
    if (!anchor) return null;
    const hasNeighboringRows = majorAnchors.length >= 2 &&
      anchor.rawText == null;
    const hasTableContext = heading || hasNeighboringRows;
    if (!hasTableContext) return null;
    return {
      anchor,
      triggerReason: hasNeighboringRows
        ? 'field-not-available-with-neighboring-nutrition-rows'
        : 'field-not-available-with-table-context',
    };
  }

  function horizontalHeaderColumnMappings(anchors, values) {
    const compatibleUnit = (field, unit) =>
      (field === 'energy' && unit === 'kcal') ||
      (field !== 'energy' && unit === 'g');
    const mapped = new Map();
    for (const value of values) {
      if (!value.unit || value.ambiguity) continue;
      const compatible = anchors.filter((anchor) =>
        compatibleUnit(anchor.field, value.unit) &&
        value.top >= anchor.bottom - Math.max(12, anchor.height * 0.2) &&
        value.top - anchor.bottom <= Math.max(260, anchor.height * 4.5),
      );
      if (!compatible.length) continue;
      const center = value.left + value.width / 2;
      const ranked = compatible.map((anchor) => ({
        anchor,
        horizontalDistance: Math.abs(center - (anchor.left + anchor.width / 2)),
      })).filter((item) => item.horizontalDistance <= Math.max(220, item.anchor.width * 1.8))
        .sort((a, b) => a.horizontalDistance - b.horizontalDistance);
      if (ranked.length !== 1 || mapped.has(ranked[0].anchor.field)) continue;
      const { anchor, horizontalDistance } = ranked[0];
      mapped.set(anchor.field, {
        ...value,
        field: anchor.field,
        mappingRule: 'local-horizontal-header-column',
        mappingReason: 'value-below-single-compatible-header-column',
        geometry: {
          sameLine: false, rightOfLabel: null,
          verticalDistance: value.top - anchor.bottom,
          horizontalDistance, relationScore: horizontalDistance,
          unitCompatibility: true, geometryConfidence: 'MEDIUM',
        },
        labelEvidence: {
          rawText: anchor.rawText, candidate: anchor.alias, status: anchor.status,
          recoveryMethod: anchor.recoveryMethod, recoveryConfidence: anchor.recoveryConfidence,
        },
      });
    }
    return mapped;
  }

  async function refineTableValueRegion(canvas, analysis) {
    const region = tableValueRegion(canvas, analysis);
    if (!region) return [];
    const roi = roiCanvas(canvas, region);
    if (!roi || roi.width < 8 || roi.height < 8) return [];
    const input = roi.toDataURL('image/png');
    const data = await recognizePass(input, {
      outputs: { text: true, tsv: true },
      pageSegmentationMode: 6,
    });
    const cropRect = {
      x: Math.max(0, Math.round(region.left)), y: Math.max(0, Math.round(region.top)),
      width: roi.width, height: roi.height,
    };
    const words = tsvWords(data.tsv || '').map((word) => ({
      ...word, left: word.left + cropRect.x, top: word.top + cropRect.y,
    }));
    const local = analyzeNutritionWords(words, analysis.sourcePass);
    const attempts = [{
      source: 'LOCAL_REFINEMENT', sourcePass: analysis.sourcePass,
      refinementPass: `${analysis.sourcePass}:${region.regionType}`,
      targetField: 'nutrition-table', regionType: region.regionType,
      triggerReason: region.triggerReason, cropRect,
      sourceImageDimensions: { width: canvas.width, height: canvas.height },
      ocrInputDimensions: { width: roi.width, height: roi.height },
      preprocessing: { pageSegmentationMode: 6 },
      cropPreviewDataUrl: roi.toDataURL('image/jpeg', 0.9),
      rawOcrText: String(data.text || ''), rawTokens: words.map((word) => word.text),
      numericValue: null, unit: null, unitStatus: null, ocrConfidence: null,
      resultStatus: local.mapped.size ? 'OBSERVED_TABLE_VALUES' : 'NO_MAPPABLE_TABLE_VALUES',
    }];

    // Table borders are often stronger than the small value glyphs. A second,
    // related observation uses a numeric/unit whitelist on the *same bounded
    // table ROI*. It is recorded separately and cannot count as another full
    // OCR pass or overwrite the Japanese/layout observation above.
    const numericData = await recognizePass(input, {
      outputs: { text: true, tsv: true },
      whitelist: '0123456789.,kcalgm',
      pageSegmentationMode: 6,
    });
    const numericWords = tsvWords(numericData.tsv || '').map((word) => ({
      ...word, left: word.left + cropRect.x, top: word.top + cropRect.y,
    }));
    attempts.push({
      source: 'LOCAL_REFINEMENT', sourcePass: analysis.sourcePass,
      refinementPass: `${analysis.sourcePass}:${region.regionType}:numeric`,
      targetField: 'nutrition-table', regionType: region.regionType,
      triggerReason: region.triggerReason, cropRect,
      sourceImageDimensions: { width: canvas.width, height: canvas.height },
      ocrInputDimensions: { width: roi.width, height: roi.height },
      preprocessing: {
        whitelist: '0123456789.,kcalgm', pageSegmentationMode: 6,
        relatedObservation: attempts[0].refinementPass,
      },
      cropPreviewDataUrl: roi.toDataURL('image/jpeg', 0.9),
      rawOcrText: String(numericData.text || ''), rawTokens: numericWords.map((word) => word.text),
      numericValue: null, unit: null, unitStatus: null, ocrConfidence: null,
      resultStatus: numericWords.length ? 'OBSERVED_TABLE_NUMERIC_TOKENS' : 'NO_TABLE_NUMERIC_TOKENS',
    });

    // The detected table heading supplies a stable vertical origin. Limit a
    // second crop to the header/value bands directly below it so that table
    // rules and unrelated package copy do not dominate PSM 6.
    const heading = analysis.groups.find((group) =>
      normalizeOcrToken(group.words.map((word) => word.text).join(''))
        .includes('栄養成分表示'),
    );
    const headingBox = heading ? boxForWords(heading.words) : null;
    if (headingBox) {
      const rowRegion = {
        left: cropRect.x,
        top: Math.max(0, headingBox.bottom + headingBox.height * 0.1),
        right: cropRect.x + cropRect.width,
        bottom: Math.min(canvas.height, headingBox.bottom + headingBox.height * 4.1),
      };
      const rowRoi = roiCanvas(canvas, rowRegion);
      if (rowRoi && rowRoi.width >= 8 && rowRoi.height >= 8) {
        const rowInput = processedVariant(rowRoi, 1.35);
        const rowData = await recognizePass(rowInput, {
          outputs: { text: true, tsv: true }, pageSegmentationMode: 6,
        });
        const rowCropRect = {
          x: Math.round(rowRegion.left), y: Math.round(rowRegion.top),
          width: rowRoi.width, height: rowRoi.height,
        };
        const rowWords = tsvWords(rowData.tsv || '').map((word) => ({
          ...word, left: word.left + rowCropRect.x, top: word.top + rowCropRect.y,
        }));
        const rowLocal = analyzeNutritionWords(rowWords, analysis.sourcePass);
        const rowNumericData = await recognizePass(rowInput, {
          outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 6,
        });
        const rowNumericWords = tsvWords(rowNumericData.tsv || '').map((word) => ({
          ...word, left: word.left + rowCropRect.x, top: word.top + rowCropRect.y,
        }));
        const rowNumericValues = numericValues(lineGroups(rowNumericWords)).map((value) => ({
          ...value, sourcePass: analysis.sourcePass,
        }));
        const columnMapped = horizontalHeaderColumnMappings(rowLocal.anchors, rowNumericValues);
        const rowAttempt = {
          source: 'LOCAL_REFINEMENT', sourcePass: analysis.sourcePass,
          refinementPass: `${analysis.sourcePass}:HORIZONTAL_HEADER_COLUMN_REGION`,
          targetField: 'nutrition-table', regionType: 'HORIZONTAL_HEADER_COLUMN_REGION',
          triggerReason: 'bounded-header-and-value-row-below-nutrition-table-heading',
          cropRect: rowCropRect,
          sourceImageDimensions: { width: canvas.width, height: canvas.height },
          ocrInputDimensions: { width: rowRoi.width, height: rowRoi.height },
          preprocessing: { grayscale: true, contrast: 1.35, pageSegmentationMode: 6,
            numericWhitelist: '0123456789.,kcalgm' },
          cropPreviewDataUrl: rowRoi.toDataURL('image/jpeg', 0.9),
          rawOcrText: String(rowData.text || ''), rawTokens: rowWords.map((word) => word.text),
          numericRawOcrText: String(rowNumericData.text || ''),
          numericRawTokens: rowNumericWords.map((word) => word.text),
          numericValue: null, unit: null, unitStatus: null, ocrConfidence: null,
          resultStatus: rowLocal.mapped.size || columnMapped.size
            ? 'OBSERVED_HEADER_COLUMN_VALUES' : 'NO_MAPPABLE_HEADER_COLUMN_VALUES',
        };
        attempts.push(rowAttempt);
        for (const [field, value] of new Map([...rowLocal.mapped, ...columnMapped]).entries()) {
          analysis.localEvidence.push({
            ...value, targetField: field, source: 'LOCAL_REFINEMENT',
            sourcePass: analysis.sourcePass, refinementPass: rowAttempt.refinementPass,
            rawToken: value.rawToken,
            supportingRawTokens: value.supportingRawTokens || [value.rawToken],
            mappingStatus: 'MAPPED', ownershipStatus: 'MAPPED',
            ownershipReason: 'local-horizontal-header-column-geometry', conflictEligible: true,
          });
        }

        // A horizontal nutrition table often has strong cell borders. Refine
        // each bounded header/value cell separately rather than asking one
        // page-segmentation pass to interpret all four columns and rules.
        const columnWidth = rowRoi.width / 4;
        // Keep the first header/value pair inside the heading-derived table
        // band. The broader row region can otherwise include the next
        // salt/mineral table and let its border join a trailing unit glyph.
        const firstValueRowBottom = Math.min(
          rowRegion.bottom,
          headingBox.bottom + headingBox.height * 3.6,
        );
        for (let column = 0; column < 4; column += 1) {
          const rawLeft = rowRegion.left + column * columnWidth;
          const rawRight = rowRegion.left + (column + 1) * columnWidth;
          // Exclude only the cell-rule edge. It is a common source of a
          // spurious trailing digit while keeping the bounded table column.
          const cellInset = Math.max(3, Math.min(14, columnWidth * 0.025));
          const cellRegion = {
            left: rawLeft + cellInset,
            top: rowRegion.top,
            right: rawRight - cellInset,
            bottom: firstValueRowBottom,
          };
          const cellRoi = roiCanvas(canvas, cellRegion);
          if (!cellRoi || cellRoi.width < 8 || cellRoi.height < 8) continue;
          const cellInput = processedVariant(cellRoi, 1.35);
          const cellData = await recognizePass(cellInput, {
            outputs: { text: true, tsv: true }, pageSegmentationMode: 6,
          });
          const cellNumericData = await recognizePass(cellInput, {
            outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 6,
          });
          // Glare can be amplified by contrast conversion in the leftmost
          // energy cell. Capture one related original-pixel numeric reading;
          // it is still the same bounded crop and remains review evidence.
          const cellOriginalNumericData = column === 0
            ? await recognizePass(cellRoi.toDataURL('image/png'), {
              outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 6,
            })
            : null;
          const cellSparseNumericData = (column === 0 || column === 2)
            ? await recognizePass(cellInput, {
              outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 11,
            })
            : null;
          // One related, character-scale-normalised observation helps small
          // numeric cells where the unit glyph can otherwise be mistaken for
          // a digit. It remains the same cell/source, never another pass.
          const cellLineScaled = scaledRoiCanvas(cellRoi, 2);
          const cellLineNumericData = await recognizePass(processedVariant(cellLineScaled, 1), {
            outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 7,
          });
          const cellThresholdNumericData = await recognizePass(thresholdVariant(cellLineScaled, 185), {
            outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 11,
          });
          const cellCropRect = {
            x: Math.round(cellRegion.left), y: Math.round(cellRegion.top),
            width: cellRoi.width, height: cellRoi.height,
          };
          const cellWords = tsvWords(cellData.tsv || '').map((word) => ({
            ...word, left: word.left + cellCropRect.x, top: word.top + cellCropRect.y,
          }));
          const cellNumericWords = tsvWords(cellNumericData.tsv || '').map((word) => ({
            ...word, left: word.left + cellCropRect.x, top: word.top + cellCropRect.y,
          }));
          const cellOriginalNumericWords = tsvWords(cellOriginalNumericData?.tsv || '').map((word) => ({
            ...word, left: word.left + cellCropRect.x, top: word.top + cellCropRect.y,
          }));
          const cellSparseNumericWords = tsvWords(cellSparseNumericData?.tsv || '').map((word) => ({
            ...word, left: word.left + cellCropRect.x, top: word.top + cellCropRect.y,
          }));
          const cellLineNumericWords = tsvWords(cellLineNumericData.tsv || '').map((word) => ({
            ...word, left: word.left / 2 + cellCropRect.x, top: word.top / 2 + cellCropRect.y,
            width: word.width / 2, height: word.height / 2,
          }));
          const cellThresholdNumericWords = tsvWords(cellThresholdNumericData.tsv || '').map((word) => ({
            ...word, left: word.left / 2 + cellCropRect.x, top: word.top / 2 + cellCropRect.y,
            width: word.width / 2, height: word.height / 2,
          }));
          const cellLocal = analyzeNutritionWords(cellWords, analysis.sourcePass);
          const baseCellValues = numericValues(lineGroups([
            ...cellNumericWords, ...cellSparseNumericWords, ...cellLineNumericWords,
          ])).map((value) => ({
            ...value, sourcePass: analysis.sourcePass,
          }));
          // A cell border can merge a trailing unit glyph into the numeric
          // token (for example, rendering a visible `g` as a digit). Re-read
          // only the detected token's numeric and unit-side glyph areas. A
          // composite is permitted solely when both pieces are independently
          // observed from that same bounded cell; no character is rewritten.
          let splitCellEvidence = null;
          let splitNumberRawOcrText = '';
          let splitUnitRawOcrText = '';
          if (!baseCellValues.some((value) => value.unit && !value.ambiguity)) {
            const sourceWord = cellNumericWords.find((word) =>
              /^[0-9.,]+$/.test(String(word.text || '')) && word.width >= 8,
            );
            if (sourceWord) {
              const localLeft = sourceWord.left - cellCropRect.x;
              const numberRegion = {
                left: Math.max(0, localLeft - 3), top: Math.max(0, sourceWord.top - cellCropRect.y - 3),
                right: Math.min(cellRoi.width, localLeft + sourceWord.width * 0.78),
                bottom: Math.min(cellRoi.height, sourceWord.top - cellCropRect.y + sourceWord.height + 3),
              };
              const unitRegion = {
                left: Math.max(0, localLeft + sourceWord.width * 0.72),
                top: numberRegion.top,
                right: Math.min(cellRoi.width, localLeft + sourceWord.width + 4),
                bottom: numberRegion.bottom,
              };
              const numberRoi = roiCanvas(cellRoi, numberRegion);
              const unitRoi = roiCanvas(cellRoi, unitRegion);
              if (numberRoi && unitRoi && numberRoi.width >= 8 && unitRoi.width >= 8) {
                const numberScaled = scaledRoiCanvas(numberRoi, 3);
                const unitScaled = scaledRoiCanvas(unitRoi, 3);
                const splitNumberData = await recognizePass(processedVariant(numberScaled, 1), {
                  outputs: { text: true, tsv: true }, whitelist: '0123456789.,', pageSegmentationMode: 7,
                });
                const splitUnitData = await recognizePass(processedVariant(unitScaled, 1), {
                  outputs: { text: true, tsv: true }, whitelist: 'g', pageSegmentationMode: 10,
                });
                const splitUnitSparseData = await recognizePass(unitScaled.toDataURL('image/png'), {
                  outputs: { text: true, tsv: true }, whitelist: 'g', pageSegmentationMode: 13,
                });
                splitNumberRawOcrText = String(splitNumberData.text || '');
                splitUnitRawOcrText = [splitUnitData.text, splitUnitSparseData.text]
                  .map((value) => String(value || '').trim()).filter(Boolean).join(' | ');
                const splitNumberWords = tsvWords(splitNumberData.tsv || '').map((word) => ({
                  ...word,
                  left: word.left / 3 + numberRegion.left + cellCropRect.x,
                  top: word.top / 3 + numberRegion.top + cellCropRect.y,
                  width: word.width / 3, height: word.height / 3,
                }));
                const splitNumbers = numericValues(lineGroups(splitNumberWords)).filter((value) =>
                  value.unit === null && !value.ambiguity,
                );
                const splitRawNumber = recoverNumericToken(splitNumberRawOcrText.trim());
                if (!splitNumbers.length && splitRawNumber.numericValue != null &&
                    splitRawNumber.candidateType === 'NUMERIC_WITHOUT_UNIT') {
                  splitNumbers.push({
                    value: splitRawNumber.numericValue, unit: null,
                    unitStatus: 'MISSING', rawToken: splitRawNumber.rawToken,
                    normalizedToken: splitRawNumber.normalizedToken,
                    candidateType: 'NUMERIC_WITHOUT_UNIT',
                    recoveryMethod: splitRawNumber.recoveryMethod,
                    recoveryConfidence: splitRawNumber.recoveryConfidence,
                    ambiguity: null,
                    left: sourceWord.left, top: sourceWord.top,
                    width: sourceWord.width * 0.78, height: sourceWord.height,
                    lineKey: sourceWord.lineKey,
                  });
                }
                const observedUnit = splitUnitRawOcrText.split('|').some((value) => /^g$/i.test(value.trim()));
                if (splitNumbers.length === 1 && observedUnit) {
                  splitCellEvidence = {
                    ...splitNumbers[0], unit: 'g', unitStatus: 'EXACT', sourcePass: analysis.sourcePass,
                    rawToken: `${splitNumbers[0].rawToken}+g`,
                    recoveryMethod: 'local-cell-number-unit-pixel-observation',
                    recoveryConfidence: 0.72,
                  };
                }
              }
            }
          }
          // Preprocessing variants share the same pixels. If the base cell
          // already produced a complete numeric/unit observation, retain it
          // rather than letting a threshold artefact change its value.
          const cellValues = baseCellValues.some((value) => value.unit && !value.ambiguity)
            ? baseCellValues
            : [...baseCellValues, ...numericValues(lineGroups(cellThresholdNumericWords)).map((value) => ({
              ...value, sourcePass: analysis.sourcePass,
            })), ...(splitCellEvidence ? [splitCellEvidence] : [])];
          // Cell-local recovery is allowed only after a bounded nutrition
          // table cell produced a compatible gram value below the damaged
          // label. It does not apply to general OCR text.
          const localFatRawText = String(cellData.text || '').match(/脂[質賞匠]/)?.[0] || null;
          if (!cellLocal.anchors.some((anchor) => anchor.field === 'fat') &&
              (cellWords.some((word) => /脂[質賞匠]/.test(String(word.text || ''))) || localFatRawText) &&
              cellValues.some((value) => value.unit === 'g' && !value.ambiguity)) {
            const labelWords = cellWords.filter((word) => normalizeOcrToken(word.text).includes('脂'));
            const labelBox = labelWords.length ? boxForWords(labelWords) : {
              left: cellCropRect.x,
              top: cellCropRect.y,
              width: cellRoi.width,
              height: cellRoi.height * 0.48,
            };
            cellLocal.anchors.push({
              field: 'fat', alias: '脂質', rawText: labelWords.map((word) => word.text).join('') || localFatRawText,
              status: 'RECOVERED_MEDIUM', recoveryMethod: 'local-nutrition-label-confusion',
              recoveryConfidence: 0.62, ambiguity: null, lineKey: `local-cell-${column + 1}`,
              confidence: labelWords.length ? averageConfidence(labelWords) : null,
              ...labelBox, sourcePass: analysis.sourcePass,
            });
          }
          const cellMapped = horizontalHeaderColumnMappings(cellLocal.anchors, cellValues);
          // kcal is uniquely compatible with energy among the supported
          // nutrition fields. In a bounded nutrition-table cell it provides
          // medium, review-only ownership even when glare hides its label.
          if (!cellMapped.has('energy')) {
            const kcalValues = cellValues.filter((value) => value.unit === 'kcal' && !value.ambiguity);
            if (kcalValues.length === 1) {
              cellMapped.set('energy', {
                ...kcalValues[0], field: 'energy', mappingRule: 'local-kcal-table-cell',
                mappingReason: 'unique-kcal-value-in-bounded-nutrition-table-cell',
                geometry: { sameLine: null, rightOfLabel: null, verticalDistance: null,
                  horizontalDistance: null, relationScore: null, unitCompatibility: true,
                  geometryConfidence: 'MEDIUM' },
                labelEvidence: { rawText: '栄養成分表示', candidate: 'nutrition-table',
                  status: 'RECOVERED_MEDIUM', recoveryMethod: 'bounded-table-context', recoveryConfidence: 0.6 },
              });
            }
          }
          const cellAttempt = {
            source: 'LOCAL_REFINEMENT', sourcePass: analysis.sourcePass,
            refinementPass: `${analysis.sourcePass}:HORIZONTAL_HEADER_COLUMN_REGION:cell-${column + 1}`,
            targetField: 'nutrition-table', regionType: 'HORIZONTAL_HEADER_COLUMN_REGION',
            triggerReason: 'bounded-horizontal-nutrition-header-value-cell', cropRect: cellCropRect,
            sourceImageDimensions: { width: canvas.width, height: canvas.height },
            ocrInputDimensions: { width: cellRoi.width, height: cellRoi.height },
            preprocessing: { grayscale: true, contrast: 1.35, pageSegmentationMode: 6,
              numericWhitelist: '0123456789.,kcalgm', tableColumn: column + 1 },
            cropPreviewDataUrl: cellRoi.toDataURL('image/jpeg', 0.9),
            rawOcrText: String(cellData.text || ''), rawTokens: cellWords.map((word) => word.text),
            numericRawOcrText: String(cellNumericData.text || ''),
            numericRawTokens: cellNumericWords.map((word) => word.text),
            originalNumericRawOcrText: String(cellOriginalNumericData?.text || ''),
            originalNumericRawTokens: cellOriginalNumericWords.map((word) => word.text),
            sparseNumericRawOcrText: String(cellSparseNumericData?.text || ''),
            sparseNumericRawTokens: cellSparseNumericWords.map((word) => word.text),
            lineNumericRawOcrText: String(cellLineNumericData.text || ''),
            lineNumericRawTokens: cellLineNumericWords.map((word) => word.text),
            thresholdNumericRawOcrText: String(cellThresholdNumericData.text || ''),
            thresholdNumericRawTokens: cellThresholdNumericWords.map((word) => word.text),
            splitNumberRawOcrText, splitUnitRawOcrText,
            splitCellEvidence: splitCellEvidence ? {
              value: splitCellEvidence.value, unit: splitCellEvidence.unit,
              rawToken: splitCellEvidence.rawToken,
            } : null,
            numericValue: null, unit: null, unitStatus: null, ocrConfidence: null,
            resultStatus: cellLocal.mapped.size || cellMapped.size
              ? 'OBSERVED_HEADER_COLUMN_VALUES' : 'NO_MAPPABLE_HEADER_COLUMN_VALUES',
          };
          attempts.push(cellAttempt);
          for (const [field, value] of new Map([...cellLocal.mapped, ...cellMapped]).entries()) {
            analysis.localEvidence.push({
              ...value, targetField: field, source: 'LOCAL_REFINEMENT',
              sourcePass: analysis.sourcePass, refinementPass: cellAttempt.refinementPass,
              rawToken: value.rawToken,
              supportingRawTokens: value.supportingRawTokens || [value.rawToken],
              mappingStatus: 'MAPPED', ownershipStatus: 'MAPPED',
              ownershipReason: 'local-horizontal-header-cell-geometry', conflictEligible: true,
            });
          }

          // The first data row can be obscured by the lower salt/calcium
          // table. Re-read only the upper portion of the first column, using
          // the heading height as the bound rather than image coordinates.
          if (column === 0) {
            const upperRegion = {
              ...cellRegion,
              bottom: Math.min(cellRegion.bottom, headingBox.bottom + headingBox.height * 2.85),
            };
            const upperRoi = roiCanvas(canvas, upperRegion);
            if (upperRoi && upperRoi.width >= 8 && upperRoi.height >= 8) {
              const upperScaled = document.createElement('canvas');
              upperScaled.width = upperRoi.width * 2;
              upperScaled.height = upperRoi.height * 2;
              const upperScaledContext = upperScaled.getContext('2d', { alpha: false });
              upperScaledContext.imageSmoothingEnabled = true;
              upperScaledContext.imageSmoothingQuality = 'high';
              upperScaledContext.drawImage(upperRoi, 0, 0, upperScaled.width, upperScaled.height);
              const upperData = await recognizePass(processedVariant(upperScaled, 1), {
                outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 11,
              });
              const upperLineData = await recognizePass(processedVariant(upperScaled, 1), {
                outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 7,
              });
              const upperThresholdData = await recognizePass(thresholdVariant(upperScaled), {
                outputs: { text: true, tsv: true }, whitelist: '0123456789.,kcalgm', pageSegmentationMode: 11,
              });
              const upperCropRect = {
                x: Math.round(upperRegion.left), y: Math.round(upperRegion.top),
                width: upperRoi.width, height: upperRoi.height,
              };
              const upperWords = tsvWords(upperData.tsv || '').map((word) => ({
                ...word, left: word.left / 2 + upperCropRect.x, top: word.top / 2 + upperCropRect.y,
              }));
              const upperLineWords = tsvWords(upperLineData.tsv || '').map((word) => ({
                ...word, left: word.left / 2 + upperCropRect.x, top: word.top / 2 + upperCropRect.y,
              }));
              const upperThresholdWords = tsvWords(upperThresholdData.tsv || '').map((word) => ({
                ...word, left: word.left / 2 + upperCropRect.x, top: word.top / 2 + upperCropRect.y,
              }));
              const upperValues = numericValues(lineGroups([
                ...upperWords, ...upperLineWords, ...upperThresholdWords,
              ]));
              const kcalValues = upperValues.filter((value) => value.unit === 'kcal' && !value.ambiguity);
              const upperAttempt = {
                source: 'LOCAL_REFINEMENT', sourcePass: analysis.sourcePass,
                refinementPass: `${analysis.sourcePass}:HORIZONTAL_HEADER_COLUMN_REGION:cell-1-upper-value-row`,
                targetField: 'energy', regionType: 'HORIZONTAL_HEADER_COLUMN_REGION',
                triggerReason: 'first-table-value-row-separated-from-lower-nutrition-table', cropRect: upperCropRect,
                sourceImageDimensions: { width: canvas.width, height: canvas.height },
                ocrInputDimensions: { width: upperScaled.width, height: upperScaled.height },
                preprocessing: { grayscale: true, contrast: 1, pageSegmentationMode: 11,
                  numericWhitelist: '0123456789.,kcalgm', upperValueRowOnly: true, upscale: 2, threshold: 170 },
                cropPreviewDataUrl: upperRoi.toDataURL('image/jpeg', 0.9),
                rawOcrText: String(upperData.text || ''), rawTokens: upperWords.map((word) => word.text),
                lineRawOcrText: String(upperLineData.text || ''), lineRawTokens: upperLineWords.map((word) => word.text),
                thresholdRawOcrText: String(upperThresholdData.text || ''),
                thresholdRawTokens: upperThresholdWords.map((word) => word.text),
                numericValue: kcalValues.length === 1 ? kcalValues[0].value : null,
                unit: kcalValues.length === 1 ? 'kcal' : null,
                unitStatus: kcalValues.length === 1 ? 'EXACT' : null, ocrConfidence: null,
                resultStatus: kcalValues.length === 1 ? 'OBSERVED_ENERGY_VALUE' : 'NO_UNIQUE_ENERGY_VALUE',
              };
              attempts.push(upperAttempt);
              if (upperAttempt.numericValue != null) {
                analysis.localEvidence.push({
                  ...kcalValues[0], targetField: 'energy', source: 'LOCAL_REFINEMENT',
                  sourcePass: analysis.sourcePass, refinementPass: upperAttempt.refinementPass,
                  rawToken: kcalValues[0].rawToken,
                  supportingRawTokens: [kcalValues[0].rawToken], mappingStatus: 'MAPPED',
                  ownershipStatus: 'MAPPED', ownershipReason: 'local-upper-horizontal-energy-cell',
                  conflictEligible: true,
                  geometry: { sameLine: null, rightOfLabel: null, verticalDistance: null,
                    horizontalDistance: null, relationScore: null, unitCompatibility: true,
                    geometryConfidence: 'MEDIUM' },
                  labelEvidence: { rawText: '栄養成分表示', candidate: 'nutrition-table',
                    status: 'RECOVERED_MEDIUM', recoveryMethod: 'bounded-table-context', recoveryConfidence: 0.6 },
                });
              }
            }
          }
        }
      }
    }
    analysis.localRefinement = [...(analysis.localRefinement || []), ...attempts];
    for (const [field, value] of local.mapped.entries()) {
      analysis.localEvidence.push({
        ...value,
        targetField: field,
        source: 'LOCAL_REFINEMENT',
        sourcePass: analysis.sourcePass,
        refinementPass: attempts[0].refinementPass,
        rawToken: value.rawToken,
        supportingRawTokens: value.supportingRawTokens || [value.rawToken],
        mappingStatus: 'MAPPED', ownershipStatus: 'MAPPED',
        ownershipReason: 'local-table-region-geometry-mapping', conflictEligible: true,
      });
    }
    return attempts;
  }

  function addLocalRefinementEvidence(analysis, attempts) {
    analysis.localRefinement = [...(analysis.localRefinement || []), ...attempts];
    for (const attempt of attempts) {
      if (attempt.numericValue == null ||
          attempt.rowOwnership !== 'SAME_TARGET_ROW') continue;
      const anchor = attempt.refinementAnchor ||
        refinementAnchor(analysis, attempt.targetField);
      if (!anchor) continue;
      analysis.localEvidence.push({
        targetField: attempt.targetField,
        value: attempt.numericValue,
        unit: attempt.unit,
        rawToken: attempt.rawOcrText,
        supportingRawTokens: attempt.rawTokens.length ? attempt.rawTokens : [attempt.rawOcrText],
        normalizedToken: `${attempt.numericValue}${attempt.unit || ''}`,
        normalizationCandidates: [],
        candidateType: attempt.unit ? 'NUMERIC_WITH_UNIT' : 'NUMERIC_WITHOUT_UNIT',
        unitStatus: attempt.unitStatus || (attempt.unit ? 'EXACT' : 'MISSING'),
        recoveryMethod: 'local-ocr-refinement',
        recoveryConfidence: 0.75,
        ambiguity: null,
        source: 'LOCAL_REFINEMENT',
        sourcePass: analysis.sourcePass,
        refinementPass: attempt.refinementPass,
        lineKey: `local:${attempt.refinementPass}`,
        left: attempt.candidateGeometry?.left ?? attempt.cropRect.x,
        top: attempt.candidateGeometry?.top ?? attempt.cropRect.y,
        width: attempt.candidateGeometry?.width ?? attempt.cropRect.width,
        height: attempt.candidateGeometry?.height ?? attempt.cropRect.height,
        ocrConfidence: null,
        mappingStatus: 'MAPPED',
        ownershipStatus: 'MAPPED',
        ownershipReason: 'local-refinement-same-target-row-geometry',
        conflictEligible: true,
        geometry: {
          sameLine: null,
          rightOfLabel: null,
          verticalDistance: null,
          horizontalDistance: null,
          relationScore: null,
          unitCompatibility: Boolean(attempt.unit),
          geometryConfidence: 'MEDIUM',
        },
        labelEvidence: {
          rawText: anchor.rawText || anchor.alias,
          candidate: anchor.alias,
          status: anchor.status || 'EXACT',
          recoveryMethod: anchor.recoveryMethod || 'exact-label',
          recoveryConfidence: anchor.recoveryConfidence ?? 1,
        },
      });
    }
  }

  // Compatibility wrapper for the single-pass structured path. Multi-pass
  // processing below keeps the complete refinement trace on its analysis.
  async function valueFromRoi(canvas, anchor, field) {
    const analysis = {
      sourcePass: anchor.sourcePass || 'original',
      anchors: [anchor],
      localEvidence: [],
      localRefinement: [],
    };
    const attempts = await localRefinementFromRegions(
      canvas,
      analysis,
      field,
      'label-detected-without-compatible-value',
    );
    const attempt = attempts.find((item) => item.numericValue != null);
    return attempt ? { value: attempt.numericValue, unit: attempt.unit } : null;
  }

  async function structuredNutritionWords(canvas, words, engineId, sourcePass = 'original') {
    const analysis = analyzeNutritionWords(words, sourcePass);
    const { groups, anchors, values, semanticValues, mapped } = analysis;
    const mappingBeforeFallback = structuredMappingDiagnostics(
      anchors,
      semanticValues,
      mapped,
    );
    let roiCount = 0;
    const roiFields = [];
    for (const field of targetNutritionFields) {
      if (mapped.has(field)) continue;
      const anchor = anchors.find((candidate) => candidate.field === field);
      if (!anchor || engineId !== 'tesseract') continue;
      roiCount += 1;
      const value = await valueFromRoi(canvas, anchor, field);
      if (value) {
        mapped.set(field, {
          ...value,
          rawToken: `${value.value}${value.unit}`,
          normalizedToken: `${value.value}${value.unit}`,
          normalizationCandidates: [],
          candidateType: 'NUMERIC_WITH_UNIT',
          unitStatus: 'EXACT',
          recoveryMethod: 'numeric-roi-fallback',
          recoveryConfidence: 0.7,
          ambiguity: null,
          sourcePass,
          geometry: {
            sameLine: null,
            rightOfLabel: null,
            verticalDistance: null,
            horizontalDistance: null,
            relationScore: null,
            unitCompatibility: true,
            geometryConfidence: 'MEDIUM',
          },
          labelEvidence: {
            rawText: anchor.rawText || anchor.alias,
            candidate: anchor.alias,
            status: anchor.status || 'EXACT',
            recoveryMethod: anchor.recoveryMethod || 'exact-label',
            recoveryConfidence: anchor.recoveryConfidence ?? 1,
          },
        });
        roiFields.push(field);
      }
    }
    const consensus = consensusForAnalyses([analysis]);
    const consistency = nutritionConsistency(consensus);
    applyNutritionConsistency(consensus, consistency);
    const fieldLabel = {
      energy: 'エネルギー',
      protein: 'たんぱく質',
      fat: '脂質',
      carbohydrate: '炭水化物',
    };
    lastStructuredDiagnostics = {
      layoutPattern: layoutPattern(anchors, mapped),
      anchors: anchors.map((anchor) => ({
        field: anchor.field,
        alias: anchor.alias,
        left: anchor.left,
        top: anchor.top,
        width: anchor.width,
        height: anchor.height,
      })),
      valueRoiCount: roiCount,
      roiFields,
      engineId,
      detectedLabels: labelDiagnostics(groups, anchors),
      tokenRecovery: values.map((value) => numericDiagnostic(value, anchors)),
      labelRecovery: anchors.map((anchor) => ({
        rawText: anchor.rawText,
        candidate: anchor.alias,
        field: anchor.field,
        sourcePass: anchor.sourcePass,
        method: anchor.recoveryMethod,
        confidence: anchor.recoveryConfidence,
        status: anchor.status,
        ambiguity: anchor.ambiguity,
        contextEvidence: anchor.contextEvidence || [],
      })),
      numericRecovery: values.map((value) => numericDiagnostic(value, anchors)),
      numericCandidates: values.map((value) => numericDiagnostic(value, anchors)),
      semanticDuplicateCollapse: semanticValues
        .filter((value) => value.rawCandidateCount > 1)
        .map((value) => ({
          sourcePass: value.sourcePass,
          value: value.value,
          unit: value.unit,
          unitStatus: value.unitStatus,
          supportingRawTokens: value.supportingRawTokens,
          rawCandidateCount: value.rawCandidateCount,
          representativeRawToken: value.rawToken,
          reason: value.duplicateCollapseReason,
          suppressedCandidates: value.suppressedCandidates,
        })),
      preMappingEvidence: targetNutritionFields.flatMap((field) =>
        evidenceForField(analysis, field).map((item) => ({
          field,
          value: item.value,
          unit: item.unit,
          unitStatus: item.unitStatus,
          rawTokens: item.supportingRawTokens || [item.rawToken],
          sourcePass: item.sourcePass,
          mappingStatus: item.mappingStatus,
          ownershipStatus: item.ownershipStatus,
          conflictEligible: item.conflictEligible,
          geometry: item.geometry,
        })),
      ),
      fieldOwnership: fieldOwnershipDiagnostics([analysis]),
      structuredCandidates: mappingBeforeFallback,
      geometryMapping: mappingBeforeFallback,
      unitTieBreak: mappingBeforeFallback.filter((item) =>
        item.selectionReason?.includes('unit-preferred'),
      ),
      multiPassConsensus: Object.values(consensus).map((decision) => ({
        field: decision.field,
        value: decision.value,
        unit: decision.unit,
        unitStatus: decision.unitStatus,
        agreement: decision.agreement,
        supportingPasses: decision.supportingPasses,
        supportingPassCount: decision.supportingPassCount,
        conflictingPassCount: decision.conflictingPassCount,
        ambiguousRelatedPassCount: decision.ambiguousRelatedPassCount,
        conflict: decision.conflict,
        consensusStatus: decision.consensusStatus,
        conflictingCandidates: decision.conflictingCandidates,
        excludedEvidence: decision.excludedEvidence,
      })),
      conflicts: Object.values(consensus)
        .filter((decision) => decision.conflict),
      nutritionConsistency: consistency,
      confidenceDecisions: Object.values(consensus).map((decision) => ({
        field: decision.field,
        value: decision.value,
        unit: decision.unit,
        unitStatus: decision.unitStatus,
        confidence: decision.confidence,
        source: decision.source,
        reviewRequired: decision.reviewRequired,
        conflict: decision.conflict,
        consistencySupport: decision.consistencySupport,
        decision: decision.decision,
        decisionReason: decision.decisionReason,
        supportingPasses: decision.supportingPasses,
        rawTokens: decision.rawTokens,
        consensusStatus: decision.consensusStatus,
        excludedEvidence: decision.excludedEvidence,
        selectedEvidence: decision.selectedEvidence,
        ownershipEvidence: decision.selectedEvidence ? {
          ownershipStatus: decision.selectedEvidence.ownershipStatus,
          ownershipReason: decision.selectedEvidence.ownershipReason,
          conflictEligible: decision.selectedEvidence.conflictEligible,
        } : null,
      })),
      selectedMappings: Object.fromEntries(
        Object.entries(consensus)
          .filter(([, decision]) => decision.value != null && !decision.conflict)
          .map(([field, decision]) => [field, {
            value: decision.value,
            unit: decision.unit,
            source: decision.source,
            confidence: decision.confidence,
            reviewRequired: decision.reviewRequired,
          }]),
      ),
      fieldSources: Object.fromEntries(
        Object.entries(consensus)
          .filter(([, decision]) => decision.value != null && !decision.conflict)
          .map(([field, decision]) => [field, decision.source]),
      ),
    };
    const lines = [];
    const normalizedContext = groups
      .map((group) => group.words.map((word) => word.text).join(' '))
      .join('\n');
    const nutritionContextIndex = normalizeOcrToken(normalizedContext)
      .indexOf('栄養成分表示');
    if (nutritionContextIndex >= 0) {
      const basis = normalizedContext.match(nutritionBasisPattern);
      if (basis) lines.push(`栄養成分表示 ${basis[0]}`);
    }
    for (const field of targetNutritionFields) {
      const decision = consensus[field];
      if (decision?.value != null && decision.unit && !decision.conflict &&
          decision.confidence !== 'LOW') {
        lines.push(`${fieldLabel[field]} ${decision.value}${decision.unit}`);
      }
    }
    const hasDecisionEvidence = Object.values(consensus).some((decision) =>
      decision.value != null,
    );
    return lines.length || hasDecisionEvidence
      ? structuredMarker + lines.join('\n') + decisionMarker + JSON.stringify(
          Object.fromEntries(Object.entries(consensus).map(([field, decision]) => [
            field,
            {
              value: decision.value,
              unit: decision.unit,
              unitStatus: decision.unitStatus,
              confidence: decision.confidence,
              source: decision.source,
              reviewRequired: decision.reviewRequired,
              conflict: decision.conflict,
              consistencySupport: decision.consistencySupport,
              decision: decision.decision,
              decisionReason: decision.decisionReason,
              supportingPasses: decision.supportingPasses,
              rawTokens: decision.rawTokens,
              selectedEvidence: bridgeSelectedEvidence(decision.selectedEvidence),
              ownershipEvidence: decision.selectedEvidence ? {
                ownershipStatus: decision.selectedEvidence.ownershipStatus,
                ownershipReason: decision.selectedEvidence.ownershipReason,
                conflictEligible: decision.selectedEvidence.conflictEligible,
              } : null,
              labelEvidence: decision.selectedEvidence?.labelEvidence
                ? {
                    field: decision.field,
                    status: decision.selectedEvidence.labelEvidence.status,
                    recoveryMethod: decision.selectedEvidence.labelEvidence.recoveryMethod,
                    recoveryConfidence: decision.selectedEvidence.labelEvidence.recoveryConfidence,
                  }
                : null,
              consensusStatus: decision.consensusStatus,
            },
          ])),
        )
      : '';
  }

  async function structuredNutritionText(canvas, tsv) {
    return structuredNutritionWords(canvas, tsvWords(tsv), 'tesseract');
  }

  async function structuredNutritionPasses(canvas, passes, {
    allowRoiFallback = true,
  } = {}) {
    if (passes.length === 1) {
      return structuredNutritionWords(
        canvas,
        tsvWords(passes[0].tsv),
        'tesseract',
        passes[0].name,
      );
    }
    const analyses = passes.map((pass) =>
      analyzeNutritionWords(tsvWords(pass.tsv), pass.name),
    );
    let consensus = consensusForAnalyses(analyses);
    const original = analyses.find((analysis) => analysis.sourcePass === 'original') ||
      analyses[0];
    const roiFields = [];
    if (allowRoiFallback && canvas.width > 0 && canvas.height > 0 &&
        typeof document?.createElement === 'function') {
      // A detected table header is enough to re-read its bounded value row
      // when *any* major field is missing. This does not make a missing field
      // acceptable; it only adds observable local pixel evidence.
      if (targetNutritionFields.some((field) => consensus[field]?.value == null)) {
        const tableAnalysis = analyses.find((analysis) => tableValueRegion(canvas, analysis));
        if (tableAnalysis) {
          const attempts = await refineTableValueRegion(canvas, tableAnalysis);
          if (attempts.length) roiFields.push('nutrition-table');
          consensus = consensusForAnalyses(analyses);
        }
      }
      for (const field of targetNutritionFields) {
        const decision = consensus[field];
        let triggerReason = decision?.conflict
          ? 'cross-pass-conflict'
          : decision?.value == null
            ? 'label-or-table-context-without-compatible-value'
            : null;
        if (!triggerReason) continue;
        let candidateAnalysis = null;
        let anchorOverride = null;
        for (const analysis of analyses) {
          const anchor = refinementAnchor(analysis, field);
          if (!anchor) continue;
          // Existing direct/recovered label behaviour stays available for
          // conflicts and incomplete mapped fields. Missing labels require
          // explicit pass-local table/row context before a structural anchor
          // can schedule a bounded re-read.
          if (anchor.rawText != null || decision?.conflict) {
            candidateAnalysis = analysis;
            anchorOverride = anchor;
            break;
          }
          if (decision?.value == null) {
            const missing = missingFieldRefinementCandidate(canvas, analysis, field);
            if (missing) {
              candidateAnalysis = analysis;
              anchorOverride = missing.anchor;
              triggerReason = missing.triggerReason;
              break;
            }
          }
        }
        if (!candidateAnalysis) continue;
        const attempts = await localRefinementFromRegions(
          canvas,
          candidateAnalysis,
          field,
          triggerReason,
          anchorOverride,
        );
        addLocalRefinementEvidence(candidateAnalysis, attempts);
        if (attempts.length) roiFields.push(field);
      }
    }
    consensus = consensusForAnalyses(analyses);
    const consistency = nutritionConsistency(consensus);
    applyNutritionConsistency(consensus, consistency);
    const labels = {
      energy: 'エネルギー',
      protein: 'たんぱく質',
      fat: '脂質',
      carbohydrate: '炭水化物',
    };
    const allValues = analyses.flatMap((analysis) => analysis.values);
    const localRefinement = analyses.flatMap((analysis) => analysis.localRefinement || []);
    const passLocalNumericDiagnostics = analyses.flatMap((analysis) =>
      analysis.values.map((value) => numericDiagnostic(value, analysis.anchors)),
    );
    const allSemanticValues = analyses.flatMap((analysis) => analysis.semanticValues);
    const allAnchors = analyses.flatMap((analysis) => analysis.anchors);
    const mappings = analyses.flatMap((analysis) =>
      structuredMappingDiagnostics(
        analysis.anchors,
        analysis.semanticValues,
        analysis.mapped,
      ).map((mapping) => ({ ...mapping, sourcePass: analysis.sourcePass })),
    );
    const selectedMappings = Object.fromEntries(
      Object.entries(consensus)
        .filter(([, decision]) => decision.value != null && !decision.conflict)
        .map(([field, decision]) => [field, {
          value: decision.value,
          unit: decision.unit,
          source: decision.source,
          confidence: decision.confidence,
          reviewRequired: decision.reviewRequired,
        }]),
    );
    lastStructuredDiagnostics = {
      layoutPattern: layoutPattern(original.anchors, original.mapped),
      anchors: allAnchors.map((anchor) => ({
        field: anchor.field,
        alias: anchor.alias,
        rawText: anchor.rawText,
        status: anchor.status,
        sourcePass: anchor.sourcePass,
        left: anchor.left,
        top: anchor.top,
        width: anchor.width,
        height: anchor.height,
      })),
      valueRoiCount: roiFields.length,
      roiFields,
      localRefinementAttempts: localRefinement,
      localRefinementSummary: {
        attempts: localRefinement.length,
        evidenceCount: localRefinement.filter((item) => item.numericValue != null).length,
        resolvedFields: [...new Set(localRefinement
          .filter((item) => item.numericValue != null)
          .map((item) => item.targetField))],
        stillReviewRequiredFields: Object.values(consensus)
          .filter((decision) => decision.reviewRequired)
          .map((decision) => decision.field),
      },
      engineId: 'tesseract',
      detectedLabels: analyses.flatMap((analysis) =>
        labelDiagnostics(analysis.groups, analysis.anchors).map((label) => ({
          ...label,
          sourcePass: analysis.sourcePass,
        })),
      ),
      tokenRecovery: passLocalNumericDiagnostics,
      labelRecovery: allAnchors.map((anchor) => ({
        rawText: anchor.rawText,
        candidate: anchor.alias,
        field: anchor.field,
        sourcePass: anchor.sourcePass,
        method: anchor.recoveryMethod,
        confidence: anchor.recoveryConfidence,
        status: anchor.status,
        ambiguity: anchor.ambiguity,
        contextEvidence: anchor.contextEvidence || [],
      })),
      numericRecovery: passLocalNumericDiagnostics,
      numericCandidates: passLocalNumericDiagnostics,
      semanticDuplicateCollapse: allSemanticValues
        .filter((value) => value.rawCandidateCount > 1)
        .map((value) => ({
          sourcePass: value.sourcePass,
          value: value.value,
          unit: value.unit,
          unitStatus: value.unitStatus,
          supportingRawTokens: value.supportingRawTokens,
          rawCandidateCount: value.rawCandidateCount,
          representativeRawToken: value.rawToken,
          reason: value.duplicateCollapseReason,
          suppressedCandidates: value.suppressedCandidates,
        })),
      preMappingEvidence: analyses.flatMap((analysis) =>
        targetNutritionFields.flatMap((field) =>
          evidenceForField(analysis, field).map((item) => ({
            field,
            value: item.value,
            unit: item.unit,
            unitStatus: item.unitStatus,
            rawTokens: item.supportingRawTokens || [item.rawToken],
            sourcePass: item.sourcePass,
            mappingStatus: item.mappingStatus,
            ownershipStatus: item.ownershipStatus,
            conflictEligible: item.conflictEligible,
            geometry: item.geometry,
          })),
        )),
      fieldOwnership: fieldOwnershipDiagnostics(analyses),
      structuredCandidates: mappings,
      geometryMapping: mappings,
      unitTieBreak: mappings.filter((item) =>
        item.selectionReason?.includes('unit-preferred'),
      ),
      multiPassConsensus: Object.values(consensus).map((decision) => ({
        field: decision.field,
        value: decision.value,
        unit: decision.unit,
        unitStatus: decision.unitStatus,
        agreement: decision.agreement,
        supportingPasses: decision.supportingPasses,
        supportingPassCount: decision.supportingPassCount,
        conflictingPassCount: decision.conflictingPassCount,
        ambiguousRelatedPassCount: decision.ambiguousRelatedPassCount,
        conflict: decision.conflict,
        consensusStatus: decision.consensusStatus,
        conflictingCandidates: decision.conflictingCandidates,
        excludedEvidence: decision.excludedEvidence,
      })),
      conflicts: Object.values(consensus).filter((decision) => decision.conflict),
      nutritionConsistency: consistency,
      confidenceDecisions: Object.values(consensus).map((decision) => ({
        field: decision.field,
        value: decision.value,
        unit: decision.unit,
        unitStatus: decision.unitStatus,
        confidence: decision.confidence,
        source: decision.source,
        reviewRequired: decision.reviewRequired,
        conflict: decision.conflict,
        consistencySupport: decision.consistencySupport,
        decision: decision.decision,
        decisionReason: decision.decisionReason,
        supportingPasses: decision.supportingPasses,
        rawTokens: decision.rawTokens,
        consensusStatus: decision.consensusStatus,
        excludedEvidence: decision.excludedEvidence,
        selectedEvidence: decision.selectedEvidence,
        ownershipEvidence: decision.selectedEvidence ? {
          ownershipStatus: decision.selectedEvidence.ownershipStatus,
          ownershipReason: decision.selectedEvidence.ownershipReason,
          conflictEligible: decision.selectedEvidence.conflictEligible,
        } : null,
      })),
      selectedMappings,
      fieldSources: Object.fromEntries(
        Object.entries(consensus)
          .filter(([, decision]) => decision.value != null && !decision.conflict)
          .map(([field, decision]) => [field, decision.source]),
      ),
    };
    const lines = [];
    const basis = analyses.flatMap((analysis) => analysis.groups)
      .map((group) => recoverNutritionBasis(
        group.words.map((word) => word.text).join(' '),
      ))
      .find(Boolean);
    if (basis) lines.push(`栄養成分表示 ${basis.basis}`);
    for (const field of targetNutritionFields) {
      const decision = consensus[field];
      if (decision?.value != null && decision.unit && !decision.conflict &&
          decision.confidence !== 'LOW') {
        lines.push(`${labels[field]} ${decision.value}${decision.unit}`);
      }
    }
    const hasDecisionEvidence = Object.values(consensus).some((decision) =>
      decision.value != null,
    );
    return lines.length || hasDecisionEvidence
      ? structuredMarker + lines.join('\n') + decisionMarker + JSON.stringify(
          Object.fromEntries(Object.entries(consensus).map(([field, decision]) => [
            field,
            {
              value: decision.value,
              unit: decision.unit,
              unitStatus: decision.unitStatus,
              confidence: decision.confidence,
              source: decision.source,
              reviewRequired: decision.reviewRequired,
              conflict: decision.conflict,
              consistencySupport: decision.consistencySupport,
              decision: decision.decision,
              decisionReason: decision.decisionReason,
              supportingPasses: decision.supportingPasses,
              rawTokens: decision.rawTokens,
              selectedEvidence: bridgeSelectedEvidence(decision.selectedEvidence),
              ownershipEvidence: decision.selectedEvidence ? {
                ownershipStatus: decision.selectedEvidence.ownershipStatus,
                ownershipReason: decision.selectedEvidence.ownershipReason,
                conflictEligible: decision.selectedEvidence.conflictEligible,
              } : null,
              labelEvidence: decision.selectedEvidence?.labelEvidence
                ? {
                    field: decision.field,
                    status: decision.selectedEvidence.labelEvidence.status,
                    recoveryMethod: decision.selectedEvidence.labelEvidence.recoveryMethod,
                    recoveryConfidence: decision.selectedEvidence.labelEvidence.recoveryConfidence,
                  }
                : null,
              consensusStatus: decision.consensusStatus,
            },
          ])),
        )
      : '';
  }

  async function structuredPaddleNutritionText(canvas, items) {
    return structuredNutritionWords(canvas, paddleWords(items), 'paddle');
  }

  async function recognizePaddleNutrition(
    canvas,
    source = 'capture',
    reuseRun = false,
  ) {
    const result = await recognizePaddlePass(canvas, source, reuseRun);
    const texts = [];
    if (result.text.trim()) texts.push(result.text);
    recordPaddleStage('P25', 'success', {
      textBlockCount: result.items.length,
    });
    const structured = await structuredPaddleNutritionText(canvas, result.items);
    if (structured) texts.push(structured);
    recordPaddleStage('P26', 'success', {
      structuredCandidate: Boolean(structured),
    });
    completePaddleDiagnostics();
    return {
      engineId: result.engineId,
      texts,
      result,
      structured,
    };
  }

  let sharedOcrArtifactSequence = 0;

  function diagnosticPassFromLayoutPass(pass) {
    const words = tsvWords(pass.tsv);
    const groups = lineGroups(words);
    const anchors = nutritionAnchors(groups).map((anchor) => ({
      ...anchor,
      sourcePass: pass.name,
    }));
    const values = numericValues(groups).map((value) => ({
      ...value,
      sourcePass: pass.name,
    }));
    return {
      preprocessVariant: pass.name,
      rawText: pass.rawText,
      lines: groups.map((group) => group.words.map((word) => word.text).join(' ')),
      words: nutritionWordDiagnostics(words),
      tokenRecovery: values.map((value) => numericDiagnostic(value, anchors)),
      labelRecovery: anchors.map((anchor) => ({
        rawText: anchor.rawText,
        candidate: anchor.alias,
        field: anchor.field,
        sourcePass: pass.name,
        method: anchor.recoveryMethod,
        confidence: anchor.recoveryConfidence,
        status: anchor.status,
        ambiguity: anchor.ambiguity,
      })),
      numericRecovery: values.map((value) => numericDiagnostic(value, anchors)),
      wordCount: words.length,
      averageConfidence: averageConfidence(words),
    };
  }

  async function collectSharedOcrPasses(variants, recognize = recognizeLayoutPass) {
    const passes = [];
    for (const variant of variants) {
      const startedAt = performance.now();
      const data = await recognize(variant.dataUrl);
      passes.push({
        name: variant.name,
        rawText: data.text || '',
        tsv: data.tsv || '',
        durationMs: Math.round(performance.now() - startedAt),
      });
    }
    return passes;
  }

  async function createSharedNutritionOcrArtifact(dataUrl) {
    let canvas = await canvasFromImage(dataUrl, 'nutrition');
    canvas = await prepareNutritionCanvasForOcr(canvas);
    const passes = await collectSharedOcrPasses(
      ocrVariants(canvas, 'nutrition'),
    );
    if (lastPhotoDiagnostics) {
      lastPhotoDiagnostics.passCount = passes.length;
      lastPhotoDiagnostics.passDurationsMs = passes.map((pass) => pass.durationMs);
      lastPhotoDiagnostics.structuredDurationMs = null;
      lastPhotoDiagnostics.engineId = 'tesseract';
    }
    return {
      artifactId: `nutrition-${Date.now()}-${++sharedOcrArtifactSequence}`,
      generatedOnce: true,
      consumerModes: ['STANDARD', 'NUTRITION'],
      canvas,
      input: { ...lastPhotoDiagnostics },
      passes,
    };
  }

  async function consumeSharedNutritionOcrArtifact(artifact, scanStrategy) {
    lastStructuredDiagnostics = null;
    const diagnosticPasses = artifact.passes.map(diagnosticPassFromLayoutPass);
    const originalPass = diagnosticPasses.find((pass) => pass.preprocessVariant === 'original') ||
      diagnosticPasses[0];
    const originalWords = tsvWords(artifact.passes.find((pass) =>
      pass.name === (originalPass?.preprocessVariant || 'original'),
    )?.tsv || '');
    const originalGroups = lineGroups(originalWords);
    const originalAnchors = nutritionAnchors(originalGroups).map((anchor) => ({
      ...anchor,
      sourcePass: originalPass?.preprocessVariant || 'original',
    }));
    const originalValues = numericValues(originalGroups).map((value) => ({
      ...value,
      sourcePass: originalPass?.preprocessVariant || 'original',
    }));
    activeNutritionPipelineDiagnostics = {
      diagnosticVersion: 2,
      scanMode: scanStrategy === 'standard' ? 'STANDARD OCR' : 'NUTRITION LABEL READER',
      engineId: 'tesseract',
      input: { ...artifact.input },
      inputPreviewDataUrl: artifact.canvas.toDataURL('image/jpeg', 0.9),
      passes: diagnosticPasses,
      sharedOcrArtifact: {
        artifactId: artifact.artifactId,
        generatedOnce: artifact.generatedOnce,
        consumerModes: artifact.consumerModes,
        passCount: artifact.passes.length,
      },
      rawStage: {
        detectedLabels: labelDiagnostics(originalGroups, originalAnchors),
        tokenRecovery: originalValues.map((value) => numericDiagnostic(value, originalAnchors)),
        labelRecovery: originalAnchors.map((anchor) => ({
          rawText: anchor.rawText,
          candidate: anchor.alias,
          field: anchor.field,
          sourcePass: anchor.sourcePass,
          method: anchor.recoveryMethod,
          confidence: anchor.recoveryConfidence,
          status: anchor.status,
          ambiguity: anchor.ambiguity,
        })),
        numericRecovery: originalValues.map((value) => numericDiagnostic(value, originalAnchors)),
        numericCandidates: originalValues.map((value) => numericDiagnostic(value, originalAnchors)),
      },
    };
    const rawTexts = artifact.passes.map((pass) => pass.rawText)
      .filter((text, index, values) => text.trim() && values.indexOf(text) === index);
    const texts = [...rawTexts];
    if (scanStrategy === 'nutritionReader') {
      const startedAt = performance.now();
      const structured = await structuredNutritionPasses(
        artifact.canvas,
        artifact.passes.filter((pass) => pass.tsv),
        // The three full-image passes stay shared. Refinement is separately
        // traced, bounded evidence derived from that same decoded image.
        { allowRoiFallback: true },
      );
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.structuredDurationMs = Math.round(performance.now() - startedAt);
      }
      if (structured) texts.push(structured);
    }
    activeNutritionPipelineDiagnostics.input = { ...artifact.input, ...lastPhotoDiagnostics };
    activeNutritionPipelineDiagnostics.rawText = rawTexts.join(ocrPassSeparator);
    activeNutritionPipelineDiagnostics.structured = lastStructuredDiagnostics
      ? JSON.parse(JSON.stringify(lastStructuredDiagnostics))
      : null;
    return texts.join(ocrPassSeparator);
  }

  async function recognizeJapaneseText(
    dataUrl,
    mode = 'package',
    engineOverride = null,
    scanStrategy = 'nutritionReader',
    collectDiagnostics = false,
  ) {
    const engineId = selectedOcrEngine(mode, engineOverride);
    if (mode === 'nutrition' && engineId === 'paddle') {
      startPaddleDiagnostics('photo', {}, engineId);
      recordPaddleStage('P15', 'started');
    }
    let canvas;
    try {
      canvas = await canvasFromImage(dataUrl, mode);
    } catch (error) {
      if (mode === 'nutrition' && engineId === 'paddle') {
        failPaddleDiagnostics(error, 'P15');
      }
      throw error;
    }
    if (mode === 'nutrition' && engineId === 'tesseract') {
      canvas = await prepareNutritionCanvasForOcr(canvas);
    }
    if (mode === 'nutrition' && engineId === 'paddle') {
      recordPaddleStage('P16', 'success', {
        originalWidth: lastPhotoDiagnostics?.originalWidth || null,
        originalHeight: lastPhotoDiagnostics?.originalHeight || null,
        decodedWidth: lastPhotoDiagnostics?.decodedWidth || null,
        decodedHeight: lastPhotoDiagnostics?.decodedHeight || null,
        orientation: lastPhotoDiagnostics?.orientation || null,
      });
      recordPaddleStage('P17', 'started');
      activePaddleDiagnostics.dimensions = {
        ...activePaddleDiagnostics.dimensions,
        cropWidth: lastPhotoDiagnostics?.cropWidth || null,
        cropHeight: lastPhotoDiagnostics?.cropHeight || null,
        ocrWidth: canvas.width,
        ocrHeight: canvas.height,
        pixelFormat: 'canvas-rgba',
        estimatedImageBufferBytes: canvas.width * canvas.height * 4,
      };
      recordPaddleStage('P18', 'success', {
        ocrWidth: canvas.width,
        ocrHeight: canvas.height,
      });
      const startedAt = performance.now();
      const paddle = await recognizePaddleNutrition(canvas, 'photo', true);
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.engineId = engineId;
        lastPhotoDiagnostics.passCount = 1;
        lastPhotoDiagnostics.passDurationsMs = [
          Math.round(performance.now() - startedAt),
        ];
        lastPhotoDiagnostics.structuredDurationMs = 0;
      }
      recordPaddleStage('P27', 'success');
      return paddle.texts.join(ocrPassSeparator);
    }
    const texts = [];
    const layoutPasses = [];
    const diagnosticPasses = [];
    if (collectDiagnostics) {
      activeNutritionPipelineDiagnostics = {
        diagnosticVersion: 1,
        scanMode: scanStrategy === 'standard'
          ? 'STANDARD OCR'
          : 'NUTRITION LABEL READER',
        engineId,
        input: { ...lastPhotoDiagnostics },
        inputPreviewDataUrl: canvas.toDataURL('image/jpeg', 0.9),
        passes: diagnosticPasses,
      };
    }
    for (const variant of ocrVariants(canvas, mode)) {
      const startedAt = performance.now();
      let text;
      let passTsv = '';
      if (mode === 'nutrition' && scanStrategy === 'nutritionReader') {
        const data = await recognizeLayoutPass(variant.dataUrl);
        text = data.text || '';
        passTsv = data.tsv || '';
        layoutPasses.push({ name: variant.name, tsv: passTsv, rawText: text });
      } else if (collectDiagnostics) {
        const data = await recognizeLayoutPass(variant.dataUrl);
        text = data.text || '';
        passTsv = data.tsv || '';
      } else {
        text = await recognizeSinglePass(variant.dataUrl);
      }
      if (collectDiagnostics) {
        const words = tsvWords(passTsv);
        const groups = lineGroups(words);
        const anchors = nutritionAnchors(groups).map((anchor) => ({
          ...anchor,
          sourcePass: variant.name,
        }));
        const values = numericValues(groups).map((value) => ({
          ...value,
          sourcePass: variant.name,
        }));
        diagnosticPasses.push({
          preprocessVariant: variant.name,
          rawText: text,
          lines: lineGroups(words).map((group) =>
            group.words.map((word) => word.text).join(' '),
          ),
          words: nutritionWordDiagnostics(words),
          tokenRecovery: values.map((value) => numericDiagnostic(value, anchors)),
          labelRecovery: anchors.map((anchor) => ({
            rawText: anchor.rawText,
            candidate: anchor.alias,
            field: anchor.field,
            sourcePass: variant.name,
            method: anchor.recoveryMethod,
            confidence: anchor.recoveryConfidence,
            status: anchor.status,
            ambiguity: anchor.ambiguity,
          })),
          numericRecovery: values.map((value) => numericDiagnostic(value, anchors)),
          wordCount: words.length,
          averageConfidence: averageConfidence(words),
        });
        if (variant.name === 'original' && activeNutritionPipelineDiagnostics) {
          activeNutritionPipelineDiagnostics.rawStage = {
            detectedLabels: labelDiagnostics(groups, anchors),
            tokenRecovery: values.map((value) => numericDiagnostic(value, anchors)),
            labelRecovery: anchors.map((anchor) => ({
              rawText: anchor.rawText,
              candidate: anchor.alias,
              field: anchor.field,
              sourcePass: variant.name,
              method: anchor.recoveryMethod,
              confidence: anchor.recoveryConfidence,
              status: anchor.status,
              ambiguity: anchor.ambiguity,
            })),
            numericRecovery: values.map((value) => numericDiagnostic(value, anchors)),
            numericCandidates: values.map((value) => numericDiagnostic(value, anchors)),
          };
        }
      }
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.passCount += 1;
        lastPhotoDiagnostics.passDurationsMs.push(
          Math.round(performance.now() - startedAt),
        );
      }
      if (text.trim() && !texts.includes(text)) texts.push(text);
    }
    if (mode === 'nutrition' &&
        scanStrategy === 'nutritionReader' &&
        layoutPasses.some((pass) => pass.tsv)) {
      const startedAt = performance.now();
      const structured = await structuredNutritionPasses(
        canvas,
        layoutPasses.filter((pass) => pass.tsv),
      );
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.structuredDurationMs = Math.round(
          performance.now() - startedAt,
        );
      }
      if (structured) texts.push(structured);
    }
    if (lastPhotoDiagnostics) lastPhotoDiagnostics.engineId = engineId;
    if (collectDiagnostics && activeNutritionPipelineDiagnostics) {
      activeNutritionPipelineDiagnostics.input = { ...lastPhotoDiagnostics };
      activeNutritionPipelineDiagnostics.rawText = diagnosticPasses
        .map((pass) => pass.rawText)
        .filter((text, index, values) => text.trim() && values.indexOf(text) === index)
        .join(ocrPassSeparator);
      activeNutritionPipelineDiagnostics.structured = lastStructuredDiagnostics
        ? JSON.parse(JSON.stringify(lastStructuredDiagnostics))
        : null;
    }
    return texts.join(ocrPassSeparator);
  }

  function barcodeFormat(value) {
    const format = String(value)
      .replace(/^BarcodeFormat\./, '')
      .replace(/_/g, '-')
      .toUpperCase();
    return /^(EAN-13|EAN-8|UPC-A)$/.test(format) ? format : 'UNKNOWN';
  }

  async function barcodeDetector() {
    if (!('BarcodeDetector' in window)) return null;
    if (!barcodeDetectorPromise) {
      barcodeDetectorPromise = (async () => {
        const supported = await BarcodeDetector.getSupportedFormats();
        const formats = ['ean_13', 'ean_8', 'upc_a'].filter((format) =>
          supported.includes(format),
        );
        return formats.length ? new BarcodeDetector({ formats }) : null;
      })();
    }
    return barcodeDetectorPromise;
  }

  async function nativeBarcode(dataUrl) {
    const detector = await barcodeDetector();
    if (!detector) return null;
    const response = await fetch(dataUrl);
    const bitmap = await createImageBitmap(await response.blob());
    try {
      const results = await detector.detect(bitmap);
      return results.length
        ? {
            value: results[0].rawValue,
            format: barcodeFormat(results[0].format),
          }
        : null;
    } finally {
      bitmap.close();
    }
  }

  async function fallbackBarcode(dataUrl) {
    if (!barcodeReaderPromise) {
      barcodeReaderPromise = (async () => {
        await loadScript(paths.zxing);
        return new ZXingBrowser.BrowserMultiFormatReader();
      })();
    }
    const reader = await barcodeReaderPromise;
    try {
      const result = await reader.decodeFromImageUrl(dataUrl);
      const rawFormat = result.getBarcodeFormat();
      const format = ZXingBrowser.BarcodeFormat[rawFormat] || String(rawFormat);
      if (!/EAN_13|EAN_8|UPC_A/.test(format)) return null;
      return {
        value: result.getText(),
        format: barcodeFormat(format),
      };
    } catch (_) {
      return null;
    }
  }

  async function scanBarcode(dataUrl) {
    try {
      const nativeResult = await nativeBarcode(dataUrl);
      if (nativeResult) return nativeResult.value;
    } catch (_) {
      // Continue with the self-hosted decoder.
    }
    const fallbackResult = await fallbackBarcode(dataUrl);
    return fallbackResult && fallbackResult.value;
  }

  async function decodeBarcode(dataUrl) {
    try {
      const nativeResult = await nativeBarcode(dataUrl);
      if (nativeResult) return nativeResult;
    } catch (_) {
      // Continue with the self-hosted decoder.
    }
    return fallbackBarcode(dataUrl);
  }

  function cameraSurface(title, guideSpec) {
    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.style.cssText = [
      'position:fixed',
      'inset:0',
      'z-index:2147483647',
      'background:#05080d',
      'color:#fff',
      'display:flex',
      'flex-direction:column',
      'padding:max(16px, env(safe-area-inset-top)) 16px max(16px, env(safe-area-inset-bottom))',
      'box-sizing:border-box',
      'font-family:system-ui,-apple-system,sans-serif',
    ].join(';');

    const header = document.createElement('div');
    header.style.cssText = 'display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px';
    const heading = document.createElement('strong');
    heading.textContent = title;
    const close = document.createElement('button');
    close.type = 'button';
    close.textContent = 'CLOSE';
    styleButton(close, false);
    header.append(heading, close);

    const preview = document.createElement('div');
    preview.style.cssText = 'position:relative;flex:1;min-height:0;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid rgba(255,255,255,.22);border-radius:16px;background:#000';
    const video = document.createElement('video');
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;
    video.setAttribute('playsinline', '');
    video.style.cssText = 'width:100%;height:100%;object-fit:cover';
    const guide = document.createElement('div');
    guide.style.cssText = [
      'display:none',
      'position:absolute',
      `left:${guideSpec.left * 100}%`,
      `top:${guideSpec.top * 100}%`,
      `width:${guideSpec.width * 100}%`,
      `height:${guideSpec.height * 100}%`,
      'box-sizing:border-box',
      'border:2px solid rgba(255,255,255,.9)',
      'border-radius:12px',
      'box-shadow:0 0 0 9999px rgba(0,0,0,.18)',
      'pointer-events:none',
    ].join(';');
    const guideLabel = document.createElement('span');
    guideLabel.textContent = '読み取り対象をこの枠内に合わせてください';
    guideLabel.style.cssText = 'position:absolute;left:8px;right:8px;top:8px;padding:6px 8px;border-radius:8px;background:rgba(0,0,0,.68);font-size:.82rem;text-align:center';
    guide.appendChild(guideLabel);
    preview.append(video, guide);

    const result = document.createElement('div');
    result.style.cssText = 'margin-top:12px;padding:12px;border:1px solid rgba(255,255,255,.22);border-radius:12px;background:#111923;min-height:48px';
    const actions = document.createElement('div');
    actions.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-top:12px';
    overlay.append(header, preview, result, actions);
    document.body.appendChild(overlay);
    return { overlay, header, video, guide, close, result, actions };
  }

  function styleButton(button, primary) {
    button.style.cssText = [
      'appearance:none',
      'border-radius:10px',
      'border:1px solid rgba(255,255,255,.28)',
      `background:${primary ? '#2f80ed' : '#182231'}`,
      'color:#fff',
      'font-weight:700',
      'min-height:44px',
      'padding:10px 14px',
      'flex:1 1 130px',
    ].join(';');
  }

  async function openCamera(title, mode = 'package') {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error('Camera unavailable');
    }
    const guideSpec = mode === 'nutrition' ? ocrGuide : packageGuide;
    const surface = cameraSurface(title, guideSpec);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 3840 },
          height: { ideal: 2160 },
        },
      });
      surface.video.srcObject = stream;
      await surface.video.play();
      const track = stream.getVideoTracks()[0];
      try {
        const capabilities = track.getCapabilities ? track.getCapabilities() : {};
        if (capabilities.focusMode && capabilities.focusMode.includes('continuous')) {
          await track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] });
        }
      } catch (_) {
        // Continuous autofocus is optional and not exposed by every iOS release.
      }
      const settings = track.getSettings ? track.getSettings() : {};
      return { ...surface, stream, mode, guideSpec, settings };
    } catch (error) {
      surface.overlay.remove();
      throw error;
    }
  }

  function captureFrame(video) {
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      return null;
    }
    const sourceWidth = video.videoWidth;
    const sourceHeight = video.videoHeight;
    const scale = Math.min(1, 1280 / sourceWidth);
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(sourceWidth * scale));
    canvas.height = Math.max(1, Math.round(sourceHeight * scale));
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(
      video,
      0,
      0,
      sourceWidth,
      sourceHeight,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    return canvas.toDataURL('image/jpeg', 0.86);
  }

  function frameQuality(canvas) {
    const sample = document.createElement('canvas');
    sample.width = Math.min(192, canvas.width);
    sample.height = Math.max(1, Math.round(sample.width * canvas.height / canvas.width));
    const context = sample.getContext('2d', { alpha: false, willReadFrequently: true });
    context.drawImage(canvas, 0, 0, sample.width, sample.height);
    const pixels = context.getImageData(0, 0, sample.width, sample.height).data;
    const gray = new Float32Array(sample.width * sample.height);
    let sum = 0;
    for (let index = 0; index < gray.length; index += 1) {
      const offset = index * 4;
      const value =
        pixels[offset] * 0.299 +
        pixels[offset + 1] * 0.587 +
        pixels[offset + 2] * 0.114;
      gray[index] = value;
      sum += value;
    }
    const brightness = sum / gray.length;
    let variance = 0;
    let sharpness = 0;
    let edges = 0;
    let samples = 0;
    for (let y = 1; y < sample.height - 1; y += 1) {
      for (let x = 1; x < sample.width - 1; x += 1) {
        const index = y * sample.width + x;
        const delta = gray[index] - brightness;
        variance += delta * delta;
        const laplacian = Math.abs(
          gray[index - 1] + gray[index + 1] +
          gray[index - sample.width] + gray[index + sample.width] -
          4 * gray[index],
        );
        sharpness += laplacian;
        if (laplacian >= 18) edges += 1;
        samples += 1;
      }
    }
    const contrast = Math.sqrt(variance / Math.max(1, samples));
    sharpness /= Math.max(1, samples);
    const edgeDensity = edges / Math.max(1, samples);
    const usable =
      brightness >= frameQualityThreshold.minBrightness &&
      brightness <= frameQualityThreshold.maxBrightness &&
      contrast >= frameQualityThreshold.minContrast &&
      sharpness >= frameQualityThreshold.minSharpness &&
      edgeDensity >= frameQualityThreshold.minEdgeDensity;
    return {
      brightness: Number(brightness.toFixed(2)),
      contrast: Number(contrast.toFixed(2)),
      sharpness: Number(sharpness.toFixed(2)),
      edgeDensity: Number(edgeDensity.toFixed(4)),
      usable,
      score: contrast + sharpness * 4 + edgeDensity * 200,
    };
  }

  function captureOcrFrame(session) {
    const video = session.video;
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      return null;
    }
    const guide = session.guideSpec;
    const geometry = ocrGeometry(video.videoWidth, video.videoHeight, guide);
    const canvas = document.createElement('canvas');
    canvas.width = geometry.inputWidth;
    canvas.height = geometry.inputHeight;
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(
      video,
      geometry.sourceX,
      geometry.sourceY,
      geometry.sourceWidth,
      geometry.sourceHeight,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    const quality = frameQuality(canvas);
    lastCaptureDiagnostics = {
      mode: session.mode,
      videoWidth: video.videoWidth,
      videoHeight: video.videoHeight,
      readyState: video.readyState,
      devicePixelRatio: window.devicePixelRatio || 1,
      facingMode: session.settings.facingMode || 'unknown',
      sourceX: geometry.sourceX,
      sourceY: geometry.sourceY,
      sourceWidth: geometry.sourceWidth,
      sourceHeight: geometry.sourceHeight,
      inputWidth: canvas.width,
      inputHeight: canvas.height,
      quality,
    };
    return { canvas, quality };
  }

  const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 120));

  async function captureBestFrame(session) {
    let best;
    for (let index = 0; index < 3; index += 1) {
      if (index) await nextFrame();
      const frame = captureOcrFrame(session);
      if (frame && (!best || frame.quality.score > best.quality.score)) best = frame;
    }
    return best && best.quality.usable ? best : null;
  }

  function stopCamera(session) {
    session.stream.getTracks().forEach((track) => track.stop());
    session.video.srcObject = null;
    session.overlay.remove();
  }

  async function scanBarcodeLive() {
    const session = await openCamera('SCAN BARCODE');
    session.result.textContent = '読み取り中...';
    const use = document.createElement('button');
    use.type = 'button';
    use.textContent = 'USE THIS CODE';
    use.disabled = true;
    styleButton(use, true);
    session.actions.appendChild(use);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let candidate = null;
      let finished = false;
      const finish = (value) => {
        if (finished) return;
        finished = true;
        clearInterval(timer);
        stopCamera(session);
        resolve(value);
      };
      session.close.onclick = () => finish(null);
      use.onclick = () => candidate && finish(JSON.stringify(candidate));

      const tick = async () => {
        if (finished || running) return;
        const frame = captureFrame(session.video);
        if (!frame) return;
        running = true;
        try {
          const next = await decodeBarcode(frame);
          if (!finished && next &&
              (!candidate || candidate.value !== next.value || candidate.format !== next.format)) {
            candidate = next;
            session.result.replaceChildren();
            const state = document.createElement('strong');
            state.textContent = '読み取り完了';
            const value = document.createElement('div');
            value.textContent = next.value;
            value.style.cssText = 'font-size:1.25rem;font-weight:800;margin-top:6px;overflow-wrap:anywhere';
            const format = document.createElement('div');
            format.textContent = `FORMAT  ${next.format || 'UNKNOWN'}`;
            format.style.cssText = 'opacity:.78;margin-top:4px';
            session.result.append(state, value, format);
            use.disabled = false;
          }
        } finally {
          running = false;
        }
      };
      timer = setInterval(tick, 400);
      tick();
    });
  }

  function ocrResultContent(target, candidate, mode) {
    target.replaceChildren();
    const state = document.createElement('strong');
    state.textContent = mode === 'nutrition'
      ? candidate.state === 'detected'
        ? '読み取り完了'
        : candidate.state === 'partial'
          ? '一部読み取り'
          : candidate.state === 'insufficient'
            ? '栄養項目不足'
            : '読み取り中...'
      : candidate.state === 'partial' || candidate.state === 'detected'
        ? '商品情報候補が見つかりました'
        : '商品情報候補を検索中...';
    target.appendChild(state);
    if (candidate.state === 'insufficient') {
      const guidance = document.createElement('div');
      guidance.textContent = mode === 'nutrition'
        ? '文字を検出しましたが、栄養成分を十分に読み取れませんでした。表全体を枠内に入れ、高精度読み取りを試してください。'
        : '文字を検出しました。商品表面全体を枠内に入れ、高精度読み取りを試してください。';
      guidance.style.cssText = 'margin-top:4px';
      target.appendChild(guidance);
    }
    const values = Object.entries(candidate.fields || {});
    for (const [label, value] of values) {
      if (!value) continue;
      const row = document.createElement('div');
      row.textContent = `${label}  ${value}`;
      row.style.cssText = 'margin-top:4px';
      target.appendChild(row);
    }
  }

  async function recognizeTextLive(
    title,
    instruction,
    describeCandidate,
    scanStrategy = 'nutritionReader',
  ) {
    const engineOverride = null;
    const mode = title.includes('NUTRITION') ? 'nutrition' : 'package';
    const engineId = selectedOcrEngine(mode, engineOverride);
    const session = await openCamera(title, mode);
    session.guide.style.display = 'block';
    session.guide.firstElementChild.textContent = instruction;
    session.result.textContent = instruction;
    if (mode === 'nutrition') {
      const modeLabel = document.createElement('div');
      modeLabel.dataset.role = 'ocr-scan-mode';
      modeLabel.textContent = `MODE: ${scanStrategy === 'standard' ? 'STANDARD OCR' : 'NUTRITION LABEL READER'}`;
      modeLabel.style.cssText = 'font-size:.82rem;font-weight:800;letter-spacing:.04em';
      session.header.insertBefore(modeLabel, session.close);
    }
    const choosePhoto = document.createElement('button');
    choosePhoto.type = 'button';
    choosePhoto.textContent = 'CHOOSE PHOTO';
    styleButton(choosePhoto, false);
    choosePhoto.style.justifySelf = 'start';
    const shutter = document.createElement('button');
    shutter.type = 'button';
    shutter.setAttribute('aria-label', 'Scan nutrition label');
    shutter.dataset.role = 'nutrition-shutter';
    shutter.style.cssText = [
      'appearance:none',
      'width:76px',
      'height:76px',
      'padding:7px',
      'border-radius:50%',
      'border:4px solid #fff',
      'background:transparent',
      'box-sizing:border-box',
      'justify-self:center',
    ].join(';');
    const shutterInner = document.createElement('span');
    shutterInner.style.cssText = 'display:block;width:100%;height:100%;border-radius:50%;background:#fff';
    shutter.appendChild(shutterInner);
    session.actions.style.cssText = [
      'display:grid',
      'grid-template-columns:minmax(0,1fr) auto minmax(0,1fr)',
      'align-items:center',
      'gap:12px',
      'margin-top:12px',
      'padding-bottom:max(4px, env(safe-area-inset-bottom))',
    ].join(';');
    const legacyReview = document.createElement(
      mode === 'nutrition' ? 'span' : 'button',
    );
    if (mode !== 'nutrition') {
      legacyReview.type = 'button';
      legacyReview.textContent = 'REVIEW RESULT';
      legacyReview.disabled = true;
      styleButton(legacyReview, true);
    }
    session.actions.append(choosePhoto, shutter, legacyReview);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let latestRawText = null;
      const highAccuracyValues = new Map();
      const highAccuracyConflicts = new Set();
      let finished = false;
      const cleanup = () => {
        if (finished) return false;
        finished = true;
        clearInterval(timer);
        stopCamera(session);
        return true;
      };
      const finish = (value) => {
        if (!cleanup()) return;
        resolve(value);
      };
      const setBusy = (busy) => {
        running = busy;
        shutter.disabled = busy;
        choosePhoto.disabled = busy;
        shutter.style.opacity = busy ? '.55' : '1';
      };
      const recognizePhoto = async () => {
        if (finished || running) return;
        setBusy(true);
        session.result.textContent = `MODE: ${scanStrategy === 'standard' ? 'STANDARD OCR' : 'NUTRITION LABEL READER'}\n読み取り中...`;
        try {
          const image = await selectImage(false);
          if (!image || finished) return;
          const rawText = await recognizeJapaneseText(
            image,
            mode,
            engineId,
            scanStrategy,
          );
          let hasCandidate = false;
          for (const pass of rawText.split(ocrPassSeparator)) {
            if (pass.trim()) hasCandidate = present(pass, true) || hasCandidate;
          }
          if (hasCandidate) finish(rawText);
          else session.result.textContent = '栄養成分を認識できませんでした。別の写真をお試しください。';
        } catch (_) {
          if (!finished) session.result.textContent = '写真の読み取りを完了できません。もう一度お試しください。';
        } finally {
          if (!finished) setBusy(false);
        }
      };
      session.close.onclick = () => finish(null);
      choosePhoto.onclick = recognizePhoto;
      if (mode !== 'nutrition') {
        legacyReview.onclick = () => latestRawText && finish(latestRawText);
      }

      const present = (rawText, trackConflicts = false) => {
        const description = JSON.parse(describeCandidate(rawText));
        if (trackConflicts) {
          for (const [field, value] of Object.entries(description.fields || {})) {
            if (!value) continue;
            const previous = highAccuracyValues.get(field);
            if (previous && previous !== value) highAccuracyConflicts.add(field);
            if (!previous) highAccuracyValues.set(field, value);
          }
          if (highAccuracyConflicts.size) {
            description.fields = {
              ...description.fields,
              'REVIEW CONFLICT': [...highAccuracyConflicts].join(', '),
            };
          }
        }
        const hasCandidate = description.state === 'partial' ||
          description.state === 'detected';
        ocrResultContent(session.result, description, mode);
        if (hasCandidate && mode !== 'nutrition') legacyReview.disabled = false;
        return hasCandidate;
      };

      shutter.onclick = async () => {
        if (finished || running) return;
        setBusy(true);
        highAccuracyValues.clear();
        highAccuracyConflicts.clear();
        session.result.textContent = `MODE: ${scanStrategy === 'standard' ? 'STANDARD OCR' : 'NUTRITION LABEL READER'}\n読み取り中...`;
        try {
          const frame = await captureBestFrame(session);
          if (!frame) {
            session.result.textContent = 'カメラを静止させ、反射を避けてもう一度お試しください。';
            return;
          }
          const texts = [];
          let layoutTsv = '';
          let hasCandidate = false;
          if (mode === 'nutrition' && engineId === 'paddle') {
            const paddle = await recognizePaddleNutrition(
              frame.canvas,
              'live-high-accuracy',
            );
            for (const rawText of paddle.texts) {
              if (!rawText.trim() || texts.includes(rawText)) continue;
              texts.push(rawText);
              hasCandidate = present(rawText, true) || hasCandidate;
            }
          } else {
            for (const variant of ocrVariants(frame.canvas, mode)) {
              let rawText;
              if (mode === 'nutrition' &&
                  scanStrategy === 'nutritionReader' &&
                  variant.name === 'original') {
                const data = await recognizeLayoutPass(variant.dataUrl);
                rawText = data.text || '';
                layoutTsv = data.tsv || '';
              } else {
                rawText = await recognizeSinglePass(variant.dataUrl);
              }
              if (!rawText.trim() || texts.includes(rawText)) continue;
              texts.push(rawText);
              hasCandidate = present(rawText, true) || hasCandidate;
            }
          }
          if (mode === 'nutrition' &&
              scanStrategy === 'nutritionReader' &&
              layoutTsv) {
            const structured = await structuredNutritionText(
              frame.canvas,
              layoutTsv,
            );
            if (structured) {
              texts.push(structured);
              hasCandidate = present(structured, true) || hasCandidate;
            }
          }
          if (texts.length) latestRawText = texts.join(ocrPassSeparator);
          if (hasCandidate && latestRawText) {
            if (mode === 'nutrition' && engineId === 'paddle') {
              recordPaddleStage('P28', 'success');
            }
            finish(latestRawText);
          } else {
            session.result.textContent = mode === 'nutrition'
              ? '栄養成分を認識できませんでした。反射を避けて再度お試しください。'
              : '商品情報候補を認識できませんでした。反射を避けて再度お試しください。';
          }
        } catch (_) {
          if (!finished) {
            session.result.textContent = '高精度読み取りを完了できません。写真での読み取りをお試しください。';
          }
        } finally {
          if (!finished) setBusy(false);
        }
      };

      const tick = async () => {
        if (finished || running) return;
        const frame = captureOcrFrame(session);
        if (!frame) return;
        if (!frame.quality.usable) {
          session.result.textContent = 'カメラを静止させ、反射を避けてください。';
          return;
        }
        running = true;
        session.result.textContent = '読み取り中...';
        try {
          const rawText = mode === 'nutrition' && engineId === 'paddle'
            ? (await recognizePaddleNutrition(
              frame.canvas,
              'live-preview',
            )).texts.join(ocrPassSeparator)
            : await recognizeSinglePass(
              frame.canvas.toDataURL('image/jpeg', 0.92),
            );
          if (finished) return;
          const description = JSON.parse(describeCandidate(rawText));
          const hasCandidate = description.state === 'partial' ||
            description.state === 'detected';
          if (hasCandidate) {
            latestRawText = rawText;
            ocrResultContent(session.result, description, mode);
            legacyReview.disabled = false;
          } else if (description.state === 'insufficient') {
            ocrResultContent(session.result, description, mode);
          } else if (description.state === 'scanning') {
            session.result.textContent = '読み取り中...';
          }
        } catch (_) {
          if (!finished) {
            clearInterval(timer);
            session.result.textContent = '読み取り処理を完了できません。写真での読み取りをお試しください';
          }
        } finally {
          running = false;
        }
      };
      if (mode !== 'nutrition') {
        timer = setInterval(tick, 1500);
        tick();
      }
    });
  }

  async function diagnosePaddleResult(result) {
    const canvas = {
      width: Number(result?.image?.width) || 0,
      height: Number(result?.image?.height) || 0,
    };
    const text = (result?.items || []).map((item) => item.text).join('\n');
    const structured = await structuredPaddleNutritionText(
      canvas,
      result?.items || [],
    );
    return {
      engineId: 'paddle',
      text,
      structured,
      items: result?.items || [],
      source: result?.image || { width: 0, height: 0 },
    };
  }

  async function benchmarkNutritionEngines(dataUrl) {
    const previous = window.__OR_APP_OCR_ENGINE__;
    const results = {};
    try {
      for (const engineId of ['tesseract', 'paddle']) {
        window.__OR_APP_OCR_ENGINE__ = engineId;
        const startedAt = performance.now();
        try {
          const text = await recognizeJapaneseText(dataUrl, 'nutrition');
          results[engineId] = {
            engineId,
            durationMs: Math.round(performance.now() - startedAt),
            text,
          };
        } catch (error) {
          results[engineId] = {
            engineId,
            durationMs: Math.round(performance.now() - startedAt),
            error: String(error && error.message || 'OCR failed'),
          };
        }
      }
      return results;
    } finally {
      window.__OR_APP_OCR_ENGINE__ = previous;
    }
  }

  function nutritionDiagnosticResult(pipeline, durationMs) {
    const input = pipeline.input || {};
    const structured = pipeline.structured || {};
    const rawStage = pipeline.rawStage || {};
    const selectedMappings = structured.selectedMappings || {};
    const requiredFields = ['energy', 'protein', 'fat', 'carbohydrate'];
    const missing = requiredFields.filter((field) => !selectedMappings[field]);
    const words = (pipeline.passes || []).flatMap((pass) => pass.words || []);
    const passTokenRecovery = (pipeline.passes || [])
      .flatMap((pass) => pass.tokenRecovery || []);
    const passLabelRecovery = (pipeline.passes || [])
      .flatMap((pass) => pass.labelRecovery || []);
    const passNumericRecovery = (pipeline.passes || [])
      .flatMap((pass) => pass.numericRecovery || []);
    const cropApplied = Number(input.cropX) !== 0 || Number(input.cropY) !== 0 ||
      Number(input.cropWidth) !== Number(input.decodedWidth) ||
      Number(input.cropHeight) !== Number(input.decodedHeight);
    const resizeApplied = Number(input.inputWidth) !== Number(input.cropWidth) ||
      Number(input.inputHeight) !== Number(input.cropHeight);
    return {
      diagnosticVersion: pipeline.diagnosticVersion,
      scanMode: pipeline.scanMode,
      engineId: pipeline.engineId,
      sourceDimensions: {
        width: input.originalWidth,
        height: input.originalHeight,
        decodedWidth: input.decodedWidth,
        decodedHeight: input.decodedHeight,
      },
      orientation: {
        exif: input.orientation,
        appliedByDecoder: input.orientationAppliedByDecoder,
      },
      cropRect: {
        x: input.cropX,
        y: input.cropY,
        width: input.cropWidth,
        height: input.cropHeight,
      },
      cropApplied: cropApplied,
      autoNutritionCrop: input.autoNutritionCrop || {
        status: 'FALLBACK_ORIGINAL', rect: null, reason: 'not-observable',
      },
      cropDimensions: { width: input.cropWidth, height: input.cropHeight },
      preResizeDimensions: {
        width: input.preResizeWidth ?? input.cropWidth,
        height: input.preResizeHeight ?? input.cropHeight,
      },
      ocrDimensions: { width: input.inputWidth, height: input.inputHeight },
      resizeApplied: resizeApplied,
      resizeMethod: input.resizeMethod || 'none',
      resizeScale: input.resizeScale ?? 1,
      rotationCorrection: Number(input.orientation) === 1
        ? 'NOT REQUIRED'
        : input.orientationAppliedByDecoder
          ? 'APPLIED BY BROWSER IMAGE DECODER'
          : 'NOT CONFIRMED',
      perspectiveCorrection: 'NOT APPLIED',
      preprocessVariant: (pipeline.passes || []).map((pass) => pass.preprocessVariant),
      passes: (pipeline.passes || []).map((pass) => ({
        ...pass,
        size: { width: input.inputWidth, height: input.inputHeight },
        parameters: pass.preprocessVariant === 'moderate-contrast'
          ? { grayscale: true, contrast: 1.35 }
          : pass.preprocessVariant === 'grayscale'
            ? { grayscale: true, contrast: 1 }
            : { jpegQuality: 0.94 },
      })),
      inputPreviewDataUrl: pipeline.inputPreviewDataUrl,
      sharedOcrArtifact: pipeline.sharedOcrArtifact || null,
      rawText: pipeline.rawText || '',
      lines: (pipeline.passes || []).flatMap((pass) => pass.lines || []),
      words,
      wordCount: words.length,
      averageConfidence: averageConfidence(words),
      detectedLabels: structured.detectedLabels || rawStage.detectedLabels || [],
      tokenRecovery: structured.tokenRecovery?.length
        ? structured.tokenRecovery
        : passTokenRecovery.length ? passTokenRecovery : rawStage.tokenRecovery || [],
      labelRecovery: structured.labelRecovery?.length
        ? structured.labelRecovery
        : passLabelRecovery.length ? passLabelRecovery : rawStage.labelRecovery || [],
      numericRecovery: structured.numericRecovery?.length
        ? structured.numericRecovery
        : passNumericRecovery.length ? passNumericRecovery : rawStage.numericRecovery || [],
      numericCandidates: structured.numericCandidates || rawStage.numericCandidates || [],
      semanticDuplicateCollapse: structured.semanticDuplicateCollapse || [],
      preMappingEvidence: structured.preMappingEvidence || [],
      fieldOwnership: structured.fieldOwnership || [],
      localRefinementAttempts: structured.localRefinementAttempts || [],
      localRefinementSummary: structured.localRefinementSummary || {
        attempts: 0,
        evidenceCount: 0,
        resolvedFields: [],
        stillReviewRequiredFields: [],
      },
      structuredCandidates: structured.structuredCandidates || [],
      unitTieBreak: structured.unitTieBreak || [],
      geometryMapping: structured.geometryMapping || [],
      multiPassConsensus: structured.multiPassConsensus || [],
      conflicts: structured.conflicts || [],
      nutritionConsistency: structured.nutritionConsistency || {
        evaluated: false,
        reason: 'not available',
      },
      confidenceDecisions: structured.confidenceDecisions || [],
      selectedMappings,
      fallbackUsed: pipeline.scanMode === 'STANDARD OCR' || missing.length > 0,
      fallbackReason: pipeline.scanMode === 'STANDARD OCR'
        ? 'standard-mode-bypasses-structured-path'
        : missing.length
          ? 'structured-result-incomplete; Dart parser receives all OCR passes'
          : null,
      fallbackPathName: 'JapaneseNutritionOcrParser',
      finalResult: {
        basis: null,
        calories: selectedMappings.energy || null,
        protein: selectedMappings.protein || null,
        fat: selectedMappings.fat || null,
        carbohydrate: selectedMappings.carbohydrate || null,
        needsReviewFields: missing,
        decisions: structured.confidenceDecisions || [],
      },
      timings: {
        totalMs: durationMs,
        ocrPassesMs: input.passDurationsMs || [],
        structuredMs: input.structuredDurationMs ?? null,
      },
    };
  }

  async function diagnoseNutritionPhoto(dataUrl) {
    const report = {
      diagnosticVersion: 1,
      generatedAt: new Date().toISOString(),
      engine: 'tesseract',
      persistence: 'none',
    };
    const artifact = await createSharedNutritionOcrArtifact(dataUrl);
    for (const [key, strategy] of [
      ['standard', 'standard'],
      ['nutritionLabelReader', 'nutritionReader'],
    ]) {
      const startedAt = performance.now();
      await consumeSharedNutritionOcrArtifact(artifact, strategy);
      report[key] = nutritionDiagnosticResult(
        activeNutritionPipelineDiagnostics,
        Math.round(performance.now() - startedAt),
      );
    }
    const standardRaw = report.standard.rawText;
    const readerRaw = report.nutritionLabelReader.rawText;
    const readerLabels = report.nutritionLabelReader.detectedLabels
      .filter((label) => label.detected).length;
    const readerNumbers = report.nutritionLabelReader.numericCandidates.length;
    const readerMappings = Object.keys(
      report.nutritionLabelReader.selectedMappings,
    ).length;
    report.comparison = {
      sameRawOcr: standardRaw === readerRaw,
      sameInput: true,
      sharedArtifact: true,
      artifactId: artifact.artifactId,
      standard: {
        wordCount: report.standard.wordCount,
        labelCount: report.standard.detectedLabels.filter((label) => label.detected).length,
        numericCandidateCount: report.standard.numericCandidates.length,
        selectedMappingCount: Object.keys(report.standard.selectedMappings).length,
        fallbackUsed: report.standard.fallbackUsed,
      },
      nutritionLabelReader: {
        wordCount: report.nutritionLabelReader.wordCount,
        labelCount: readerLabels,
        numericCandidateCount: readerNumbers,
        selectedMappingCount: readerMappings,
        fallbackUsed: report.nutritionLabelReader.fallbackUsed,
      },
    };
    report.rootCauseClassification = report.nutritionLabelReader.wordCount === 0 ||
        readerNumbers === 0
      ? {
          primary: report.nutritionLabelReader.wordCount === 0
            ? 'RAW_OCR'
            : 'NUMERIC_EXTRACTION',
          secondary: null,
          reason: 'Required words or numeric tokens are absent before structured mapping.',
        }
      : readerLabels === 0
        ? {
            primary: 'LABEL_DETECTION',
            secondary: null,
            reason: 'OCR words and numeric candidates exist but no nutrition label was detected.',
          }
        : readerMappings === 0
          ? {
              primary: 'MAPPING',
              secondary: null,
              reason: 'Labels and numeric candidates exist but no field was mapped.',
            }
          : report.nutritionLabelReader.fallbackUsed &&
            report.comparison.sameRawOcr
            ? {
              primary: 'MAPPING',
              secondary: null,
              reason: 'Reader output is incomplete and rejoins the same Dart parser path.',
            }
          : {
              primary: 'UNKNOWN',
              secondary: null,
              reason: 'The captured diagnostic does not isolate a failing stage.',
            };
    return JSON.stringify(report);
  }

  window.orAppFoodInput = {
    selectImage,
    recognizeJapaneseText,
    scanBarcode,
    scanBarcodeLive,
    recognizeTextLive,
    diagnosePaddleResult,
    benchmarkNutritionEngines,
    diagnoseNutritionPhoto,
    recognizePaddleCanvasForDiagnostics: recognizePaddleNutrition,
    runPaddleSmallFixtureDiagnostic,
    getPaddleDiagnostics: paddleDiagnosticsSnapshot,
    copyPaddleDiagnostics,
    classifyPaddleFailureForDiagnostics: (message, stageId) =>
      classifyPaddleFailure(new Error(message), stageId),
    mapPaddleFailureForDiagnostics: (message, stageId) => ({
      failureCategory: classifyPaddleFailure(new Error(message), stageId),
      errorCategory: paddleFailureCode(new Error(message), stageId),
    }),
    diagnoseStructuredNutritionTsv: (tsv) =>
      structuredNutritionText({ width: 0, height: 0 }, tsv),
    diagnoseStructuredNutritionPassesForTesting: (tsvs) =>
      structuredNutritionPasses(
        { width: 0, height: 0 },
        (tsvs || []).map((tsv, index) => ({
          name: ['original', 'grayscale', 'moderate-contrast'][index] ||
            `pass-${index + 1}`,
          tsv,
        })),
      ),
    localRefinementRegionsForTesting: (tsv, field, width = 1200, height = 800) => {
      const analysis = analyzeNutritionWords(tsvWords(tsv), 'original');
      return refinementRegions(
        { width, height },
        analysis,
        field,
        'test-incomplete-structured-evidence',
      ).map((region) => ({
        regionType: region.regionType,
        triggerReason: region.triggerReason,
        cropRect: {
          x: Math.round(region.left),
          y: Math.round(region.top),
          width: Math.round(region.right - region.left),
          height: Math.round(region.bottom - region.top),
        },
      }));
    },
    missingFieldRefinementTriggerForTesting: (tsv, field, width = 1200, height = 800) => {
      const canvas = { width, height };
      const analysis = analyzeNutritionWords(tsvWords(tsv), 'original');
      const candidate = missingFieldRefinementCandidate(canvas, analysis, field);
      if (!candidate) return null;
      return {
        triggerReason: candidate.triggerReason,
        anchor: {
          field: candidate.anchor.field,
          rawText: candidate.anchor.rawText,
          recoveryMethod: candidate.anchor.recoveryMethod,
        },
        regions: refinementRegions(
          canvas,
          analysis,
          field,
          candidate.triggerReason,
          candidate.anchor,
        ).map((region) => ({
          regionType: region.regionType,
          triggerReason: region.triggerReason,
          cropRect: {
            x: Math.round(region.left), y: Math.round(region.top),
            width: Math.round(region.right - region.left),
            height: Math.round(region.bottom - region.top),
          },
        })),
      };
    },
    localRowOwnershipForTesting: (tsv, field, width = 1200, height = 800) => {
      const analysis = analyzeNutritionWords(tsvWords(tsv), 'original');
      const anchor = refinementAnchor(analysis, field);
      if (!anchor) return null;
      const rowBand = nutritionRowBand({ width, height }, analysis, anchor, field);
      return {
        rowBand,
        values: numericValues(lineGroups(tsvWords(tsv))).map((value) => ({
          value: value.value,
          unit: value.unit,
          rawToken: value.rawToken,
          rowOwnership: localRowOwnership(value, rowBand),
        })),
      };
    },
    collectSharedOcrPassesForTesting: async (passNames) => {
      let invocationCount = 0;
      const passes = await collectSharedOcrPasses(
        (passNames || ['original', 'grayscale', 'moderate-contrast']).map((name) => ({
          name,
          dataUrl: `test:${name}`,
        })),
        async (dataUrl) => {
          invocationCount += 1;
          return { text: dataUrl, tsv: '' };
        },
      );
      return {
        generatedOnce: true,
        consumerModes: ['STANDARD', 'NUTRITION'],
        invocationCount,
        passes,
      };
    },
    diagnoseSharedArtifactPassesForTesting: async (tsvs) => {
      const passes = (tsvs || []).map((tsv, index) => ({
        name: ['original', 'grayscale', 'moderate-contrast'][index] ||
          `pass-${index + 1}`,
        rawText: String(tsv).split(/\r?\n/).slice(1)
          .map((row) => row.split('\t').slice(11).join('\t'))
          .filter(Boolean)
          .join('\n'),
        tsv,
        durationMs: 0,
      }));
      const artifact = {
        artifactId: 'nutrition-test-artifact',
        generatedOnce: true,
        consumerModes: ['STANDARD', 'NUTRITION'],
        canvas: { width: 0, height: 0, toDataURL: () => 'data:image/png;base64,AA==' },
        input: {
          originalWidth: 1200,
          originalHeight: 800,
          decodedWidth: 1200,
          decodedHeight: 800,
          cropWidth: 1104,
          cropHeight: 640,
          preResizeWidth: 1104,
          preResizeHeight: 640,
          inputWidth: 2048,
          inputHeight: 1187,
          resizeScale: 1.85,
          resizeMethod: 'canvas-image-smoothing-upscale',
        },
        passes,
      };
      await consumeSharedNutritionOcrArtifact(artifact, 'standard');
      const standard = JSON.parse(JSON.stringify(activeNutritionPipelineDiagnostics));
      await consumeSharedNutritionOcrArtifact(artifact, 'nutritionReader');
      const nutrition = JSON.parse(JSON.stringify(activeNutritionPipelineDiagnostics));
      return {
        artifactId: artifact.artifactId,
        generatedOnce: artifact.generatedOnce,
        consumerModes: artifact.consumerModes,
        sameRawOcr: standard.rawText === nutrition.rawText,
        standard,
        nutrition,
      };
    },
    ocrGeometryForDiagnostics: (width, height, mode = 'nutrition') =>
      ocrGeometry(width, height, mode === 'nutrition' ? ocrGuide : packageGuide),
    nutritionRegionFromTsvForTesting: (tsv, width = 1200, height = 800) =>
      nutritionRegionFromDiscovery({ width, height }, tsv),
    recoverNumericTokenForDiagnostics: recoverNumericToken,
    recoverLabelForDiagnostics: labelRecovery,
    recoverBasisForDiagnostics: recoverNutritionBasis,
    assetState: () => ({
      selectedOcrEngine: selectedOcrEngine(),
      requestedOcrEngine: requestedOcrEngine(),
      resolvedOcrEngine: selectedOcrEngine(),
      ocrLoaded: loadedScripts.has(paths.tesseract),
      paddleRuntimeLoaded: Boolean(paddleModulePromise),
      paddleWorkerLoaded: Boolean(paddleWorkerInstance),
      paddleRuntimeLoadCount,
      paddleModelLoadCount,
      paddlePaths: { ...paths },
      lastPaddleDiagnostics,
      barcodeFallbackLoaded: loadedScripts.has(paths.zxing),
      ocrGuide: { ...ocrGuide },
      packageGuide: { ...packageGuide },
      frameQualityThreshold: { ...frameQualityThreshold },
      ocrPasses: ['original', 'grayscale', 'moderate-contrast'],
      lastCaptureDiagnostics,
      lastPhotoDiagnostics,
      lastStructuredDiagnostics,
    }),
  };
  if (selectedOcrEngine('nutrition') === 'paddle') {
    setTimeout(() => updatePaddleDiagnosticPanel('SELECTED'), 0);
  }
})();
