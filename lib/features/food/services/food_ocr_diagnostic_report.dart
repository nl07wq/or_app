import 'dart:convert';

import 'food_input_capture_gateway.dart';
import 'food_live_capture_presenter.dart';

enum FoodOcrBottleneck {
  input,
  preprocess,
  rawOcr,
  labelDetection,
  numericExtraction,
  mapping,
  parser,
  formBinding,
  multiple,
  unknown,
}

extension FoodOcrBottleneckPresentation on FoodOcrBottleneck {
  String get diagnosticValue => switch (this) {
    FoodOcrBottleneck.input => 'INPUT',
    FoodOcrBottleneck.preprocess => 'PREPROCESS',
    FoodOcrBottleneck.rawOcr => 'RAW_OCR',
    FoodOcrBottleneck.labelDetection => 'LABEL_DETECTION',
    FoodOcrBottleneck.numericExtraction => 'NUMERIC_EXTRACTION',
    FoodOcrBottleneck.mapping => 'MAPPING',
    FoodOcrBottleneck.parser => 'PARSER',
    FoodOcrBottleneck.formBinding => 'FORM_BINDING',
    FoodOcrBottleneck.multiple => 'MULTIPLE',
    FoodOcrBottleneck.unknown => 'UNKNOWN',
  };
}

FoodOcrBottleneck classifyFoodOcrBottleneck({
  required bool inputObservable,
  required bool inputAvailable,
  required bool preprocessFailureEvidence,
  required String rawText,
  required int wordCount,
  bool labelDetectionApplicable = true,
  required int detectedLabelCount,
  required bool rawContainsSupportedLabel,
  bool numericExtractionApplicable = true,
  required int numericCandidateCount,
  required bool mappingApplicable,
  required int mappedFieldCount,
  required int parsedFieldCount,
  required bool formBindingExecuted,
  required bool formBindingMatches,
}) {
  if (!inputObservable) return FoodOcrBottleneck.unknown;
  if (!inputAvailable) return FoodOcrBottleneck.input;
  if (preprocessFailureEvidence) return FoodOcrBottleneck.preprocess;
  if (rawText.trim().isEmpty || wordCount == 0) {
    return FoodOcrBottleneck.rawOcr;
  }
  if (labelDetectionApplicable && detectedLabelCount == 0) {
    return rawContainsSupportedLabel
        ? FoodOcrBottleneck.labelDetection
        : FoodOcrBottleneck.rawOcr;
  }
  if (numericExtractionApplicable && numericCandidateCount == 0) {
    return FoodOcrBottleneck.numericExtraction;
  }
  if (mappingApplicable && mappedFieldCount == 0) {
    return FoodOcrBottleneck.mapping;
  }
  if (!labelDetectionApplicable &&
      parsedFieldCount == 0 &&
      !rawContainsSupportedLabel) {
    return FoodOcrBottleneck.rawOcr;
  }
  if (parsedFieldCount == 0) return FoodOcrBottleneck.parser;
  if (formBindingExecuted && !formBindingMatches) {
    return FoodOcrBottleneck.formBinding;
  }
  return FoodOcrBottleneck.unknown;
}

Map<String, dynamic> enrichFoodOcrDiagnosticReport(
  Map<String, dynamic> report, {
  required FoodImageSource source,
}) {
  report['sourceType'] = source == FoodImageSource.camera
      ? 'cameraStill'
      : 'photoLibrary';
  final classifications = <FoodOcrBottleneck>[];
  for (final entry in const [
    ('standard', false),
    ('nutritionLabelReader', true),
  ]) {
    final value = report[entry.$1];
    if (value is! Map) continue;
    final branch = value.cast<String, dynamic>();
    final rawText = branch['rawText'] as String? ?? '';
    final session = FoodNutritionCandidateSession();
    for (final pass in rawText.split('\u001e')) {
      if (pass.trim().isNotEmpty) session.describe(pass);
    }
    final structuredDecisionInput = _structuredDecisionInput(branch);
    if (structuredDecisionInput.isNotEmpty) {
      session.describe(structuredDecisionInput);
    }
    final draft = session.draft;
    final decisions = session.fieldDecisions;
    final finalResult = <String, dynamic>{
      'basis': draft.basisQuantity == null
          ? null
          : {'value': draft.basisQuantity, 'unit': draft.basisUnit?.name},
      'calories': draft.calories,
      'protein': draft.protein,
      'fat': draft.fat,
      'carbohydrate': draft.carbohydrate,
      'fieldSources': {
        'calories': _finalFieldSource(decisions['ENERGY']),
        'protein': _finalFieldSource(decisions['PROTEIN']),
        'fat': _finalFieldSource(decisions['FAT']),
        'carbohydrate': _finalFieldSource(decisions['CARBOHYDRATE']),
      },
    };
    finalResult['needsReviewFields'] = [
      if (draft.basisQuantity == null) 'basis',
      if (draft.calories == null) 'calories',
      if (draft.protein == null) 'protein',
      if (draft.fat == null) 'fat',
      if (draft.carbohydrate == null) 'carbohydrate',
    ];
    branch['finalResult'] = finalResult;
    branch['parserDiagnostics'] = _parserDiagnostics(
      branch,
      finalResult,
      session.candidateSources,
      decisions,
    );
    branch['reviewCandidates'] = decisions.entries
        .where((entry) => entry.value['bridgeStatus'] != 'ACCEPTED_STRUCTURED')
        .map(
          (entry) => <String, dynamic>{
            'field': entry.key,
            'candidateValue': entry.value['value'],
            'candidateUnit': entry.value['unit'],
            'unitStatus': entry.value['unitStatus'],
            'confidence': entry.value['confidence'],
            'conflict': entry.value['conflict'],
            'reviewRequired': entry.value['reviewRequired'],
            'decision': entry.value['decision'],
            'sourcePasses': entry.value['supportingPasses'],
            'rawTokens': entry.value['rawTokens'],
            'labelEvidence': entry.value['labelEvidence'],
            'consensusStatus': entry.value['consensusStatus'],
            'decisionReason': entry.value['decisionReason'],
            'selectedEvidence': entry.value['selectedEvidence'],
            'ownershipEvidence': entry.value['ownershipEvidence'],
            'legacyFallbackSafety': entry.value['legacyFallbackSafety'],
            'reviewBridgeStatus':
                entry.value['bridgeStatus'] ?? 'RETAINED_FOR_REVIEW',
          },
        )
        .toList(growable: false);
    branch['formBinding'] = {
      'status': 'NOT EXECUTED',
      'reason':
          'Diagnostic mode is read-only and does not apply OCR values to the Food form.',
      'observable': false,
    };
    final labels = _list(branch['detectedLabels']);
    final mapped = _map(branch['selectedMappings']);
    final parsedCount = const [
      'calories',
      'protein',
      'fat',
      'carbohydrate',
    ].where((field) => finalResult[field] != null).length;
    final classification = classifyFoodOcrBottleneck(
      inputObservable: branch['inputPreviewDataUrl'] is String,
      inputAvailable: _dimensionAvailable(branch['ocrDimensions']),
      preprocessFailureEvidence: false,
      rawText: rawText,
      wordCount: _int(branch['wordCount']),
      labelDetectionApplicable: entry.$2,
      detectedLabelCount: labels
          .where((item) => _map(item)['detected'] == true)
          .length,
      rawContainsSupportedLabel: _containsSupportedLabel(rawText),
      numericExtractionApplicable: entry.$2,
      numericCandidateCount: _list(branch['numericCandidates']).length,
      mappingApplicable: entry.$2,
      mappedFieldCount: mapped.length,
      parsedFieldCount: parsedCount,
      formBindingExecuted: false,
      formBindingMatches: true,
    );
    branch['bottleneckClassification'] = classification.diagnosticValue;
    classifications.add(classification);
    branch['summary'] = {
      'labelsDetected': labels
          .where((item) => _map(item)['detected'] == true)
          .length,
      'numericValuesDetected': _list(branch['numericCandidates']).length,
      'mappedFields': mapped.length,
      'parsedFields': parsedCount,
      'formFieldsPopulated': 'NOT OBSERVABLE',
    };
  }
  final significant = classifications
      .where((value) => value != FoodOcrBottleneck.unknown)
      .toSet();
  report['rootCauseClassification'] = {
    'primary': significant.isEmpty
        ? FoodOcrBottleneck.unknown.diagnosticValue
        : significant.length == 1
        ? significant.single.diagnosticValue
        : FoodOcrBottleneck.multiple.diagnosticValue,
    'standard': _map(report['standard'])['bottleneckClassification'],
    'nutrition': _map(
      report['nutritionLabelReader'],
    )['bottleneckClassification'],
    'certainty': 'EVIDENCE-BASED; inspect OCR input preview before concluding',
  };
  final standard = _map(report['standard']);
  final nutrition = _map(report['nutritionLabelReader']);
  final comparison = _map(report['comparison'])
    ..addAll({
      'inputDifference':
          _sameValues(standard, nutrition, const [
            'cropRect',
            'ocrDimensions',
            'rotationCorrection',
          ])
          ? 'NONE'
          : 'DIFFERENT',
      'rawOcrDifference': standard['rawText'] == nutrition['rawText']
          ? 'NONE'
          : 'DIFFERENT',
      'labelDetectionDifference':
          '${_list(standard['detectedLabels']).length} vs '
          '${_list(nutrition['detectedLabels']).length}',
      'mappingDifference':
          '${_map(standard['selectedMappings']).length} vs '
          '${_map(nutrition['selectedMappings']).length}',
      'parserDifference':
          '${_map(standard['finalResult'])} vs '
          '${_map(nutrition['finalResult'])}',
      'formBindingDifference': 'NOT OBSERVABLE (diagnostic mode is read-only)',
    });
  report['comparison'] = comparison;
  return report;
}

/// Produces the compact, copy-friendly diagnostic used by the scanner UI.
///
/// The complete evidence remains in [report] and can be rendered with
/// [formatFullFoodOcrDiagnosticReport] when a developer needs token-level
/// debugging. Keeping the default output field-centred avoids repeating the
/// same token, geometry and ownership objects in several sections.
String formatFoodOcrDiagnosticReport(Map<String, dynamic> report) {
  final out = StringBuffer()
    ..writeln('OCR PIPELINE DIAGNOSTICS')
    ..writeln('diagnosticVersion: ${_text(report['diagnosticVersion'])}')
    ..writeln('generatedAt: ${_text(report['generatedAt'])}')
    ..writeln('sourceType: ${_text(report['sourceType'])}')
    ..writeln('persistence: ${_text(report['persistence'])}');
  final comparison = _map(report['comparison']);
  _writeCompactMode(out, 'STANDARD OCR', _map(report['standard']));
  _writeCompactMode(
    out,
    'NUTRITION LABEL READER',
    _map(report['nutritionLabelReader']),
    includePassRaw: comparison['sameRawOcr'] != true,
  );
  out
    ..writeln('\n==============================')
    ..writeln('COMPARISON SUMMARY')
    ..writeln('==============================')
    ..writeln('sameRawOcr: ${_text(comparison['sameRawOcr'])}')
    ..writeln('sameInput: ${_text(comparison['sameInput'])}')
    ..writeln('sharedArtifact: ${_text(comparison['sharedArtifact'])}')
    ..writeln('standard: ${_compactComparison(_map(report['standard']))}')
    ..writeln(
      'nutrition: ${_compactComparison(_map(report['nutritionLabelReader']))}',
    )
    ..writeln('bottleneck: ${_lines(_map(report['rootCauseClassification']))}');
  return out.toString().trimRight();
}

/// Full developer-only rendering. This intentionally retains the detailed
/// token, geometry and parser objects for an on-demand debugging surface.
String formatFullFoodOcrDiagnosticReport(Map<String, dynamic> report) {
  final out = StringBuffer()
    ..writeln('OCR PIPELINE DIAGNOSTICS')
    ..writeln('diagnosticVersion: ${_text(report['diagnosticVersion'])}')
    ..writeln('generatedAt: ${_text(report['generatedAt'])}')
    ..writeln('sourceType: ${_text(report['sourceType'])}')
    ..writeln('persistence: ${_text(report['persistence'])}');
  _writeMode(out, 'STANDARD OCR', _map(report['standard']));
  _writeMode(
    out,
    'NUTRITION LABEL READER',
    _map(report['nutritionLabelReader']),
  );
  out
    ..writeln('\n==============================')
    ..writeln('COMPARISON SUMMARY')
    ..writeln('==============================')
    ..writeln(_lines(_map(report['comparison'])))
    ..writeln('bottleneck: ${_lines(_map(report['rootCauseClassification']))}');
  return out.toString().trimRight();
}

void _writeCompactMode(
  StringBuffer out,
  String title,
  Map<String, dynamic> branch, {
  bool includePassRaw = true,
}) {
  out
    ..writeln('\n==============================')
    ..writeln(title)
    ..writeln('==============================')
    ..writeln('scanMode: ${_text(branch['scanMode'])}')
    ..writeln('engine: ${_text(branch['engineId'])}')
    ..writeln('sourceDimensions: ${_lines(_map(branch['sourceDimensions']))}')
    ..writeln('processedSize: ${_lines(_map(branch['ocrDimensions']))}')
    ..writeln('cropApplied: ${_text(branch['cropApplied'])}')
    ..writeln('cropRect: ${_lines(_map(branch['cropRect']))}')
    ..writeln('rotationCorrection: ${_text(branch['rotationCorrection'])}')
    ..writeln(
      'perspectiveCorrection: ${_text(branch['perspectiveCorrection'])}',
    );
  final autoCrop = _map(branch['autoNutritionCrop']);
  out
    ..writeln('AUTO NUTRITION CROP')
    ..writeln('status=${_text(autoCrop['status'])}')
    ..writeln('rect=${_lines(_map(autoCrop['rect']))}')
    ..writeln('reason=${_text(autoCrop['reason'])}');
  final artifact = _map(branch['sharedOcrArtifact']);
  out
    ..writeln('artifactId: ${_text(artifact['artifactId'])}')
    ..writeln('sharedArtifact: ${_text(artifact['generatedOnce'])}')
    ..writeln('passCount: ${_text(artifact['passCount'])}')
    ..writeln('\nPASS RAW OCR');
  final passes = _list(branch['passes']);
  if (!includePassRaw) {
    out.writeln('SHARED ARTIFACT (listed under STANDARD OCR)');
  } else if (passes.isEmpty) {
    out.writeln('NOT AVAILABLE');
  } else {
    for (var index = 0; index < passes.length; index += 1) {
      final pass = _map(passes[index]);
      out
        ..writeln('PASS ${index + 1}: ${_text(pass['preprocessVariant'])}')
        ..writeln('RAW OCR:')
        ..writeln((pass['rawText'] as String?)?.trimRight() ?? '');
    }
  }
  _writeCompactFields(out, branch);
  _writeCompactRefinement(out, branch);
  _writeCompactLegacyFallback(out, branch);
  final finalResult = _map(branch['finalResult']);
  out
    ..writeln('\nFINAL OCR RESULT')
    ..writeln('basis=${_compactValue(finalResult['basis'])}')
    ..writeln('calories=${_text(finalResult['calories'])}')
    ..writeln('protein=${_text(finalResult['protein'])}')
    ..writeln('fat=${_text(finalResult['fat'])}')
    ..writeln('carbohydrate=${_text(finalResult['carbohydrate'])}')
    ..writeln('fieldSources=${_lines(_map(finalResult['fieldSources']))}')
    ..writeln('needsReviewFields=${_text(finalResult['needsReviewFields'])}')
    ..writeln('\nFORM BINDING')
    ..writeln('status=${_text(_map(branch['formBinding'])['status'])}')
    ..writeln('reason=${_text(_map(branch['formBinding'])['reason'])}')
    ..writeln('\nSUMMARY')
    ..writeln(_lines(_map(branch['summary'])))
    ..writeln(
      'localRefinementRuns=${_list(branch['localRefinementAttempts']).length}',
    )
    ..writeln('autoFillFields=${_compactAutoFillFields(branch)}')
    ..writeln('reviewRequiredFields=${_compactReviewFields(branch)}')
    ..writeln(
      'firstLossClassification=${_text(branch['bottleneckClassification'])}',
    );
}

void _writeCompactFields(StringBuffer out, Map<String, dynamic> branch) {
  final decisions = _list(branch['confidenceDecisions'])
      .map(_map)
      .where((decision) => decision['field'] != null)
      .toList(growable: false);
  if (decisions.isEmpty) return;
  out.writeln('\nSTRUCTURED EVIDENCE SUMMARY');
  for (final decision in decisions) {
    final field = _text(decision['field']).toUpperCase();
    final label = _map(decision['labelEvidence']);
    final selected = _map(decision['selectedEvidence']);
    final rawTokens = _list(decision['rawTokens']);
    out
      ..writeln('\nFIELD: $field')
      ..writeln('LABEL: ${_compactLabel(label, decision['labelStatus'])}')
      ..writeln(
        'VALUE: ${_compactDecisionValue(decision, selected, rawTokens)}',
      )
      ..writeln(
        'CONSENSUS: status=${_text(decision['consensusStatus'])}, '
        'supportingPasses=${_text(decision['supportingPasses'])}, '
        'conflict=${_text(decision['conflict'])}',
      )
      ..writeln(
        'FINAL DECISION: status=${_text(decision['decision'])}, '
        'confidence=${_text(decision['confidence'])}, '
        'reviewRequired=${_text(decision['reviewRequired'])}, '
        'reason=${_text(decision['decisionReason'])}',
      );
  }
}

void _writeCompactRefinement(StringBuffer out, Map<String, dynamic> branch) {
  final attempts = _list(branch['localRefinementAttempts']).map(_map).toList();
  if (attempts.isEmpty) return;
  out.writeln('\nLOCAL OCR REFINEMENT');
  for (final attempt in attempts) {
    out
      ..writeln(
        '- targetField=${_text(attempt['targetField'])}, '
        'regionType=${_text(attempt['regionType'])}, '
        'triggerReason=${_text(attempt['triggerReason'])}',
      )
      ..writeln(
        '  cropRect=${_lines(_map(attempt['cropRect']))}, '
        'processedDimensions=${_lines(_map(attempt['ocrInputDimensions']))}, '
        'preprocessing=${_lines(_map(attempt['preprocessing']))}',
      )
      ..writeln('  rawOCR=${_quoted(attempt['rawOcrText'])}')
      ..writeln(
        '  candidate=${_compactCandidate(attempt)}, '
        'ownership=${_text(attempt['rowOwnership'])}, '
        'result=${_text(attempt['resultStatus'] ?? attempt['status'])}, '
        'reason=${_text(attempt['rejectionReason'] ?? attempt['reason'])}',
      );
  }
}

void _writeCompactLegacyFallback(
  StringBuffer out,
  Map<String, dynamic> branch,
) {
  final review = _list(branch['reviewCandidates']).map(_map);
  final safety = review
      .map((candidate) => _map(candidate['legacyFallbackSafety']))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (safety.isEmpty) return;
  out.writeln('\nLEGACY FALLBACK');
  for (final item in safety) {
    out.writeln(
      'field=${_text(item['field'])}, candidate=${_text(item['legacyCandidateValue'])}, '
      'status=${_text(item['fallbackStatus'] ?? item['status'])}, '
      'reason=${_text(item['suppressionReason'] ?? item['reason'])}',
    );
  }
}

String _compactDecisionValue(
  Map<String, dynamic> decision,
  Map<String, dynamic> selected,
  List<dynamic> rawTokens,
) {
  final value = decision['value'] ?? selected['value'];
  final unit = decision['unit'] ?? selected['unit'];
  final source = selected['sourcePass'] ?? decision['source'];
  final raw = rawTokens.isEmpty ? selected['rawToken'] : rawTokens.join(' | ');
  return 'value=${_text(value)}, unit=${_text(unit)}, '
      'unitStatus=${_text(decision['unitStatus'] ?? selected['unitStatus'])}, '
      'source=${_text(source)}, raw=${_quoted(raw)}';
}

String _compactLabel(Map<String, dynamic> label, Object? fallbackStatus) {
  if (label.isEmpty) return 'NOT AVAILABLE';
  return 'raw=${_quoted(label['rawText'] ?? label['matchedRawText'])}, '
      'candidate=${_text(label['candidate'] ?? label['field'])}, '
      'status=${_text(label['status'] ?? fallbackStatus)}, '
      'method=${_text(label['recoveryMethod'])}';
}

String _compactCandidate(Map<String, dynamic> attempt) =>
    'value=${_text(attempt['numericValue'])}, unit=${_text(attempt['unit'])}, '
    'unitStatus=${_text(attempt['unitStatus'])}';

String _compactValue(Object? value) {
  final map = _map(value);
  return map.isEmpty
      ? _text(value)
      : '${_text(map['value'])} ${_text(map['unit'])}';
}

String _compactAutoFillFields(Map<String, dynamic> branch) =>
    _list(branch['confidenceDecisions'])
        .map(_map)
        .where((item) => item['decision'] == 'AUTO_FILL_ALLOWED')
        .map((item) => _text(item['field']))
        .join(', ')
        .letOrNone();

String _compactReviewFields(Map<String, dynamic> branch) => _list(
  branch['reviewCandidates'],
).map(_map).map((item) => _text(item['field'])).join(', ').letOrNone();

String _compactComparison(Map<String, dynamic> branch) {
  final summary = _map(branch['summary']);
  return 'labelsDetected=${_text(summary['labelsDetected'])}, '
      'numericEvidence=${_text(summary['numericValuesDetected'])}, '
      'mappedFields=${_text(summary['mappedFields'])}, '
      'parsedFields=${_text(summary['parsedFields'])}, '
      'localRefinementRuns=${_list(branch['localRefinementAttempts']).length}';
}

String _quoted(Object? value) => '"${_text(value)}"';

extension on String {
  String letOrNone() => isEmpty ? 'NONE' : this;
}

void _writeMode(StringBuffer out, String title, Map<String, dynamic> branch) {
  out
    ..writeln('\n==============================')
    ..writeln(title)
    ..writeln('==============================')
    ..writeln('\nSOURCE')
    ..writeln('scanMode: ${_text(branch['scanMode'])}')
    ..writeln('engine: ${_text(branch['engineId'])}')
    ..writeln('sourceDimensions: ${_lines(_map(branch['sourceDimensions']))}')
    ..writeln('orientation: ${_lines(_map(branch['orientation']))}')
    ..writeln('\nINPUT TRANSFORM')
    ..writeln('cropApplied: ${_text(branch['cropApplied'])}')
    ..writeln('cropRect: ${_lines(_map(branch['cropRect']))}')
    ..writeln('preResizeSize: ${_lines(_map(branch['preResizeDimensions']))}')
    ..writeln('resizeApplied: ${_text(branch['resizeApplied'])}')
    ..writeln('resizeMethod: ${_text(branch['resizeMethod'])}')
    ..writeln('resizeScale: ${_text(branch['resizeScale'])}')
    ..writeln('processedSize: ${_lines(_map(branch['ocrDimensions']))}')
    ..writeln('rotationCorrection: ${_text(branch['rotationCorrection'])}')
    ..writeln(
      'perspectiveCorrection: ${_text(branch['perspectiveCorrection'])}',
    )
    ..writeln('\nSHARED OCR ARTIFACT')
    ..writeln(_lines(_map(branch['sharedOcrArtifact'])))
    ..writeln('\nPREPROCESS');
  final passes = _list(branch['passes']);
  if (passes.isEmpty) {
    out.writeln('NOT OBSERVABLE');
  } else {
    for (var index = 0; index < passes.length; index += 1) {
      final pass = _map(passes[index]);
      out
        ..writeln('PASS ${index + 1}: ${_text(pass['preprocessVariant'])}')
        ..writeln('size: ${_lines(_map(pass['size']))}')
        ..writeln('parameters: ${_lines(_map(pass['parameters']))}')
        ..writeln('RAW OCR:')
        ..writeln((pass['rawText'] as String?)?.trimRight() ?? '');
    }
  }
  out
    ..writeln('\nRAW TOKENS')
    ..writeln(_items(branch['words']))
    ..writeln('\nTOKEN RECOVERY')
    ..writeln(_items(branch['tokenRecovery']))
    ..writeln('\nLABEL DETECTION')
    ..writeln(_items(branch['detectedLabels']))
    ..writeln('\nLABEL RECOVERY')
    ..writeln(_items(branch['labelRecovery']))
    ..writeln('\nNUMERIC CANDIDATES')
    ..writeln(_items(branch['numericCandidates']))
    ..writeln('\nNUMERIC RECOVERY')
    ..writeln(_items(branch['numericRecovery']))
    ..writeln('\nSEMANTIC DUPLICATE COLLAPSE')
    ..writeln(_items(branch['semanticDuplicateCollapse']))
    ..writeln('\nPRE-MAPPING EVIDENCE')
    ..writeln(_items(branch['preMappingEvidence']))
    ..writeln('\nFIELD OWNERSHIP')
    ..writeln(_items(branch['fieldOwnership']))
    ..writeln('\nLOCAL OCR REFINEMENT')
    ..writeln(_items(branch['localRefinementAttempts']))
    ..writeln('summary: ${_lines(_map(branch['localRefinementSummary']))}')
    ..writeln('\nMAPPING')
    ..writeln(_items(branch['structuredCandidates']))
    ..writeln('\nUNIT TIE BREAK')
    ..writeln(_items(branch['unitTieBreak']))
    ..writeln('\nGEOMETRY MAPPING')
    ..writeln(_items(branch['geometryMapping']))
    ..writeln('\nMULTI-PASS CONSENSUS')
    ..writeln(_items(branch['multiPassConsensus']))
    ..writeln('\nCONFLICT')
    ..writeln(_items(branch['conflicts']))
    ..writeln('\nCONSISTENCY')
    ..writeln(_lines(_map(branch['nutritionConsistency'])))
    ..writeln('\nCONFIDENCE DECISION')
    ..writeln(_items(branch['confidenceDecisions']))
    ..writeln('selectedMappings: ${_lines(_map(branch['selectedMappings']))}')
    ..writeln('fallbackUsed: ${_text(branch['fallbackUsed'])}')
    ..writeln('fallbackReason: ${_text(branch['fallbackReason'])}')
    ..writeln('\nNORMALIZATION / PARSER')
    ..writeln(_items(branch['parserDiagnostics']))
    ..writeln('\nDECISION → PARSER HANDOFF')
    ..writeln(_items(branch['parserDiagnostics']))
    ..writeln('\nREVIEW BRIDGE')
    ..writeln(_items(branch['reviewCandidates']))
    ..writeln('\nLEGACY FALLBACK SAFETY')
    ..writeln(
      _items(
        _list(branch['reviewCandidates'])
            .map((item) => _map(item)['legacyFallbackSafety'])
            .whereType<Map>()
            .toList(),
      ),
    )
    ..writeln('\nFINAL OCR RESULT')
    ..writeln(_lines(_map(branch['finalResult'])))
    ..writeln('\nFORM BINDING')
    ..writeln(_lines(_map(branch['formBinding'])))
    ..writeln('\nSUMMARY')
    ..writeln(_lines(_map(branch['summary'])))
    ..writeln(
      'firstLossClassification: ${_text(branch['bottleneckClassification'])}',
    );
}

List<Map<String, dynamic>> _parserDiagnostics(
  Map<String, dynamic> branch,
  Map<String, dynamic> result,
  Map<String, String> candidateSources,
  Map<String, Map<String, dynamic>> decisions,
) {
  final mapped = _map(branch['selectedMappings']);
  return const {
        'basis': 'basis',
        'calories': 'energy',
        'protein': 'protein',
        'fat': 'fat',
        'carbohydrate': 'carbohydrate',
      }.entries
      .map((entry) {
        final parsed = result[entry.key];
        final decision = decisions[entry.value.toUpperCase()];
        return <String, dynamic>{
          'field': entry.key,
          'rawMappedValue': mapped[entry.value],
          'decisionValue': decision?['value'],
          'decisionUnit': decision?['unit'],
          'decisionConfidence': decision?['confidence'],
          'decisionStatus': decision?['decision'],
          'bridgeStatus': decision?['bridgeStatus'],
          'bridgeReason': decision?['bridgeReason'],
          'normalizedValue': parsed,
          'parsedNumericValue': parsed,
          'candidateSource': candidateSources[entry.key.toUpperCase()],
          'accepted': parsed != null,
          'reason': parsed != null
              ? 'accepted by the existing per-pass nutrition candidate session'
              : 'exact rejection reason is NOT OBSERVABLE inside the existing parser',
        };
      })
      .toList(growable: false);
}

String _finalFieldSource(Map<String, dynamic>? decision) {
  if (decision == null || decision['value'] is! num) return 'NOT_AVAILABLE';
  return decision['bridgeStatus'] == 'ACCEPTED_STRUCTURED'
      ? 'STRUCTURED_DECISION'
      : 'REVIEW_ONLY';
}

String _structuredDecisionInput(Map<String, dynamic> branch) {
  final decisions = <String, dynamic>{};
  for (final item in _list(branch['confidenceDecisions'])) {
    final decision = _map(item);
    final field = decision['field'];
    if (field is String && field.isNotEmpty) {
      decisions[field] = decision;
    }
  }
  if (decisions.isEmpty) return '';
  return '[[OR_STRUCTURED_NUTRITION]]\n'
      '[[OR_OCR_DECISIONS]]\n${jsonEncode(decisions)}';
}

bool _sameValues(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
  List<String> keys,
) => keys.every((key) => '${first[key]}' == '${second[key]}');

bool _containsSupportedLabel(String rawText) => const [
  'エネルギー',
  '熱量',
  'たんぱく質',
  'タンパク質',
  '蛋白質',
  '脂質',
  '炭水化物',
  '糖質',
  '食物繊維',
  '食塩相当量',
].any(rawText.contains);

bool _dimensionAvailable(Object? value) {
  final map = _map(value);
  return _int(map['width']) > 0 && _int(map['height']) > 0;
}

int _int(Object? value) => value is num ? value.toInt() : 0;
List<dynamic> _list(Object? value) => value is List ? value : const [];
Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
String _text(Object? value) => value == null ? 'NOT AVAILABLE' : '$value';
String _lines(Map<String, dynamic> value) => value.isEmpty
    ? 'NOT AVAILABLE'
    : value.entries
          .map((entry) => '${entry.key}=${_text(entry.value)}')
          .join(', ');
String _items(Object? value) {
  final items = _list(value);
  if (items.isEmpty) return 'NOT AVAILABLE';
  return items
      .map((item) => item is Map ? '- ${_lines(_map(item))}' : '- $item')
      .join('\n');
}
