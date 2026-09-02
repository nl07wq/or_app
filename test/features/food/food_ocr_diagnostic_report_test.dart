import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';
import 'package:or_app/features/food/services/food_ocr_diagnostic_report.dart';

void main() {
  test('classifies good raw tokens lost by structured mapping', () {
    expect(
      classifyFoodOcrBottleneck(
        inputObservable: true,
        inputAvailable: true,
        preprocessFailureEvidence: false,
        rawText: 'たんぱく質 7.3g',
        wordCount: 2,
        detectedLabelCount: 1,
        rawContainsSupportedLabel: true,
        numericCandidateCount: 1,
        mappingApplicable: true,
        mappedFieldCount: 0,
        parsedFieldCount: 1,
        formBindingExecuted: false,
        formBindingMatches: true,
      ),
      FoodOcrBottleneck.mapping,
    );
  });

  test('classifies absent engine text as raw OCR loss', () {
    expect(
      classifyFoodOcrBottleneck(
        inputObservable: true,
        inputAvailable: true,
        preprocessFailureEvidence: false,
        rawText: '',
        wordCount: 0,
        detectedLabelCount: 0,
        rawContainsSupportedLabel: false,
        numericCandidateCount: 0,
        mappingApplicable: true,
        mappedFieldCount: 0,
        parsedFieldCount: 0,
        formBindingExecuted: false,
        formBindingMatches: true,
      ),
      FoodOcrBottleneck.rawOcr,
    );
  });

  test('classifies parsed values lost during binding', () {
    expect(
      classifyFoodOcrBottleneck(
        inputObservable: true,
        inputAvailable: true,
        preprocessFailureEvidence: false,
        rawText: '熱量 80kcal',
        wordCount: 2,
        detectedLabelCount: 1,
        rawContainsSupportedLabel: true,
        numericCandidateCount: 1,
        mappingApplicable: true,
        mappedFieldCount: 1,
        parsedFieldCount: 1,
        formBindingExecuted: true,
        formBindingMatches: false,
      ),
      FoodOcrBottleneck.formBinding,
    );
  });

  test('keeps insufficient evidence unknown', () {
    expect(
      classifyFoodOcrBottleneck(
        inputObservable: false,
        inputAvailable: false,
        preprocessFailureEvidence: false,
        rawText: '',
        wordCount: 0,
        detectedLabelCount: 0,
        rawContainsSupportedLabel: false,
        numericCandidateCount: 0,
        mappingApplicable: true,
        mappedFieldCount: 0,
        parsedFieldCount: 0,
        formBindingExecuted: false,
        formBindingMatches: true,
      ),
      FoodOcrBottleneck.unknown,
    );
  });

  test('formats compact copy diagnostics without image bytes', () {
    final report = enrichFoodOcrDiagnosticReport(
      _fixtureReport(),
      source: FoodImageSource.gallery,
    );
    final text = formatFoodOcrDiagnosticReport(report);

    expect(report['sourceType'], 'photoLibrary');
    expect(text, contains('STANDARD OCR'));
    expect(text, contains('NUTRITION LABEL READER'));
    expect(text, contains('PASS RAW OCR'));
    expect(text, contains('RAW OCR:'));
    expect(text, contains('artifactId: nutrition-test'));
    expect(text, contains('AUTO NUTRITION CROP'));
    expect(text, contains('status=APPLIED'));
    expect(text, contains('FORM BINDING'));
    expect(text, contains('NOT EXECUTED'));
    expect(text, contains('COMPARISON SUMMARY'));
    expect(text, isNot(contains('TOKEN RECOVERY')));
    expect(text, isNot(contains('RAW TOKENS')));
    expect(text, isNot(contains('data:image/png;base64')));

    final full = formatFullFoodOcrDiagnosticReport(report);
    expect(full, contains('TOKEN RECOVERY'));
    expect(full, contains('NUMERIC RECOVERY'));
    expect(full, contains('GEOMETRY MAPPING'));
  });

  test(
    'keeps high decisions typed and lower decisions in the review bridge',
    () {
      final report = enrichFoodOcrDiagnosticReport(
        _fixtureReportWithDecisions(),
        source: FoodImageSource.gallery,
      );
      final nutrition = (report['nutritionLabelReader'] as Map)
          .cast<String, dynamic>();
      final result = (nutrition['finalResult'] as Map).cast<String, dynamic>();
      final handoff = (nutrition['parserDiagnostics'] as List)
          .cast<Map>()
          .firstWhere((item) => item['field'] == 'calories');
      final review = (nutrition['reviewCandidates'] as List).cast<Map>();

      expect(result['calories'], 188);
      expect(
        (result['fieldSources'] as Map)['calories'],
        'STRUCTURED_DECISION',
      );
      expect(handoff['bridgeStatus'], 'ACCEPTED_STRUCTURED');
      expect(result['protein'], isNull);
      expect(result['fat'], isNull);
      expect(result['carbohydrate'], isNull);
      expect((result['fieldSources'] as Map)['fat'], 'REVIEW_ONLY');
      expect((result['fieldSources'] as Map)['carbohydrate'], 'REVIEW_ONLY');
      expect((result['fieldSources'] as Map)['protein'], 'NOT_AVAILABLE');
      final fat = review.firstWhere((item) => item['field'] == 'FAT');
      final carbohydrate = review.firstWhere(
        (item) => item['field'] == 'CARBOHYDRATE',
      );
      expect(fat['candidateValue'], 8);
      expect(fat['reviewBridgeStatus'], 'RETAINED_FOR_REVIEW');
      expect(carbohydrate['candidateValue'], 23.5);
      expect(carbohydrate['candidateUnit'], isNull);
      expect(carbohydrate['reviewBridgeStatus'], 'RETAINED_FOR_REVIEW');
    },
  );

  test('keeps compact field, refinement and fallback safety evidence', () {
    final report = enrichFoodOcrDiagnosticReport(
      _fixtureReportWithDecisions(),
      source: FoodImageSource.gallery,
    );
    final nutrition = (report['nutritionLabelReader'] as Map)
        .cast<String, dynamic>();
    nutrition['localRefinementAttempts'] = [
      {
        'targetField': 'fat',
        'regionType': 'LABEL_RIGHT_VALUE',
        'triggerReason': 'cross-pass-conflict',
        'cropRect': {'x': 12, 'y': 24, 'width': 56, 'height': 30},
        'ocrInputDimensions': {'width': 224, 'height': 120},
        'preprocessing': {'grayscale': true, 'pageSegmentationMode': 7},
        'rawOcrText': '04g',
        'numericValue': 4,
        'unit': 'g',
        'unitStatus': 'EXACT',
        'rowOwnership': 'SAME_TARGET_ROW',
        'status': 'REVIEW_ONLY',
        'reason': 'cross-pass-conflict',
      },
    ];
    final review = (nutrition['reviewCandidates'] as List).cast<Map>();
    review.firstWhere(
      (item) => item['field'] == 'FAT',
    )['legacyFallbackSafety'] = {
      'field': 'fat',
      'legacyCandidateValue': 4,
      'fallbackStatus': 'SUPPRESSED',
      'suppressionReason': 'structured-field-review-required',
    };

    final text = formatFoodOcrDiagnosticReport(report);
    expect(text, contains('FIELD: FAT'));
    expect(text, contains('LOCAL OCR REFINEMENT'));
    expect(text, contains('rawOCR="04g"'));
    expect(text, contains('ownership=SAME_TARGET_ROW'));
    expect(text, contains('LEGACY FALLBACK'));
    expect(text, contains('status=SUPPRESSED'));
    expect(text, isNot(contains('ownershipEvidence')));
  });

  test('compact copy excludes repeated token-level debug payloads', () {
    final report = enrichFoodOcrDiagnosticReport(
      _fixtureReport(),
      source: FoodImageSource.gallery,
    );
    for (final key in ['standard', 'nutritionLabelReader']) {
      final branch = (report[key] as Map).cast<String, dynamic>();
      branch['words'] = List.generate(
        200,
        (index) => {
          'text': 'token-$index',
          'left': index * 10,
          'top': index * 5,
          'lineKey': 'line-$index',
          'confidence': 95,
        },
      );
    }

    final compact = formatFoodOcrDiagnosticReport(report);
    final full = formatFullFoodOcrDiagnosticReport(report);
    expect(compact.length, lessThan(full.length * 0.3));
    expect(compact, isNot(contains('token-199')));
    expect(full, contains('token-199'));
  });
}

Map<String, dynamic> _fixtureReport() => {
  'diagnosticVersion': 1,
  'generatedAt': '2026-09-01T00:00:00Z',
  'persistence': 'none',
  'standard': _branch('STANDARD OCR'),
  'nutritionLabelReader': _branch('NUTRITION LABEL READER'),
  'comparison': {'sameRawOcr': true},
};

Map<String, dynamic> _fixtureReportWithDecisions() {
  const decisions = [
    {
      'field': 'energy',
      'value': 188,
      'unit': 'kcal',
      'confidence': 'HIGH',
      'reviewRequired': false,
      'conflict': false,
      'decision': 'AUTO_FILL_ALLOWED',
    },
    {
      'field': 'fat',
      'value': 8,
      'unit': 'g',
      'confidence': 'MEDIUM',
      'reviewRequired': true,
      'conflict': true,
      'decision': 'REVIEW_REQUIRED',
    },
    {
      'field': 'carbohydrate',
      'value': 23.5,
      'unit': null,
      'unitStatus': 'MISSING',
      'confidence': 'MEDIUM',
      'reviewRequired': true,
      'conflict': true,
      'decision': 'REVIEW_REQUIRED',
      'rawTokens': ['5', "'23.5手", '2@3.5'],
      'ownershipEvidence': {
        'ownershipStatus': 'OWNED_REVIEW',
        'conflictEligible': true,
      },
    },
    {
      'field': 'protein',
      'value': null,
      'unit': null,
      'confidence': 'NONE',
      'reviewRequired': true,
      'conflict': false,
      'decision': 'NOT_AVAILABLE',
      'labelEvidence': {
        'field': 'protein',
        'status': 'RECOVERED_HIGH',
        'recoveryMethod': 'nutrition-protein-label-confusion',
      },
    },
  ];
  final report = _fixtureReport();
  for (final key in ['standard', 'nutritionLabelReader']) {
    final branch = report[key] as Map<String, dynamic>;
    branch['rawText'] = 'raw OCR remains separate from structured decisions';
    branch['confidenceDecisions'] = decisions;
  }
  return report;
}

Map<String, dynamic> _branch(String mode) => {
  'scanMode': mode,
  'engineId': 'tesseract',
  'sourceDimensions': {'width': 1200, 'height': 800},
  'orientation': {'exif': 1, 'appliedByDecoder': true},
  'cropApplied': true,
  'cropRect': {'x': 48, 'y': 80, 'width': 1104, 'height': 640},
  'autoNutritionCrop': {
    'status': 'APPLIED',
    'rect': {'x': 96, 'y': 120, 'width': 800, 'height': 420},
    'reason': 'nutrition-header+row-cluster',
  },
  'resizeApplied': false,
  'resizeMethod': 'none',
  'resizeScale': 1,
  'preResizeDimensions': {'width': 1104, 'height': 640},
  'ocrDimensions': {'width': 1104, 'height': 640},
  'sharedOcrArtifact': {
    'artifactId': 'nutrition-test',
    'generatedOnce': true,
    'consumerModes': ['STANDARD', 'NUTRITION'],
    'passCount': 3,
  },
  'rotationCorrection': 'NOT REQUIRED',
  'perspectiveCorrection': 'NOT APPLIED',
  'inputPreviewDataUrl': 'data:image/png;base64,AA==',
  'rawText': '熱量 80kcal',
  'wordCount': 2,
  'passes': [
    {
      'preprocessVariant': 'original',
      'size': {'width': 1104, 'height': 640},
      'parameters': {'jpegQuality': 0.94},
      'rawText': '熱量 80kcal',
    },
  ],
  'words': [
    {'text': '熱量', 'confidence': 90},
    {'text': '80kcal', 'confidence': 88},
  ],
  'detectedLabels': [
    {'field': 'energy', 'detected': true, 'matchedRawText': '熱量'},
  ],
  'numericCandidates': [
    {'rawToken': '80kcal', 'normalizedToken': '80kcal'},
  ],
  'structuredCandidates': [
    {'field': 'energy', 'candidateCount': 1, 'accepted': true},
  ],
  'selectedMappings': {'energy': 80},
  'fallbackUsed': false,
  'fallbackReason': null,
};
