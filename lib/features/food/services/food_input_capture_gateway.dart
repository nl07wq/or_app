import 'food_input_capture_gateway_stub.dart'
    if (dart.library.html) 'food_input_capture_gateway_web.dart';

enum FoodImageSource { camera, gallery }

class FoodCapturedImage {
  const FoodCapturedImage(this.dataUrl);

  final String dataUrl;
}

abstract interface class FoodInputCaptureGateway {
  Future<FoodCapturedImage?> selectImage(FoodImageSource source);

  Future<String> recognizeJapaneseText(FoodCapturedImage image);

  Future<String?> scanBarcode(FoodCapturedImage image);
}

FoodInputCaptureGateway createFoodInputCaptureGateway() =>
    createPlatformFoodInputCaptureGateway();
