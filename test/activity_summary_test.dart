import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/activity_data.dart';

void main() {
  test('empty activity summary is distinguishable from a zero-step record', () {
    const summary = ActivitySummary.empty();

    expect(summary.steps, 0);
    expect(summary.isRecorded, isFalse);
  });

  test('activity summary preserves recorded zero steps', () {
    final summary = ActivitySummary.fromActivityData(
      ActivityData(date: DateTime(2026, 7, 21), steps: 0),
    );

    expect(summary.steps, 0);
    expect(summary.isRecorded, isTrue);
  });

  test('activity summary maps saved steps', () {
    final summary = ActivitySummary.fromActivityData(
      ActivityData(date: DateTime(2026, 7, 21), steps: 8420),
    );

    expect(summary.steps, 8420);
    expect(summary.isRecorded, isTrue);
  });
}
