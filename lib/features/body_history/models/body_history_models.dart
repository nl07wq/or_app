enum BodyHistorySource { status, aggregateRecords, aggregateLegacyDns }

enum BodyHistoryMetric {
  weight('WEIGHT', 'kg'),
  bodyFat('BODY FAT', '%');

  const BodyHistoryMetric(this.label, this.unit);

  final String label;
  final String unit;
}

enum BodyHistoryGranularity {
  daily('日次実測値'),
  weekly('週平均'),
  monthly('月平均');

  const BodyHistoryGranularity(this.label);

  final String label;
}

enum BodyHistoryPeriod {
  oneWeek('1週間'),
  fifteenDays('15日'),
  oneMonth('1か月'),
  threeMonths('3か月'),
  sixMonths('6か月'),
  oneYear('1年'),
  allTime('全期間'),
  custom('指定期間');

  const BodyHistoryPeriod(this.label);

  final String label;
}

class BodyHistoryDataPoint {
  final String operationDate;
  final double? weightKg;
  final double? bodyFatPercent;
  final BodyHistorySource source;

  const BodyHistoryDataPoint({
    required this.operationDate,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.source,
  });

  double? valueFor(BodyHistoryMetric metric) => switch (metric) {
    BodyHistoryMetric.weight => weightKg,
    BodyHistoryMetric.bodyFat => bodyFatPercent,
  };
}

class BodyHistoryDisplayPoint {
  final double x;
  final double value;
  final String startDate;
  final String endDate;
  final int measurementCount;

  const BodyHistoryDisplayPoint({
    required this.x,
    required this.value,
    required this.startDate,
    required this.endDate,
    required this.measurementCount,
  });
}

class BodyHistorySummary {
  final double first;
  final double latest;
  final double change;
  final double maximum;
  final double minimum;
  final int measurementCount;

  const BodyHistorySummary({
    required this.first,
    required this.latest,
    required this.change,
    required this.maximum,
    required this.minimum,
    required this.measurementCount,
  });
}

class BodyHistoryAxisRange {
  final double minimum;
  final double maximum;
  final double interval;

  const BodyHistoryAxisRange({
    required this.minimum,
    required this.maximum,
    required this.interval,
  });
}

class BodyHistoryChartModel {
  final BodyHistoryMetric metric;
  final BodyHistoryGranularity granularity;
  final String startDate;
  final String endDate;
  final List<BodyHistoryDisplayPoint> points;
  final List<List<BodyHistoryDisplayPoint>> segments;
  final BodyHistorySummary? summary;
  final BodyHistoryAxisRange? axis;

  BodyHistoryChartModel({
    required this.metric,
    required this.granularity,
    required this.startDate,
    required this.endDate,
    required Iterable<BodyHistoryDisplayPoint> points,
    required Iterable<List<BodyHistoryDisplayPoint>> segments,
    required this.summary,
    required this.axis,
  }) : points = List.unmodifiable(points),
       segments = List.unmodifiable(
         segments.map(List<BodyHistoryDisplayPoint>.unmodifiable),
       );
}
