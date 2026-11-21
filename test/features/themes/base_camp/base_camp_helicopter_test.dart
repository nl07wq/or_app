import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/features/themes/base_camp/base_camp_helicopter_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_helicopter.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy MAP configuration defaults to the exact V1 assembly', () {
    final legacy = BaseCampMapConfiguration.defaults().toJson()
      ..remove('helicopterAssembly');
    final restored = BaseCampMapConfiguration.tryParse(legacy);
    expect(restored, isNotNull);
    expect(restored!.helicopterAssembly.globalScale, 1);
    expect(restored.helicopterAssembly.mainHub, const Offset(772, 273));
    expect(restored.helicopterAssembly.mainScale, 1);
    expect(restored.helicopterAssembly.tailHub, const Offset(1250, 484));
    expect(restored.helicopterAssembly.tailScale, .5);
    expect(restored.helicopterAssembly.mainFrameMs, 110);
    expect(restored.helicopterAssembly.tailFrameMs, 50);
    expect(restored.helicopterAssembly.flightSpeed, 190);
    expect(restored.helicopterAssembly.forwardPitchDegrees, 4);
  });

  test('legacy V1 assembly JSON adds optional motion defaults', () {
    final legacyAssembly = BaseCampHelicopterAssembly.defaults.toJson()
      ..remove('mainFrameMs')
      ..remove('tailFrameMs')
      ..remove('flightSpeed')
      ..remove('forwardPitchDegrees');
    final restored = BaseCampHelicopterAssembly.tryParse(legacyAssembly);
    expect(restored, isNotNull);
    expect(restored!.mainFrameMs, 110);
    expect(restored.tailFrameMs, 50);
    expect(restored.flightSpeed, 190);
    expect(restored.forwardPitchDegrees, 4);
  });

  test('V1.1 saved tail timing is preserved while motion fields default', () {
    final v11 = BaseCampHelicopterAssembly.defaults.toJson()
      ..['tailFrameMs'] = 20
      ..remove('flightSpeed')
      ..remove('forwardPitchDegrees');
    final restored = BaseCampHelicopterAssembly.tryParse(v11);
    expect(restored, isNotNull);
    expect(restored!.tailFrameMs, 20);
    expect(restored.flightSpeed, 190);
    expect(restored.forwardPitchDegrees, 4);
  });

  test('assembly timing round-trips and rejects invalid increments', () {
    const configured = BaseCampHelicopterAssembly(
      globalScale: .75,
      mainFrameMs: 35,
      tailFrameMs: 5,
      flightSpeed: 400,
      forwardPitchDegrees: 12,
    );
    final restored = BaseCampHelicopterAssembly.tryParse(configured.toJson());
    expect(restored, isNotNull);
    expect(restored!.globalScale, .75);
    expect(restored.mainFrameMs, 35);
    expect(restored.tailFrameMs, 5);
    expect(restored.flightSpeed, 400);
    expect(restored.forwardPitchDegrees, 12);
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...configured.toJson(),
        'mainFrameMs': 33,
      }),
      isNull,
    );
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...configured.toJson(),
        'flightSpeed': 195,
      }),
      isNull,
    );
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...configured.toJson(),
        'forwardPitchDegrees': 13,
      }),
      isNull,
    );
  });

  test('flight speed accepts the complete 80 to 1200 MAP px/s range', () {
    for (final speed in <int>[80, 190, 400, 800, 1200]) {
      final configured = BaseCampHelicopterAssembly(flightSpeed: speed);
      expect(configured.isValid, isTrue);
      expect(
        BaseCampHelicopterAssembly.tryParse(configured.toJson())?.flightSpeed,
        speed,
      );
    }
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...BaseCampHelicopterAssembly.defaults.toJson(),
        'flightSpeed': 1210,
      }),
      isNull,
    );
  });

  test('independent rotor timing uses elapsed frame duration', () {
    for (final frameMs in <int>[5, 10, 15, 20, 50, 120]) {
      const elapsed = Duration(milliseconds: 1000);
      expect(
        baseCampHelicopterFrameIndex(
          elapsed: elapsed,
          frameDurationMs: frameMs,
          frameCount: 16,
        ),
        (1000 ~/ frameMs) % 16,
      );
    }
  });

  test('helicopter assembly rejects invalid finite geometry', () {
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...BaseCampHelicopterAssembly.defaults.toJson(),
        'mainScale': 0,
      }),
      isNull,
    );
    expect(
      BaseCampHelicopterAssembly.tryParse(<String, Object?>{
        ...BaseCampHelicopterAssembly.defaults.toJson(),
        'tailHubX': 2000,
      }),
      isNull,
    );
  });

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
    }
  });

  test('rotated assembly starts and finishes fully outside at every scale', () {
    for (final globalScale in <double>[.1, .5, 1, 3]) {
      for (final pitch in <int>[0, 12]) {
        final assembly = BaseCampHelicopterAssembly(
          globalScale: globalScale,
          forwardPitchDegrees: pitch,
        );
        for (final direction in BaseCampHelicopterDirection.values) {
          final path = baseCampHelicopterFlightPath(
            assembly: assembly,
            direction: direction,
          );
          if (direction == BaseCampHelicopterDirection.leftToRight) {
            expect(
              path.startLeft + path.visualBounds.right,
              lessThanOrEqualTo(.000001),
            );
            expect(
              path.endLeft + path.visualBounds.left,
              greaterThanOrEqualTo(1254 - .000001),
            );
          } else {
            expect(
              path.startLeft + path.visualBounds.left,
              greaterThanOrEqualTo(1254 - .000001),
            );
            expect(
              path.endLeft + path.visualBounds.right,
              lessThanOrEqualTo(.000001),
            );
          }
          expect(
            path.duration.inMicroseconds,
            closeTo(path.travelDistance / assembly.flightSpeed * 1000000, 1),
          );
        }
      }
    }
  });

  test('linear path advances equal MAP distances in equal time', () {
    for (final speed in <int>[80, 190, 400, 800, 1200]) {
      for (final direction in BaseCampHelicopterDirection.values) {
        final path = baseCampHelicopterFlightPath(
          assembly: BaseCampHelicopterAssembly(flightSpeed: speed),
          direction: direction,
        );
        final segments = <double>[
          path.leftAt(.25) - path.leftAt(0),
          path.leftAt(.50) - path.leftAt(.25),
          path.leftAt(.75) - path.leftAt(.50),
          path.leftAt(1) - path.leftAt(.75),
        ];
        for (final segment in segments.skip(1)) {
          expect(segment, closeTo(segments.first, .000001));
        }
      }
    }
  });

  test('Editor and Dashboard widths share one artwork flight duration', () {
    for (final speed in <int>[80, 190, 400, 800, 1200]) {
      for (final scale in <double>[.1, .5, 1, 3]) {
        for (final pitch in <int>[0, 4, 12]) {
          final assembly = BaseCampHelicopterAssembly(
            flightSpeed: speed,
            globalScale: scale,
            forwardPitchDegrees: pitch,
          );
          for (final direction in BaseCampHelicopterDirection.values) {
            final path = baseCampHelicopterFlightPath(
              assembly: assembly,
              direction: direction,
            );
            for (final displayWidth in <double>[320, 375, 390, 430, 1254]) {
              final displayStart = baseCampHelicopterDisplayLeft(
                path: path,
                progress: 0,
                displayWidth: displayWidth,
              );
              final displayEnd = baseCampHelicopterDisplayLeft(
                path: path,
                progress: 1,
                displayWidth: displayWidth,
              );
              final displayScale = baseCampHelicopterArtworkToDisplayScale(
                displayWidth,
              );
              expect(
                (displayEnd - displayStart).abs() / displayScale,
                closeTo(path.travelDistance, .000001),
              );
              expect(
                path.duration.inMicroseconds,
                closeTo(
                  path.travelDistance / speed * Duration.microsecondsPerSecond,
                  1,
                ),
              );
            }
          }
        }
      }
    }
  });

  test('flight coordinate contract matches the approved MAP artwork', () {
    expect(
      BaseCampHelicopterAssembly.flightArtworkSize,
      baseCampMapArtworkSize,
    );
  });

  test('pitch eases for 600ms with direction-correct nose-down sign', () {
    for (final pitch in <int>[0, 4, 12]) {
      final start = baseCampHelicopterSignedPitchRadians(
        direction: BaseCampHelicopterDirection.leftToRight,
        forwardPitchDegrees: pitch,
        elapsed: Duration.zero,
      );
      final leftToRight = baseCampHelicopterSignedPitchRadians(
        direction: BaseCampHelicopterDirection.leftToRight,
        forwardPitchDegrees: pitch,
        elapsed: const Duration(milliseconds: 600),
      );
      final rightToLeft = baseCampHelicopterSignedPitchRadians(
        direction: BaseCampHelicopterDirection.rightToLeft,
        forwardPitchDegrees: pitch,
        elapsed: const Duration(milliseconds: 600),
      );
      expect(start, 0);
      expect(leftToRight, closeTo(pitch * math.pi / 180, .000001));
      expect(rightToLeft, closeTo(-leftToRight, .000001));
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

      final flightDuration = baseCampHelicopterFlightPath(
        assembly: BaseCampHelicopterAssembly.defaults,
        direction: BaseCampHelicopterDirection.leftToRight,
      ).duration;
      await tester.pump(flightDuration + const Duration(milliseconds: 1));
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

  testWidgets('production playback uses independent saved rotor timing', (
    tester,
  ) async {
    final interactive = ValueNotifier<bool>(true);
    addTearDown(interactive.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 390,
          child: BaseCampHelicopterFlybyLayer(
            dashboardInteractive: interactive,
            assembly: const BaseCampHelicopterAssembly(
              mainFrameMs: 20,
              tailFrameMs: 120,
            ),
            schedule: const BaseCampHelicopterSchedule(
              firstDelayMin: Duration(milliseconds: 1),
              firstDelayMax: Duration(milliseconds: 1),
            ),
            assetLoader: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));
    final main = tester.widget<Image>(
      find.byKey(const ValueKey('base-camp-helicopter-main-rotor')),
    );
    final tail = tester.widget<Image>(
      find.byKey(const ValueKey('base-camp-helicopter-tail-rotor')),
    );
    expect(
      (main.image as AssetImage).assetName,
      baseCampHelicopterMainRotorAssets[1],
    );
    expect(
      (tail.image as AssetImage).assetName,
      baseCampHelicopterTailRotorAssets[0],
    );
  });

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
                pitchRadians:
                    direction == BaseCampHelicopterDirection.leftToRight
                    ? .1
                    : -.1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      final pitch = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-pitch-transform')),
      );
      expect(pitch.transform.entry(0, 1), isNot(0));
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

  testWidgets('MAP EDITOR suppresses and cleanly restarts random scheduling', (
    tester,
  ) async {
    baseCampHelicopterEditorActive.value = true;
    addTearDown(() => baseCampHelicopterEditorActive.value = false);
    final interactive = ValueNotifier<bool>(true);
    addTearDown(interactive.dispose);
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 390,
          child: BaseCampHelicopterFlybyLayer(
            dashboardInteractive: interactive,
            random: math.Random(3),
            schedule: const BaseCampHelicopterSchedule(
              firstDelayMin: Duration(milliseconds: 1),
              firstDelayMax: Duration(milliseconds: 1),
              laterDelayMin: Duration(milliseconds: 1),
              laterDelayMax: Duration(milliseconds: 1),
            ),
            assetLoader: (_, _) async => loads++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(loads, 0);
    baseCampHelicopterEditorActive.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(loads, 1);
    expect(
      find.byKey(const ValueKey('base-camp-helicopter-positioned')),
      findsOneWidget,
    );
  });

  testWidgets('rotors scale around their configured hubs', (tester) async {
    const assembly = BaseCampHelicopterAssembly(
      mainHub: Offset(800, 300),
      mainScale: 1.25,
      tailHub: Offset(1200, 500),
      tailScale: .75,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1448,
            height: 1086,
            child: BaseCampHelicopterSprite(
              direction: BaseCampHelicopterDirection.rightToLeft,
              mainRotorFrame: 0,
              tailRotorFrame: 0,
              assembly: assembly,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final main = tester.widget<Positioned>(
      find.ancestor(
        of: find.byKey(const ValueKey('base-camp-helicopter-main-rotor')),
        matching: find.byType(Positioned),
      ),
    );
    final tail = tester.widget<Positioned>(
      find.ancestor(
        of: find.byKey(const ValueKey('base-camp-helicopter-tail-rotor')),
        matching: find.byType(Positioned),
      ),
    );
    final renderedScale =
        tester
            .getSize(
              find.byKey(
                const ValueKey('base-camp-helicopter-direction-transform'),
              ),
            )
            .width /
        BaseCampHelicopterSprite.sourceSize.width;
    expect(main.left, closeTo((800 - 359.5 * 1.25) * renderedScale, .001));
    expect(main.top, closeTo((300 - 170 * 1.25) * renderedScale, .001));
    expect(main.width, closeTo(719 * 1.25 * renderedScale, .001));
    expect(tail.left, closeTo((1200 - 210 * .75) * renderedScale, .001));
    expect(tail.top, closeTo((500 - 210 * .75) * renderedScale, .001));
    expect(tail.width, closeTo(420 * .75 * renderedScale, .001));
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
    final elements = tester.allElements.toList(growable: false);
    final labelIndex = elements.indexWhere(
      (element) => element.widget is BaseCampFacilityLabelLayer,
    );
    final helicopterIndex = elements.indexWhere(
      (element) => element.widget is BaseCampHelicopterFlybyLayer,
    );
    expect(labelIndex, greaterThanOrEqualTo(0));
    expect(helicopterIndex, greaterThan(labelIndex));
    expect(tester.takeException(), isNull);
  });
}
