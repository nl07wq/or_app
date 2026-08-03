import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import 'report_sync_import_schema_v2.dart';

abstract interface class ReportSyncPayloadSchema {
  ReportSyncExchangeType get exchangeType;
  void validateRequest(Map<String, Object?> payload);
  void validateResponse(Map<String, Object?> payload);
  Map<String, Object?> get minimalResponseExample;
}

class ReportSyncPayloadRegistry {
  final Map<ReportSyncExchangeType, ReportSyncPayloadSchema> _schemas;

  ReportSyncPayloadRegistry(Iterable<ReportSyncPayloadSchema> schemas)
    : _schemas = {for (final schema in schemas) schema.exchangeType: schema} {
    if (_schemas.length != ReportSyncExchangeType.values.length) {
      throw StateError('All REPORT SYNC payload schemas are required.');
    }
  }

  factory ReportSyncPayloadRegistry.standard() => ReportSyncPayloadRegistry([
    const TrainingReportSyncPayloadSchema(),
    const FoodReportSyncPayloadSchema(),
    const MorningBriefReportSyncPayloadSchema(),
    const DailyDebriefReportSyncPayloadSchema(),
  ]);

  ReportSyncPayloadSchema forType(ReportSyncExchangeType type) =>
      _schemas[type]!;

  void validate(ReportSyncEnvelope envelope) {
    if (envelope.schemaVersion == ReportSyncEnvelope.importSchemaVersion2) {
      if (envelope.direction != ReportSyncDirection.response) {
        _fail('Schema 2.0 is only supported for import responses.');
      }
      switch (envelope.exchangeType) {
        case ReportSyncExchangeType.training:
          const TrainingReportSyncPayloadSchemaV2().validateResponse(
            envelope.payload,
          );
          return;
        case ReportSyncExchangeType.food:
          const FoodReportSyncPayloadSchemaV2().validateResponse(
            envelope.payload,
          );
          return;
        case ReportSyncExchangeType.morningBrief:
        case ReportSyncExchangeType.dailyDebrief:
          _fail('Schema 2.0 is not supported for this exchange type.');
      }
    }
    final schema = forType(envelope.exchangeType);
    if (envelope.direction == ReportSyncDirection.request) {
      schema.validateRequest(envelope.payload);
    } else {
      schema.validateResponse(envelope.payload);
    }
  }
}

class TrainingReportSyncPayloadSchema implements ReportSyncPayloadSchema {
  const TrainingReportSyncPayloadSchema();
  @override
  ReportSyncExchangeType get exchangeType => ReportSyncExchangeType.training;

  @override
  void validateRequest(Map<String, Object?> value) {
    _exact(value, const {
      'operationDate',
      'requestPurpose',
      'currentSession',
      'recentTrainingSummary',
      'registeredExercises',
      'registeredEquipment',
      'statusWeight',
      'instructionContext',
    });
    _date(value['operationDate'], 'operationDate');
    _text(value['requestPurpose'], 'requestPurpose');
    _nullableMap(value['currentSession'], 'currentSession', (session) {
      _exact(session, const {
        'recordId',
        'localDate',
        'sessionType',
        'operationStatus',
        'warmup',
        'dynamicStretchCompleted',
        'exercises',
        'cardio',
        'cooldownStretchCompleted',
        'overallEvaluation',
        'nextTarget',
      });
      _nullableText(session['recordId'], 'recordId');
      _nullableDate(session['localDate'], 'localDate');
      _nullableText(session['sessionType'], 'sessionType');
      _nullableText(session['operationStatus'], 'operationStatus');
      _nullable(session['warmup'], 'warmup');
      _nullableBool(
        session['dynamicStretchCompleted'],
        'dynamicStretchCompleted',
      );
      _list(session['exercises'], 'exercises');
      _list(session['cardio'], 'cardio');
      _nullableBool(
        session['cooldownStretchCompleted'],
        'cooldownStretchCompleted',
      );
      _nullableText(session['overallEvaluation'], 'overallEvaluation');
      _nullableText(session['nextTarget'], 'nextTarget');
    });
    _nullable(value['recentTrainingSummary'], 'recentTrainingSummary');
    _list(value['registeredExercises'], 'registeredExercises');
    _list(value['registeredEquipment'], 'registeredEquipment');
    _nullableFiniteNumber(value['statusWeight'], 'statusWeight');
    _map(value['instructionContext'], 'instructionContext');
  }

  @override
  void validateResponse(Map<String, Object?> value) {
    _responseIdentity(value, const {'recordId', 'idempotencyKey', 'session'});
    final recordId = _text(value['recordId'], 'recordId');
    if (_text(value['idempotencyKey'], 'idempotencyKey') != recordId) {
      _fail('idempotencyKey must equal recordId.');
    }
    final session = _map(value['session'], 'session');
    _exact(session, const {'session', 'exercises', 'cardio'});
    final header = _map(session['session'], 'session.session');
    _exact(header, const {
      'recordId',
      'localDate',
      'name',
      'grade',
      'memo',
      'dynamicStretchCompleted',
      'cooldownStretchCompleted',
      'overallEvaluation',
    });
    if (header['recordId'] != recordId ||
        header['localDate'] != value['operationDate']) {
      _fail('Training record identity does not match the response.');
    }
    _list(session['exercises'], 'session.exercises');
    _list(session['cardio'], 'session.cardio');
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'recordId': '<RECORD_ID>',
    'idempotencyKey': '<RECORD_ID>',
    'session': {
      'session': {
        'recordId': '<RECORD_ID>',
        'localDate': '2000-01-01',
        'name': '<SESSION_NAME>',
        'grade': 'a',
        'memo': null,
        'dynamicStretchCompleted': false,
        'cooldownStretchCompleted': false,
        'overallEvaluation': null,
      },
      'exercises': <Object?>[],
      'cardio': <Object?>[],
    },
  };
}

class FoodReportSyncPayloadSchema implements ReportSyncPayloadSchema {
  const FoodReportSyncPayloadSchema();
  @override
  ReportSyncExchangeType get exchangeType => ReportSyncExchangeType.food;

  @override
  void validateRequest(Map<String, Object?> value) {
    _exact(value, const {
      'operationDate',
      'requestPurpose',
      'meals',
      'dailySummary',
      'knownFoodReferences',
      'instructionContext',
    });
    _date(value['operationDate'], 'operationDate');
    _text(value['requestPurpose'], 'requestPurpose');
    _meals(value['meals']);
    _nullable(value['dailySummary'], 'dailySummary');
    _list(value['knownFoodReferences'], 'knownFoodReferences');
    _map(value['instructionContext'], 'instructionContext');
  }

  @override
  void validateResponse(Map<String, Object?> value) {
    _responseIdentity(value, const {'meals'});
    _meals(value['meals'], requireNonEmpty: true);
  }

  static void _meals(Object? raw, {bool requireNonEmpty = false}) {
    final meals = _list(raw, 'meals');
    if (requireNonEmpty && meals.isEmpty) {
      _fail('meals must contain at least one meal.');
    }
    final mealIds = <String>{};
    for (final entry in meals) {
      final meal = _map(entry, 'meal');
      _exact(meal, const {'mealId', 'mealType', 'items', 'memo', 'waterMl'});
      _text(meal['mealId'], 'mealId');
      if (!mealIds.add(meal['mealId'] as String)) {
        _fail('mealId must be unique within meals.');
      }
      _text(meal['mealType'], 'mealType');
      _nullableStringAllowEmpty(meal['memo'], 'memo');
      _nullableFiniteNumber(meal['waterMl'], 'waterMl');
      if (meal['waterMl'] is num && (meal['waterMl'] as num) <= 0) {
        _fail('waterMl must be positive when present.');
      }
      for (final itemValue in _list(meal['items'], 'items')) {
        final item = _map(itemValue, 'item');
        _exact(item, const {
          'name',
          'calories',
          'protein',
          'fat',
          'carbohydrate',
          'quantity',
          'amount',
          'baseAmount',
          'baseUnit',
          'amountMode',
        });
        _text(item['name'], 'name');
        for (final key in const [
          'calories',
          'protein',
          'fat',
          'carbohydrate',
        ]) {
          final number = item[key];
          if (number is! num || !number.isFinite || number < 0) {
            _fail('$key must be a non-negative number.');
          }
        }
        if (item['quantity'] is! int || (item['quantity'] as int) < 1) {
          _fail('quantity must be a positive integer.');
        }
        _nullableFiniteNumber(item['amount'], 'amount');
        _nullableFiniteNumber(item['baseAmount'], 'baseAmount');
        _nullableText(item['baseUnit'], 'baseUnit');
        _nullableText(item['amountMode'], 'amountMode');
        final measured = [item['amount'], item['baseAmount'], item['baseUnit']];
        final measuredCount = measured.where((value) => value != null).length;
        if (measuredCount != 0 && measuredCount != measured.length) {
          _fail('amount, baseAmount, and baseUnit must be supplied together.');
        }
        if (item['amountMode'] != null && measuredCount != measured.length) {
          _fail('amountMode requires measured amount fields.');
        }
        final amount = item['amount'];
        if (amount is num && amount <= 0) {
          _fail('amount must be positive.');
        }
        final baseAmount = item['baseAmount'];
        if (baseAmount is num && baseAmount <= 0) {
          _fail('baseAmount must be positive.');
        }
      }
    }
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'meals': [
      {
        'mealId': '<MEAL_ID>',
        'mealType': '<MEAL_TYPE>',
        'items': [
          {
            'name': '<FOOD_NAME>',
            'calories': 0,
            'protein': 0,
            'fat': 0,
            'carbohydrate': 0,
            'quantity': 1,
            'amount': null,
            'baseAmount': null,
            'baseUnit': null,
            'amountMode': null,
          },
        ],
        'memo': null,
        'waterMl': null,
      },
    ],
  };
}

class MorningBriefReportSyncPayloadSchema implements ReportSyncPayloadSchema {
  const MorningBriefReportSyncPayloadSchema();
  @override
  ReportSyncExchangeType get exchangeType =>
      ReportSyncExchangeType.morningBrief;

  @override
  void validateRequest(Map<String, Object?> value) {
    _exact(value, const {
      'operationDate',
      'morningFact',
      'carryover',
      'previousDaySummary',
      'recentTrend',
      'availableStrategicResources',
      'generationRequirements',
    });
    _date(value['operationDate'], 'operationDate');
    final fact = _map(value['morningFact'], 'morningFact');
    _exact(fact, const {'body', 'recovery', 'condition', 'work', 'carryover'});
    final body = _map(fact['body'], 'body');
    _exact(body, const {'weightKg', 'bodyFatPercent'});
    _nullableFiniteNumber(body['weightKg'], 'weightKg');
    _nullableFiniteNumber(body['bodyFatPercent'], 'bodyFatPercent');
    final recovery = _map(fact['recovery'], 'recovery');
    _exact(recovery, const {'sleepDurationMinutes', 'sleepScore'});
    _nullableInteger(recovery['sleepDurationMinutes'], 'sleepDurationMinutes');
    _nullableInteger(recovery['sleepScore'], 'sleepScore');
    final condition = _map(fact['condition'], 'condition');
    _exact(condition, const {'footPainLevel', 'reportedConditions'});
    _nullableInteger(condition['footPainLevel'], 'footPainLevel');
    final reported = _list(
      condition['reportedConditions'],
      'reportedConditions',
    );
    if (reported.any((entry) => entry is! String || entry.trim().isEmpty)) {
      _fail('reportedConditions is invalid.');
    }
    final work = _map(fact['work'], 'work');
    _exact(work, const {'workStatus', 'startTime', 'endTime'});
    for (final key in const ['workStatus', 'startTime', 'endTime']) {
      _nullableText(work[key], key);
    }
    if (fact['carryover'] != null && fact['carryover'] is! bool) {
      _fail('morningFact.carryover must be a boolean or null.');
    }
    for (final key in const [
      'carryover',
      'previousDaySummary',
      'recentTrend',
      'availableStrategicResources',
      'generationRequirements',
    ]) {
      _nullable(value[key], key);
    }
  }

  @override
  void validateResponse(Map<String, Object?> value) {
    _responseIdentity(value, const {'generatedAt', 'content'});
    _utc(value['generatedAt'], 'generatedAt');
    final content = _map(value['content'], 'content');
    _exact(content, const {
      'situationAnalysis',
      'operationStatus',
      'commanderIntent',
      'argoComment',
      'strategicResourceDecision',
      'actions',
    });
    for (final key in const [
      'situationAnalysis',
      'commanderIntent',
      'argoComment',
      'strategicResourceDecision',
    ]) {
      _text(content[key], key);
    }
    if (!const {
      'green',
      'yellow',
      'red',
    }.contains(content['operationStatus'])) {
      _fail('Unknown operationStatus.');
    }
    for (final raw in _list(content['actions'], 'actions')) {
      final action = _map(raw, 'action');
      _exact(action, const {'actionId', 'text', 'priority'});
      _text(action['actionId'], 'actionId');
      _text(action['text'], 'text');
      _text(action['priority'], 'priority');
    }
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'generatedAt': '2000-01-01T00:00:00.000Z',
    'content': {
      'situationAnalysis': '<TEXT>',
      'operationStatus': 'green',
      'commanderIntent': '<TEXT>',
      'argoComment': '<TEXT>',
      'strategicResourceDecision': '<TEXT>',
      'actions': [
        {'actionId': '<ID>', 'text': '<TEXT>', 'priority': 'high'},
      ],
    },
  };
}

class DailyDebriefReportSyncPayloadSchema implements ReportSyncPayloadSchema {
  const DailyDebriefReportSyncPayloadSchema();
  @override
  ReportSyncExchangeType get exchangeType =>
      ReportSyncExchangeType.dailyDebrief;

  @override
  void validateRequest(Map<String, Object?> value) {
    _exact(value, const {
      'operationDate',
      'confirmationDigest',
      'confirmation',
      'finalizedSnapshot',
      'morningBrief',
      'commanderIntent',
      'generationRequirements',
    });
    _date(value['operationDate'], 'operationDate');
    _digest(value['confirmationDigest'], 'confirmationDigest');
    for (final key in const [
      'confirmation',
      'finalizedSnapshot',
      'morningBrief',
      'commanderIntent',
      'generationRequirements',
    ]) {
      _nullable(value[key], key);
    }
  }

  @override
  void validateResponse(Map<String, Object?> value) {
    _responseIdentity(value, const {
      'confirmationDigest',
      'generatedAt',
      'content',
    });
    _digest(value['confirmationDigest'], 'confirmationDigest');
    _utc(value['generatedAt'], 'generatedAt');
    final content = _map(value['content'], 'content');
    _exact(content, const {
      'dailySummary',
      'commanderIntentEvaluation',
      'successes',
      'issues',
      'nutritionEvaluation',
      'activityEvaluation',
      'trainingEvaluation',
      'recoveryEvaluation',
      'carryover',
      'tomorrowConsiderations',
    });
    for (final key in const [
      'dailySummary',
      'commanderIntentEvaluation',
      'nutritionEvaluation',
      'activityEvaluation',
      'trainingEvaluation',
      'recoveryEvaluation',
    ]) {
      _text(content[key], key);
    }
    for (final key in const [
      'successes',
      'issues',
      'carryover',
      'tomorrowConsiderations',
    ]) {
      final list = _list(content[key], key);
      if (list.any((entry) => entry is! String || entry.trim().isEmpty)) {
        _fail('$key is invalid.');
      }
    }
  }

  @override
  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'confirmationDigest':
        '0000000000000000000000000000000000000000000000000000000000000000',
    'generatedAt': '2000-01-01T00:00:00.000Z',
    'content': {
      'dailySummary': '<TEXT>',
      'commanderIntentEvaluation': '<TEXT>',
      'successes': ['<TEXT>'],
      'issues': ['<TEXT>'],
      'nutritionEvaluation': '<TEXT>',
      'activityEvaluation': '<TEXT>',
      'trainingEvaluation': '<TEXT>',
      'recoveryEvaluation': '<TEXT>',
      'carryover': ['<TEXT>'],
      'tomorrowConsiderations': ['<TEXT>'],
    },
  };
}

void _responseIdentity(Map<String, Object?> value, Set<String> additional) {
  final current = {'operationDate', ...additional};
  final legacy = {'requestId', 'requestDigest', ...current};
  final fields = value.keys.toSet();
  if (fields.length != current.length && fields.length != legacy.length) {
    _fail('Fields do not match the response schema.');
  }
  if (fields.length == legacy.length) {
    _exact(value, legacy);
    _text(value['requestId'], 'requestId');
    _digest(value['requestDigest'], 'requestDigest');
  } else {
    _exact(value, current);
  }
  _date(value['operationDate'], 'operationDate');
}

void _exact(Map<String, Object?> value, Set<String> fields) {
  if (value.keys.toSet().difference(fields).isNotEmpty ||
      fields.difference(value.keys.toSet()).isNotEmpty) {
    _fail('Fields do not match schema: expected ${fields.join(', ')}.');
  }
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) _fail('$name must be an object.');
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Object? value, String name) {
  if (value is! List) _fail('$name must be an array.');
  return value.cast<Object?>();
}

String _text(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    _fail('$name must be a non-empty string.');
  }
  return value;
}

void _nullableText(Object? value, String name) {
  if (value != null) _text(value, name);
}

void _nullableStringAllowEmpty(Object? value, String name) {
  if (value != null && value is! String) {
    _fail('$name must be a string or null.');
  }
}

void _nullableBool(Object? value, String name) {
  if (value != null && value is! bool) {
    _fail('$name must be a boolean or null.');
  }
}

void _nullableInteger(Object? value, String name) {
  if (value != null && value is! int) {
    _fail('$name must be an integer or null.');
  }
}

void _nullableFiniteNumber(Object? value, String name) {
  if (value != null && (value is! num || !value.isFinite)) {
    _fail('$name must be a finite number or null.');
  }
}

void _nullable(Object? value, String name) {
  if (value is double && !value.isFinite) _fail('$name is invalid.');
}

void _nullableMap(
  Object? value,
  String name,
  void Function(Map<String, Object?>) validate,
) {
  if (value != null) validate(_map(value, name));
}

void _date(Object? value, String name) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      DateTime.tryParse(
            '${value}T00:00:00Z',
          )?.toIso8601String().substring(0, 10) !=
          value) {
    _fail('$name is invalid.');
  }
}

void _nullableDate(Object? value, String name) {
  if (value != null) _date(value, name);
}

void _utc(Object? value, String name) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc) _fail('$name must be UTC.');
}

void _digest(Object? value, String name) {
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    _fail('$name is invalid.');
  }
}

Never _fail(String message) =>
    throw ReportSyncException(ReportSyncIssueCode.schemaMismatch, message);
