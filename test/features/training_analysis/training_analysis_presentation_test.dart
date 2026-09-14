import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training_analysis/services/training_analysis_presentation.dart';

void main() {
  group('TrainingAnalysisPresentation.recentHistoryDates', () {
    test('uses compact month/day dates in the newest displayed year', () {
      expect(
        TrainingAnalysisPresentation.recentHistoryDates(const [
          '2026-09-08',
          '2026-08-31',
          '2026-08-18',
          '2026-08-16',
          '2026-08-10',
        ]),
        '9/8 | 8/31 | 8/18 | 8/16 | 8/10',
      );
    });

    test('keeps years outside the newest displayed year', () {
      expect(
        TrainingAnalysisPresentation.recentHistoryDates(const [
          '2026-09-08',
          '2026-08-31',
          '2025-08-16',
          '2024-08-10',
        ]),
        '9/8 | 8/31 | 2025/8/16 | 2024/8/10',
      );
    });

    test('uses the newest displayed date instead of the current year', () {
      expect(
        TrainingAnalysisPresentation.recentHistoryDates(const [
          '2026-09-08',
          '2026-08-31',
          '2025-08-16',
        ]),
        '9/8 | 8/31 | 2025/8/16',
      );
    });

    test('preserves order through a calendar-year boundary', () {
      expect(
        TrainingAnalysisPresentation.recentHistoryDates(const [
          '2026-01-05',
          '2025-12-28',
          '2025-12-20',
        ]),
        '1/5 | 2025/12/28 | 2025/12/20',
      );
    });

    test('formats a single date without a delimiter', () {
      expect(
        TrainingAnalysisPresentation.recentHistoryDates(const ['2026-09-08']),
        '9/8',
      );
    });
  });
}
