import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';

void main() {
  group('DashboardNeonFaultPatterns', () {
    test('provides four irregular plans which always recover fully', () {
      expect(
        DashboardNeonFaultPatterns.patterns,
        hasLength(greaterThanOrEqualTo(4)),
      );

      for (final plan in DashboardNeonFaultPatterns.patterns) {
        expect(plan.first.isFullyIlluminated, isTrue);
        expect(plan.last.isFullyIlluminated, isTrue);
        expect(plan.skip(1).any((phase) => !phase.isFullyIlluminated), isTrue);

        final duration = plan.fold<Duration>(
          Duration.zero,
          (total, phase) => total + phase.duration,
        );
        expect(
          duration,
          greaterThanOrEqualTo(const Duration(milliseconds: 150)),
        );
        expect(duration, lessThanOrEqualTo(const Duration(milliseconds: 600)));

        for (final phase in plan) {
          expect(phase.coreIntensity, inInclusiveRange(0, 1));
          expect(phase.innerGlowIntensity, inInclusiveRange(0, 1));
          expect(phase.outerGlowIntensity, inInclusiveRange(0, 1));
          expect(phase.logoIntensity, inInclusiveRange(0, 1));
          if (phase.duration != Duration.zero) {
            expect(
              phase.duration.inMilliseconds,
              inInclusiveRange(
                25,
                140,
              ),
            );
          }
        }
      }
    });

    test('chooses only bounded low-frequency event intervals', () {
      final random = math.Random(42);
      for (var index = 0; index < 100; index++) {
        final interval = DashboardNeonFaultPatterns.intervalFor(random);
        expect(
          interval,
          greaterThanOrEqualTo(DashboardNeonFaultPatterns.minimumInterval),
        );
        expect(
          interval,
          lessThanOrEqualTo(DashboardNeonFaultPatterns.maximumInterval),
        );
      }
    });
  });
}
