import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/bird_v1_flight_preview.dart';

void main() {
  test('Bird V1 retains six supplied source cels and a forward flap loop', () {
    expect(BirdV1SourceSet.assets, hasLength(6));
    expect(BirdV1SourceSet.cycle, const [0, 1, 2, 3, 4, 5]);
    expect(BirdV1SourceSet.cycle, isNot(containsAllInOrder([5, 4])));
    expect(BirdV1SourceSet.bobOffsets, hasLength(BirdV1SourceSet.cycle.length));
    expect(
      BirdV1SourceSet.flutterOffsets,
      hasLength(BirdV1SourceSet.cycle.length),
    );
  });

  testWidgets('Bird V1 source cels are registered app assets', (tester) async {
    for (final asset in BirdV1SourceSet.assets) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });

  test(
    'Production tuning frame selection retains only forward source order',
    () {
      expect(
        BirdV1FlightTuning.filteredForwardCycle(const [
          true,
          true,
          false,
          true,
          false,
          true,
        ]),
        const [0, 1, 3, 5],
      );
      expect(BirdV1FlightTuning.nextFrame(const [0, 1, 3, 5], 5), 0);
      expect(BirdV1FlightTuning.minimumFrameCount, 2);
    },
  );

  test(
    'Cadences preserve current timing and Cruise is the rounded Smooth/Glide midpoint',
    () {
      expect(BirdV1FlightTuning.holdsFor(BirdV1Cadence.current), const [
        40,
        40,
        40,
        40,
        40,
        40,
      ]);
      expect(BirdV1FlightTuning.cycleDurationMs(BirdV1Cadence.current), 240);
      expect(BirdV1FlightTuning.cycleDurationMs(BirdV1Cadence.smooth), 370);
      expect(BirdV1FlightTuning.holdsFor(BirdV1Cadence.cruise), const [
        63,
        55,
        58,
        68,
        115,
        125,
      ]);
      expect(BirdV1FlightTuning.cycleDurationMs(BirdV1Cadence.cruise), 484);
      expect(BirdV1FlightTuning.cycleDurationMs(BirdV1Cadence.glide), 595);
      for (var index = 0; index < BirdV1SourceSet.cycle.length; index++) {
        final smooth = BirdV1FlightTuning.smoothHoldsMs[index];
        final glide = BirdV1FlightTuning.glideHoldsMs[index];
        final cruise = BirdV1FlightTuning.cruiseHoldsMs[index];
        expect(cruise, ((smooth + glide) / 2).round());
        expect(
          cruise,
          inInclusiveRange(
            smooth < glide ? smooth : glide,
            smooth > glide ? smooth : glide,
          ),
        );
      }
      expect(
        BirdV1FlightTuning.holdsFor(BirdV1Cadence.glide)[4],
        greaterThan(BirdV1FlightTuning.holdsFor(BirdV1Cadence.smooth)[4]),
      );
      expect(
        BirdV1FlightTuning.holdsFor(BirdV1Cadence.glide)[5],
        greaterThan(BirdV1FlightTuning.holdsFor(BirdV1Cadence.smooth)[5]),
      );
    },
  );

  test('Flight speed scales only the horizontal crossing duration', () {
    expect(BirdV1FlightTuning.flightSpeedLabel(BirdV1FlightSpeed.half), '0.5×');
    expect(BirdV1FlightTuning.flightSpeedLabel(BirdV1FlightSpeed.one), '1×');
    expect(
      BirdV1FlightTuning.flightSpeedLabel(BirdV1FlightSpeed.onePointFive),
      '1.5×',
    );
    expect(BirdV1FlightTuning.flightSpeedLabel(BirdV1FlightSpeed.two), '2×');
    expect(BirdV1FlightTuning.crossingDurationMs(BirdV1FlightSpeed.half), 4400);
    expect(BirdV1FlightTuning.crossingDurationMs(BirdV1FlightSpeed.one), 2200);
    expect(
      BirdV1FlightTuning.crossingDurationMs(BirdV1FlightSpeed.onePointFive),
      1467,
    );
    expect(BirdV1FlightTuning.crossingDurationMs(BirdV1FlightSpeed.two), 1100);
    expect(BirdV1FlightTuning.holdsFor(BirdV1Cadence.glide), const [
      70,
      55,
      55,
      75,
      160,
      180,
    ]);
    expect(BirdV1FlightTuning.transitionMs(BirdV1Transition.ms20), 20);
    expect(BirdV1FlightTuning.transitionMs(BirdV1Transition.ms35), 35);
    expect(BirdV1FlightTuning.transitionMs(BirdV1Transition.overlap20), 20);
    expect(BirdV1FlightTuning.holdsFor(BirdV1Cadence.cruise), const [
      63,
      55,
      58,
      68,
      115,
      125,
    ]);
  });

  test('Overlap transition retains a fully opaque cel through both phases', () {
    expect(BirdV1FlightTuning.transitionOpacities(BirdV1Transition.off, 0), (
      outgoing: 0,
      incoming: 1,
    ));
    expect(BirdV1FlightTuning.transitionOpacities(BirdV1Transition.ms20, 10), (
      outgoing: 0.5,
      incoming: 0.5,
    ));
    expect(
      BirdV1FlightTuning.transitionOpacities(BirdV1Transition.overlap20, 0),
      (outgoing: 1, incoming: 0),
    );
    expect(
      BirdV1FlightTuning.transitionOpacities(BirdV1Transition.overlap20, 10),
      (outgoing: 1, incoming: 1),
    );
    expect(
      BirdV1FlightTuning.transitionOpacities(BirdV1Transition.overlap20, 15),
      (outgoing: 0.5, incoming: 1),
    );
    expect(
      BirdV1FlightTuning.transitionOpacities(BirdV1Transition.overlap20, 20),
      (outgoing: 0, incoming: 1),
    );
  });

  test('Bob and bird-specific flutter are continuous at a cadence seam', () {
    const cadence = BirdV1Cadence.current;
    final period = BirdV1FlightTuning.cycleDurationMs(cadence);
    expect(BirdV1FlightTuning.bobForElapsed(0, cadence), closeTo(0, 0.0001));
    expect(
      BirdV1FlightTuning.bobForElapsed(period, cadence),
      closeTo(0, 0.0001),
    );
    expect(
      BirdV1FlightTuning.flutterYForElapsed(0, cadence),
      closeTo(0, 0.0001),
    );
    expect(
      BirdV1FlightTuning.flutterYForElapsed(period, cadence),
      closeTo(0, 0.0001),
    );
    expect(BirdV1FlightTuning.birdFlutterVerticalAmplitude, lessThan(1));
    expect(BirdV1FlightTuning.birdFlutterRotationAmplitude, lessThan(0.01));
  });

  testWidgets('Production tuning controls fit the supported preview widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: BirdV1ProductionPreview()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FRAME SET'), findsOneWidget);
      expect(find.text('FLIGHT SPEED'), findsOneWidget);
      expect(find.text('CADENCE'), findsOneWidget);
      expect(find.text('OVERLAP 20'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
