import '../../../core/models/training_session_v2.dart';

class ActiveTrainingDraft {
  static const currentVersion = 1;

  final String id;
  final int version;
  final String operationDate;
  final String startTime;
  final String? endTime;

  ActiveTrainingDraft({
    String? id,
    this.version = currentVersion,
    required this.operationDate,
    required this.startTime,
    this.endTime,
  }) : id = id ?? draftId(operationDate) {
    _validateOperationDate(operationDate);
    if (this.id != draftId(operationDate) || version != currentVersion) {
      throw const FormatException('Invalid Active Training Draft envelope.');
    }
    try {
      TrainingSessionV2(
        date: operationDate,
        startTime: startTime,
        endTime: endTime,
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid Active Training Draft time.', error);
    }
  }

  Map<String, Object?> toRecord() => {
    'id': id,
    'version': version,
    'operationDate': operationDate,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory ActiveTrainingDraft.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final version = record['version'];
    final operationDate = record['operationDate'];
    final startTime = record['startTime'];
    final endTime = record['endTime'];
    if (id is! String ||
        version is! int ||
        operationDate is! String ||
        startTime is! String ||
        (endTime != null && endTime is! String)) {
      throw const FormatException('Invalid Active Training Draft record.');
    }
    return ActiveTrainingDraft(
      id: id,
      version: version,
      operationDate: operationDate,
      startTime: startTime,
      endTime: endTime as String?,
    );
  }

  static String draftId(String operationDate) {
    _validateOperationDate(operationDate);
    return 'active-training-draft:$operationDate';
  }

  static void _validateOperationDate(String operationDate) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(operationDate);
    if (match == null) {
      throw const FormatException('Invalid Active Training operationDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid Active Training operationDate.');
    }
  }
}
