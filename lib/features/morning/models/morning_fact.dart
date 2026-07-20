class MorningFact {
  static const Object _unset = Object();

  final DateTime date;
  final double weight;
  final double? bodyFat;
  final Duration sleepDuration;
  final double workHours;
  final bool bowelMovement;
  final int footPain;
  final List<String> medications;
  final String? freeNotes;

  const MorningFact({
    required this.date,
    required this.weight,
    required this.bodyFat,
    required this.sleepDuration,
    required this.workHours,
    required this.bowelMovement,
    required this.footPain,
    required this.medications,
    required this.freeNotes,
  });

  MorningFact copyWith({
    DateTime? date,
    double? weight,
    Object? bodyFat = _unset,
    Duration? sleepDuration,
    double? workHours,
    bool? bowelMovement,
    int? footPain,
    List<String>? medications,
    Object? freeNotes = _unset,
  }) {
    return MorningFact(
      date: date ?? this.date,
      weight: weight ?? this.weight,
      bodyFat: bodyFat == _unset ? this.bodyFat : bodyFat as double?,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      workHours: workHours ?? this.workHours,
      bowelMovement: bowelMovement ?? this.bowelMovement,
      footPain: footPain ?? this.footPain,
      medications: medications ?? this.medications,
      freeNotes: freeNotes == _unset ? this.freeNotes : freeNotes as String?,
    );
  }

  factory MorningFact.fromJson(Map<String, dynamic> json) {
    return MorningFact(
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
      bodyFat: (json['bodyFat'] as num?)?.toDouble(),
      sleepDuration: Duration(
        microseconds: json['sleepDuration'] as int,
      ),
      workHours: (json['workHours'] as num).toDouble(),
      bowelMovement: json['bowelMovement'] as bool,
      footPain: json['footPain'] as int,
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
      'workHours': workHours,
      'bowelMovement': bowelMovement,
      'footPain': footPain,
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
        workHours == other.workHours &&
        bowelMovement == other.bowelMovement &&
        footPain == other.footPain &&
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
      workHours,
      bowelMovement,
      footPain,
      Object.hashAll(medications),
      freeNotes,
    );
  }
}
