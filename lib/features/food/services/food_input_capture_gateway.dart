import 'food_input_capture_gateway_stub.dart'
    if (dart.library.html) 'food_input_capture_gateway_web.dart';

enum FoodImageSource { camera, gallery }

enum FoodNutritionCaptureMode { live, camera, gallery }

enum FoodTextOcrMode { package, nutrition }

enum FoodOcrEngine { tesseract, paddle }

enum FoodOcrScanMode { standard, nutritionLabelReader }

/// Identifies the pixels given to the OCR pipeline without conflating a
/// user-confirmed crop with an automatic OCR optimization.
enum FoodOcrImageOrigin { originalImage, userManualCrop, autoCrop }

class FoodImageDimensions {
  const FoodImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}

class FoodImageCropRect {
  const FoodImageCropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

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
  const FoodCapturedImage(
    this.dataUrl, {
    this.origin = FoodOcrImageOrigin.originalImage,
  });

  final String dataUrl;
  final FoodOcrImageOrigin origin;
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

/// Web-capable image operations used by the fixed-viewport nutrition crop.
/// The crop is always calculated in decoded source-image coordinates.
abstract interface class FoodManualNutritionCropGateway {
  Future<FoodImageDimensions> nutritionImageDimensions(FoodCapturedImage image);

  Future<FoodCapturedImage> cropNutritionImage(
    FoodCapturedImage image,
    FoodImageCropRect sourceRect,
  );
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

/// Temporary audit access to transient OCR pipeline diagnostics.
///
/// Implementations must not persist the source image or include image bytes in
/// copied diagnostic text.
abstract interface class FoodOcrDiagnosticGateway {
  Future<Map<String, dynamic>> diagnoseNutritionImage(
    FoodCapturedImage image, {
    required FoodImageSource source,
  });
}

FoodInputCaptureGateway createFoodInputCaptureGateway() =>
    createPlatformFoodInputCaptureGateway();
