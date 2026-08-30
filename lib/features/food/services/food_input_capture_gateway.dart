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

class FoodOcrLiveCandidate {
  const FoodOcrLiveCandidate({required this.state, required this.fields});

  final String state;
  final Map<String, String?> fields;

  Map<String, Object?> toJson() => {'state': state, 'fields': fields};
}

abstract interface class FoodInputCaptureGateway {
  Future<FoodCapturedImage?> selectImage(FoodImageSource source);

  Future<String> recognizeJapaneseText(FoodCapturedImage image);

  Future<String?> scanBarcode(FoodCapturedImage image);
}

abstract interface class FoodLiveCaptureGateway
    implements FoodInputCaptureGateway {
  Future<FoodBarcodeCandidate?> scanBarcodeLive();

  Future<String?> recognizeTextLive({
    required String title,
    required String instruction,
    required FoodOcrLiveCandidate Function(String rawText) describeCandidate,
  });
}

FoodInputCaptureGateway createFoodInputCaptureGateway() =>
    createPlatformFoodInputCaptureGateway();
