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

  test(
    'active interaction permits bounded elasticity before end correction',
    () {
      const crop = Rect.fromLTWH(100, 100, 200, 160);
      final active = FoodManualCropInteraction.limitWithElasticity(
        viewport: crop,
        imageSize: const Size(300, 260),
        candidate: const Offset(30, -20),
        overscroll: 40,
      );

      expect(active.dx, 30);
      expect(active.dy, -20);
    },
  );

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

  test('elastic pan limits remain finite on all four crop edges', () {
    const crop = Rect.fromLTWH(100, 100, 200, 160);
    const image = Size(500, 460);
    final limited = FoodManualCropInteraction.limitWithElasticity(
      viewport: crop,
      imageSize: image,
      candidate: const Offset(999, -999),
      overscroll: 40,
    );

    expect(limited.dx, 140);
    expect(limited.dy, -240);
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

  test(
    'portrait active drag permits additional positive X and Y before release',
    () {
      const crop = Rect.fromLTWH(48, 92, 286, 414);
      const image = Size(508, 902);
      final bounds = FoodManualCropInteraction.translationBounds(
        viewport: crop,
        imageSize: image,
      );
      final active = FoodManualCropInteraction.limitWithElasticity(
        viewport: crop,
        imageSize: image,
        candidate: Offset(bounds.maxX + 132, bounds.maxY + 132),
        overscroll: 160,
      );

      expect(active.dx, bounds.maxX + 132);
      expect(active.dy, bounds.maxY + 132);
      expect(
        FoodManualCropInteraction.clampToCoverage(
          viewport: crop,
          imageSize: image,
          candidate: active,
        ),
        Offset(bounds.maxX, bounds.maxY),
      );
    },
  );

  test('portrait cover scale can collapse the persistent horizontal range', () {
    const crop = Rect.fromLTWH(24, 110, 343.2, 420);
    const image = Size(343.2, 610);
    final strict = FoodManualCropInteraction.translationBounds(
      viewport: crop,
      imageSize: image,
    );
    final active = FoodManualCropInteraction.activeTranslationBounds(
      viewport: crop,
      imageSize: image,
      overscroll: 120,
    );

    expect(strict.minX, crop.left);
    expect(strict.maxX, crop.left);
    expect(active.minX, crop.left - 120);
    expect(active.maxX, crop.left + 120);
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
    expect(during.x - before.x, closeTo(40, 1));
    expect(during.y - before.y, closeTo(25, 1));
    expect(find.textContaining('ACTIVE raw='), findsOneWidget);
    expect(find.textContaining('candidate='), findsOneWidget);
    expect(find.textContaining('bounds x:'), findsOneWidget);
    expect(find.textContaining('post='), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('RELEASE norm='), findsOneWidget);
  });

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
  int cropCalls = 0;
  FoodImageCropRect? lastRect;

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
  ) async => const FoodImageDimensions(width: 1200, height: 800);
}
