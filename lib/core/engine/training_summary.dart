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
}
