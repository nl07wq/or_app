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
  const recoverNumeric =
    window.orAppFoodInput.recoverNumericTokenForDiagnostics;
  const recoverLabel = window.orAppFoodInput.recoverLabelForDiagnostics;
  const recoverBasis = window.orAppFoodInput.recoverBasisForDiagnostics;

  assert.deepEqual(
    {
      value: recoverNumeric('188 kcal').numericValue,
      unit: recoverNumeric('188 kcal').unit,
      method: recoverNumeric('188 kcal').recoveryMethod,
    },
    { value: 188, unit: 'kcal', method: 'exact-numeric-unit' },
  );
  assert.equal(recoverNumeric('188keal').numericValue, 188);
  assert.equal(recoverNumeric('188keal').unit, 'kcal');
  assert.match(recoverNumeric('188keal').recoveryMethod, /fuzzy-unit/);
  assert.equal(recoverNumeric('188kKe@l').rawToken, '188kKe@l');
  assert.equal(recoverNumeric('188kKe@l').numericValue, 188);
  assert.equal(recoverNumeric('23.8g').numericValue, 23.8);
  assert.equal(recoverNumeric('２３．８ｇ').numericValue, 23.8);
  assert.equal(recoverNumeric('２３．８ｇ').unit, 'g');
  const unitless = recoverNumeric('23.9');
  assert.equal(unitless.numericValue, 23.9);
  assert.equal(unitless.unit, null);
  assert.equal(unitless.unitStatus, 'MISSING');
  assert.equal(unitless.candidateType, 'NUMERIC_WITHOUT_UNIT');
  const ambiguous = recoverNumeric('2@3.9g');
  assert.equal(ambiguous.candidateType, 'AMBIGUOUS_NUMERIC');
  assert.equal(ambiguous.numericValue, null);
  assert.match(ambiguous.ambiguity, /multiple-plausible/);

  assert.equal(recoverLabel('エネルギー', 95).status, 'EXACT');
  assert.equal(recoverLabel('ィネルギー', 95).field, 'energy');
  assert.match(recoverLabel('ィネルギー', 95).status, /RECOVERED/);
  assert.equal(recoverLabel('たんばぱく質', 95).field, 'protein');
  assert.equal(recoverLabel('エネルキー', 95).field, 'energy');
  assert.equal(recoverLabel('エネルキギー', 95).field, 'energy');
  assert.equal(recoverLabel('たんばく質', 95).field, 'protein');
  assert.equal(recoverBasis('栄養成分表示'), null);
  assert.equal(recoverBasis('栄養成分表示（製品1個あたり）').basis, '製品1個あたり');

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
  const horizontalRefinement = window.orAppFoodInput
    .localRefinementRegionsForTesting(headerValues, 'protein');
  assert.ok(horizontalRefinement.some((item) =>
    item.regionType === 'HORIZONTAL_HEADER_COLUMN' &&
    item.cropRect.width > 0 && item.cropRect.height > 0,
  ));
  const verticalRefinement = window.orAppFoodInput
    .localRefinementRegionsForTesting(vertical, 'fat');
  assert.ok(verticalRefinement.some((item) =>
    item.regionType === 'VERTICAL_ROW_REGION' &&
    item.cropRect.width > 0 && item.cropRect.height > 0,
  ));

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

  const wrongRow = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(2, 1, 10, 50, 110, '炭水化物'),
    word(2, 2, 300, 50, 60, '23.8g'),
  ]);
  assert.doesNotMatch(await diagnose(wrongRow), /エネルギー 23.8/);

  const ambiguousOnly = tsv([
    word(1, 1, 10, 10, 110, '炭水化物'),
    word(1, 2, 300, 10, 60, '2@3.9g'),
  ]);
  assert.equal(await diagnose(ambiguousOnly), '');
  const lowDecision =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .confidenceDecisions.find((item) => item.field === 'carbohydrate');
  assert.equal(lowDecision.confidence, 'LOW');
  assert.equal(lowDecision.decision, 'CANDIDATE_ONLY');

  const unitlessCarbohydrate = tsv([
    word(1, 1, 10, 10, 110, '炭水化物'),
    word(1, 2, 300, 10, 60, '23.9'),
  ]);
  const unitlessText = await diagnose(unitlessCarbohydrate);
  assert.match(unitlessText, /\[\[OR_OCR_DECISIONS\]\]/);
  const unitlessDecision =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .confidenceDecisions.find((item) => item.field === 'carbohydrate');
  assert.equal(unitlessDecision.value, 23.9);
  assert.equal(unitlessDecision.unit, null);
  assert.equal(unitlessDecision.confidence, 'MEDIUM');
  assert.equal(unitlessDecision.decision, 'REVIEW_REQUIRED');
  assert.equal(unitlessDecision.reviewRequired, true);
  assert.ok(
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .numericCandidates.some((item) =>
        item.rawToken === '23.9' &&
        item.candidateType === 'NUMERIC_WITHOUT_UNIT' &&
        item.unit === null && item.sourcePass === 'original',
      ),
  );

  const noLabelUnitless = tsv([word(1, 1, 10, 10, 60, '23.9')]);
  assert.equal(await diagnose(noLabelUnitless), '');

  const shared = await window.orAppFoodInput.collectSharedOcrPassesForTesting();
  assert.equal(shared.generatedOnce, true);
  assert.deepEqual(shared.consumerModes, ['STANDARD', 'NUTRITION']);
  assert.equal(shared.invocationCount, 3);
  assert.deepEqual(
    shared.passes.map((pass) => pass.name),
    ['original', 'grayscale', 'moderate-contrast'],
  );

  const resized = window.orAppFoodInput.ocrGeometryForDiagnostics(1199, 859);
  assert.equal(resized.inputWidth, 2048);
  assert.equal(resized.resizeMethod, 'canvas-image-smoothing-upscale');
  assert.ok(resized.resizeScale > 1 && resized.resizeScale < 2);
  assert.ok(
    Math.abs(
      resized.inputWidth / resized.inputHeight -
      resized.sourceWidth / resized.sourceHeight,
    ) < 0.002,
  );
  const alreadyLarge = window.orAppFoodInput.ocrGeometryForDiagnostics(2500, 1200);
  assert.equal(alreadyLarge.resizeScale, 1);
  const tiny = window.orAppFoodInput.ocrGeometryForDiagnostics(320, 200);
  assert.equal(tiny.resizeScale, 2);

  const recovered = tsv([
    word(1, 1, 10, 10, 120, 'ィネルギー'),
    word(1, 2, 300, 10, 90, '188keal'),
    word(2, 1, 10, 50, 150, 'たんばぱく質'),
    word(2, 2, 300, 50, 60, '2.8g'),
  ]);
  const recoveredText = await diagnose(recovered);
  assert.match(recoveredText, /エネルギー 188kcal/);
  assert.match(recoveredText, /たんぱく質 2.8g/);
  const recoveredDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  assert.ok(recoveredDiagnostics.labelRecovery.some((item) =>
    item.rawText === 'ィネルギー' && item.candidate === 'エネルギー',
  ));
  assert.ok(recoveredDiagnostics.numericRecovery.some((item) =>
    item.rawToken === '188keal' && item.numericValue === 188,
  ));

  const pass1 = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 90, '188keal'),
    word(2, 1, 10, 50, 110, '炭水化物'),
    word(2, 2, 300, 50, 60, '23.8g'),
  ]);
  const pass2 = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 90, '19@kcal'),
    word(2, 1, 10, 50, 110, '炭水化物'),
    word(2, 2, 300, 50, 60, '23.9g'),
  ]);
  const pass3 = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 90, '188kKe@l'),
    word(2, 1, 10, 50, 110, '炭水化物'),
    word(2, 2, 300, 50, 60, '2@3.9g'),
  ]);
  const consensusText = await window.orAppFoodInput
    .diagnoseStructuredNutritionPassesForTesting([pass1, pass2, pass3]);
  assert.match(consensusText, /エネルギー 188kcal/);
  assert.doesNotMatch(consensusText, /炭水化物/);
  const consensusDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  const energyDecision = consensusDiagnostics.confidenceDecisions
    .find((item) => item.field === 'energy');
  assert.equal(energyDecision.confidence, 'HIGH');
  assert.equal(energyDecision.decision, 'AUTO_FILL_ALLOWED');
  const carbohydrateDecision = consensusDiagnostics.confidenceDecisions
    .find((item) => item.field === 'carbohydrate');
  assert.equal(carbohydrateDecision.conflict, true);
  assert.equal(carbohydrateDecision.confidence, 'MEDIUM');
  assert.equal(carbohydrateDecision.decision, 'REVIEW_REQUIRED');
  assert.ok(consensusDiagnostics.conflicts.some((item) =>
    item.field === 'carbohydrate' && item.conflict === true,
  ));

  const sharedDiagnostic = await window.orAppFoodInput
    .diagnoseSharedArtifactPassesForTesting([pass1, pass2, pass3]);
  assert.equal(sharedDiagnostic.generatedOnce, true);
  assert.deepEqual(sharedDiagnostic.consumerModes, ['STANDARD', 'NUTRITION']);
  assert.equal(sharedDiagnostic.sameRawOcr, true);
  assert.equal(
    sharedDiagnostic.standard.sharedOcrArtifact.artifactId,
    sharedDiagnostic.nutrition.sharedOcrArtifact.artifactId,
  );
  assert.equal(
    sharedDiagnostic.nutrition.structured.confidenceDecisions
      .find((item) => item.field === 'energy').value,
    188,
  );

  const exactUnitTieBreak = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 36, '188'),
    word(1, 3, 338, 10, 54, 'kcal'),
  ]);
  const exactUnitTieBreakText = await diagnose(exactUnitTieBreak);
  assert.match(exactUnitTieBreakText, /エネルギー 188kcal/);
  const tieBreakDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  const tieBreakMapping = tieBreakDiagnostics.structuredCandidates
    .find((item) => item.field === 'energy');
  assert.equal(tieBreakMapping.selectedCandidate.unit, 'kcal');
  assert.equal(tieBreakMapping.selectedCandidate.unitStatus, 'EXACT');
  assert.match(tieBreakMapping.selectionReason, /exact-compatible-unit-preferred/);
  assert.equal(
    tieBreakDiagnostics.semanticDuplicateCollapse
      .find((item) => item.value === 188).rawCandidateCount,
    2,
  );

  const energyPassGarbled = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 70, '19@kcal'),
  ]);
  const energyPassExact = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 36, '188'),
    word(1, 3, 338, 10, 54, 'kcal'),
  ]);
  await window.orAppFoodInput.diagnoseStructuredNutritionPassesForTesting([
    energyPassGarbled,
    energyPassExact,
    energyPassExact,
  ]);
  const energyConsensus =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .confidenceDecisions.find((item) => item.field === 'energy');
  assert.equal(energyConsensus.value, 188);
  assert.equal(energyConsensus.unit, 'kcal');
  assert.deepEqual(energyConsensus.supportingPasses, [
    'grayscale',
    'moderate-contrast',
  ]);

  const fatConfusion = tsv([
    word(1, 1, 10, 10, 24, '肥'),
    word(1, 2, 36, 10, 24, '質'),
    word(1, 3, 220, 10, 48, '8g'),
  ]);
  const fatConfusionText = await diagnose(fatConfusion);
  assert.match(fatConfusionText, /脂質 8g/);
  const fatDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  assert.ok(fatDiagnostics.labelRecovery.some((item) =>
    item.field === 'fat' &&
    item.method === 'nutrition-label-confusion' &&
    item.status === 'RECOVERED_MEDIUM',
  ));
  const fatDecision = fatDiagnostics.confidenceDecisions
    .find((item) => item.field === 'fat');
  assert.equal(fatDecision.value, 8);
  assert.equal(fatDecision.unit, 'g');
  assert.equal(fatDecision.confidence, 'MEDIUM');
  assert.equal(fatDecision.decision, 'REVIEW_REQUIRED');

  const proteinLabelOnly = tsv([
    word(1, 1, 10, 10, 150, 'たんばぱく質'),
    word(2, 1, 10, 50, 140, 'たんぱく算'),
  ]);
  await diagnose(proteinLabelOnly);
  const proteinDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  assert.ok(proteinDiagnostics.labelRecovery.some((item) =>
    item.field === 'protein' && item.rawText === 'たんばぱく質',
  ));
  assert.ok(proteinDiagnostics.labelRecovery.some((item) =>
    item.field === 'protein' && item.rawText === 'たんぱく算',
  ));
  const proteinDecision = proteinDiagnostics.confidenceDecisions
    .find((item) => item.field === 'protein');
  assert.equal(proteinDecision.value, null);
  assert.equal(proteinDecision.decision, 'NOT_AVAILABLE');
  assert.ok(proteinDiagnostics.detectedLabels.some((item) =>
    item.field === 'protein' && item.detected === true &&
    item.matchedRawText === 'たんばぱく質',
  ));

  const carbohydratePass1 = tsv([
    word(1, 1, 10, 10, 110, '炭水化物'),
    word(1, 2, 300, 10, 24, '5'),
  ]);
  const carbohydratePass2 = tsv([
    word(1, 1, 10, 10, 110, '大水化物'),
    word(1, 2, 300, 10, 56, '23.5'),
  ]);
  const carbohydratePass3 = tsv([
    word(1, 1, 10, 10, 110, '大水化物'),
    word(1, 2, 300, 10, 64, '2@3.5'),
  ]);
  const carbohydrateText = await window.orAppFoodInput
    .diagnoseStructuredNutritionPassesForTesting([
      carbohydratePass1,
      carbohydratePass2,
      carbohydratePass3,
    ]);
  assert.doesNotMatch(carbohydrateText, /炭水化物 5/);
  const carbohydrateDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  const carbohydrateClusterDecision = carbohydrateDiagnostics.confidenceDecisions
    .find((item) => item.field === 'carbohydrate');
  assert.equal(carbohydrateClusterDecision.value, 23.5);
  assert.equal(carbohydrateClusterDecision.unit, null);
  assert.equal(carbohydrateClusterDecision.conflict, true);
  assert.equal(carbohydrateClusterDecision.decision, 'REVIEW_REQUIRED');
  assert.equal(carbohydrateClusterDecision.reviewRequired, true);
  assert.ok(carbohydrateClusterDecision.rawTokens.includes('23.5'));
  assert.ok(
    carbohydrateDiagnostics.numericCandidates.some((item) =>
      item.rawToken === '2@3.5' && item.numericValue === null &&
      /multiple-plausible/.test(item.ambiguity),
    ),
  );
  assert.ok(carbohydrateDiagnostics.conflicts
    .find((item) => item.field === 'carbohydrate')
    .conflictingCandidates.some((item) =>
      item.value === 5 && item.status === 'DOWNRANKED_SINGLE_PASS_OUTLIER',
    ));

  const substring = window.orAppFoodInput.recoverNumericTokenForDiagnostics(
    "'23.5手",
  );
  assert.equal(substring.numericValue, 23.5);
  assert.equal(substring.unit, null);
  assert.equal(substring.unitStatus, 'MISSING');
  assert.equal(substring.candidateType, 'NUMERIC_WITHOUT_UNIT');
  assert.equal(substring.recoveryMethod, 'safe-numeric-substring-unitless');
  const ambiguousNumeric = window.orAppFoodInput
    .recoverNumericTokenForDiagnostics('2@3.5');
  assert.equal(ambiguousNumeric.numericValue, null);
  assert.match(ambiguousNumeric.ambiguity, /multiple-plausible/);

  const passLocalOriginal = tsv([
    word(1, 1, 10, 10, 110, '炭水化物'),
    word(1, 2, 300, 10, 24, '5'),
  ]);
  const passLocalGrayscale = tsv([
    word(1, 1, 10, 10, 70, '糖質'),
    word(1, 2, 300, 10, 56, '23.4g'),
  ]);
  const passLocalFat = tsv([
    word(1, 1, 10, 10, 24, '肥'),
    word(1, 2, 36, 10, 24, '質'),
    word(1, 3, 220, 10, 48, '8g'),
  ]);
  await window.orAppFoodInput.diagnoseStructuredNutritionPassesForTesting([
    passLocalOriginal,
    passLocalGrayscale,
    passLocalFat,
  ]);
  const passLocalDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  const originalFive = passLocalDiagnostics.numericCandidates.find((item) =>
    item.rawToken === '5' && item.sourcePass === 'original',
  );
  assert.equal(originalFive.nearestLabel, 'carbohydrate');
  assert.equal(originalFive.nearestLabelSourcePass, 'original');
  const sugarOwnership = passLocalDiagnostics.fieldOwnership.find((item) =>
    item.rawToken === '23.4g',
  );
  assert.equal(sugarOwnership.ownerField, 'sugar');
  assert.equal(sugarOwnership.nearestLabelSourcePass, 'grayscale');

  const difficultOriginal = tsv([
    word(1, 1, 10, 10, 150, 'たんばぱく質'),
    word(2, 1, 10, 50, 110, '炭'),
    word(2, 2, 124, 50, 26, '水'),
    word(2, 3, 154, 50, 26, '化'),
    word(2, 4, 184, 50, 26, '物'),
    word(2, 5, 300, 50, 24, '5'),
    word(3, 1, 10, 90, 70, '糖質'),
    word(3, 2, 300, 90, 56, '23.28'),
  ]);
  const difficultGrayscale = tsv([
    word(1, 1, 10, 10, 120, 'ィネルギー'),
    word(1, 2, 300, 10, 70, '188'),
    word(1, 3, 374, 10, 54, 'kcal'),
    word(2, 1, 10, 50, 140, 'たんぱく算'),
    word(3, 1, 10, 90, 110, '大水化物'),
    word(3, 2, 300, 90, 64, "'23.5手"),
    word(4, 1, 10, 130, 70, '糖質'),
    word(4, 2, 300, 130, 56, '23.4g'),
  ]);
  const difficultModerate = tsv([
    word(1, 1, 10, 10, 120, 'ィネルギー'),
    word(1, 2, 300, 10, 70, '188'),
    word(1, 3, 374, 10, 54, 'kcal'),
    word(2, 1, 10, 50, 150, 'たんばぱく質'),
    word(3, 1, 10, 90, 24, '肥'),
    word(3, 2, 36, 90, 24, '質'),
    word(3, 3, 220, 90, 48, '8g'),
    word(4, 1, 10, 130, 110, '大水化物'),
    word(4, 2, 300, 130, 64, '2@3.5'),
    word(5, 1, 10, 170, 70, '糖質'),
    word(5, 2, 300, 170, 56, '23.4g'),
  ]);
  await window.orAppFoodInput.diagnoseStructuredNutritionPassesForTesting([
    difficultOriginal,
    difficultGrayscale,
    difficultModerate,
  ]);
  const difficultDiagnostics =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics;
  const difficultEnergy = difficultDiagnostics.confidenceDecisions
    .find((item) => item.field === 'energy');
  const difficultFat = difficultDiagnostics.confidenceDecisions
    .find((item) => item.field === 'fat');
  const difficultCarbohydrate = difficultDiagnostics.confidenceDecisions
    .find((item) => item.field === 'carbohydrate');
  assert.equal(difficultEnergy.value, 188);
  assert.equal(difficultEnergy.unit, 'kcal');
  assert.deepEqual(difficultEnergy.supportingPasses, [
    'grayscale',
    'moderate-contrast',
  ]);
  assert.equal(difficultEnergy.conflict, false);
  assert.equal(difficultEnergy.confidence, 'HIGH');
  assert.equal(difficultEnergy.decision, 'AUTO_FILL_ALLOWED');
  assert.equal(difficultFat.value, 8);
  assert.equal(difficultFat.unit, 'g');
  assert.equal(difficultFat.conflict, false);
  assert.equal(difficultFat.reviewRequired, true);
  assert.equal(difficultCarbohydrate.value, 23.5);
  assert.equal(difficultCarbohydrate.unit, null);
  assert.equal(difficultCarbohydrate.reviewRequired, true);
  assert.ok(difficultDiagnostics.labelRecovery.some((item) =>
    item.field === 'carbohydrate' &&
    item.rawText === '大水化物' &&
    item.method === 'nutrition-carbohydrate-label-confusion',
  ));
  assert.ok(difficultDiagnostics.labelRecovery.some((item) =>
    item.field === 'protein' && item.rawText === 'たんばぱく質',
  ));
  assert.ok(difficultDiagnostics.labelRecovery.some((item) =>
    item.field === 'protein' && item.rawText === 'たんぱく算',
  ));
  assert.ok(difficultDiagnostics.fieldOwnership.some((item) =>
    item.rawToken === "'23.5手" &&
    item.ownerField === 'carbohydrate' &&
    ['MAPPED', 'OWNED_REVIEW'].includes(item.ownershipStatus) &&
    item.conflictEligible === true,
  ));
  assert.ok(difficultDiagnostics.fieldOwnership.some((item) =>
    item.rawToken === '23.4g' && item.ownerField === 'sugar',
  ));
  assert.ok(difficultDiagnostics.numericCandidates.some((item) =>
    item.rawToken === '2@3.5' && item.numericValue === null,
  ));

  const consistentPass = tsv([
    word(1, 1, 10, 10, 120, 'エネルギー'),
    word(1, 2, 300, 10, 70, '188kcal'),
    word(2, 1, 10, 50, 140, 'たんぱく質'),
    word(2, 2, 300, 50, 50, '2.8g'),
    word(3, 1, 10, 90, 60, '脂質'),
    word(3, 2, 300, 90, 50, '9.2g'),
    word(4, 1, 10, 130, 110, '炭水化物'),
    word(4, 2, 300, 130, 60, '23.8g'),
  ]);
  await diagnose(consistentPass);
  const consistency =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .nutritionConsistency;
  assert.equal(consistency.evaluated, true);
  assert.equal(consistency.support, true);
  assert.equal(consistency.valueGenerated, false);

  const inconsistentPass = consistentPass.replace('188kcal', '818kcal');
  const inconsistentText = await diagnose(inconsistentPass);
  assert.match(inconsistentText, /エネルギー 818kcal/);
  assert.doesNotMatch(inconsistentText, /エネルギー 188kcal/);
  const inconsistency =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .nutritionConsistency;
  assert.equal(inconsistency.evaluated, true);
  assert.equal(inconsistency.support, false);
  assert.equal(inconsistency.valueGenerated, false);
  const suspiciousEnergy =
    window.orAppFoodInput.assetState().lastStructuredDiagnostics
      .confidenceDecisions.find((item) => item.field === 'energy');
  assert.equal(suspiciousEnergy.value, 818);
  assert.equal(suspiciousEnergy.confidence, 'MEDIUM');
  assert.equal(suspiciousEnergy.decision, 'REVIEW_REQUIRED');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
