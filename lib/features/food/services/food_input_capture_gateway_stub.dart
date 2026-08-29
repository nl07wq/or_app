import 'food_input_capture_gateway.dart';

FoodInputCaptureGateway createPlatformFoodInputCaptureGateway() =>
    _UnsupportedFoodInputCaptureGateway();

class _UnsupportedFoodInputCaptureGateway implements FoodInputCaptureGateway {
  Never _unsupported() =>
      throw UnsupportedError('Image capture is available on web only.');

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async =>
      _unsupported();

  @override
  Future<String> recognizeJapaneseText(FoodCapturedImage image) async =>
      _unsupported();

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async => _unsupported();
}
