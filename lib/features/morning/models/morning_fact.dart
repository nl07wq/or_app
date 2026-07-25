class MorningFact {
  static const Object _unset = Object();

  final DateTime date;
  final double weight;
  final double? bodyFat;
  final Duration sleepDuration;
  final int sleepScore;
  final double workHours;
  final int footPain;
  final int? condition;
  final bool? previousCarryoverConfirmed;
  final List<String> medications;
  final String? freeNotes;

  MorningFact({
    required this.date,
    required this.weight,
    required this.bodyFat,
    required this.sleepDuration,
    required this.sleepScore,
    required this.workHours,
    required this.footPain,
    this.condition,
    this.previousCarryoverConfirmed,
    required List<String> medications,
    required this.freeNotes,
  }) : medications = List.unmodifiable(medications);

  MorningFact copyWith({
    DateTime? date,
    double? weight,
    Object? bodyFat = _unset,
    Duration? sleepDuration,
    int? sleepScore,
    double? workHours,
    int? footPain,
    Object? condition = _unset,
    Object? previousCarryoverConfirmed = _unset,
    List<String>? medications,
    Object? freeNotes = _unset,
  }) {
    return MorningFact(
      date: date ?? this.date,
      weight: weight ?? this.weight,
      bodyFat: bodyFat == _unset ? this.bodyFat : bodyFat as double?,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      sleepScore: sleepScore ?? this.sleepScore,
      workHours: workHours ?? this.workHours,
      footPain: footPain ?? this.footPain,
      condition: condition == _unset ? this.condition : condition as int?,
      previousCarryoverConfirmed: previousCarryoverConfirmed == _unset
          ? this.previousCarryoverConfirmed
          : previousCarryoverConfirmed as bool?,
      medications: medications ?? this.medications,
      freeNotes: freeNotes == _unset ? this.freeNotes : freeNotes as String?,
    );
  }

  factory MorningFact.fromJson(Map<String, dynamic> json) {
    return MorningFact(
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
      bodyFat: (json['bodyFat'] as num?)?.toDouble(),
      sleepDuration: Duration(microseconds: json['sleepDuration'] as int),
      sleepScore: (json['sleepScore'] as num?)?.toInt() ?? 0,
      workHours: (json['workHours'] as num).toDouble(),
      footPain: json['footPain'] as int,
      condition: (json['condition'] as num?)?.toInt(),
      previousCarryoverConfirmed: json['previousCarryoverConfirmed'] as bool?,
      medications: List<String>.from(json['medications'] as List),
      freeNotes: json['freeNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
      'bodyFat': bodyFat,
      'sleepDuration': sleepDuration.inMicroseconds,
      'sleepScore': sleepScore,
      'workHours': workHours,
      'footPain': footPain,
      if (condition != null) 'condition': condition,
      if (previousCarryoverConfirmed != null)
        'previousCarryoverConfirmed': previousCarryoverConfirmed,
      'medications': medications,
      'freeNotes': freeNotes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MorningFact &&
        date == other.date &&
        weight == other.weight &&
        bodyFat == other.bodyFat &&
        sleepDuration == other.sleepDuration &&
        sleepScore == other.sleepScore &&
        workHours == other.workHours &&
        footPain == other.footPain &&
        condition == other.condition &&
        previousCarryoverConfirmed == other.previousCarryoverConfirmed &&
        freeNotes == other.freeNotes &&
        _sameMedications(other.medications);
  }

  bool _sameMedications(List<String> other) {
    if (medications.length != other.length) return false;

    for (var index = 0; index < medications.length; index++) {
      if (medications[index] != other[index]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      date,
      weight,
      bodyFat,
      sleepDuration,
      sleepScore,
      workHours,
      footPain,
      condition,
      previousCarryoverConfirmed,
      Object.hashAll(medications),
      freeNotes,
    );
  }
}
