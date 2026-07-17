class WorkCalculator {
  const WorkCalculator._();

  static double calculate({
    required String start,
    required String end,
    required String workBreak,
  }) {
    final startHour = _toHours(start);
    final endHour = _toHours(end);
    final breakHour = _toHours(workBreak);

    if (startHour == null || endHour == null || breakHour == null) {
      return 0;
    }

    double work = endHour - startHour;

    // 日跨ぎ対応
    if (work < 0) {
      work += 24;
    }

    work -= breakHour;

    if (work < 0) {
      work = 0;
    }

    return work;
  }

  static double? _toHours(String value) {
    final parts = value.split(":");

    if (parts.length != 2) return null;

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);

    if (h == null || m == null) {
      return null;
    }

    return h + m / 60;
  }

  static String format(double hours) {
    final totalMinutes = (hours * 60).round();

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }
}
