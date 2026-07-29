enum TrainingSetType {
  warmUp('Warm-up'),
  main('Main'),
  legacyUnknown('Legacy');

  final String displayLabel;

  const TrainingSetType(this.displayLabel);

  String get stableId => name;

  static TrainingSetType fromStableId(String stableId) {
    try {
      return values.byName(stableId);
    } on ArgumentError {
      throw FormatException('Unknown TRAINING setType: $stableId.');
    }
  }
}

class TrainingSetV2 {
  final int setNo;
  final TrainingSetType setType;
  final double weightKg;
  final int reps;
  final int? rpe;
  final int? restAfterSeconds;

  TrainingSetV2({
    required this.setNo,
    required this.setType,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.restAfterSeconds,
  }) {
    _validate(allowLegacyUnknown: false);
  }

  TrainingSetV2.forMigration({
    required this.setNo,
    required this.setType,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.restAfterSeconds,
  }) {
    _validate(allowLegacyUnknown: true);
  }

  bool get hasLegacyUnknown => setType == TrainingSetType.legacyUnknown;

  Map<String, Object?> toJson() => {
    'setNo': setNo,
    'setType': setType.stableId,
    'weightKg': weightKg,
    'reps': reps,
    'rpe': rpe,
    'restAfterSeconds': restAfterSeconds,
  };

  factory TrainingSetV2.fromJson(Map<String, Object?> json) =>
      TrainingSetV2._decode(json, allowLegacyUnknown: false);

  factory TrainingSetV2.fromMigrationJson(Map<String, Object?> json) =>
      TrainingSetV2._decode(json, allowLegacyUnknown: true);

  static TrainingSetV2 _decode(
    Map<String, Object?> json, {
    required bool allowLegacyUnknown,
  }) {
    final setNo = json['setNo'];
    final setType = json['setType'];
    final weightKg = json['weightKg'];
    final reps = json['reps'];
    final rpe = json['rpe'];
    final restAfterSeconds = json['restAfterSeconds'];
    if (setNo is! int ||
        setType is! String ||
        weightKg is! num ||
        reps is! int ||
        (rpe != null && rpe is! int) ||
        (restAfterSeconds != null && restAfterSeconds is! int)) {
      throw const FormatException('Invalid TRAINING v2 set.');
    }
    final type = TrainingSetType.fromStableId(setType);
    if (allowLegacyUnknown) {
      return TrainingSetV2.forMigration(
        setNo: setNo,
        setType: type,
        weightKg: weightKg.toDouble(),
        reps: reps,
        rpe: rpe as int?,
        restAfterSeconds: restAfterSeconds as int?,
      );
    }
    return TrainingSetV2(
      setNo: setNo,
      setType: type,
      weightKg: weightKg.toDouble(),
      reps: reps,
      rpe: rpe as int?,
      restAfterSeconds: restAfterSeconds as int?,
    );
  }

  void _validate({required bool allowLegacyUnknown}) {
    if (setNo < 1) {
      throw ArgumentError.value(
        setNo,
        'setNo',
        'Set number must be at least 1.',
      );
    }
    if (!allowLegacyUnknown && hasLegacyUnknown) {
      throw ArgumentError.value(
        setType,
        'setType',
        'legacyUnknown is reserved for migration.',
      );
    }
    if (!weightKg.isFinite || weightKg < 0) {
      throw ArgumentError.value(
        weightKg,
        'weightKg',
        'Weight must be finite and not negative.',
      );
    }
    if (reps < 1) {
      throw ArgumentError.value(reps, 'reps', 'Reps must be at least 1.');
    }
    if (rpe != null && (rpe! < 1 || rpe! > 10)) {
      throw ArgumentError.value(rpe, 'rpe', 'RPE must be between 1 and 10.');
    }
    if (restAfterSeconds != null && restAfterSeconds! < 0) {
      throw ArgumentError.value(
        restAfterSeconds,
        'restAfterSeconds',
        'Rest must not be negative.',
      );
    }
  }
}
