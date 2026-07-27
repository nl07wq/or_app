class ActivityDraftDigestiveEvent {
  final String id;
  final int sequence;
  final int? amount;
  final int? shape;
  final int? relief;
  final DateTime recordedAt;

  ActivityDraftDigestiveEvent({
    required this.id,
    required this.sequence,
    this.amount,
    this.shape,
    this.relief,
    required this.recordedAt,
  }) {
    if (id.isEmpty ||
        sequence < 1 ||
        (amount != null && (amount! < 1 || amount! > 3)) ||
        (shape != null && (shape! < 1 || shape! > 3)) ||
        (relief != null && (relief! < 0 || relief! > 2))) {
      throw ArgumentError('Invalid ACTIVITY Draft digestive event.');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sequence': sequence,
    if (amount != null) 'amount': amount,
    if (shape != null) 'shape': shape,
    if (relief != null) 'relief': relief,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };

  factory ActivityDraftDigestiveEvent.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final sequence = json['sequence'];
    final amount = json['amount'];
    final shape = json['shape'];
    final relief = json['relief'];
    final recordedAt = _requiredDate(json, 'recordedAt');
    if (id is! String ||
        id.isEmpty ||
        sequence is! int ||
        sequence < 1 ||
        (amount != null && (amount is! int || amount < 1 || amount > 3)) ||
        (shape != null && (shape is! int || shape < 1 || shape > 3)) ||
        (relief != null && (relief is! int || relief < 0 || relief > 2))) {
      throw const FormatException('Invalid ACTIVITY Draft digestive event.');
    }
    return ActivityDraftDigestiveEvent(
      id: id,
      sequence: sequence,
      amount: amount as int?,
      shape: shape as int?,
      relief: relief as int?,
      recordedAt: recordedAt,
    );
  }
}

class ActivityDraft {
  static const currentVersion = 1;

  final String id;
  final int version;
  final String localDate;
  final String measuredStepsInput;
  final String carryOverInput;
  final List<ActivityDraftDigestiveEvent> digestiveEvents;
  final DateTime createdAt;
  final DateTime updatedAt;

  ActivityDraft({
    String? id,
    this.version = currentVersion,
    required this.localDate,
    this.measuredStepsInput = '',
    this.carryOverInput = '',
    Iterable<ActivityDraftDigestiveEvent> digestiveEvents = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : id = id ?? draftId(localDate),
       digestiveEvents = List.unmodifiable(digestiveEvents) {
    validateLocalDate(localDate);
    if (this.id != draftId(localDate) ||
        version != currentVersion ||
        updatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid ACTIVITY Draft envelope.');
    }
    final eventIds = <String>{};
    for (final event in this.digestiveEvents) {
      if (!eventIds.add(event.id)) {
        throw const FormatException(
          'ACTIVITY Draft contains duplicate event IDs.',
        );
      }
    }
  }

  Map<String, Object?> toRecord() => {
    'id': id,
    'version': version,
    'localDate': localDate,
    'measuredStepsInput': measuredStepsInput,
    'carryOverInput': carryOverInput,
    'digestiveEvents': [for (final event in digestiveEvents) event.toJson()],
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ActivityDraft.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final version = record['version'];
    final localDate = record['localDate'];
    final measuredStepsInput = record['measuredStepsInput'];
    final carryOverInput = record['carryOverInput'];
    final digestiveEvents = record['digestiveEvents'];
    if (id is! String ||
        version is! int ||
        localDate is! String ||
        measuredStepsInput is! String ||
        carryOverInput is! String ||
        digestiveEvents is! List) {
      throw const FormatException('Invalid ACTIVITY Draft record.');
    }
    return ActivityDraft(
      id: id,
      version: version,
      localDate: localDate,
      measuredStepsInput: measuredStepsInput,
      carryOverInput: carryOverInput,
      digestiveEvents: [
        for (final event in digestiveEvents)
          if (event is Map)
            ActivityDraftDigestiveEvent.fromJson(
              Map<String, Object?>.from(event),
            )
          else
            throw const FormatException(
              'Invalid ACTIVITY Draft digestive event.',
            ),
      ],
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
    );
  }

  ActivityDraft copyWith({
    String? measuredStepsInput,
    String? carryOverInput,
    Iterable<ActivityDraftDigestiveEvent>? digestiveEvents,
    DateTime? updatedAt,
  }) {
    return ActivityDraft(
      id: id,
      version: version,
      localDate: localDate,
      measuredStepsInput: measuredStepsInput ?? this.measuredStepsInput,
      carryOverInput: carryOverInput ?? this.carryOverInput,
      digestiveEvents: digestiveEvents ?? this.digestiveEvents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String draftId(String localDate) {
    validateLocalDate(localDate);
    return 'activity-draft:$localDate';
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid ACTIVITY Draft localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid ACTIVITY Draft localDate.');
    }
  }
}

DateTime _requiredDate(Map<String, Object?> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw FormatException('Invalid ACTIVITY Draft $key.');
  }
  return parsed;
}
