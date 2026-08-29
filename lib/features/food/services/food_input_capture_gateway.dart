import 'food_input_capture_gateway_stub.dart'
    if (dart.library.html) 'food_input_capture_gateway_web.dart';

enum FoodImageSource { camera, gallery }

enum FoodNutritionCaptureMode { live, camera, gallery }

class FoodCapturedImage {
  const FoodCapturedImage(this.dataUrl);

  final String dataUrl;
}

class FoodBarcodeCandidate {
  const FoodBarcodeCandidate({required this.value, required this.format});

  final String value;
  final String format;
}

class FoodNutritionLiveCandidate {
  const FoodNutritionLiveCandidate({
    required this.state,
    this.calories,
    this.protein,
    this.fat,
    this.carbohydrate,
    this.basis,
    this.package,
  });

  final String state;
  final String? calories;
  final String? protein;
  final String? fat;
  final String? carbohydrate;
  final String? basis;
  final String? package;

  Map<String, String?> toJson() => {
    'state': state,
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbohydrate': carbohydrate,
    'basis': basis,
    'package': package,
  };
}

abstract interface class FoodInputCaptureGateway {
  Future<FoodCapturedImage?> selectImage(FoodImageSource source);

  Future<String> recognizeJapaneseText(FoodCapturedImage image);

  Future<String?> scanBarcode(FoodCapturedImage image);
}

abstract interface class FoodLiveCaptureGateway
    implements FoodInputCaptureGateway {
  Future<FoodBarcodeCandidate?> scanBarcodeLive();

  Future<String?> recognizeNutritionLive(
    FoodNutritionLiveCandidate Function(String rawText) describeCandidate,
  );
}

FoodInputCaptureGateway createFoodInputCaptureGateway() =>
    createPlatformFoodInputCaptureGateway();
