class TrainingSummary {
  final bool completed;
  final int exerciseCount;
  final int setCount;
  final Duration? duration;
  final String? sessionName;

  const TrainingSummary({
    required this.completed,
    required this.exerciseCount,
    required this.setCount,
    required this.duration,
    required this.sessionName,
  });

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'exerciseCount': exerciseCount,
    'setCount': setCount,
    'duration': duration?.inMicroseconds,
    'sessionName': sessionName,
  };

  factory TrainingSummary.fromJson(Map<String, dynamic> json) => TrainingSummary(
    completed: json['completed'] as bool,
    exerciseCount: json['exerciseCount'] as int,
    setCount: json['setCount'] as int,
    duration: (json['duration'] as int?) == null
        ? null
        : Duration(microseconds: json['duration'] as int),
    sessionName: json['sessionName'] as String?,
  );
}
