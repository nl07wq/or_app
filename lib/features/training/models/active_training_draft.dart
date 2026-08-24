import '../../../core/models/training_session_v2.dart';

class ActiveTrainingDraft {
  static const legacyVersion = 1;
  static const entryStateVersion = 2;
  static const currentVersion = 3;

  final String id;
  final int version;
  final String operationDate;
  final String? startTime;
  final String? endTime;
  final Map<String, Object?>? entryState;

  ActiveTrainingDraft({
    String? id,
    this.version = currentVersion,
    required this.operationDate,
    this.startTime,
    this.endTime,
    this.entryState,
  }) : id = id ?? draftId(operationDate) {
    _validateOperationDate(operationDate);
    if (this.id != draftId(operationDate) ||
        (version != legacyVersion &&
            version != entryStateVersion &&
            version != currentVersion) ||
        (version == legacyVersion && entryState != null) ||
        (version >= entryStateVersion && entryState == null) ||
        (version < currentVersion && startTime == null) ||
        (startTime == null && endTime != null)) {
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
    if (version >= entryStateVersion) 'entryState': entryState,
  };

  factory ActiveTrainingDraft.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final version = record['version'];
    final operationDate = record['operationDate'];
    final startTime = record['startTime'];
    final endTime = record['endTime'];
    final entryState = record['entryState'];
    if (id is! String ||
        version is! int ||
        operationDate is! String ||
        (startTime != null && startTime is! String) ||
        (endTime != null && endTime is! String) ||
        (entryState != null && entryState is! Map)) {
      throw const FormatException('Invalid Active Training Draft record.');
    }
    return ActiveTrainingDraft(
      id: id,
      version: version,
      operationDate: operationDate,
      startTime: startTime as String?,
      endTime: endTime as String?,
      entryState: entryState == null
          ? null
          : Map<String, Object?>.from(entryState as Map),
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
