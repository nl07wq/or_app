class OperationLocalDate implements Comparable<OperationLocalDate> {
  final String value;

  OperationLocalDate._(this.value);

  factory OperationLocalDate.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid operation date.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid operation date.');
    }
    return OperationLocalDate._(value);
  }

  factory OperationLocalDate.fromDateTime(DateTime value) {
    final local = value.toLocal();
    return OperationLocalDate._(
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}',
    );
  }

  DateTime get asUtcDate {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  OperationLocalDate addDays(int days) {
    final next = asUtcDate.add(Duration(days: days));
    return OperationLocalDate._(
      '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}-'
      '${next.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  int compareTo(OperationLocalDate other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is OperationLocalDate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
