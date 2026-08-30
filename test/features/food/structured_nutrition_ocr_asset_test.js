'use strict';

const assert = require('node:assert/strict');

global.window = {};
global.document = { baseURI: 'https://or-app.test/' };
require('../../../web/assets/food_input/food_input_bridge.js');

const header = [
  'level',
  'page_num',
  'block_num',
  'par_num',
  'line_num',
  'word_num',
  'left',
  'top',
  'width',
  'height',
  'conf',
  'text',
].join('\t');

function word(line, number, left, top, width, text) {
  return [5, 1, 1, 1, line, number, left, top, width, 24, 95, text].join(
    '\t',
  );
}

function tsv(rows) {
  return [header, ...rows].join('\n');
}

function expectMajorFields(text) {
  assert.match(text, /エネルギー 201kcal/);
  assert.match(text, /たんぱく質 2.3g/);
  assert.match(text, /脂質 12.4g/);
  assert.match(text, /炭水化物 21.5g/);
}

async function main() {
  const diagnose = window.orAppFoodInput.diagnoseStructuredNutritionTsv;

  const vertical = tsv([
    word(1, 1, 10, 0, 300, '栄養成分表示：1袋38g当たり'),
    word(2, 1, 10, 40, 120, 'エネルギー'),
    word(2, 2, 170, 40, 70, '201kcal'),
    word(3, 1, 10, 80, 140, 'たんぱく質'),
    word(3, 2, 205, 80, 50, '2.3g'),
    word(4, 1, 10, 120, 60, '脂質'),
    word(4, 2, 115, 120, 60, '12.4g'),
    word(5, 1, 10, 160, 110, '炭水化物'),
    word(5, 2, 190, 160, 60, '21.5g'),
  ]);
  const verticalText = await diagnose(vertical);
  expectMajorFields(verticalText);
  assert.match(verticalText, /栄養成分表示 1袋38g当たり/);
  assert.equal(
    window.orAppFoodInput.assetState().lastStructuredDiagnostics.layoutPattern,
    'vertical-list',
  );

  const twoColumn = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 70, '201kcal'),
    word(2, 1, 10, 50, 140, 'たんぱく質'),
    word(2, 2, 300, 50, 50, '2.3g'),
    word(3, 1, 10, 90, 60, '脂質'),
    word(3, 2, 300, 90, 60, '12.4g'),
    word(4, 1, 10, 130, 110, '炭水化物'),
    word(4, 2, 300, 130, 60, '21.5g'),
  ]);
  expectMajorFields(await diagnose(twoColumn));
  assert.equal(
    window.orAppFoodInput.assetState().lastStructuredDiagnostics.layoutPattern,
    'two-column-table',
  );

  const headerValues = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 180, 10, 140, 'たんぱく質'),
    word(1, 3, 360, 10, 60, '脂質'),
    word(1, 4, 500, 10, 110, '炭水化物'),
    word(2, 1, 20, 55, 70, '201kcal'),
    word(2, 2, 220, 55, 50, '2.3g'),
    word(2, 3, 365, 55, 60, '12.4g'),
    word(2, 4, 520, 55, 60, '21.5g'),
  ]);
  expectMajorFields(await diagnose(headerValues));
  assert.equal(
    window.orAppFoodInput.assetState().lastStructuredDiagnostics.layoutPattern,
    'header-value-row',
  );

  const exclusions = tsv([
    word(1, 1, 10, 10, 110, '炭水化物'),
    word(1, 2, 300, 10, 60, '21.5g'),
    word(2, 1, 10, 50, 60, '糖質'),
    word(2, 2, 300, 50, 60, '18.5g'),
    word(3, 1, 10, 90, 110, '食物繊維'),
    word(3, 2, 300, 90, 50, '3.0g'),
  ]);
  const exclusionText = await diagnose(exclusions);
  assert.match(exclusionText, /炭水化物 21.5g/);
  assert.doesNotMatch(exclusionText, /18.5g|3g/);

  const contentOnly = tsv([
    word(1, 1, 10, 10, 120, '内容量94g'),
    word(2, 1, 10, 50, 110, '炭水化物'),
    word(2, 2, 300, 50, 60, '21.5g'),
  ]);
  assert.doesNotMatch(await diagnose(contentOnly), /94g/);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
