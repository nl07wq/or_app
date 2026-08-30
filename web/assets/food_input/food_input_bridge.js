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

  function requestedOcrEngine() {
    const queryEngine = typeof location === 'undefined'
      ? null
      : new URLSearchParams(location.search).get('orOcrEngine');
    return window.__OR_APP_OCR_ENGINE__ || queryEngine || 'tesseract';
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

  function startPaddleDiagnostics(source, dimensions = {}) {
    const requestedEngine = requestedOcrEngine();
    const resolvedEngine = selectedOcrEngine('nutrition');
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

  function ensurePaddleDiagnostics(source, dimensions, force = false) {
    if (force || !activePaddleDiagnostics ||
        activePaddleDiagnostics.state !== 'running') {
      return startPaddleDiagnostics(source, dimensions);
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

  function selectedOcrEngine(mode = 'nutrition') {
    if (mode !== 'nutrition') return 'tesseract';
    return requestedOcrEngine() === 'paddle'
      ? 'paddle'
      : 'tesseract';
  }

  function updatePaddleDiagnosticPanel(status) {
    if (selectedOcrEngine('nutrition') !== 'paddle' ||
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
      ensurePaddleDiagnostics(source, canvas, !reuseRun);
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
  } = {}) {
    const recognize = async () => {
      const worker = await ocrWorker();
      let timeout;
      try {
        if (whitelist) {
          await worker.setParameters({ tessedit_char_whitelist: whitelist });
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
        if (whitelist && workerInstance === worker) {
          await worker.setParameters({ tessedit_char_whitelist: '' });
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
    const maxWidth = 2560;
    const scale = Math.min(1, maxWidth / sourceWidth);
    return {
      sourceX,
      sourceY,
      sourceWidth,
      sourceHeight,
      inputWidth: Math.max(1, Math.round(sourceWidth * scale)),
      inputHeight: Math.max(1, Math.round(sourceHeight * scale)),
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
        const canvas = document.createElement('canvas');
        canvas.width = geometry.inputWidth;
        canvas.height = geometry.inputHeight;
        const context = canvas.getContext('2d', { alpha: false });
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
          inputWidth: canvas.width,
          inputHeight: canvas.height,
          passCount: 0,
          passDurationsMs: [],
        };
        resolve(canvas);
      };
      image.onerror = reject;
      image.src = dataUrl;
    });
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
  const structuredMarker = '[[OR_STRUCTURED_NUTRITION]]\n';
  const nutritionBasisPattern =
    /(?:100\s*(?:g|m[lL])|(?:\d+\s*)?(?:袋|個|本|枚|食)(?:\s*\d+(?:[.,]\d+)?\s*(?:g|m[lL]))?)\s*当たり/i;

  function normalizeOcrToken(value) {
    return String(value || '')
      .replace(/[ \t　]/g, '')
      .replace(/．/g, '.')
      .replace(/，/g, ',')
      .replace(/[０-９]/g, (digit) =>
        String.fromCharCode(digit.charCodeAt(0) - 0xff10 + 0x30),
      );
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
            anchors.push({ field, alias, lineKey: group.lineKey, ...boxForWords(matched) });
          }
          break;
        }
      }
    }
    return anchors;
  }

  function numericValues(groups) {
    const values = [];
    const pattern = /^(\d+(?:[.,]\d+)?)(kcal|mg|g)$/i;
    for (const group of groups) {
      for (let index = 0; index < group.words.length; index += 1) {
        for (const count of [1, 2]) {
          const selected = group.words.slice(index, index + count);
          if (selected.length !== count) continue;
          const match = pattern.exec(normalizeOcrToken(selected.map((word) => word.text).join('')));
          if (!match) continue;
          const number = Number(match[1].replace(',', '.'));
          if (!Number.isFinite(number) || number < 0) continue;
          values.push({
            value: number,
            unit: match[2].toLowerCase(),
            lineKey: group.lineKey,
            ...boxForWords(selected),
          });
        }
      }
    }
    return values.filter((value, index, all) =>
      all.findIndex((candidate) =>
        candidate.lineKey === value.lineKey && candidate.left === value.left &&
        candidate.value === value.value && candidate.unit === value.unit,
      ) === index,
    );
  }

  const targetNutritionFields = ['energy', 'protein', 'fat', 'carbohydrate'];

  function compatibleValue(field, value) {
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
        .sort((a, b) => a.score - b.score);
      const best = ranked[0];
      if (!best) continue;
      const competingAnchors = anchors.filter((candidate) =>
        compatibleValue(candidate.field, best.value) &&
        relationshipScore(candidate, best.value, headerAnchors) < best.score,
      );
      if (competingAnchors.length) continue;
      mapped.set(anchor.field, best.value);
      used.add(best.index);
    }
    return mapped;
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

  async function valueFromRoi(canvas, anchor, field) {
    const regions = [
      {
        left: anchor.right,
        top: anchor.top - anchor.height * 0.5,
        right: canvas.width,
        bottom: anchor.bottom + anchor.height * 0.5,
      },
      {
        left: anchor.left - anchor.width * 0.4,
        top: anchor.bottom,
        right: anchor.right + Math.max(anchor.width * 2.5, 320),
        bottom: anchor.bottom + anchor.height * 2.6,
      },
    ];
    const pattern = field === 'energy'
      ? /(\d+(?:[.,]\d+)?)\s*kcal/i
      : /(\d+(?:[.,]\d+)?)\s*g/i;
    for (const region of regions) {
      const roi = roiCanvas(canvas, region);
      if (!roi || roi.width < 8 || roi.height < 8) continue;
      const data = await recognizePass(roi.toDataURL('image/png'), {
        whitelist: '0123456789.,kcalg',
      });
      const matches = [...String(data.text || '').matchAll(new RegExp(pattern, 'gi'))];
      if (matches.length !== 1) continue;
      const value = Number(matches[0][1].replace(',', '.'));
      if (Number.isFinite(value) && value >= 0) {
        return { value, unit: field === 'energy' ? 'kcal' : 'g' };
      }
    }
    return null;
  }

  async function structuredNutritionWords(canvas, words, engineId) {
    const groups = lineGroups(words);
    const anchors = nutritionAnchors(groups);
    const mapped = mapAnchorValues(anchors, numericValues(groups));
    let roiCount = 0;
    for (const field of targetNutritionFields) {
      if (mapped.has(field)) continue;
      const anchor = anchors.find((candidate) => candidate.field === field);
      if (!anchor || engineId !== 'tesseract') continue;
      roiCount += 1;
      const value = await valueFromRoi(canvas, anchor, field);
      if (value) mapped.set(field, value);
    }
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
      engineId,
      fieldSources: Object.fromEntries(
        [...mapped.keys()].map((field) => [field, 'structured']),
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
      const value = mapped.get(field);
      if (value) lines.push(`${fieldLabel[field]} ${value.value}${value.unit}`);
    }
    return lines.length ? structuredMarker + lines.join('\n') : '';
  }

  async function structuredNutritionText(canvas, tsv) {
    return structuredNutritionWords(canvas, tsvWords(tsv), 'tesseract');
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

  async function recognizeJapaneseText(dataUrl, mode = 'package') {
    const engineId = selectedOcrEngine(mode);
    if (mode === 'nutrition' && engineId === 'paddle') {
      startPaddleDiagnostics('photo');
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
    let layoutTsv = '';
    for (const variant of ocrVariants(canvas, mode)) {
      const startedAt = performance.now();
      let text;
      if (mode === 'nutrition' && variant.name === 'original') {
        const data = await recognizeLayoutPass(variant.dataUrl);
        text = data.text || '';
        layoutTsv = data.tsv || '';
      } else {
        text = await recognizeSinglePass(variant.dataUrl);
      }
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.passCount += 1;
        lastPhotoDiagnostics.passDurationsMs.push(
          Math.round(performance.now() - startedAt),
        );
      }
      if (text.trim() && !texts.includes(text)) texts.push(text);
    }
    if (mode === 'nutrition' && layoutTsv) {
      const startedAt = performance.now();
      const structured = await structuredNutritionText(canvas, layoutTsv);
      if (lastPhotoDiagnostics) {
        lastPhotoDiagnostics.structuredDurationMs = Math.round(
          performance.now() - startedAt,
        );
      }
      if (structured) texts.push(structured);
    }
    if (lastPhotoDiagnostics) lastPhotoDiagnostics.engineId = engineId;
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
    return { overlay, video, guide, close, result, actions };
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

  async function recognizeTextLive(title, instruction, describeCandidate) {
    const mode = title.includes('NUTRITION') ? 'nutrition' : 'package';
    const session = await openCamera(title, mode);
    session.guide.style.display = 'block';
    session.guide.firstElementChild.textContent = instruction;
    session.result.textContent = instruction;
    const review = document.createElement('button');
    review.type = 'button';
    review.textContent = 'REVIEW RESULT';
    review.disabled = true;
    styleButton(review, true);
    const takePhoto = document.createElement('button');
    takePhoto.type = 'button';
    takePhoto.textContent = 'TAKE PHOTO';
    styleButton(takePhoto, false);
    const choosePhoto = document.createElement('button');
    choosePhoto.type = 'button';
    choosePhoto.textContent = 'CHOOSE PHOTO';
    styleButton(choosePhoto, false);
    const highAccuracy = document.createElement('button');
    highAccuracy.type = 'button';
    highAccuracy.textContent = 'HIGH ACCURACY SCAN';
    styleButton(highAccuracy, true);
    session.actions.append(highAccuracy, review, takePhoto, choosePhoto);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let latestRawText = null;
      let latestDescription = null;
      let unsuccessfulScans = 0;
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
      const finishWithImage = async (preferCamera) => {
        if (!cleanup()) return;
        try {
          const image = await selectImage(preferCamera);
          resolve(image ? await recognizeJapaneseText(image, mode) : null);
        } catch (_) {
          resolve(null);
        }
      };
      session.close.onclick = () => finish(null);
      review.onclick = () => {
        if (!latestRawText) return;
        if (mode === 'nutrition' && selectedOcrEngine(mode) === 'paddle') {
          recordPaddleStage('P28', 'success');
        }
        finish(latestRawText);
      };
      takePhoto.onclick = () => finishWithImage(true);
      choosePhoto.onclick = () => finishWithImage(false);

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
        const serialized = JSON.stringify(description);
        const hasCandidate = description.state === 'partial' ||
          description.state === 'detected';
        if (hasCandidate) {
          latestDescription = serialized;
          ocrResultContent(session.result, description, mode);
          review.disabled = false;
        } else if (review.disabled) {
          ocrResultContent(session.result, description, mode);
        }
        return hasCandidate;
      };

      highAccuracy.onclick = async () => {
        if (finished || running) return;
        running = true;
        highAccuracy.disabled = true;
        highAccuracyValues.clear();
        highAccuracyConflicts.clear();
        session.result.textContent = '高精度で読み取り中...';
        try {
          const frame = await captureBestFrame(session);
          if (!frame) {
            session.result.textContent = 'カメラを静止させ、反射を避けてもう一度お試しください。';
            return;
          }
          const texts = [];
          let layoutTsv = '';
          if (mode === 'nutrition' && selectedOcrEngine(mode) === 'paddle') {
            const paddle = await recognizePaddleNutrition(
              frame.canvas,
              'live-high-accuracy',
            );
            for (const rawText of paddle.texts) {
              if (!rawText.trim() || texts.includes(rawText)) continue;
              texts.push(rawText);
              present(rawText, true);
            }
          } else {
            for (const variant of ocrVariants(frame.canvas, mode)) {
              let rawText;
              if (mode === 'nutrition' && variant.name === 'original') {
                const data = await recognizeLayoutPass(variant.dataUrl);
                rawText = data.text || '';
                layoutTsv = data.tsv || '';
              } else {
                rawText = await recognizeSinglePass(variant.dataUrl);
              }
              if (!rawText.trim() || texts.includes(rawText)) continue;
              texts.push(rawText);
              present(rawText, true);
            }
          }
          if (mode === 'nutrition' && layoutTsv) {
            const structured = await structuredNutritionText(
              frame.canvas,
              layoutTsv,
            );
            if (structured) {
              texts.push(structured);
              present(structured, true);
            }
          }
          if (texts.length) latestRawText = texts.join(ocrPassSeparator);
          if (review.disabled) {
            session.result.textContent = mode === 'nutrition'
              ? '栄養成分を認識できませんでした。反射を避けて再度お試しください。'
              : '商品情報候補を認識できませんでした。反射を避けて再度お試しください。';
          }
        } catch (_) {
          if (!finished) {
            session.result.textContent = '高精度読み取りを完了できません。写真での読み取りをお試しください。';
          }
        } finally {
          running = false;
          highAccuracy.disabled = false;
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
          const rawText = mode === 'nutrition' && selectedOcrEngine(mode) === 'paddle'
            ? (await recognizePaddleNutrition(
              frame.canvas,
              'live-preview',
            )).texts.join(ocrPassSeparator)
            : await recognizeSinglePass(
              frame.canvas.toDataURL('image/jpeg', 0.92),
            );
          if (finished) return;
          const description = JSON.parse(describeCandidate(rawText));
          const serialized = JSON.stringify(description);
          const hasCandidate = description.state === 'partial' ||
            description.state === 'detected';
          if (hasCandidate &&
              serialized !== latestDescription) {
            unsuccessfulScans = 0;
            latestRawText = rawText;
            latestDescription = serialized;
            ocrResultContent(session.result, description, mode);
            review.disabled = false;
          } else if (description.state === 'insufficient') {
            unsuccessfulScans += 1;
            ocrResultContent(session.result, description, mode);
          } else if (description.state === 'scanning') {
            unsuccessfulScans += 1;
            session.result.textContent = unsuccessfulScans >= 3
                ? '高精度読み取り、または写真での読み取りをお試しください。'
                : '読み取り中...';
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
      timer = setInterval(tick, 1500);
      tick();
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

  window.orAppFoodInput = {
    selectImage,
    recognizeJapaneseText,
    scanBarcode,
    scanBarcodeLive,
    recognizeTextLive,
    diagnosePaddleResult,
    benchmarkNutritionEngines,
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
