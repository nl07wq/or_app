enum PersonalRecordStatus { newRecord, currentRecord }

class PersonalRecordResult {
  final double highestWeight;
  final int highestRepetitions;
  final PersonalRecordStatus status;

  const PersonalRecordResult({
    required this.highestWeight,
    required this.highestRepetitions,
    required this.status,
  });
}
