import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/services/food_input_capture_gateway.dart';
import 'package:or_app/features/food/widgets/food_manual_nutrition_crop.dart';

void main() {
  const source = FoodImageDimensions(width: 2000, height: 1000);
  const viewport = Rect.fromLTWH(100, 100, 400, 200);

  test('fixed viewport maps to original pixels without zoom', () {
    final rect = FoodManualCropTransform(
      source: source,
      viewport: viewport,
      scale: .25,
      imageOffset: Offset.zero,
    ).sourceRect;
    expect(rect, const Rect.fromLTWH(400, 400, 1600, 600));
  });

  test('zoom and pan map the same viewport to bounded source pixels', () {
    final rect = FoodManualCropTransform(
      source: source,
      viewport: viewport,
      scale: .5,
      imageOffset: const Offset(-150, -100),
    ).sourceRect;
    expect(rect.left, 500);
    expect(rect.top, 400);
    expect(rect.width, 800);
    expect(rect.height, 400);
    expect(rect.right, lessThanOrEqualTo(source.width.toDouble()));
    expect(rect.bottom, lessThanOrEqualTo(source.height.toDouble()));
  });

  test('pan follows the finger directly during an active gesture', () {
    final offset = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: const Offset(-20, -40),
      startFocalPoint: const Offset(200, 160),
      currentFocalPoint: const Offset(240, 185),
      startScale: .5,
      currentScale: .5,
    );

    expect(offset, const Offset(20, -15));
  });

  test('pinch preserves the source point beneath its focal point', () {
    const focal = Offset(180, 140);
    const startOffset = Offset(-80, -60);
    const startScale = .5;
    const nextScale = .9;
    final sourcePoint = (focal - startOffset) / startScale;
    final offset = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: startOffset,
      startFocalPoint: focal,
      currentFocalPoint: focal,
      startScale: startScale,
      currentScale: nextScale,
    );

    final remapped = (focal - offset) / nextScale;
    expect(remapped.dx, closeTo(sourcePoint.dx, .001));
    expect(remapped.dy, closeTo(sourcePoint.dy, .001));
  });

  test('one-finger pan to pinch and back keeps the current transform', () {
    const start = Offset(-40, -30);
    const firstFocal = Offset(160, 130);
    final afterPan = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: start,
      startFocalPoint: firstFocal,
      currentFocalPoint: const Offset(190, 145),
      startScale: .6,
      currentScale: .6,
    );
    const pinchFocal = Offset(190, 145);
    final afterPinch = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: afterPan,
      startFocalPoint: pinchFocal,
      currentFocalPoint: pinchFocal,
      startScale: .6,
      currentScale: .9,
    );
    final afterSecondPan = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: afterPinch,
      startFocalPoint: pinchFocal,
      currentFocalPoint: const Offset(205, 155),
      startScale: .9,
      currentScale: .9,
    );

    expect(afterPan, const Offset(-10, -15));
    expect(afterSecondPan - afterPinch, const Offset(15, 10));
  });

  test('end correction clamps only the exposed edge to coverage', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    final corrected = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: const Size(300, 300),
      candidate: const Offset(140, -20),
    );

    expect(corrected.dx, 100);
    expect(corrected.dy, -20);
  });

  test('active interaction clamps directly to strict coverage bounds', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    final strict = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: const Size(300, 260),
      candidate: const Offset(140, -20),
    );

    expect(strict, const Offset(100, 0));
  });

  test('relative scale normalizes to the valid crop range at gesture end', () {
    expect(FoodManualCropInteraction.normalizedRelativeScale(.85), 1);
    expect(FoodManualCropInteraction.normalizedRelativeScale(2.4), 2.4);
    expect(FoodManualCropInteraction.normalizedRelativeScale(8), 5);
  });

  test('coverage clamping supports every crop boundary', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    const image = Size(500, 460);
    expect(
      FoodManualCropInteraction.clampToCoverage(
        viewport: crop,
        imageSize: image,
        candidate: const Offset(500, 500),
      ),
      const Offset(100, 100),
    );
    expect(
      FoodManualCropInteraction.clampToCoverage(
        viewport: crop,
        imageSize: image,
        candidate: const Offset(-500, -500),
      ),
      const Offset(-200, -200),
    );
  });

  test('translation bounds expose every usable source edge symmetrically', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    const image = Size(500, 460);
    final bounds = FoodManualCropInteraction.translationBounds(
      viewport: crop,
      imageSize: image,
    );

    expect(bounds.minX, -200);
    expect(bounds.maxX, 100);
    expect(bounds.minY, -200);
    expect(bounds.maxY, 100);
    expect(bounds.clamp(const Offset(100, 100)), const Offset(100, 100));
    expect(bounds.clamp(const Offset(-200, -200)), const Offset(-200, -200));
  });

  test('downward image translation reaches the lower coverage edge', () {
    const crop = Rect.fromLTWH(60, 120, 300, 220);
    const image = Size(700, 640);
    final normalized = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: image,
      candidate: const Offset(-40, 999),
    );

    expect(normalized.dy, crop.top);
    final visible = Rect.fromLTWH(
      normalized.dx,
      normalized.dy,
      image.width,
      image.height,
    );
    expect(visible.top, crop.top);
    expect(visible.bottom, greaterThanOrEqualTo(crop.bottom));
  });

  test('strict pan limits remain finite on all four crop edges', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    const image = Size(500, 460);
    final limited = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: image,
      candidate: const Offset(999, -999),
    );

    expect(limited.dx, 100);
    expect(limited.dy, -200);
    final normalized = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: image,
      candidate: limited,
    );
    final imageRect = Rect.fromLTWH(
      normalized.dx,
      normalized.dy,
      image.width,
      image.height,
    );
    expect(imageRect.left, lessThanOrEqualTo(crop.left));
    expect(imageRect.top, lessThanOrEqualTo(crop.top));
    expect(imageRect.right, greaterThanOrEqualTo(crop.right));
    expect(imageRect.bottom, greaterThanOrEqualTo(crop.bottom));
  });

  test('portrait active drag stops at the strict positive X and Y edges', () {
    const crop = Rect.fromLTWH(48, 92, 286, 414);
    const image = Size(508, 902);
    final bounds = FoodManualCropInteraction.translationBounds(
      viewport: crop,
      imageSize: image,
    );
    final active = FoodManualCropInteraction.clampToCoverage(
      viewport: crop,
      imageSize: image,
      candidate: Offset(bounds.maxX + 132, bounds.maxY + 132),
    );

    expect(active, Offset(bounds.maxX, bounds.maxY));
  });

  test('strict edge reverses immediately without a pan dead zone', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    const image = Size(500, 460);
    final bounds = FoodManualCropInteraction.translationBounds(
      viewport: crop,
      imageSize: image,
    );
    final atMax = bounds.clamp(const Offset(999, 999));
    final reversed = bounds.clamp(atMax - const Offset(12, 12));

    expect(atMax, Offset(bounds.maxX, bounds.maxY));
    expect(reversed.dx, lessThan(atMax.dx));
    expect(reversed.dy, lessThan(atMax.dy));
  });

  test(
    'minimum over-coverage gives portrait geometry persistent pan range',
    () {
      const canvas = Size(402, 640);
      final crop = Rect.fromCenter(
        center: canvas.center(Offset.zero),
        width: canvas.width * .88,
        height: canvas.height * .60,
      );
      const source = FoodImageDimensions(width: 1206, height: 1595);
      final scale = FoodManualCropInteraction.minimumBaseScale(
        viewport: crop,
        source: source,
      );
      final image = Size(source.width * scale, source.height * scale);
      final bounds = FoodManualCropInteraction.translationBounds(
        viewport: crop,
        imageSize: image,
      );
      final center = canvas.center(Offset.zero);
      final centered = Offset(
        center.dx - image.width / 2,
        center.dy - image.height / 2,
      );

      expect(image.width, greaterThan(crop.width));
      expect(image.height, greaterThan(crop.height));
      expect(
        FoodManualCropInteraction.minimumOverCoverageFactor,
        closeTo(1.10, .0001),
      );
      expect(bounds.maxX - bounds.minX, closeTo(crop.width * .10, .001));
      expect((bounds.maxX - bounds.minX) / 2, closeTo(crop.width * .05, .001));
      expect(
        (bounds.maxY - bounds.minY) / 2,
        greaterThanOrEqualTo(crop.height * .05),
      );
      expect(centered.dx, closeTo((bounds.minX + bounds.maxX) / 2, .001));
      expect(centered.dy, closeTo((bounds.minY + bounds.maxY) / 2, .001));
    },
  );

  test('minimum over-coverage exceeds both axes for landscape and square', () {
    const canvas = Size(402, 640);
    final crop = Rect.fromCenter(
      center: canvas.center(Offset.zero),
      width: canvas.width * .88,
      height: canvas.height * .60,
    );
    for (final source in const [
      FoodImageDimensions(width: 1600, height: 900),
      FoodImageDimensions(width: 1200, height: 1200),
    ]) {
      final scale = FoodManualCropInteraction.minimumBaseScale(
        viewport: crop,
        source: source,
      );
      final image = Size(source.width * scale, source.height * scale);
      final bounds = FoodManualCropInteraction.translationBounds(
        viewport: crop,
        imageSize: image,
      );

      expect(image.width, greaterThan(crop.width));
      expect(image.height, greaterThan(crop.height));
      expect(
        (bounds.maxX - bounds.minX) / 2,
        greaterThanOrEqualTo(crop.width * .05),
      );
      expect(
        (bounds.maxY - bounds.minY) / 2,
        greaterThanOrEqualTo(crop.height * .05),
      );
    }
  });

  test('strict release keeps minimum-scale pan shifted on all four sides', () {
    const canvas = Size(402, 640);
    final crop = Rect.fromCenter(
      center: canvas.center(Offset.zero),
      width: canvas.width * .88,
      height: canvas.height * .60,
    );
    const source = FoodImageDimensions(width: 1206, height: 1595);
    final scale = FoodManualCropInteraction.minimumBaseScale(
      viewport: crop,
      source: source,
    );
    final image = Size(source.width * scale, source.height * scale);
    final bounds = FoodManualCropInteraction.translationBounds(
      viewport: crop,
      imageSize: image,
    );
    final center = canvas.center(Offset.zero);
    final centered = Offset(
      center.dx - image.width / 2,
      center.dy - image.height / 2,
    );
    final xStep =
        crop.width *
        FoodManualCropInteraction.minimumPersistentTravelPerSideFraction;
    final yStep =
        crop.height *
        FoodManualCropInteraction.minimumPersistentTravelPerSideFraction;

    final right = bounds.clamp(centered + Offset(xStep, 0));
    final left = bounds.clamp(centered - Offset(xStep, 0));
    final down = bounds.clamp(centered + Offset(0, yStep));
    final up = bounds.clamp(centered - Offset(0, yStep));

    expect(right.dx - centered.dx, closeTo(xStep, .001));
    expect(left.dx - centered.dx, closeTo(-xStep, .001));
    expect(down.dy - centered.dy, closeTo(yStep, .001));
    expect(up.dy - centered.dy, closeTo(-yStep, .001));
  });

  test('crop geometry diagnostic has no persistent storage dependency', () {
    final source = File(
      'lib/features/food/widgets/food_manual_nutrition_crop.dart',
    ).readAsStringSync();

    expect(source, contains('_CropGeometryDiagnosticPanel'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('localStorage')));
    expect(source, isNot(contains('IndexedDB')));
  });

  testWidgets('manual crop requires confirmation before creating OCR input', (
    tester,
  ) async {
    final gateway = _CropGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showManualNutritionCrop(
              context: context,
              gateway: gateway,
              image: const FoodCapturedImage('data:image/png;base64,AA=='),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('CROP NUTRITION LABEL'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('manual-nutrition-crop-source-image')),
      findsOneWidget,
    );
    expect(gateway.cropCalls, 0);
    await tester.tap(
      find.byKey(const ValueKey('manual-nutrition-crop-cancel')),
    );
    await tester.pumpAndSettle();
    expect(gateway.cropCalls, 0);
  });

  testWidgets('Use This Area produces a manual-crop image', (tester) async {
    final gateway = _CropGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showManualNutritionCrop(
              context: context,
              gateway: gateway,
              image: const FoodCapturedImage('data:image/png;base64,AA=='),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('manual-nutrition-crop-confirm')),
    );
    await tester.pumpAndSettle();
    expect(gateway.cropCalls, 1);
    expect(gateway.lastRect, isNotNull);
    expect(gateway.lastRect!.width, greaterThan(1));
    expect(gateway.lastRect!.height, greaterThan(1));
  });

  testWidgets('source image stays visible and pans during active touch', (
    tester,
  ) async {
    final gateway = _CropGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showManualNutritionCrop(
              context: context,
              gateway: gateway,
              image: const FoodCapturedImage('data:image/png;base64,AA=='),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('manual-nutrition-crop-geometry-diagnostic')),
      findsOneWidget,
    );
    expect(find.textContaining('CANVAS'), findsOneWidget);
    final transformFinder = find.descendant(
      of: find.byKey(const ValueKey('manual-nutrition-crop-image-layer')),
      matching: find.byType(Transform),
    );
    final before = tester
        .widget<Transform>(transformFinder)
        .transform
        .getTranslation();
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('manual-nutrition-crop-gesture-area')),
      ),
    );
    await gesture.moveBy(const Offset(40, 25));
    await tester.pump();
    final during = tester
        .widget<Transform>(transformFinder)
        .transform
        .getTranslation();

    expect(
      find.byKey(const ValueKey('manual-nutrition-crop-source-image')),
      findsOneWidget,
    );
    expect(during.x - before.x, greaterThan(0));
    expect(during.y - before.y, greaterThan(0));
    expect(during.x - before.x, lessThanOrEqualTo(40));
    expect(during.y - before.y, lessThanOrEqualTo(25));
    expect(find.textContaining('STRICT raw='), findsOneWidget);
    expect(find.textContaining('candidate='), findsOneWidget);
    expect(find.textContaining('bounds x:'), findsOneWidget);
    expect(find.textContaining('post='), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('RELEASE norm='), findsOneWidget);
  });

  testWidgets(
    'minimum scale keeps a strict positive edge after release on portrait mobile geometry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _CropGateway(
        dimensions: const FoodImageDimensions(width: 1206, height: 1595),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showManualNutritionCrop(
                context: context,
                gateway: gateway,
                image: const FoodCapturedImage('data:image/png;base64,AA=='),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      final transform = find.byKey(
        const ValueKey('manual-nutrition-crop-image-transform'),
      );
      final before = tester
          .widget<Transform>(transform)
          .transform
          .getTranslation();
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('manual-nutrition-crop-gesture-area')),
        ),
      );
      await gesture.moveBy(const Offset(300, 300));
      await tester.pump();
      final atStrictEdge = tester
          .widget<Transform>(transform)
          .transform
          .getTranslation();
      await gesture.up();
      await tester.pumpAndSettle();
      final after = tester
          .widget<Transform>(transform)
          .transform
          .getTranslation();

      expect(atStrictEdge.x, greaterThan(before.x));
      expect(atStrictEdge.y, greaterThan(before.y));
      expect(after.x, closeTo(atStrictEdge.x, .1));
      expect(after.y, closeTo(atStrictEdge.y, .1));
      expect(find.textContaining('RELEASE norm='), findsOneWidget);
    },
  );

  testWidgets('pinch changes the rendered image transform scale', (
    tester,
  ) async {
    final gateway = _CropGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showManualNutritionCrop(
              context: context,
              gateway: gateway,
              image: const FoodCapturedImage('data:image/png;base64,AA=='),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    final transform = find.byKey(
      const ValueKey('manual-nutrition-crop-image-transform'),
    );
    final before = tester
        .widget<Transform>(transform)
        .transform
        .getMaxScaleOnAxis();
    final center = tester.getCenter(
      find.byKey(const ValueKey('manual-nutrition-crop-gesture-area')),
    );
    final first = await tester.startGesture(center - const Offset(24, 0));
    final second = await tester.startGesture(
      center + const Offset(24, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(-36, 0));
    await second.moveBy(const Offset(36, 0));
    await tester.pump();

    final after = tester
        .widget<Transform>(transform)
        .transform
        .getMaxScaleOnAxis();
    expect(after, greaterThan(before));
    expect(
      find.byKey(const ValueKey('manual-nutrition-crop-source-image')),
      findsOneWidget,
    );
    await second.up();
    await first.up();
  });
}

class _CropGateway implements FoodManualNutritionCropGateway {
  _CropGateway({
    this.dimensions = const FoodImageDimensions(width: 1200, height: 800),
  });

  int cropCalls = 0;
  FoodImageCropRect? lastRect;
  final FoodImageDimensions dimensions;

  @override
  Future<FoodCapturedImage> cropNutritionImage(
    FoodCapturedImage image,
    FoodImageCropRect sourceRect,
  ) async {
    cropCalls += 1;
    lastRect = sourceRect;
    return const FoodCapturedImage(
      'data:image/png;base64,AA==',
      origin: FoodOcrImageOrigin.userManualCrop,
    );
  }

  @override
  Future<FoodImageDimensions> nutritionImageDimensions(
    FoodCapturedImage image,
  ) async => dimensions;
}
