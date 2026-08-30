'use strict';

const assert = require('node:assert/strict');

global.window = {};
global.location = {
  search: '',
  hash: '#/food',
  origin: 'https://or-app.test',
};
global.document = { baseURI: 'https://or-app.test/' };
global.performance = { now: () => Date.now() };
require('../../../web/assets/food_input/food_input_bridge.js');

const bridge = window.orAppFoodInput;

function item(text, left, top, width, height = 24, score = 0.96) {
  return {
    text,
    score,
    poly: [
      { x: left, y: top },
      { x: left + width, y: top },
      { x: left + width, y: top + height },
      { x: left, y: top + height },
    ],
  };
}

function result(items) {
  return {
    image: { width: 900, height: 700 },
    items,
    metrics: {
      detMs: 12,
      recMs: 18,
      totalMs: 30,
      detectedBoxes: items.length,
      recognizedCount: items.length,
    },
    runtime: {
      requestedBackend: 'wasm',
      detProvider: 'wasm',
      recProvider: 'wasm',
      webgpuAvailable: false,
    },
  };
}

function expectMajorFields(text) {
  assert.match(text, /栄養成分表示 1袋38g当たり/);
  assert.match(text, /エネルギー 201kcal/);
  assert.match(text, /たんぱく質 2.3g/);
  assert.match(text, /脂質 12.4g/);
  assert.match(text, /炭水化物 21.5g/);
  assert.doesNotMatch(text, /炭水化物 (?:18\.5|3(?:\.0)?)g/);
}

async function verifyLayout(items, expectedLayout) {
  const output = await bridge.diagnosePaddleResult(result([
    item('栄養成分表示：1袋38g当たり', 10, 0, 330),
    ...items,
    item('糖質 18.5g', 10, 500, 180),
    item('食物繊維 3.0g', 10, 540, 200),
  ]));
  expectMajorFields(output.structured);
  assert.equal(output.engineId, 'paddle');
  assert.equal(output.source.width, 900);
  assert.equal(output.items[0].score, 0.96);
  assert.equal(
    bridge.assetState().lastStructuredDiagnostics.layoutPattern,
    expectedLayout,
  );
}

async function main() {
  assert.equal(bridge.assetState().selectedOcrEngine, 'tesseract');
  location.search = '?orOcrEngine=paddle';
  assert.equal(bridge.assetState().requestedOcrEngine, 'paddle');
  assert.equal(bridge.assetState().resolvedOcrEngine, 'paddle');
  assert.equal(location.hash, '#/food');
  assert.match(
    bridge.assetState().paddlePaths.paddleModule,
    /^https:\/\/or-app\.test\/assets\/food_input\/paddle\//,
  );
  location.search = '';
  window.__OR_APP_OCR_ENGINE__ = 'paddle';
  assert.equal(bridge.assetState().selectedOcrEngine, 'paddle');
  window.__OR_APP_OCR_ENGINE__ = 'tesseract';

  await verifyLayout([
    item('エネルギー 201kcal', 10, 50, 260),
    item('たんぱく質 2.3g', 10, 100, 260),
    item('脂質 12.4g', 10, 150, 180),
    item('炭水化物 21.5g', 10, 200, 240),
  ], 'vertical-list');

  await verifyLayout([
    item('エネルギー', 10, 50, 130), item('201kcal', 350, 50, 90),
    item('たんぱく質', 10, 100, 150), item('2.3g', 350, 100, 70),
    item('脂質', 10, 150, 70), item('12.4g', 350, 150, 80),
    item('炭水化物', 10, 200, 120), item('21.5g', 350, 200, 80),
  ], 'two-column-table');

  await verifyLayout([
    item('エネルギー', 10, 50, 130),
    item('たんぱく質', 210, 50, 150),
    item('脂質', 430, 50, 70),
    item('炭水化物', 600, 50, 120),
    item('201kcal', 20, 100, 90),
    item('2.3g', 240, 100, 70),
    item('12.4g', 430, 100, 80),
    item('21.5g', 620, 100, 80),
  ], 'header-value-row');

  await verifyLayout([
    item('エネルギー', 10, 50, 130), item('201kcal', 20, 82, 90),
    item('たんぱく質', 10, 140, 150), item('2.3g', 20, 172, 70),
    item('脂質', 10, 230, 70), item('12.4g', 20, 262, 80),
    item('炭水化物', 10, 320, 120), item('21.5g', 20, 352, 80),
  ], 'boxed-wrapped');

  let createCount = 0;
  let predictCount = 0;
  const fakeResult = result([item('脂質 10.6g', 10, 40, 180)]);
  window.__OR_APP_OCR_ENGINE__ = 'paddle';
  let failRuntimeProbe = true;
  window.__OR_APP_PADDLE_ASSET_PROBE__ = async (url) => {
    const failed = failRuntimeProbe && url.endsWith('paddleocr-engine.mjs');
    return {
      ok: !failed,
      status: failed ? 404 : 200,
      headers: {
        get: (name) => name === 'content-type'
          ? (url.endsWith('.wasm') ? 'application/wasm' : 'application/javascript')
          : (name === 'content-length' ? '1024' : null),
      },
    };
  };
  window.__OR_APP_PADDLE_FACTORY__ = async () => {
    createCount += 1;
    return {
      getInitializationSummary: () => ({ backend: 'wasm', elapsedMs: 5 }),
      predict: async () => {
        predictCount += 1;
        return [fakeResult];
      },
    };
  };
  await assert.rejects(
    bridge.recognizePaddleCanvasForDiagnostics({ width: 320, height: 180 }),
    /runtime-module returned HTTP 404/,
  );
  let diagnostics = bridge.getPaddleDiagnostics();
  assert.equal(diagnostics.requestedEngine, 'paddle');
  assert.equal(diagnostics.resolvedEngine, 'paddle');
  assert.equal(diagnostics.actualExecutedEngine, null);
  assert.equal(diagnostics.failureStage, 'P1');
  assert.equal(diagnostics.failureCategory, 'CLASS B');
  assert.equal(diagnostics.errorCategory, 'LOAD-MODULE');
  assert.equal(diagnostics.assets['runtime-module'].status, 404);
  assert.equal(diagnostics.assets['runtime-module'].ok, false);

  failRuntimeProbe = false;
  await bridge.recognizePaddleCanvasForDiagnostics({ width: 900, height: 700 });
  assert.equal(createCount, 1);
  assert.equal(predictCount, 1);
  assert.equal(bridge.assetState().paddleRuntimeLoadCount, 2);
  assert.equal(bridge.assetState().paddleModelLoadCount, 1);
  diagnostics = bridge.getPaddleDiagnostics();
  assert.equal(diagnostics.requestedEngine, 'paddle');
  assert.equal(diagnostics.resolvedEngine, 'paddle');
  assert.equal(diagnostics.actualExecutedEngine, 'paddle');
  assert.equal(diagnostics.state, 'ready');
  assert.equal(diagnostics.detectedTextCount, 1);
  assert.equal(diagnostics.recognizedTextCount, 1);
  assert.equal(diagnostics.watchdogFired, false);
  assert.equal(diagnostics.dimensions.sourceWidth, 900);
  assert.equal(diagnostics.dimensions.sourceHeight, 700);
  assert.ok(diagnostics.stages.some((stage) => stage.stageId === 'P5'));
  assert.ok(diagnostics.stages.some((stage) => stage.stageId === 'P20'));
  assert.ok(diagnostics.stages.some((stage) => stage.stageId === 'P23'));
  assert.ok(diagnostics.stages.some((stage) => stage.stageId === 'P26'));
  assert.equal(diagnostics.assets['detection-model'].status, 200);
  assert.equal(diagnostics.assets['recognition-model'].status, 200);
  assert.equal(diagnostics.runtime.numThreads, 1);
  assert.equal(diagnostics.standaloneChecks.detectionOnly.available, false);
  assert.equal(diagnostics.standaloneChecks.recognitionOnly.available, false);
  const exported = JSON.stringify(diagnostics);
  assert.doesNotMatch(exported, /脂質 10\.6g/);
  assert.doesNotMatch(exported, /rawText|dataUrl|base64/i);

  await bridge.recognizePaddleCanvasForDiagnostics({ width: 900, height: 700 });
  assert.equal(createCount, 1);
  assert.equal(predictCount, 2);
  assert.equal(bridge.assetState().paddleRuntimeLoadCount, 2);
  assert.equal(bridge.assetState().paddleModelLoadCount, 1);

  assert.equal(
    bridge.classifyPaddleFailureForDiagnostics('worker stopped', 'P3'),
    'CLASS C',
  );
  assert.equal(
    bridge.classifyPaddleFailureForDiagnostics('WebAssembly compile failed', 'P5'),
    'CLASS D',
  );
  assert.equal(
    bridge.classifyPaddleFailureForDiagnostics('recognition timed out', 'P22'),
    'CLASS I',
  );
  assert.deepEqual(
    bridge.mapPaddleFailureForDiagnostics('recognition timed out', 'P22'),
    { failureCategory: 'CLASS I', errorCategory: 'TIMEOUT-UNKNOWN' },
  );
  assert.deepEqual(
    bridge.mapPaddleFailureForDiagnostics('asset missing', 'P11'),
    { failureCategory: 'CLASS B', errorCategory: 'MODEL-FETCH-REC' },
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
