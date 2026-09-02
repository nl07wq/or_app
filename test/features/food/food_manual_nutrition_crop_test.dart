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
