import 'food_input_capture_gateway_stub.dart'
    if (dart.library.html) 'food_input_capture_gateway_web.dart';

enum FoodImageSource { camera, gallery }

enum FoodNutritionCaptureMode { live, camera, gallery }

enum FoodTextOcrMode { package, nutrition }

enum FoodOcrEngine { tesseract, paddle }

enum FoodOcrScanMode { standard, nutritionLabelReader }

extension FoodOcrScanModePresentation on FoodOcrScanMode {
  String get bridgeValue => switch (this) {
    FoodOcrScanMode.standard => 'standard',
    FoodOcrScanMode.nutritionLabelReader => 'nutritionReader',
  };

  String get label => switch (this) {
    FoodOcrScanMode.standard => 'STANDARD OCR',
    FoodOcrScanMode.nutritionLabelReader => 'NUTRITION LABEL READER',
  };
}

extension FoodOcrEnginePresentation on FoodOcrEngine {
  String get bridgeValue => name;

  String get label => switch (this) {
    FoodOcrEngine.tesseract => 'TESSERACT',
    FoodOcrEngine.paddle => 'PADDLE PoC',
  };
}

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

  Future<String> recognizeJapaneseText(
    FoodCapturedImage image, {
    FoodTextOcrMode mode = FoodTextOcrMode.package,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  });

  Future<String?> scanBarcode(FoodCapturedImage image);
}

abstract interface class FoodLiveCaptureGateway
    implements FoodInputCaptureGateway {
  Future<FoodBarcodeCandidate?> scanBarcodeLive();

  Future<String?> recognizeTextLive({
    required String title,
    required String instruction,
    required FoodOcrLiveCandidate Function(String rawText) describeCandidate,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  });
}

FoodInputCaptureGateway createFoodInputCaptureGateway() =>
    createPlatformFoodInputCaptureGateway();
