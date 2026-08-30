import 'dart:math' as math;

import '../models/body_history_models.dart';

class HistoryDisplayObservation {
  final DateTime date;
  final double value;

  const HistoryDisplayObservation({required this.date, required this.value});
}

class HistoryDisplayPointCompression {
  final int bucketDays;
  final List<BodyHistoryDisplayPoint> points;
  final List<List<BodyHistoryDisplayPoint>> segments;

  HistoryDisplayPointCompression({
    required this.bucketDays,
    required Iterable<BodyHistoryDisplayPoint> points,
    required Iterable<List<BodyHistoryDisplayPoint>> segments,
  }) : points = List.unmodifiable(points),
       segments = List.unmodifiable(
         segments.map(List<BodyHistoryDisplayPoint>.unmodifiable),
       );
}

class HistoryDisplayPointCompressor {
  static const double minimumReadablePointSpacing = 24;

  const HistoryDisplayPointCompressor();

  HistoryDisplayPointCompression compress({
    required List<HistoryDisplayObservation> observations,
    required BodyHistoryPeriod period,
    required String rangeStartDate,
    required String rangeEndDate,
    required double availablePlotWidth,
  }) {
    if (observations.isEmpty) {
      return HistoryDisplayPointCompression(
        bucketDays: 1,
        points: const [],
        segments: const [],
      );
    }
    final sorted = [...observations]
      ..sort((first, second) => first.date.compareTo(second.date));
    final requestedStart = _parse(rangeStartDate);
    final requestedEnd = _parse(rangeEndDate);
    final bucketDays = _bucketDays(
      period: period,
      start: period == BodyHistoryPeriod.allTime
          ? sorted.first.date
          : requestedStart,
      end: period == BodyHistoryPeriod.allTime ? sorted.last.date : requestedEnd,
      availablePlotWidth: availablePlotWidth,
    );
    final bucketOrigin = period == BodyHistoryPeriod.allTime
        ? sorted.first.date
        : requestedStart;
    final bucketRangeEnd = period == BodyHistoryPeriod.allTime
        ? sorted.last.date
        : requestedEnd;
    final viewportStart = sorted.first.date;
    final grouped = <int, List<HistoryDisplayObservation>>{};
    for (final observation in sorted) {
      final elapsedDays = observation.date.difference(bucketOrigin).inDays;
      final bucketIndex = elapsedDays ~/ bucketDays;
      grouped.putIfAbsent(bucketIndex, () => []).add(observation);
    }
    final bucketIndexes = grouped.keys.toList()..sort();
    final points = <BodyHistoryDisplayPoint>[
      for (final bucketIndex in bucketIndexes)
        _point(
          observations: grouped[bucketIndex]!,
          bucketStart: bucketOrigin.add(
            Duration(days: bucketIndex * bucketDays),
          ),
          bucketEnd: _minimumDate(
            bucketOrigin.add(
              Duration(days: (bucketIndex + 1) * bucketDays - 1),
            ),
            bucketRangeEnd,
          ),
          viewportStart: viewportStart,
        ),
    ];
    return HistoryDisplayPointCompression(
      bucketDays: bucketDays,
      points: points,
      segments: _segments(points, bucketDays),
    );
  }

  static int _bucketDays({
    required BodyHistoryPeriod period,
    required DateTime start,
    required DateTime end,
    required double availablePlotWidth,
  }) => switch (period) {
    BodyHistoryPeriod.oneWeek ||
    BodyHistoryPeriod.fifteenDays ||
    BodyHistoryPeriod.oneMonth => 1,
    BodyHistoryPeriod.threeMonths => 5,
    BodyHistoryPeriod.sixMonths => 10,
    BodyHistoryPeriod.oneYear => 15,
    BodyHistoryPeriod.allTime || BodyHistoryPeriod.custom => math.max(
      1,
      ((end.difference(start).inDays + 1) /
              math.max(
                2,
                (availablePlotWidth / minimumReadablePointSpacing)
                    .floor(),
              ))
          .ceil(),
    ),
  };

  static BodyHistoryDisplayPoint _point({
    required List<HistoryDisplayObservation> observations,
    required DateTime bucketStart,
    required DateTime bucketEnd,
    required DateTime viewportStart,
  }) {
    final representative = observations.last;
    return BodyHistoryDisplayPoint(
      x: representative.date.difference(viewportStart).inDays.toDouble(),
      value: representative.value,
      startDate: _format(bucketStart),
      endDate: _format(bucketEnd),
      representativeDate: _format(representative.date),
      measurementCount: observations.length,
    );
  }

  static List<List<BodyHistoryDisplayPoint>> _segments(
    List<BodyHistoryDisplayPoint> points,
    int bucketDays,
  ) {
    if (points.isEmpty) return const [];
    final result = <List<BodyHistoryDisplayPoint>>[];
    var current = <BodyHistoryDisplayPoint>[points.first];
    for (var index = 1; index < points.length; index += 1) {
      final previousBucketStart = _parse(points[index - 1].startDate);
      final nextBucketStart = _parse(points[index].startDate);
      if (nextBucketStart !=
          previousBucketStart.add(Duration(days: bucketDays))) {
        result.add(current);
        current = <BodyHistoryDisplayPoint>[];
      }
      current.add(points[index]);
    }
    result.add(current);
    return result;
  }

  static DateTime _minimumDate(DateTime first, DateTime second) =>
      first.isBefore(second) ? first : second;

  static DateTime _parse(String value) =>
      DateTime.parse('${value}T00:00:00Z');

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
