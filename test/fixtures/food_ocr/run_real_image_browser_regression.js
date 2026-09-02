'use strict';

// Test-only CDP client for the loopback real-image harness. The page itself
// loads the production bridge and fixture bytes; this script only waits for
// the asynchronous Tesseract result and returns the diagnostic text.
const assert = require('node:assert/strict');

const debugPort = Number(process.env.OR_APP_OCR_CDP_PORT || 9229);
const fixturePort = Number(process.env.OR_APP_OCR_FIXTURE_PORT || 43127);
const summaryOnly = process.argv.includes('--summary');
const manualCrop = process.argv.includes('--manual-crop');
const fixtureNames = process.argv.slice(2).filter((argument) =>
  argument !== '--summary' && argument !== '--manual-crop');
const fixtures = fixtureNames.length ? fixtureNames : [
  'fixture_a_vertical_nutrition.jpg',
  'fixture_b_horizontal_table.jpg',
  'fixture_c_decimal_conflict.jpg',
];

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function cdp(url, expression) {
  const socket = new WebSocket(url);
  let nextId = 1;
  const pending = new Map();
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const resolve = pending.get(message.id);
    if (resolve) {
      pending.delete(message.id);
      resolve(message);
    }
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  const evaluate = () => new Promise((resolve) => {
    const id = nextId++;
    pending.set(id, resolve);
    socket.send(JSON.stringify({
      id,
      method: 'Runtime.evaluate',
      params: { expression, returnByValue: true },
    }));
  });
  const result = await evaluate();
  socket.close();
  return result.result?.result?.value;
}

async function createPage(url) {
  const response = await fetch(
    `http://127.0.0.1:${debugPort}/json/new?${encodeURIComponent(url)}`,
    { method: 'PUT' },
  );
  assert.equal(response.ok, true, `Cannot create CDP page: ${response.status}`);
  return response.json();
}

async function resultForFixture(fixture) {
  const page = await createPage(
    `http://127.0.0.1:${fixturePort}/real_image_harness.html?fixture=${encodeURIComponent(fixture)}&manualCrop=${manualCrop}`,
  );
  const deadline = Date.now() + 240000;
  while (Date.now() < deadline) {
    const state = await cdp(page.webSocketDebuggerUrl,
      'JSON.stringify({title: document.title, result: document.getElementById("result")?.textContent || ""})');
    const parsed = JSON.parse(state || '{}');
    if (parsed.title === 'COMPLETE') return { fixture, result: parsed.result };
    if (parsed.title === 'FAILED') throw new Error(`${fixture}: ${parsed.result}`);
    await delay(1000);
  }
  throw new Error(`${fixture}: timed out waiting for browser OCR`);
}

function assertFixtureOutcome({ fixture, result }) {
  const nutrition = JSON.parse(result).nutritionLabelReader;
  const final = nutrition.finalResult;
  if (manualCrop) {
    assert.equal(nutrition.autoNutritionCrop?.status, 'SKIPPED_USER_MANUAL_CROP');
    if (fixture === 'fixture_a_vertical_nutrition.jpg') {
      assert.equal(final.calories?.value, 188);
    }
    if (fixture === 'fixture_b_horizontal_table.jpg') {
      assert.equal(final.protein?.value, 0.65);
      assert.equal(final.fat?.value, 0.51);
      assert.equal(final.carbohydrate?.value, 0.54);
    }
    if (fixture === 'fixture_c_decimal_conflict.jpg') {
      assert.equal(final.calories?.value, 167);
      assert.equal(final.protein?.value, 4.4);
      assert.equal(final.fat?.value, 0.4);
      assert.equal(final.carbohydrate?.value, 36.5);
    }
    return;
  }
  if (fixture === 'fixture_a_vertical_nutrition.jpg') {
    // Row isolation must never let a neighbouring value become Protein/Fat.
    assert.notEqual(final.protein?.value, 5.2);
    assert.notEqual(final.fat?.value, 23.8);
  }
  if (fixture === 'fixture_b_horizontal_table.jpg') {
    assert.equal(final.protein?.value, 0.65);
    assert.equal(final.protein?.unit, 'g');
    assert.equal(final.fat?.value, 0.51);
    assert.equal(final.fat?.unit, 'g');
    assert.equal(final.carbohydrate?.value, 0.54);
    assert.equal(final.carbohydrate?.unit, 'g');
  }
  if (fixture === 'fixture_c_decimal_conflict.jpg') {
    assert.equal(final.calories?.value, 167);
    assert.equal(final.protein?.value, 4.4);
    assert.equal(final.carbohydrate?.value, 36.5);
    // `04g` must never make an unsafe 4g form value. A genuine 0.4g
    // consensus or a retained review state are both safe outcomes.
    assert.notEqual(final.fat?.value, 4);
    if (manualCrop) {
      assert.equal(nutrition.autoNutritionCrop?.status, 'SKIPPED_USER_MANUAL_CROP');
    } else {
      assert.equal(
        nutrition.autoNutritionCrop?.status,
        'APPLIED',
        'Fixture C must exercise nutrition-region discovery before full OCR',
      );
    }
  }
}

async function main() {
  const results = [];
  for (const fixture of fixtures) results.push(await resultForFixture(fixture));
  results.forEach(assertFixtureOutcome);
  const output = summaryOnly ? results.map(({ fixture, result }) => {
    const diagnostic = JSON.parse(result);
    const nutrition = diagnostic.nutritionLabelReader;
    return {
      fixture,
      finalResult: {
        basis: nutrition.finalResult.basis,
        calories: nutrition.finalResult.calories,
        protein: nutrition.finalResult.protein,
        fat: nutrition.finalResult.fat,
        carbohydrate: nutrition.finalResult.carbohydrate,
        needsReviewFields: nutrition.finalResult.needsReviewFields,
      },
      decisions: nutrition.confidenceDecisions.map((decision) => ({
        field: decision.field, value: decision.value, unit: decision.unit,
        confidence: decision.confidence, conflict: decision.conflict,
        reviewRequired: decision.reviewRequired, decision: decision.decision,
      })),
      autoNutritionCrop: nutrition.autoNutritionCrop,
      ocrViews: nutrition.ocrViews,
      localRefinement: nutrition.localRefinementAttempts.map((attempt) => ({
        targetField: attempt.targetField, regionType: attempt.regionType,
        triggerReason: attempt.triggerReason || null,
        resultStatus: attempt.resultStatus, numericValue: attempt.numericValue,
        unit: attempt.unit, rowOwnership: attempt.rowOwnership,
        variant: attempt.preprocessing?.variant || null,
        variantAgreement: attempt.variantAgreement || 0,
        rawOcrText: attempt.rawOcrText || '',
        numericRawOcrText: attempt.numericRawOcrText || '',
        lineNumericRawOcrText: attempt.lineNumericRawOcrText || '',
        thresholdNumericRawOcrText: attempt.thresholdNumericRawOcrText || '',
        splitNumberRawOcrText: attempt.splitNumberRawOcrText || '',
        splitUnitRawOcrText: attempt.splitUnitRawOcrText || '',
        splitCellEvidence: attempt.splitCellEvidence || null,
      })),
    };
  }) : results;
  process.stdout.write(`${JSON.stringify(output)}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
