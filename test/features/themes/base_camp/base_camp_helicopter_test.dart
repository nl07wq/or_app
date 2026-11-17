import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_helicopter.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'approved asset contract is registered in the approved playback order',
    () {
      expect(baseCampHelicopterAssets, hasLength(23));
      expect(baseCampHelicopterMainRotorAssets, <String>[
        'assets/base_camp/helicopter/main_rotor/frame_01.png',
        'assets/base_camp/helicopter/main_rotor/frame_02.png',
        'assets/base_camp/helicopter/main_rotor/frame_03.png',
        'assets/base_camp/helicopter/main_rotor/frame_04.png',
        'assets/base_camp/helicopter/main_rotor/frame_05.png',
        'assets/base_camp/helicopter/main_rotor/frame_06.png',
      ]);
      expect(baseCampHelicopterTailRotorAssets, hasLength(16));
    },
  );

  test('production schedule remains inside the approved timing bands', () {
    const schedule = BaseCampHelicopterSchedule();
    final random = math.Random(42);
    for (var index = 0; index < 100; index++) {
      expect(
        schedule.firstDelay(random).inMilliseconds,
        inInclusiveRange(10000, 25000),
      );
      expect(
        schedule.laterDelay(random).inMilliseconds,
        inInclusiveRange(20000, 50000),
      );
      expect(
        schedule.flightDuration(random).inMilliseconds,
        inInclusiveRange(7000, 10000),
      );
    }
  });

  test('both directions start and finish fully outside the map', () {
    for (final direction in BaseCampHelicopterDirection.values) {
      final start = baseCampHelicopterLeft(
        progress: 0,
        viewportWidth: 390,
        spriteWidth: 164,
        direction: direction,
      );
      final end = baseCampHelicopterLeft(
        progress: 1,
        viewportWidth: 390,
        spriteWidth: 164,
        direction: direction,
      );
      if (direction == BaseCampHelicopterDirection.leftToRight) {
        expect(start, -164);
        expect(end, 390);
      } else {
        expect(start, 390);
        expect(end, -164);
      }
    }
  });

  testWidgets('approved PNGs load with their original canvas dimensions', (
    tester,
  ) async {
    final expectedSizes = <String, Size>{
      baseCampHelicopterBodyAsset: const Size(1448, 1086),
      for (final asset in baseCampHelicopterMainRotorAssets)
        asset: const Size(719, 358),
      for (final asset in baseCampHelicopterTailRotorAssets)
        asset: const Size(420, 420),
    };
    for (final entry in expectedSizes.entries) {
      final data = await rootBundle.load(entry.key);
      expect(data.lengthInBytes, greaterThan(24), reason: entry.key);
      final bytes = data.buffer.asByteData(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(
        Size(
          bytes.getUint32(16, Endian.big).toDouble(),
          bytes.getUint32(20, Endian.big).toDouble(),
        ),
        entry.value,
        reason: entry.key,
      );
    }
  });

  testWidgets(
    'lazy scheduler waits for Dashboard interactive, caches once, and exits',
    (tester) async {
      final interactive = ValueNotifier<bool>(false);
      addTearDown(interactive.dispose);
      var loads = 0;
      var taps = 0;
      final events = <String>[];
      const schedule = BaseCampHelicopterSchedule(
        firstDelayMin: Duration(milliseconds: 10),
        firstDelayMax: Duration(milliseconds: 10),
        laterDelayMin: Duration(seconds: 1),
        laterDelayMax: Duration(seconds: 1),
        flightDurationMin: Duration(milliseconds: 100),
        flightDurationMax: Duration(milliseconds: 100),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.square(
              dimension: 320,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                    ),
                  ),
                  Positioned.fill(
                    child: BaseCampHelicopterFlybyLayer(
                      dashboardInteractive: interactive,
                      schedule: schedule,
                      random: math.Random(3),
                      assetLoader: (context, assets) async => loads++,
                      eventRecorder: (category, event, fields) =>
                          events.add(event),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(loads, 0);
      expect(events, isEmpty);

      interactive.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(loads, 1);
      expect(events, contains('HELICOPTER_ASSET_LOAD_START'));
      expect(events, contains('HELICOPTER_ASSET_LOAD_SUCCESS'));
      expect(events, contains('HELICOPTER_SPAWN'));
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-positioned')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(160, 160));
      await tester.pump();
      expect(taps, 1, reason: 'the visual overlay must not intercept map taps');

      await tester.pump(const Duration(milliseconds: 101));
      await tester.pump();
      expect(events, contains('HELICOPTER_EXIT'));
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-positioned')),
        findsNothing,
      );
      expect(loads, 1);

      final eventCountBeforeDispose = events.length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(events, hasLength(eventCountBeforeDispose));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'asset failure disables flyby without presenting a partial craft',
    (tester) async {
      final interactive = ValueNotifier<bool>(true);
      addTearDown(interactive.dispose);
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 320,
            child: BaseCampHelicopterFlybyLayer(
              dashboardInteractive: interactive,
              schedule: const BaseCampHelicopterSchedule(
                firstDelayMin: Duration(milliseconds: 1),
                firstDelayMax: Duration(milliseconds: 1),
              ),
              assetLoader: (context, assets) async =>
                  throw StateError('fixture'),
              eventRecorder: (category, event, fields) => events.add(event),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(events, contains('HELICOPTER_ASSET_LOAD_FAILURE'));
      expect(events, isNot(contains('HELICOPTER_SPAWN')));
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-positioned')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direction mirrors the complete body and both rotor layers', (
    tester,
  ) async {
    Future<double> render(BaseCampHelicopterDirection direction) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 220,
              height: 165,
              child: BaseCampHelicopterSprite(
                direction: direction,
                mainRotorFrame: 2,
                tailRotorFrame: 7,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-main-rotor')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-tail-rotor')),
        findsOneWidget,
      );
      return transform.transform.entry(0, 0);
    }

    expect(await render(BaseCampHelicopterDirection.rightToLeft), 1);
    expect(await render(BaseCampHelicopterDirection.leftToRight), -1);
  });

  testWidgets('BASE CAMP map owns the overlay without startup asset work', (
    tester,
  ) async {
    SystemDiagnostics.instance.clear();
    addTearDown(SystemDiagnostics.instance.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 390,
            child: BaseCampMap(onFacilityPressed: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    final layer = find.byKey(
      const ValueKey('base-camp-helicopter-flyby-layer'),
    );
    expect(layer, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-map')),
        matching: layer,
      ),
      findsOneWidget,
    );
    expect(
      SystemDiagnostics.instance.copyText(),
      isNot(contains('HELICOPTER_ASSET_LOAD_START')),
    );
    expect(tester.takeException(), isNull);
  });
}
