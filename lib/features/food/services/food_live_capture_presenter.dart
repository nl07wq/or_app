import 'dart:convert';

import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import 'food_input_capture_gateway.dart';
import 'japanese_nutrition_ocr_parser.dart';

FoodOcrLiveCandidate describeNutritionCandidate(String rawText) =>
    FoodNutritionCandidateSession().describe(rawText);

class FoodNutritionCandidateSession {
  static const _structuredMarker = '[[OR_STRUCTURED_NUTRITION]]';
  static const _decisionMarker = '[[OR_OCR_DECISIONS]]';

  NutritionOcrDraft _draft = const NutritionOcrDraft();
  String? _lastRawText;
  final Map<String, String> _sources = {};
  final Map<String, String> _candidateSources = {};
  final Set<String> _conflicts = {};
  final Map<String, Map<String, dynamic>> _fieldDecisions = {};

  NutritionOcrDraft get draft => _draft;
  String? get lastRawText => _lastRawText;
  Set<String> get conflicts => Set.unmodifiable(_conflicts);
  Map<String, String> get candidateSources =>
      Map.unmodifiable(_candidateSources);
  Map<String, Map<String, dynamic>> get fieldDecisions => Map.unmodifiable(
    _fieldDecisions.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.unmodifiable(value)),
    ),
  );

  FoodOcrLiveCandidate describe(String rawText) {
    _lastRawText = rawText;
    final isStructured = rawText.startsWith(_structuredMarker);
    var parserInput = isStructured
        ? rawText.substring(_structuredMarker.length).trimLeft()
        : rawText;
    if (isStructured) {
      final decisionIndex = parserInput.indexOf(_decisionMarker);
      if (decisionIndex >= 0) {
        final encoded = parserInput
            .substring(decisionIndex + _decisionMarker.length)
            .trim();
        parserInput = parserInput.substring(0, decisionIndex).trimRight();
        _readFieldDecisions(encoded);
      }
    }
    final next = const JapaneseNutritionOcrParser().parse(parserInput);
    final structured = _structuredDraft(next);
    _draft = NutritionOcrDraft(
      basisQuantity: structured.basisQuantity ?? _draft.basisQuantity,
      basisUnit: structured.basisUnit ?? _draft.basisUnit,
      calories: _merge(
        'CALORIES',
        _draft.calories,
        structured.calories,
        isStructured,
      ),
      protein: _merge(
        'PROTEIN',
        _draft.protein,
        structured.protein,
        isStructured,
      ),
      fat: _merge('FAT', _draft.fat, structured.fat, isStructured),
      carbohydrate: _merge(
        'CARBOHYDRATE',
        _draft.carbohydrate,
        structured.carbohydrate,
        isStructured,
      ),
      packageQuantity: structured.packageQuantity ?? _draft.packageQuantity,
      packageUnit: structured.packageUnit ?? _draft.packageUnit,
    );
    _applyFieldDecisionPolicy();
    _recordCandidateSources(structured);
    return _candidate(
      _draft,
      hasRawText: parserInput.trim().isNotEmpty,
      conflicts: _conflicts,
    );
  }

  void _applyFieldDecisionPolicy() {
    final excludedFields = <String>{};
    for (final entry in _fieldDecisions.entries) {
      if (!_isAutoFillDecision(entry.key, entry.value)) {
        excludedFields.add(entry.key);
        _sources.remove(entry.key);
        _candidateSources.remove(entry.key);
      }
    }

    _draft = NutritionOcrDraft(
      basisQuantity: _draft.basisQuantity,
      basisUnit: _draft.basisUnit,
      calories: excludedFields.contains('ENERGY') ? null : _draft.calories,
      protein: excludedFields.contains('PROTEIN') ? null : _draft.protein,
      fat: excludedFields.contains('FAT') ? null : _draft.fat,
      carbohydrate: excludedFields.contains('CARBOHYDRATE')
          ? null
          : _draft.carbohydrate,
      packageQuantity: _draft.packageQuantity,
      packageUnit: _draft.packageUnit,
    );
  }

  NutritionOcrDraft _structuredDraft(NutritionOcrDraft parsed) =>
      NutritionOcrDraft(
        basisQuantity: parsed.basisQuantity,
        basisUnit: parsed.basisUnit,
        calories: _structuredValue('ENERGY') ?? parsed.calories,
        protein: _structuredValue('PROTEIN') ?? parsed.protein,
        fat: _structuredValue('FAT') ?? parsed.fat,
        carbohydrate: _structuredValue('CARBOHYDRATE') ?? parsed.carbohydrate,
        packageQuantity: parsed.packageQuantity,
        packageUnit: parsed.packageUnit,
      );

  double? _structuredValue(String field) {
    final decision = _fieldDecisions[field];
    if (decision == null) return null;
    if (!_isAutoFillDecision(field, decision)) {
      decision['bridgeStatus'] = 'RETAINED_FOR_REVIEW';
      decision['bridgeReason'] = decision['conflict'] == true
          ? 'conflicting-structured-evidence'
          : 'structured-decision-is-not-auto-fill-eligible';
      return null;
    }
    final value = decision['value'];
    if (value is! num || !value.isFinite) {
      decision['bridgeStatus'] = 'REJECTED';
      decision['bridgeReason'] = 'structured-decision-value-is-not-numeric';
      return null;
    }
    decision['bridgeStatus'] = 'ACCEPTED_STRUCTURED';
    decision['bridgeReason'] = 'compatible-high-confidence-structured-decision';
    return value.toDouble();
  }

  bool _isAutoFillDecision(String field, Map<String, dynamic> decision) {
    if (decision['confidence'] != 'HIGH' ||
        decision['decision'] != 'AUTO_FILL_ALLOWED' ||
        decision['reviewRequired'] != false ||
        decision['conflict'] == true) {
      return false;
    }
    final unit = decision['unit'];
    return switch (field) {
      'ENERGY' => unit == 'kcal',
      'PROTEIN' || 'FAT' || 'CARBOHYDRATE' => unit == 'g',
      _ => false,
    };
  }

  void _readFieldDecisions(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        if (entry.value case final Map value) {
          _fieldDecisions[entry.key.toString().toUpperCase()] = value.map(
            (key, item) => MapEntry(key.toString(), item),
          );
          if (value['conflict'] == true) {
            _conflicts.add(entry.key.toString().toUpperCase());
          }
        }
      }
    } on FormatException {
      // Decision metadata is advisory. Raw OCR parsing remains available.
    }
  }

  void _recordCandidateSources(NutritionOcrDraft next) {
    final incoming = {
      'CALORIES': next.calories,
      'PROTEIN': next.protein,
      'FAT': next.fat,
      'CARBOHYDRATE': next.carbohydrate,
    };
    for (final entry in incoming.entries) {
      final current = switch (entry.key) {
        'CALORIES' => _draft.calories,
        'PROTEIN' => _draft.protein,
        'FAT' => _draft.fat,
        _ => _draft.carbohydrate,
      };
      if (entry.value != null) {
        _candidateSources[entry.key] = _sources[entry.key] ?? 'parser';
      } else if (current != null) {
        _candidateSources[entry.key] = 'session';
      }
    }
  }

  double? _merge(
    String field,
    double? current,
    double? next,
    bool isStructured,
  ) {
    if (next == null) return current;
    if (current == null) {
      _sources[field] =
          isStructured &&
              _fieldDecisions[field]?['bridgeStatus'] == 'ACCEPTED_STRUCTURED'
          ? 'STRUCTURED_DECISION'
          : isStructured
          ? 'structured'
          : 'parser';
      return next;
    }
    if (current == next) {
      if (isStructured) _sources[field] = 'structured';
      return current;
    }
    _conflicts.add(field);
    if (isStructured) {
      _sources[field] = 'structured';
      return next;
    }
    return _sources[field] == 'structured' ? current : next;
  }
}

FoodOcrLiveCandidate _candidate(
  NutritionOcrDraft draft, {
  required bool hasRawText,
  Set<String> conflicts = const {},
}) {
  if (draft.isEmpty) {
    return FoodOcrLiveCandidate(
      state: hasRawText ? 'insufficient' : 'scanning',
      fields: const {},
    );
  }
  final hasMajorValues =
      draft.calories != null &&
      draft.protein != null &&
      draft.fat != null &&
      draft.carbohydrate != null;
  return FoodOcrLiveCandidate(
    state: hasMajorValues ? 'detected' : 'partial',
    fields: {
      'CALORIES': draft.calories == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.calories!)} kcal',
      'PROTEIN': draft.protein == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.protein!)} g',
      'FAT': draft.fat == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.fat!)} g',
      'CARBOHYDRATE': draft.carbohydrate == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.carbohydrate!)} g',
      'BASIS': _quantity(draft.basisQuantity, draft.basisUnit),
      'PACKAGE': _quantity(draft.packageQuantity, draft.packageUnit),
      if (conflicts.isNotEmpty) 'REVIEW CONFLICT': conflicts.join(', '),
    },
  );
}

String? _quantity(double? value, FoodQuantityUnit? unit) {
  if (value == null || unit == null) return null;
  final number = value == value.roundToDouble()
      ? value.round().toString()
      : FoodNutritionFormatter.macro(value);
  return '$number ${switch (unit) {
    FoodQuantityUnit.gram => 'g',
    FoodQuantityUnit.milliliter => 'mL',
    FoodQuantityUnit.piece => 'piece',
    FoodQuantityUnit.pack => 'pack',
    FoodQuantityUnit.serving => 'serving',
  }}';
}
