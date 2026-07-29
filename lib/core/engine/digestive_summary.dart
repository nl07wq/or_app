import '../models/digestive_event.dart';

class DigestiveSummary {
  final int eventCount;
  final int totalAmount;
  final int? latestShape;
  final int? latestRelief;
  final List<int> shapeTrend;
  final List<int> reliefTrend;
  final bool hasExplicitNoMovement;

  DigestiveSummary({
    required this.eventCount,
    required this.totalAmount,
    required this.latestShape,
    required this.latestRelief,
    required Iterable<int> shapeTrend,
    required Iterable<int> reliefTrend,
    this.hasExplicitNoMovement = false,
  }) : shapeTrend = List<int>.unmodifiable(shapeTrend),
       reliefTrend = List<int>.unmodifiable(reliefTrend) {
    if (eventCount < 0 ||
        totalAmount < eventCount ||
        totalAmount > eventCount * 3 ||
        this.shapeTrend.length != eventCount ||
        this.reliefTrend.length != eventCount ||
        (hasExplicitNoMovement && eventCount != 0) ||
        (eventCount == 0 && (latestShape != null || latestRelief != null)) ||
        (eventCount > 0 &&
            (latestShape != this.shapeTrend.last ||
                latestRelief != this.reliefTrend.last)) ||
        this.shapeTrend.any((value) => value < 1 || value > 3) ||
        this.reliefTrend.any((value) => value < 0 || value > 2)) {
      throw const FormatException('Invalid digestive summary.');
    }
  }

  factory DigestiveSummary.fromEvents(Iterable<DigestiveEvent> events) {
    final ordered = DigestiveEvent.normalizeAndValidate(events);
    final movements = ordered.where((event) => event.amount > 0).toList();
    return DigestiveSummary(
      eventCount: movements.length,
      totalAmount: movements.fold(0, (total, event) => total + event.amount),
      latestShape: movements.isEmpty ? null : movements.last.shape,
      latestRelief: movements.isEmpty ? null : movements.last.relief,
      shapeTrend: movements.map((event) => event.shape!),
      reliefTrend: movements.map((event) => event.relief!),
      hasExplicitNoMovement:
          movements.isEmpty && ordered.any((event) => event.amount == 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'eventCount': eventCount,
    'totalAmount': totalAmount,
    if (latestShape != null) 'latestShape': latestShape,
    if (latestRelief != null) 'latestRelief': latestRelief,
    'shapeTrend': shapeTrend,
    'reliefTrend': reliefTrend,
    'hasExplicitNoMovement': hasExplicitNoMovement,
  };

  factory DigestiveSummary.fromJson(Map<String, dynamic> json) {
    final eventCount = json['eventCount'];
    final totalAmount = json['totalAmount'];
    final latestShape = json['latestShape'];
    final latestRelief = json['latestRelief'];
    final shapeTrend = json['shapeTrend'];
    final reliefTrend = json['reliefTrend'];
    final hasExplicitNoMovement = json['hasExplicitNoMovement'];
    if (eventCount is! int ||
        totalAmount is! int ||
        (latestShape != null && latestShape is! int) ||
        (latestRelief != null && latestRelief is! int) ||
        shapeTrend is! List ||
        reliefTrend is! List ||
        (hasExplicitNoMovement != null && hasExplicitNoMovement is! bool) ||
        shapeTrend.any((value) => value is! int) ||
        reliefTrend.any((value) => value is! int)) {
      throw const FormatException('Invalid digestive summary.');
    }
    return DigestiveSummary(
      eventCount: eventCount,
      totalAmount: totalAmount,
      latestShape: latestShape as int?,
      latestRelief: latestRelief as int?,
      shapeTrend: shapeTrend.cast<int>(),
      reliefTrend: reliefTrend.cast<int>(),
      hasExplicitNoMovement: hasExplicitNoMovement as bool? ?? false,
    );
  }
}
