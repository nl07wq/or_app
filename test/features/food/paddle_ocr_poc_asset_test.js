'use strict';

const assert = require('node:assert/strict');

global.window = {};
global.location = { search: '' };
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
  await bridge.recognizePaddleCanvasForDiagnostics({ width: 900, height: 700 });
  await bridge.recognizePaddleCanvasForDiagnostics({ width: 900, height: 700 });
  assert.equal(createCount, 1);
  assert.equal(predictCount, 2);
  assert.equal(bridge.assetState().paddleRuntimeLoadCount, 1);
  assert.equal(bridge.assetState().paddleModelLoadCount, 1);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
