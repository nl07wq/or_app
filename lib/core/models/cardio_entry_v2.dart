import 'cardio_entry.dart';
import 'training_equipment_snapshot.dart';

enum CardioPurpose {
  warmUp('Warm-up'),
  main('Main'),
  cooldown('Cooldown'),
  legacyUnknown('Legacy');

  final String displayLabel;

  const CardioPurpose(this.displayLabel);

  String get stableId => name;

  static CardioPurpose fromStableId(String stableId) {
    try {
      return values.byName(stableId);
    } on ArgumentError {
      throw FormatException('Unknown TRAINING cardio purpose: $stableId.');
    }
  }
}

class CardioEntryV2 {
  final CardioPurpose purpose;
  final CardioType type;
  final TrainingEquipmentSnapshot? equipment;
  final int durationSeconds;
  final double? distanceKm;
  final double? mets;
  final int? averageHeartRateBpm;
  final int? maximumHeartRateBpm;
  final double? averageSpeedKmh;
  final double? estimatedCaloriesKcal;
  final double? weightSnapshotKg;
  final String? calculationMethod;
  final int? calculationVersion;
  final String? notes;
  final String? legacyIntensity;
  final double? legacyReferenceCaloriesKcal;

  CardioEntryV2({
    required this.purpose,
    required this.type,
    this.equipment,
    required this.durationSeconds,
    this.distanceKm,
    this.mets,
    this.averageHeartRateBpm,
    this.maximumHeartRateBpm,
    this.averageSpeedKmh,
    this.estimatedCaloriesKcal,
    this.weightSnapshotKg,
    String? calculationMethod,
    this.calculationVersion,
    String? notes,
    String? legacyIntensity,
    this.legacyReferenceCaloriesKcal,
  }) : calculationMethod = _normalizeOptional(calculationMethod),
       notes = _normalizeOptional(notes),
       legacyIntensity = _normalizeOptional(legacyIntensity) {
    _validate(allowLegacyUnknown: false);
  }

  CardioEntryV2.forMigration({
    required this.purpose,
    required this.type,
    this.equipment,
    required this.durationSeconds,
    this.distanceKm,
    this.mets,
    this.averageHeartRateBpm,
    this.maximumHeartRateBpm,
    this.averageSpeedKmh,
    this.estimatedCaloriesKcal,
    this.weightSnapshotKg,
    String? calculationMethod,
    this.calculationVersion,
    String? notes,
    String? legacyIntensity,
    this.legacyReferenceCaloriesKcal,
  }) : calculationMethod = _normalizeOptional(calculationMethod),
       notes = _normalizeOptional(notes),
       legacyIntensity = _normalizeOptional(legacyIntensity) {
    _validate(allowLegacyUnknown: true);
  }

  bool get hasLegacyUnknown => purpose == CardioPurpose.legacyUnknown;

  Map<String, Object?> toJson() => {
    'purpose': purpose.stableId,
    'type': type.name,
    'equipment': equipment?.toJson(),
    'durationSeconds': durationSeconds,
    'distanceKm': distanceKm,
    'mets': mets,
    'averageHeartRateBpm': averageHeartRateBpm,
    'maximumHeartRateBpm': maximumHeartRateBpm,
    'averageSpeedKmh': averageSpeedKmh,
    'estimatedCaloriesKcal': estimatedCaloriesKcal,
    'weightSnapshotKg': weightSnapshotKg,
    'calculationMethod': calculationMethod,
    'calculationVersion': calculationVersion,
    'notes': notes,
    'legacyIntensity': legacyIntensity,
    'legacyReferenceCaloriesKcal': legacyReferenceCaloriesKcal,
  };

  factory CardioEntryV2.fromJson(Map<String, Object?> json) =>
      CardioEntryV2._decode(json, allowLegacyUnknown: false);

  factory CardioEntryV2.fromMigrationJson(Map<String, Object?> json) =>
      CardioEntryV2._decode(json, allowLegacyUnknown: true);

  static CardioEntryV2 _decode(
    Map<String, Object?> json, {
    required bool allowLegacyUnknown,
  }) {
    final purpose = json['purpose'];
    final type = json['type'];
    final equipment = json['equipment'];
    final durationSeconds = json['durationSeconds'];
    if (purpose is! String ||
        type is! String ||
        (equipment != null && equipment is! Map) ||
        durationSeconds is! int) {
      throw const FormatException('Invalid TRAINING v2 cardio entry.');
    }
    final decodedPurpose = CardioPurpose.fromStableId(purpose);
    final decodedType = _decodeCardioType(type);
    final optional = _CardioOptionalFields.fromJson(json);
    if (allowLegacyUnknown) {
      return CardioEntryV2.forMigration(
        purpose: decodedPurpose,
        type: decodedType,
        equipment: _decodeEquipment(equipment),
        durationSeconds: durationSeconds,
        distanceKm: optional.distanceKm,
        mets: optional.mets,
        averageHeartRateBpm: optional.averageHeartRateBpm,
        maximumHeartRateBpm: optional.maximumHeartRateBpm,
        averageSpeedKmh: optional.averageSpeedKmh,
        estimatedCaloriesKcal: optional.estimatedCaloriesKcal,
        weightSnapshotKg: optional.weightSnapshotKg,
        calculationMethod: optional.calculationMethod,
        calculationVersion: optional.calculationVersion,
        notes: optional.notes,
        legacyIntensity: optional.legacyIntensity,
        legacyReferenceCaloriesKcal: optional.legacyReferenceCaloriesKcal,
      );
    }
    return CardioEntryV2(
      purpose: decodedPurpose,
      type: decodedType,
      equipment: _decodeEquipment(equipment),
      durationSeconds: durationSeconds,
      distanceKm: optional.distanceKm,
      mets: optional.mets,
      averageHeartRateBpm: optional.averageHeartRateBpm,
      maximumHeartRateBpm: optional.maximumHeartRateBpm,
      averageSpeedKmh: optional.averageSpeedKmh,
      estimatedCaloriesKcal: optional.estimatedCaloriesKcal,
      weightSnapshotKg: optional.weightSnapshotKg,
      calculationMethod: optional.calculationMethod,
      calculationVersion: optional.calculationVersion,
      notes: optional.notes,
      legacyIntensity: optional.legacyIntensity,
      legacyReferenceCaloriesKcal: optional.legacyReferenceCaloriesKcal,
    );
  }

  void _validate({required bool allowLegacyUnknown}) {
    if (!allowLegacyUnknown && hasLegacyUnknown) {
      throw ArgumentError.value(
        purpose,
        'purpose',
        'legacyUnknown is reserved for migration.',
      );
    }
    if (durationSeconds < 1) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'Duration must be at least 1 second.',
      );
    }
    _validateOptionalFinite(distanceKm, 'distanceKm', allowZero: true);
    _validateOptionalFinite(mets, 'mets', allowZero: false);
    _validateOptionalFinite(
      averageSpeedKmh,
      'averageSpeedKmh',
      allowZero: true,
    );
    _validateOptionalFinite(
      estimatedCaloriesKcal,
      'estimatedCaloriesKcal',
      allowZero: true,
    );
    _validateOptionalFinite(
      weightSnapshotKg,
      'weightSnapshotKg',
      allowZero: false,
    );
    _validateOptionalFinite(
      legacyReferenceCaloriesKcal,
      'legacyReferenceCaloriesKcal',
      allowZero: true,
    );
    if (averageHeartRateBpm != null && averageHeartRateBpm! < 1) {
      throw ArgumentError.value(
        averageHeartRateBpm,
        'averageHeartRateBpm',
        'Average heart rate must be at least 1.',
      );
    }
    if (maximumHeartRateBpm != null && maximumHeartRateBpm! < 1) {
      throw ArgumentError.value(
        maximumHeartRateBpm,
        'maximumHeartRateBpm',
        'Maximum heart rate must be at least 1.',
      );
    }
    if (averageHeartRateBpm != null &&
        maximumHeartRateBpm != null &&
        maximumHeartRateBpm! < averageHeartRateBpm!) {
      throw ArgumentError.value(
        maximumHeartRateBpm,
        'maximumHeartRateBpm',
        'Maximum heart rate must not be below average heart rate.',
      );
    }
    if (calculationVersion != null && calculationVersion! < 1) {
      throw ArgumentError.value(
        calculationVersion,
        'calculationVersion',
        'Calculation version must be at least 1.',
      );
    }
  }
}

class _CardioOptionalFields {
  final double? distanceKm;
  final double? mets;
  final int? averageHeartRateBpm;
  final int? maximumHeartRateBpm;
  final double? averageSpeedKmh;
  final double? estimatedCaloriesKcal;
  final double? weightSnapshotKg;
  final String? calculationMethod;
  final int? calculationVersion;
  final String? notes;
  final String? legacyIntensity;
  final double? legacyReferenceCaloriesKcal;

  const _CardioOptionalFields({
    this.distanceKm,
    this.mets,
    this.averageHeartRateBpm,
    this.maximumHeartRateBpm,
    this.averageSpeedKmh,
    this.estimatedCaloriesKcal,
    this.weightSnapshotKg,
    this.calculationMethod,
    this.calculationVersion,
    this.notes,
    this.legacyIntensity,
    this.legacyReferenceCaloriesKcal,
  });

  factory _CardioOptionalFields.fromJson(Map<String, Object?> json) {
    double? number(String key) {
      final value = json[key];
      if (value != null && value is! num) {
        throw FormatException('Invalid TRAINING cardio $key.');
      }
      return (value as num?)?.toDouble();
    }

    int? integer(String key) {
      final value = json[key];
      if (value != null && value is! int) {
        throw FormatException('Invalid TRAINING cardio $key.');
      }
      return value as int?;
    }

    String? text(String key) {
      final value = json[key];
      if (value != null && value is! String) {
        throw FormatException('Invalid TRAINING cardio $key.');
      }
      return value as String?;
    }

    return _CardioOptionalFields(
      distanceKm: number('distanceKm'),
      mets: number('mets'),
      averageHeartRateBpm: integer('averageHeartRateBpm'),
      maximumHeartRateBpm: integer('maximumHeartRateBpm'),
      averageSpeedKmh: number('averageSpeedKmh'),
      estimatedCaloriesKcal: number('estimatedCaloriesKcal'),
      weightSnapshotKg: number('weightSnapshotKg'),
      calculationMethod: text('calculationMethod'),
      calculationVersion: integer('calculationVersion'),
      notes: text('notes'),
      legacyIntensity: text('legacyIntensity'),
      legacyReferenceCaloriesKcal: number('legacyReferenceCaloriesKcal'),
    );
  }
}

CardioType _decodeCardioType(String stableId) {
  try {
    return CardioType.values.byName(stableId);
  } on ArgumentError {
    throw FormatException('Unknown TRAINING cardio type: $stableId.');
  }
}

TrainingEquipmentSnapshot? _decodeEquipment(Object? value) => value == null
    ? null
    : TrainingEquipmentSnapshot.fromJson(
        Map<String, Object?>.from(value as Map),
      );

void _validateOptionalFinite(
  double? value,
  String name, {
  required bool allowZero,
}) {
  if (value == null) return;
  if (!value.isFinite || (allowZero ? value < 0 : value <= 0)) {
    throw ArgumentError.value(value, name, 'Invalid $name.');
  }
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
