class MorningInitialValues {
  final String weight;
  final String bodyFat;
  final String sleep;
  final String sleepScore;

  const MorningInitialValues({
    required this.weight,
    required this.bodyFat,
    required this.sleep,
    required this.sleepScore,
  });

  const MorningInitialValues.empty()
    : weight = '',
      bodyFat = '',
      sleep = '',
      sleepScore = '';
}
