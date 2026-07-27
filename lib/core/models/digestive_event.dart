class DigestiveEvent {
  final String id;
  final int sequence;
  final int amount;
  final int shape;
  final int relief;
  final DateTime recordedAt;

  DigestiveEvent({
    required this.id,
    required this.sequence,
    required this.amount,
    required this.shape,
    required this.relief,
    required this.recordedAt,
  }) {
    _validate(
      id: id,
      sequence: sequence,
      amount: amount,
      shape: shape,
      relief: relief,
    );
  }

  DigestiveEvent copyWith({
    String? id,
    int? sequence,
    int? amount,
    int? shape,
    int? relief,
    DateTime? recordedAt,
  }) {
    return DigestiveEvent(
      id: id ?? this.id,
      sequence: sequence ?? this.sequence,
      amount: amount ?? this.amount,
      shape: shape ?? this.shape,
      relief: relief ?? this.relief,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sequence': sequence,
    'amount': amount,
    'shape': shape,
    'relief': relief,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory DigestiveEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final sequence = json['sequence'];
    final amount = json['amount'];
    final shape = json['shape'];
    final relief = json['relief'];
    final recordedAt = json['recordedAt'];
    final parsedRecordedAt = recordedAt is String
        ? DateTime.tryParse(recordedAt)
        : null;

    if (id is! String ||
        sequence is! int ||
        amount is! int ||
        shape is! int ||
        relief is! int ||
        parsedRecordedAt == null) {
      throw const FormatException('Invalid digestive event.');
    }

    try {
      return DigestiveEvent(
        id: id,
        sequence: sequence,
        amount: amount,
        shape: shape,
        relief: relief,
        recordedAt: parsedRecordedAt,
      );
    } on ArgumentError {
      throw const FormatException('Invalid digestive event.');
    }
  }

  static List<DigestiveEvent> normalizeAndValidate(
    Iterable<DigestiveEvent> events,
  ) {
    final ordered = events.toList()
      ..sort((left, right) => left.sequence.compareTo(right.sequence));
    final ids = <String>{};
    for (var index = 0; index < ordered.length; index++) {
      final event = ordered[index];
      if (!ids.add(event.id)) {
        throw const FormatException('Duplicate digestive event ID.');
      }
      if (event.sequence != index + 1) {
        throw const FormatException(
          'Digestive event sequences must be contiguous from 1.',
        );
      }
    }
    return List<DigestiveEvent>.unmodifiable(ordered);
  }

  static String amountLabel(int value) => switch (value) {
    1 => '少量',
    2 => '普通',
    3 => '多量',
    _ => throw ArgumentError.value(value, 'value', 'Invalid amount.'),
  };

  static String shapeLabel(int value) => switch (value) {
    1 => '硬便',
    2 => '普通便',
    3 => '軟便',
    _ => throw ArgumentError.value(value, 'value', 'Invalid shape.'),
  };

  static String reliefLabel(int value) => switch (value) {
    0 => '残便感あり',
    1 => '普通',
    2 => 'スッキリ',
    _ => throw ArgumentError.value(value, 'value', 'Invalid relief.'),
  };

  static void _validate({
    required String id,
    required int sequence,
    required int amount,
    required int shape,
    required int relief,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID must not be empty.');
    }
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'Must be at least 1.');
    }
    if (amount < 1 || amount > 3) {
      throw ArgumentError.value(amount, 'amount', 'Must be from 1 to 3.');
    }
    if (shape < 1 || shape > 3) {
      throw ArgumentError.value(shape, 'shape', 'Must be from 1 to 3.');
    }
    if (relief < 0 || relief > 2) {
      throw ArgumentError.value(relief, 'relief', 'Must be from 0 to 2.');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigestiveEvent &&
          id == other.id &&
          sequence == other.sequence &&
          amount == other.amount &&
          shape == other.shape &&
          relief == other.relief &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode =>
      Object.hash(id, sequence, amount, shape, relief, recordedAt);
}
