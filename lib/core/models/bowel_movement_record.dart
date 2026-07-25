enum BowelMovementStatus { unconfirmed, none, recorded }

class BowelMovementRecord {
  final BowelMovementStatus status;
  final int? amount;
  final int? shape;

  const BowelMovementRecord.unconfirmed()
    : status = BowelMovementStatus.unconfirmed,
      amount = null,
      shape = null;

  const BowelMovementRecord.none()
    : status = BowelMovementStatus.none,
      amount = null,
      shape = null;

  const BowelMovementRecord._({
    required this.status,
    required this.amount,
    required this.shape,
  });

  factory BowelMovementRecord.recorded({
    required int amount,
    required int shape,
  }) {
    if (amount < 1 || amount > 3) {
      throw ArgumentError.value(amount, 'amount', 'must be between 1 and 3');
    }
    if (shape < 1 || shape > 3) {
      throw ArgumentError.value(shape, 'shape', 'must be between 1 and 3');
    }
    return BowelMovementRecord._(
      status: BowelMovementStatus.recorded,
      amount: amount,
      shape: shape,
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
      amount: amount,
      shape: shape == null ? null : shape + 1,
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
      amount: null,
      shape: null,
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
    if (amount != null) 'amount': amount,
    if (shape != null) 'shape': shape,
  };

  factory BowelMovementRecord.fromJson(Map<String, dynamic> json) {
    final status = BowelMovementStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => BowelMovementStatus.unconfirmed,
    );
    return BowelMovementRecord._(
      status: status,
      amount: (json['amount'] as num?)?.toInt(),
      shape: (json['shape'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BowelMovementRecord &&
      status == other.status &&
      amount == other.amount &&
      shape == other.shape;

  @override
  int get hashCode => Object.hash(status, amount, shape);
}
