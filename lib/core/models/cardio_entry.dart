enum CardioType {
  walking,
  running,
  exerciseBike,
  elliptical,
  treadmillWalking,
  treadmillRunning,
}

enum CardioIntensity { light, moderate, vigorous }

class CardioEntry {
  final CardioType type;
  final CardioIntensity intensity;
  final int durationMinutes;
  final double? distanceKm;
  final String? notes;
  final double? estimatedCalories;

  CardioEntry({
    required this.type,
    required this.intensity,
    required this.durationMinutes,
    this.distanceKm,
    String? notes,
    this.estimatedCalories,
  }) : notes = _normalizeNotes(notes) {
    if (durationMinutes <= 0) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'Duration must be greater than zero.',
      );
    }

    if (distanceKm != null && (!distanceKm!.isFinite || distanceKm! < 0)) {
      throw ArgumentError.value(
        distanceKm,
        'distanceKm',
        'Distance must be finite and not negative.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'intensity': intensity.name,
      'durationMinutes': durationMinutes,
      'distanceKm': distanceKm,
      'notes': notes,
      'estimatedCalories': estimatedCalories,
    };
  }

  factory CardioEntry.fromJson(Map<String, dynamic> json) {
    return CardioEntry(
      type: CardioType.values.byName(json['type'] as String),
      intensity: CardioIntensity.values.byName(json['intensity'] as String),
      durationMinutes: json['durationMinutes'] as int,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      estimatedCalories: (json['estimatedCalories'] as num?)?.toDouble(),
    );
  }

  static String? _normalizeNotes(String? notes) {
    final normalized = notes?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}

const Map<CardioType, List<double>> _cardioMetValues = {
  CardioType.walking: [2.8, 3.8, 5.0],
  CardioType.running: [6.0, 8.3, 10.0],
  CardioType.exerciseBike: [3.5, 6.0, 8.0],
  CardioType.elliptical: [4.5, 5.5, 7.0],
  CardioType.treadmillWalking: [2.8, 4.3, 6.0],
  CardioType.treadmillRunning: [6.0, 8.3, 10.0],
};

double cardioMet(CardioType type, CardioIntensity intensity) {
  final intensityValues = _cardioMetValues[type];

  if (intensityValues == null) {
    throw ArgumentError.value(
      type,
      'type',
      'No MET values are configured for this CardioType.',
    );
  }

  return intensityValues[intensity.index];
}

double estimateCardioCalories({
  required CardioType type,
  required CardioIntensity intensity,
  required int durationMinutes,
  required double bodyWeightKg,
}) {
  if (durationMinutes <= 0) {
    throw ArgumentError.value(
      durationMinutes,
      'durationMinutes',
      'Duration must be greater than zero.',
    );
  }

  if (bodyWeightKg <= 0) {
    throw ArgumentError.value(
      bodyWeightKg,
      'bodyWeightKg',
      'Body weight must be greater than zero.',
    );
  }

  final met = cardioMet(type, intensity);

  return met * 3.5 * bodyWeightKg / 200 * durationMinutes;
}
