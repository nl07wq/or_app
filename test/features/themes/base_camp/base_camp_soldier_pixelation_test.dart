import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  test('all levels resolve to one screen-space block density', () {
    final profile = baseCampSoldierPixelProfile(
      viewport: const Size(360, 300),
      devicePixelRatio: 3,
    );
    for (final level in SoldierPixelationLevel.values.skip(1)) {
      for (final request in profile.requests) {
        final size = request.reducedSize(level);
        final rect = request.displayRect(level);
        expect(
          rect.width / size.width * request.devicePixelRatio,
          closeTo(level.referenceBlockSize.toDouble(), .001),
        );
        expect(
          rect.height / size.height * request.devicePixelRatio,
          closeTo(level.referenceBlockSize.toDouble(), .001),
        );
        expect(
          (rect.left * request.devicePixelRatio) % level.referenceBlockSize,
          closeTo(0, .001),
        );
        expect(
          (rect.top * request.devicePixelRatio) % level.referenceBlockSize,
          closeTo(0, .001),
        );
      }
    }
  });

  test(
    'iPhone density preserves substantially more detail than logical grid',
    () {
      const viewport = Size(112, 82);
      final logicalProfile = baseCampSoldierPixelProfile(viewport: viewport);
      final retinaProfile = baseCampSoldierPixelProfile(
        viewport: viewport,
        devicePixelRatio: 3,
      );
      for (final level in SoldierPixelationLevel.values.skip(1)) {
        final logical = logicalProfile
            .requestFor(baseCampBreathingSoldierLowerAsset)
            .reducedSize(level);
        final retina = retinaProfile
            .requestFor(baseCampBreathingSoldierLowerAsset)
            .reducedSize(level);
        expect(retina.width, greaterThanOrEqualTo(logical.width * 2.5));
        expect(retina.height, greaterThanOrEqualTo(logical.height * 2.5));
      }
    },
  );

  test('iPhone profile raster memory remains bounded off the startup path', () {
    int profilePixels(Size viewport, SoldierPixelationLevel level) {
      final profile = baseCampSoldierPixelProfile(
        viewport: viewport,
        devicePixelRatio: 3,
      );
      return profile.requests.fold<int>(0, (total, request) {
        final reduced = request.reducedSize(level);
        return total + reduced.width.toInt() * reduced.height.toInt();
      });
    }

    for (final level in SoldierPixelationLevel.values.skip(1)) {
      expect(profilePixels(const Size(112, 82), level), lessThan(250000));
      expect(
        profilePixels(const Size(398, 398 / 1.35), level),
        lessThan(2000000),
      );
    }
  });

  for (final width in <double>[320, 375, 390, 430]) {
    test('screen grid remains exact for the ${width.toInt()}dp layout', () {
      final viewport = Size((width - 40) * .4, 82);
      final profile = baseCampSoldierPixelProfile(
        viewport: viewport,
        devicePixelRatio: 3,
      );
      for (final level in SoldierPixelationLevel.values.skip(1)) {
        for (final request in profile.requests) {
          final size = request.reducedSize(level);
          final rect = request.displayRect(level);
          expect(
            rect.width / size.width * request.devicePixelRatio,
            closeTo(level.referenceBlockSize.toDouble(), .001),
          );
          expect(
            rect.height / size.height * request.devicePixelRatio,
            closeTo(level.referenceBlockSize.toDouble(), .001),
          );
        }
      }
    });
  }

  test('regrip sampling follows final alignment axis scales', () {
    const viewport = Size(360, 300);
    final profile = baseCampSoldierPixelProfile(
      viewport: viewport,
      globalScale: 1.2,
      frameScales: const <double>[.8, .9, 1, 1.1, 1.2, 1.3],
      horizontalScaleY: .7,
      verticalScaleX: 1.25,
    );
    for (var frame = 0; frame < baseCampRifleRegripAssets.length; frame++) {
      final request = profile.requestFor(baseCampRifleRegripAssets[frame]);
      final transform = baseCampRifleRegripTransform(
        viewport,
        frame,
        globalScale: 1.2,
        frameScales: const <double>[.8, .9, 1, 1.1, 1.2, 1.3],
        horizontalScaleY: .7,
        verticalScaleX: 1.25,
      );
      expect(request.targetRect.left, closeTo(transform.left, .001));
      expect(request.targetRect.top, closeTo(transform.top, .001));
      expect(request.targetRect.width, closeTo(transform.width, .001));
      expect(request.targetRect.height, closeTo(transform.height, .001));
    }
  });

  test('breathing layers share one source grid and profile origin', () {
    final profile = baseCampSoldierPixelProfile(viewport: const Size(360, 300));
    final lower = profile.requestFor(baseCampBreathingSoldierLowerAsset);
    final upper = profile.requestFor(baseCampBreathingSoldierUpperAsset);
    expect(lower.profileKey, upper.profileKey);
    for (final level in SoldierPixelationLevel.values.skip(1)) {
      expect(lower.reducedSize(level), upper.reducedSize(level));
    }
  });

  test('breathing reuses one processed upper image for the complete cycle', () {
    final profile = baseCampSoldierPixelProfile(viewport: const Size(360, 300));
    final upper = profile.requestFor(baseCampBreathingSoldierUpperAsset);
    for (var elapsed = 0; elapsed <= 2400; elapsed += 17) {
      final dy = baseCampBreathingOffset(elapsed.toDouble());
      expect(dy, inInclusiveRange(-1, 0));
      expect(
        profile.requestFor(baseCampBreathingSoldierUpperAsset),
        same(upper),
      );
      for (final level in SoldierPixelationLevel.values.skip(1)) {
        final rect = upper.displayRect(level);
        expect(rect.left % level.referenceBlockSize, closeTo(0, .001));
        expect(rect.top % level.referenceBlockSize, closeTo(0, .001));
      }
    }
    expect(
      profile.breathingRequests.map((request) => request.cacheId),
      <String>['breathing-lower', 'breathing-upper'],
    );
  });

  testWidgets('fixed upper image retains the original presentation offset', (
    tester,
  ) async {
    const level = SoldierPixelationLevel.extreme;
    DeviceSettingsController.instance.update(
      const DeviceSettings(breathingPixelLevel: level),
    );
    final profile = baseCampSoldierPixelProfile(
      viewport: const Size(360, 300),
      devicePixelRatio: 3,
    );
    await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareMotionRequests(
        profile.breathingRequests,
        BaseCampSoldierMotion.breathing,
        level,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 300,
          child: BaseCampBreathingSoldier(dy: 0, pixelProfile: profile),
        ),
      ),
    );
    await tester.pump();
    final renderedUpper = _pixelatedImage(
      level,
      baseCampBreathingSoldierUpperAsset,
    );
    expect(renderedUpper, findsOneWidget);
    final restingTop = tester.getTopLeft(renderedUpper);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 300,
          child: BaseCampBreathingSoldier(dy: -.625, pixelProfile: profile),
        ),
      ),
    );
    await tester.pump();
    final upper = tester.widget<BaseCampSoldierAssetImage>(
      find.byKey(const ValueKey('base-camp-soldier-upper')),
    );
    expect(upper.request.cacheId, 'breathing-upper');
    expect(upper.originalOffset, const Offset(0, -.625));
    expect(
      upper.request,
      same(profile.requestFor(baseCampBreathingSoldierUpperAsset)),
    );
    expect(
      tester.getTopLeft(renderedUpper).dy,
      closeTo(restingTop.dy - .625, .001),
    );
  });

  test('all motion assets respond monotonically from LV.1 through LV.4', () {
    final profile = baseCampSoldierPixelProfile(
      viewport: const Size(398, 398 / 1.35),
    );
    for (final request in profile.requests) {
      var previous = const Size(double.infinity, double.infinity);
      for (final level in SoldierPixelationLevel.values.skip(1)) {
        final current = request.reducedSize(level);
        expect(current.width, lessThan(previous.width));
        expect(current.height, lessThan(previous.height));
        previous = current;
      }
    }
  });

  testWidgets('failed profile is not partially committed', (tester) async {
    final profile = baseCampSoldierPixelProfile(viewport: const Size(360, 300));
    final requests = <BaseCampSoldierPixelRequest>[
      ...profile.requests.take(2),
      BaseCampSoldierPixelRequest(
        asset: 'assets/missing_soldier_frame.png',
        cacheId: 'missing-frame',
        profileKey: profile.key,
        viewport: const Size(360, 300),
        targetRect: const Rect.fromLTWH(0, 0, 360, 300),
      ),
    ];
    final prepared = await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        requests,
        SoldierPixelationLevel.fine,
      ),
    );
    expect(prepared, isFalse);
    expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 0);
    expect(BaseCampSoldierPixelCache.instance.lastFailure, isNotNull);
  });

  testWidgets('level change never presents a prior-level frame as exact', (
    tester,
  ) async {
    final profile = baseCampSoldierPixelProfile(viewport: const Size(240, 180));
    expect(
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareMotionRequests(
          profile.regripRequests,
          BaseCampSoldierMotion.regrip,
          SoldierPixelationLevel.fine,
        ),
      ),
      isTrue,
    );
    BaseCampSoldierPixelCache.instance.selectMotionLevel(
      BaseCampSoldierMotion.regrip,
      SoldierPixelationLevel.medium,
    );
    final retained = BaseCampSoldierPixelCache.instance.cachedFrame(
      profile.requestFor(baseCampRifleRegripAssets.first),
      SoldierPixelationLevel.medium,
    );
    expect(retained, isNull);
    expect(
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareMotionRequests(
          profile.regripRequests,
          BaseCampSoldierMotion.regrip,
          SoldierPixelationLevel.medium,
        ),
      ),
      isTrue,
    );
    final committed = BaseCampSoldierPixelCache.instance.cachedFrame(
      profile.requestFor(baseCampRifleRegripAssets.first),
      SoldierPixelationLevel.medium,
    );
    expect(committed, isNotNull);
    expect(committed!.level, SoldierPixelationLevel.medium);
  });

  testWidgets('cache rejects a frame from a different viewport profile', (
    tester,
  ) async {
    const level = SoldierPixelationLevel.coarse;
    final preview = baseCampSoldierPixelProfile(
      viewport: const Size(398, 294.8148148148),
      devicePixelRatio: 3,
    );
    final dashboard = baseCampSoldierPixelProfile(
      viewport: const Size(112, 82),
      devicePixelRatio: 3,
    );
    final cache = BaseCampSoldierPixelCache.instance;
    expect(
      await tester.runAsync(
        () => cache.prepareMotionRequests(
          preview.breathingRequests,
          BaseCampSoldierMotion.breathing,
          level,
        ),
      ),
      isTrue,
    );
    expect(
      cache.cachedFrame(
        preview.requestFor(baseCampBreathingSoldierUpperAsset),
        level,
      ),
      isNotNull,
    );
    expect(
      cache.cachedFrame(
        dashboard.requestFor(baseCampBreathingSoldierUpperAsset),
        level,
      ),
      isNull,
      reason: 'Preview pixels are not valid for the Dashboard viewport',
    );
  });

  testWidgets('cache rejects mismatched DPR alignment and frame identity', (
    tester,
  ) async {
    const level = SoldierPixelationLevel.medium;
    final exact = baseCampSoldierPixelProfile(
      viewport: const Size(112, 82),
      devicePixelRatio: 3,
      globalX: 2,
    );
    final cache = BaseCampSoldierPixelCache.instance;
    expect(
      await tester.runAsync(
        () => cache.prepareMotionRequests(
          exact.regripRequests,
          BaseCampSoldierMotion.regrip,
          level,
        ),
      ),
      isTrue,
    );
    final exactRequest = exact.requestFor(baseCampRifleRegripAssets.first);
    expect(cache.cachedFrame(exactRequest, level), isNotNull);

    for (final mismatch in <BaseCampSoldierPixelRequest>[
      baseCampSoldierPixelProfile(
        viewport: const Size(112, 82),
        devicePixelRatio: 2,
        globalX: 2,
      ).requestFor(baseCampRifleRegripAssets.first),
      baseCampSoldierPixelProfile(
        viewport: const Size(112, 82),
        devicePixelRatio: 3,
        globalX: 3,
      ).requestFor(baseCampRifleRegripAssets.first),
      exactRequest.withAsset(baseCampRifleRegripAssets.last),
    ]) {
      expect(cache.cachedFrame(mismatch, level), isNull);
    }
  });

  testWidgets('viewport profiles regenerate atomically and remain bounded', (
    tester,
  ) async {
    const level = SoldierPixelationLevel.fine;
    final profiles = <BaseCampSoldierPixelProfile>[
      baseCampSoldierPixelProfile(viewport: const Size(120, 90)),
      baseCampSoldierPixelProfile(viewport: const Size(240, 180)),
      baseCampSoldierPixelProfile(viewport: const Size(398, 398 / 1.35)),
    ];
    for (final profile in profiles) {
      final prepared = await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          profile.requests,
          level,
        ),
      );
      expect(prepared, isTrue);
    }
    expect(BaseCampSoldierPixelCache.instance.cachedProfileCount, 4);
    expect(
      BaseCampSoldierPixelCache.instance.cachedImageCount,
      baseCampSoldierPixelFrameCount * 2,
    );
    expect(
      BaseCampSoldierPixelCache.instance.cachedPixelCount,
      lessThan(400000),
    );
    expect(
      BaseCampSoldierPixelCache.instance.cachedFrame(
        profiles.first.requestFor(baseCampBreathingSoldierLowerAsset),
        level,
      ),
      isNull,
    );
    for (final profile in profiles.skip(1)) {
      expect(
        BaseCampSoldierPixelCache.instance.cachedFrame(
          profile.requestFor(baseCampRifleRegripAssets.last),
          level,
        ),
        isNotNull,
      );
    }
  });

  testWidgets('motion levels regenerate independently and remain bounded', (
    tester,
  ) async {
    final profile = baseCampSoldierPixelProfile(
      viewport: const Size(398, 398 / 1.35),
      devicePixelRatio: 3,
    );
    final cache = BaseCampSoldierPixelCache.instance;
    expect(
      await tester.runAsync(
        () => cache.prepareRequests(
          profile.requests,
          SoldierPixelationLevel.fine,
        ),
      ),
      isTrue,
    );
    expect(cache.processedImageCount, baseCampSoldierPixelFrameCount);

    expect(
      await tester.runAsync(
        () => cache.prepareMotionRequests(
          profile.breathingRequests,
          BaseCampSoldierMotion.breathing,
          SoldierPixelationLevel.medium,
        ),
      ),
      isTrue,
    );
    expect(cache.processedImageCount, baseCampSoldierPixelFrameCount + 2);
    expect(
      cache
          .cachedFrame(
            profile.requestFor(baseCampRifleRegripAssets.first),
            SoldierPixelationLevel.fine,
          )
          ?.level,
      SoldierPixelationLevel.fine,
    );

    expect(
      await tester.runAsync(
        () => cache.prepareMotionRequests(
          profile.regripRequests,
          BaseCampSoldierMotion.regrip,
          SoldierPixelationLevel.coarse,
        ),
      ),
      isTrue,
    );
    expect(
      cache
          .cachedFrame(
            profile.requestFor(baseCampBreathingSoldierLowerAsset),
            SoldierPixelationLevel.medium,
          )
          ?.level,
      SoldierPixelationLevel.medium,
    );
    expect(cache.cachedProfileCount, 2);
    expect(cache.cachedImageCount, baseCampSoldierPixelFrameCount);
  });

  testWidgets(
    'selected level pixelates breathing and regrip once then reuses cache',
    (tester) async {
      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.fine,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile(
            viewport: const Size(512, 512),
            devicePixelRatio: tester.view.devicePixelRatio,
          ).requests,
          SoldierPixelationLevel.fine,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 512,
              height: 512,
              child: Stack(
                children: <Widget>[
                  BaseCampBreathingSoldier(dy: 0),
                  BaseCampRifleRegripFrame(frame: 0),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampRifleRegripAssets.first,
        ).evaluate().isNotEmpty,
      );

      expect(
        _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampBreathingSoldierLowerAsset,
        ),
        findsOneWidget,
      );
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.fine,
          baseCampBreathingSoldierUpperAsset,
        ),
        findsOneWidget,
      );
      expect(
        BaseCampSoldierPixelCache.instance.cachedImageCount,
        baseCampSoldierPixelFrameCount,
      );
      expect(
        BaseCampSoldierPixelCache.instance.processedImageCount,
        baseCampSoldierPixelFrameCount,
      );

      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 140));
      }
      expect(
        BaseCampSoldierPixelCache.instance.processedImageCount,
        baseCampSoldierPixelFrameCount,
      );

      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.medium,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile(
            viewport: const Size(512, 512),
            devicePixelRatio: tester.view.devicePixelRatio,
          ).requests,
          SoldierPixelationLevel.medium,
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () =>
            BaseCampSoldierPixelCache.instance.processedImageCount ==
            baseCampSoldierPixelFrameCount * 2,
      );
      expect(
        BaseCampSoldierPixelCache.instance.cachedImageCount,
        baseCampSoldierPixelFrameCount,
      );
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.medium,
          baseCampRifleRegripAssets.first,
        ),
        findsOneWidget,
      );

      DeviceSettingsController.instance.update(const DeviceSettings());
      await tester.pump();
      await tester.pump();
      expect(
        _pixelatedImage(
          SoldierPixelationLevel.medium,
          baseCampRifleRegripAssets.first,
        ),
        findsNothing,
      );
      expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 0);
      expect(find.byType(Image), findsNWidgets(3));
    },
  );

  testWidgets(
    'pixelation uses bounded grid raster and original draw geometry',
    (tester) async {
      DeviceSettingsController.instance.update(
        const DeviceSettings(
          soldierPixelationLevel: SoldierPixelationLevel.coarse,
        ),
      );
      await tester.runAsync(
        () => BaseCampSoldierPixelCache.instance.prepareRequests(
          baseCampSoldierPixelProfile(
            viewport: const Size(256, 256),
            devicePixelRatio: tester.view.devicePixelRatio,
          ).requests,
          SoldierPixelationLevel.coarse,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 256,
              child: BaseCampRifleRegripFrame(frame: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => _pixelatedImage(
          SoldierPixelationLevel.coarse,
          baseCampRifleRegripAssets.first,
        ).evaluate().isNotEmpty,
      );
      final rendered = tester.widget<RawImage>(
        _pixelatedImage(
          SoldierPixelationLevel.coarse,
          baseCampRifleRegripAssets.first,
        ),
      );
      final request = baseCampSoldierPixelProfile(
        viewport: const Size(256, 256),
        devicePixelRatio: tester.view.devicePixelRatio,
      ).requestFor(baseCampRifleRegripAssets.first);
      final expected = request.reducedSize(SoldierPixelationLevel.coarse);
      expect(rendered.image!.width, expected.width);
      expect(rendered.image!.height, expected.height);
      expect(rendered.fit, BoxFit.fill);
      expect(rendered.filterQuality, FilterQuality.none);
    },
  );
}

Finder _pixelatedImage(SoldierPixelationLevel level, String asset) =>
    find.byKey(ValueKey<String>('soldier-pixelated-${level.name}-$asset'));

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}
