enum BowelMovementStatus { unconfirmed, none, recorded }

class BowelMovementRecord {
  final BowelMovementStatus status;
  final int? count;
  final int? amount;
  final int? shape;
  final DateTime? time;
  final String? note;

  const BowelMovementRecord.unconfirmed()
    : status = BowelMovementStatus.unconfirmed,
      count = null,
      amount = null,
      shape = null,
      time = null,
      note = null;

  const BowelMovementRecord.none({this.time, this.note})
    : status = BowelMovementStatus.none,
      count = 0,
      amount = null,
      shape = null;

  const BowelMovementRecord._({
    required this.status,
    required this.count,
    required this.amount,
    required this.shape,
    required this.time,
    required this.note,
  });

  factory BowelMovementRecord.recorded({
    required int count,
    int? amount,
    int? shape,
    DateTime? time,
    String? note,
  }) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be greater than zero');
    }
    return BowelMovementRecord._(
      status: BowelMovementStatus.recorded,
      count: count,
      amount: amount,
      shape: shape,
      time: time,
      note: note,
    );
  }

  factory BowelMovementRecord.fromLegacy({
    required int? amount,
    required int? shape,
  }) {
    if (amount == null && shape == null) {
      return const BowelMovementRecord.unconfirmed();
    }
    if (amount == null || amount <= 0) {
      return const BowelMovementRecord.none();
    }
    return BowelMovementRecord._(
      status: BowelMovementStatus.recorded,
      count: null,
      amount: amount,
      shape: shape,
      time: null,
      note: null,
    );
  }

  factory BowelMovementRecord.fromLegacyText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const BowelMovementRecord.unconfirmed();
    }
    if ({'none', 'no', 'false', '0'}.contains(text.toLowerCase())) {
      return const BowelMovementRecord.none();
    }
    return BowelMovementRecord._(
      status: BowelMovementStatus.recorded,
      count: null,
      amount: null,
      shape: null,
      time: null,
      note: text,
    );
  }

  bool get isConfirmed => status != BowelMovementStatus.unconfirmed;

  bool? get hasMovement => switch (status) {
    BowelMovementStatus.unconfirmed => null,
    BowelMovementStatus.none => false,
    BowelMovementStatus.recorded => true,
  };

  Map<String, dynamic> toJson() => {
    'status': status.name,
    if (count != null) 'count': count,
    if (amount != null) 'amount': amount,
    if (shape != null) 'shape': shape,
    if (time != null) 'time': time!.toIso8601String(),
    if (note != null) 'note': note,
  };

  factory BowelMovementRecord.fromJson(Map<String, dynamic> json) {
    final status = BowelMovementStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => BowelMovementStatus.unconfirmed,
    );
    final timeValue = json['time'];
    return BowelMovementRecord._(
      status: status,
      count: (json['count'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toInt(),
      shape: (json['shape'] as num?)?.toInt(),
      time: timeValue == null ? null : DateTime.parse(timeValue as String),
      note: json['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BowelMovementRecord &&
      status == other.status &&
      count == other.count &&
      amount == other.amount &&
      shape == other.shape &&
      time == other.time &&
      note == other.note;

  @override
  int get hashCode => Object.hash(status, count, amount, shape, time, note);
}
