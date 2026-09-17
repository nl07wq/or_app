import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';

void main() {
  group('DashboardNeonTubeGeometry', () {
    test(
      'uses industrial condensed monoline glyph and baseline period geometry',
      () {
        expect(
          DashboardNeonTubeGeometry.glyphHeight,
          greaterThan(DashboardNeonTubeGeometry.ovalWidth),
        );
        expect(DashboardNeonTubeGeometry.ovalWidth, greaterThan(9));
        expect(
          DashboardNeonTubeGeometry.ovalWidth /
              DashboardNeonTubeGeometry.glyphHeight,
          inInclusiveRange(.6, .72),
        );
        expect(DashboardNeonTubeGeometry.rWidth, lessThanOrEqualTo(12));
        expect(DashboardNeonTubeGeometry.lFootWidth, lessThanOrEqualTo(9));
        expect(DashboardNeonTubeGeometry.signWidth, 118);
        expect(
          DashboardNeonTubeGeometry.wordmarkPaintRight -
              DashboardNeonTubeGeometry.wordmarkPaintLeft,
          59,
        );
        expect(DashboardNeonTubeGeometry.tubeWidth, lessThanOrEqualTo(2.2));
        expect(
          DashboardNeonTubeGeometry.hotCoreWidth,
          lessThan(DashboardNeonTubeGeometry.tubeWidth),
        );
        expect(DashboardNeonTubeGeometry.periodCenters, hasLength(3));
        for (final center in DashboardNeonTubeGeometry.periodCenters) {
          expect(
            center.dy,
            greaterThan(DashboardNeonTubeGeometry.wordmarkHeight / 2),
          );
        }
        expect(DashboardNeonTubeGeometry.periodRadius, lessThan(.5));
      },
    );

    test('keeps the luminous perimeter parallel and subordinate', () {
      expect(
        DashboardNeonTubeGeometry.physicalFrameRadius -
            DashboardNeonTubeGeometry.perimeterInset,
        DashboardNeonTubeGeometry.perimeterRadius,
      );
      expect(DashboardNeonTubeGeometry.perimeterInset, 2);
    });
  });

  group('DashboardNeonFaultPatterns', () {
    test('provides irregular plans which always recover fully', () {
      expect(
        DashboardNeonFaultPatterns.families,
        hasLength(greaterThanOrEqualTo(6)),
      );
      expect(
        DashboardNeonFaultPatterns.families.any(
          (family) => family.name == 'failed_shared_restrike',
        ),
        isTrue,
      );
      expect(
        DashboardNeonFaultPatterns.families.any(
          (family) => family.name == 'staged_logo_first_recovery',
        ),
        isTrue,
      );

      for (final family in DashboardNeonFaultPatterns.families) {
        expect(family.weight, greaterThan(0));
        final plan = family.phases;
        expect(plan.first.isFullyIlluminated, isTrue);
        expect(plan.last.isFullyIlluminated, isTrue);
        expect(plan.skip(1).any((phase) => !phase.isFullyIlluminated), isTrue);

        final duration = plan.fold<Duration>(
          Duration.zero,
          (total, phase) => total + phase.duration,
        );
        expect(
          duration,
          greaterThanOrEqualTo(const Duration(milliseconds: 350)),
        );
        expect(duration, lessThanOrEqualTo(const Duration(milliseconds: 900)));

        for (final phase in plan) {
          expect(phase.coreIntensity, inInclusiveRange(0, 1));
          expect(phase.innerGlowIntensity, inInclusiveRange(0, 1));
          expect(phase.outerGlowIntensity, inInclusiveRange(0, 1));
          expect(phase.logoIntensity, inInclusiveRange(0, 1));
          expect(phase.frameTubeIntensity, inInclusiveRange(0, 1));
          expect(phase.frameReflectionIntensity, inInclusiveRange(0, 1));
          if (phase.duration != Duration.zero) {
            expect(phase.duration.inMilliseconds, inInclusiveRange(25, 220));
          }
        }
      }
    });

    test(
      'fault plans are multi-channel rather than binary blink sequences',
      () {
        for (final family in DashboardNeonFaultPatterns.families) {
          final activePhases = family.phases.where(
            (phase) => phase.duration != Duration.zero,
          );
          expect(
            activePhases.any(
              (phase) =>
                  phase.coreIntensity != phase.logoIntensity ||
                  phase.frameTubeIntensity != phase.coreIntensity ||
                  phase.outerGlowIntensity != phase.coreIntensity,
            ),
            isTrue,
          );
          expect(
            activePhases.map((phase) => phase.duration).toSet().length,
            greaterThan(1),
          );
        }
      },
    );

    test('includes failed restrike and staged logo-first recovery', () {
      final failedRestrike = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'failed_shared_restrike',
      );
      final restrikeAttempt = failedRestrike.phases.indexWhere(
        (phase) => phase.coreIntensity > .5 && phase.coreIntensity < 1,
      );
      expect(restrikeAttempt, greaterThanOrEqualTo(0));
      expect(
        failedRestrike.phases
            .skip(restrikeAttempt + 1)
            .any((phase) => phase.coreIntensity < .2),
        isTrue,
      );

      final stagedRecovery = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'staged_logo_first_recovery',
      );
      expect(
        stagedRecovery.phases.any(
          (phase) => phase.logoIntensity > phase.coreIntensity + .35,
        ),
        isTrue,
      );
    });

    test('logo channel supports shared, independent, and partial failures', () {
      final shared = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'shared_transformer_dip',
      );
      expect(
        shared.phases.any(
          (phase) => phase.coreIntensity < .1 && phase.logoIntensity < .1,
        ),
        isTrue,
      );
      final logoOnly = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'logo_emblem_contact',
      );
      expect(
        logoOnly.phases.any(
          (phase) => phase.coreIntensity > .8 && phase.logoIntensity < .1,
        ),
        isTrue,
      );
      final wordmarkOnly = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'wordmark_tube_instability',
      );
      expect(
        wordmarkOnly.phases.any(
          (phase) => phase.coreIntensity < .1 && phase.logoIntensity > .3,
        ),
        isTrue,
      );
    });

    test('neon perimeter has a dedicated rare contact-fault channel', () {
      final frameOnly = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'frame_perimeter_contact',
      );
      expect(frameOnly.weight, lessThan(10));
      expect(
        frameOnly.phases.any(
          (phase) =>
              phase.coreIntensity > .8 &&
              phase.logoIntensity > .6 &&
              phase.frameTubeIntensity < .1,
        ),
        isTrue,
      );

      final shared = DashboardNeonFaultPatterns.families.firstWhere(
        (family) => family.name == 'shared_transformer_dip',
      );
      expect(
        shared.phases.any(
          (phase) =>
              phase.coreIntensity < .1 &&
              phase.logoIntensity < .1 &&
              phase.frameTubeIntensity < .1,
        ),
        isTrue,
      );
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
