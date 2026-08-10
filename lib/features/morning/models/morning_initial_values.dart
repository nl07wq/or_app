class MorningInitialValues {
  final String weight;
  final String bodyFat;
  final String sleep;
  final String sleepScore;
  final bool hasPreviousRecord;

  const MorningInitialValues({
    required this.weight,
    required this.bodyFat,
    required this.sleep,
    required this.sleepScore,
    this.hasPreviousRecord = false,
  });

  const MorningInitialValues.empty()
    : weight = '',
      bodyFat = '',
      sleep = '',
      sleepScore = '',
      hasPreviousRecord = false;
}
