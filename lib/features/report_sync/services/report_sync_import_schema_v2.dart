import '../models/report_sync_issue.dart';

class TrainingReportSyncPayloadSchemaV2 {
  const TrainingReportSyncPayloadSchemaV2();

  void validateResponse(Map<String, Object?> value) {
    _exact(value, const {
      'operationDate',
      'sourceRecordId',
      'session',
    }, r'$.payload');
    _date(value['operationDate'], r'$.payload.operationDate');
    _nullableText(value['sourceRecordId'], r'$.payload.sourceRecordId');
    final session = _map(value['session'], r'$.payload.session');
    _exact(session, const {
      'session',
      'exercises',
      'cardio',
    }, r'$.payload.session');
    final header = _map(session['session'], r'$.payload.session.session');
    _exact(header, const {
      'localDate',
      'name',
      'grade',
      'memo',
      'dynamicStretchCompleted',
      'cooldownStretchCompleted',
      'overallEvaluation',
    }, r'$.payload.session.session');
    _date(header['localDate'], r'$.payload.session.session.localDate');
    _text(header['name'], r'$.payload.session.session.name');
    _text(header['grade'], r'$.payload.session.session.grade');
    _nullableString(header['memo'], r'$.payload.session.session.memo');
    _boolean(
      header['dynamicStretchCompleted'],
      r'$.payload.session.session.dynamicStretchCompleted',
    );
    _boolean(
      header['cooldownStretchCompleted'],
      r'$.payload.session.session.cooldownStretchCompleted',
    );
    _nullableString(
      header['overallEvaluation'],
      r'$.payload.session.session.overallEvaluation',
    );
    final exercises = _list(
      session['exercises'],
      r'$.payload.session.exercises',
    );
    for (var index = 0; index < exercises.length; index++) {
      final path = '${r'$.payload.session.exercises'}[$index]';
      final exercise = _map(exercises[index], path);
      _exact(exercise, const {
        'exerciseName',
        'equipment',
        'sets',
        'evaluation',
        'nextTarget',
      }, path);
      _text(exercise['exerciseName'], '$path.exerciseName');
      final equipment = exercise['equipment'];
      if (equipment != null) {
        final equipmentPath = '$path.equipment';
        final equipmentMap = _map(equipment, equipmentPath);
        _exact(equipmentMap, const {'id', 'name'}, equipmentPath);
        _nullableText(equipmentMap['id'], '$equipmentPath.id');
        _text(equipmentMap['name'], '$equipmentPath.name');
      }
      final sets = _list(exercise['sets'], '$path.sets');
      for (var setIndex = 0; setIndex < sets.length; setIndex++) {
        final setPath = '$path.sets[$setIndex]';
        final set = _map(sets[setIndex], setPath);
        _fields(
          set,
          const {'type', 'weightKg', 'reps', 'rpe', 'restAfterSeconds'},
          const {'type', 'weightKg', 'reps'},
          setPath,
        );
        _text(set['type'], '$setPath.type');
        _number(set['weightKg'], '$setPath.weightKg');
        _integer(set['reps'], '$setPath.reps');
        _nullableInteger(set['rpe'], '$setPath.rpe');
        _nullableInteger(set['restAfterSeconds'], '$setPath.restAfterSeconds');
      }
      _nullableString(exercise['evaluation'], '$path.evaluation');
      _nullableString(exercise['nextTarget'], '$path.nextTarget');
    }
    final cardio = _list(session['cardio'], r'$.payload.session.cardio');
    for (var index = 0; index < cardio.length; index++) {
      final path = '${r'$.payload.session.cardio'}[$index]';
      final entry = _map(cardio[index], path);
      _fields(
        entry,
        const {
          'purpose',
          'type',
          'durationSeconds',
          'distanceKm',
          'mets',
          'averageHeartRateBpm',
          'maximumHeartRateBpm',
          'averageSpeedKmh',
          'estimatedCaloriesKcal',
          'weightSnapshotKg',
          'calculationMethod',
          'calculationVersion',
          'notes',
        },
        const {'purpose', 'type', 'durationSeconds'},
        path,
      );
      _text(entry['purpose'], '$path.purpose');
      _text(entry['type'], '$path.type');
      _integer(entry['durationSeconds'], '$path.durationSeconds');
      for (final key in const [
        'distanceKm',
        'mets',
        'averageSpeedKmh',
        'estimatedCaloriesKcal',
        'weightSnapshotKg',
      ]) {
        _nullableNumber(entry[key], '$path.$key');
      }
      for (final key in const [
        'averageHeartRateBpm',
        'maximumHeartRateBpm',
        'calculationVersion',
      ]) {
        _nullableInteger(entry[key], '$path.$key');
      }
      _nullableString(entry['calculationMethod'], '$path.calculationMethod');
      _nullableString(entry['notes'], '$path.notes');
    }
  }

  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'sourceRecordId': null,
    'session': {
      'session': {
        'localDate': '2000-01-01',
        'name': '<SESSION_NAME>',
        'grade': 'a',
        'memo': null,
        'dynamicStretchCompleted': false,
        'cooldownStretchCompleted': false,
        'overallEvaluation': null,
      },
      'exercises': [
        {
          'exerciseName': '<EXERCISE_NAME>',
          'equipment': {'id': null, 'name': '<EQUIPMENT_NAME>'},
          'sets': <Object?>[],
          'evaluation': null,
          'nextTarget': null,
        },
      ],
      'cardio': <Object?>[],
    },
  };
}

class FoodReportSyncPayloadSchemaV2 {
  const FoodReportSyncPayloadSchemaV2();

  void validateResponse(Map<String, Object?> value) {
    _exact(value, const {'operationDate', 'meals'}, r'$.payload');
    _date(value['operationDate'], r'$.payload.operationDate');
    final meals = _list(value['meals'], r'$.payload.meals');
    if (meals.isEmpty) {
      _invalid(
        r'$.payload.meals',
        '少なくとも1件のMealが必要です。',
        'non-empty Array',
        meals,
      );
    }
    for (var index = 0; index < meals.length; index++) {
      final path = '${r'$.payload.meals'}[$index]';
      final meal = _map(meals[index], path);
      _exact(meal, const {
        'sourceMealId',
        'mealType',
        'items',
        'memo',
        'waterMl',
      }, path);
      _nullableText(meal['sourceMealId'], '$path.sourceMealId');
      _text(meal['mealType'], '$path.mealType');
      _nullableString(meal['memo'], '$path.memo');
      _nullablePositiveNumber(meal['waterMl'], '$path.waterMl');
      final items = _list(meal['items'], '$path.items');
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final itemPath = '$path.items[$itemIndex]';
        final item = _map(items[itemIndex], itemPath);
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
        }, itemPath);
        _text(item['name'], '$itemPath.name');
        for (final key in const [
          'calories',
          'protein',
          'fat',
          'carbohydrate',
        ]) {
          _nonNegativeNumber(item[key], '$itemPath.$key');
        }
        final quantity = item['quantity'];
        if (quantity is! int || quantity < 1) {
          _invalid(
            '$itemPath.quantity',
            '数量は1以上の整数で指定してください。',
            'positive integer',
            quantity,
          );
        }
        _nullablePositiveNumber(item['amount'], '$itemPath.amount');
        _nullablePositiveNumber(item['baseAmount'], '$itemPath.baseAmount');
        _nullableText(item['baseUnit'], '$itemPath.baseUnit');
        _nullableText(item['amountMode'], '$itemPath.amountMode');
        final measured = [item['amount'], item['baseAmount'], item['baseUnit']];
        final count = measured.where((entry) => entry != null).length;
        if (count != 0 && count != measured.length) {
          _invalid(
            itemPath,
            '計量項目は一式で指定してください。',
            'amount/baseAmount/baseUnit together',
            item,
          );
        }
        if (item['amountMode'] != null && count != measured.length) {
          _invalid(
            '$itemPath.amountMode',
            'amountModeには計量項目が必要です。',
            'measured fields',
            item['amountMode'],
          );
        }
      }
    }
  }

  Map<String, Object?> get minimalResponseExample => {
    'operationDate': '2000-01-01',
    'meals': [
      {
        'sourceMealId': null,
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

void _exact(Map<String, Object?> value, Set<String> fields, String path) {
  final actual = value.keys.toSet();
  if (actual.difference(fields).isNotEmpty ||
      fields.difference(actual).isNotEmpty) {
    _invalid(path, '項目構成がSchemaと一致しません。', fields.join(', '), value);
  }
}

void _fields(
  Map<String, Object?> value,
  Set<String> allowed,
  Set<String> required,
  String path,
) {
  final actual = value.keys.toSet();
  if (actual.difference(allowed).isNotEmpty ||
      required.difference(actual).isNotEmpty) {
    _invalid(
      path,
      '項目構成がSchemaと一致しません。',
      'required: ${required.join(', ')}',
      value,
    );
  }
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) _invalid(path, 'Objectが必要です。', 'Object', value);
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) _invalid(path, '配列が必要です。', 'Array', value);
  return value.cast<Object?>();
}

void _text(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    _invalid(path, '空でない文字列が必要です。', 'non-empty String', value);
  }
}

void _nullableText(Object? value, String path) {
  if (value != null) _text(value, path);
}

void _nullableString(Object? value, String path) {
  if (value != null && value is! String) {
    _invalid(path, '文字列またはnullが必要です。', 'String or null', value);
  }
}

void _boolean(Object? value, String path) {
  if (value is! bool) _invalid(path, '真偽値が必要です。', 'boolean', value);
}

void _integer(Object? value, String path) {
  if (value is! int) _invalid(path, '整数が必要です。', 'integer', value);
}

void _nullableInteger(Object? value, String path) {
  if (value != null) _integer(value, path);
}

void _number(Object? value, String path) {
  if (value is! num || !value.isFinite) {
    _invalid(path, '有限数が必要です。', 'number', value);
  }
}

void _nullableNumber(Object? value, String path) {
  if (value != null) _number(value, path);
}

void _date(Object? value, String path) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      DateTime.tryParse(
            '${value}T00:00:00Z',
          )?.toIso8601String().substring(0, 10) !=
          value) {
    _invalid(path, '有効な日付が必要です。', 'YYYY-MM-DD', value);
  }
}

void _nonNegativeNumber(Object? value, String path) {
  if (value is! num || !value.isFinite || value < 0) {
    _invalid(path, '0以上の有限数が必要です。', 'non-negative number', value);
  }
}

void _nullablePositiveNumber(Object? value, String path) {
  if (value != null && (value is! num || !value.isFinite || value <= 0)) {
    _invalid(path, '正の有限数またはnullが必要です。', 'positive number or null', value);
  }
}

Never _invalid(String path, String message, String expected, Object? actual) {
  final preview = actual is String || actual is num || actual is bool
      ? actual.toString()
      : actual == null
      ? 'null'
      : '<${actual.runtimeType}>';
  throw ReportSyncException(
    ReportSyncIssueCode.schemaMismatch,
    message,
    validationError: ReportSyncValidationError(
      code: 'invalidField',
      jsonPath: path,
      message: message,
      expected: expected,
      actualType: actual?.runtimeType.toString() ?? 'null',
      actualValuePreview: preview.length <= 80
          ? preview
          : '${preview.substring(0, 77)}...',
    ),
  );
}
