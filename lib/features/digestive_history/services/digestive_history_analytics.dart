import '../models/digestive_history_models.dart';

class DigestiveHistoryAnalytics {
  const DigestiveHistoryAnalytics();

  DigestivePeriodSummary summarize(List<DigestiveDaySummary> days) {
    final ordered = [...days]
      ..sort((a, b) => a.operationDate.compareTo(b.operationDate));
    final known = ordered.where((day) => day.isKnown).toList();
    final exact = ordered.where((day) => day.countKnown).toList();
    final exactYes = exact
        .where((day) => day.state == DigestiveDayState.yes)
        .toList();
    final amount = _distribution(ordered, (event) => event.amount);
    final form = _distribution(ordered, (event) => event.shape);
    final relief = _distribution(ordered, (event) => event.relief);
    final latest = ordered.lastWhere(
      (day) => day.state == DigestiveDayState.yes,
      orElse: () => const DigestiveDaySummary(
        operationDate: '',
        state: DigestiveDayState.unknown,
        source: DigestiveHistorySource.none,
        quality: DigestiveDataQuality.unknown,
        countKnown: false,
      ),
    );
    final total = exact.fold<int>(0, (sum, day) => sum + (day.exactCount ?? 0));
    return DigestivePeriodSummary(
      days: List.unmodifiable(ordered),
      calendarDays: ordered.length,
      knownDays: known.length,
      yesDays: known.where((day) => day.state == DigestiveDayState.yes).length,
      confirmedNoDays: known
          .where((day) => day.state == DigestiveDayState.confirmedNo)
          .length,
      unknownDays: ordered
          .where((day) => day.quality == DigestiveDataQuality.unknown)
          .length,
      invalidDays: ordered
          .where((day) => day.quality == DigestiveDataQuality.invalid)
          .length,
      exactCountDays: exact.length,
      totalExactEvents: total,
      maximumDailyExactCount: exact.isEmpty
          ? null
          : exact.map((day) => day.exactCount!).reduce((a, b) => a > b ? a : b),
      averagePerExactCountDay: exact.isEmpty ? null : total / exact.length,
      averagePerYesExactCountDay: exactYes.isEmpty
          ? null
          : exactYes.fold<int>(0, (sum, day) => sum + day.exactCount!) /
                exactYes.length,
      currentConfirmedNoStreak: _currentNoStreak(ordered),
      longestConfirmedNoStreak: _longestNoStreak(ordered),
      latestConfirmedBmDate: latest.operationDate.isEmpty
          ? null
          : latest.operationDate,
      daysSinceLatestConfirmedBmDate:
          latest.operationDate.isEmpty || ordered.isEmpty
          ? null
          : DateTime.parse(
              ordered.last.operationDate,
            ).difference(DateTime.parse(latest.operationDate)).inDays,
      amountDistribution: amount,
      formDistribution: form,
      reliefDistribution: relief,
    );
  }

  DigestiveDistribution _distribution(
    List<DigestiveDaySummary> days,
    int? Function(DigestiveEventSummary event) field,
  ) {
    final known = <int, int>{};
    var missing = 0;
    for (final event in days.expand((day) => day.events)) {
      final value = field(event);
      if (value == null) {
        missing++;
      } else {
        known[value] = (known[value] ?? 0) + 1;
      }
    }
    return DigestiveDistribution(
      knownCounts: Map.unmodifiable(known),
      missingCount: missing,
    );
  }

  int _currentNoStreak(List<DigestiveDaySummary> days) {
    var count = 0;
    for (final day in days.reversed) {
      if (day.state != DigestiveDayState.confirmedNo) break;
      count++;
    }
    return count;
  }

  int _longestNoStreak(List<DigestiveDaySummary> days) {
    var current = 0;
    var longest = 0;
    for (final day in days) {
      if (day.state == DigestiveDayState.confirmedNo) {
        longest = (current += 1) > longest ? current : longest;
      } else {
        current = 0;
      }
    }
    return longest;
  }
}
