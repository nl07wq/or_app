// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'food_input_capture_gateway.dart';

FoodInputCaptureGateway createPlatformFoodInputCaptureGateway() =>
    WebFoodInputCaptureGateway();

@JS('window')
external JSObject get _window;

class WebFoodInputCaptureGateway implements FoodLiveCaptureGateway {
  JSObject get _bridge {
    if (!_window.has('orAppFoodInput')) {
      throw StateError('Food input browser bridge is unavailable.');
    }
    return _window['orAppFoodInput'] as JSObject;
  }

  @override
  Future<FoodCapturedImage?> selectImage(FoodImageSource source) async {
    final result = await _bridge
        .callMethod<JSPromise<JSString?>>(
          'selectImage'.toJS,
          (source == FoodImageSource.camera).toJS,
        )
        .toDart;
    return result == null ? null : FoodCapturedImage(result.toDart);
  }

  @override
  Future<String> recognizeJapaneseText(
    FoodCapturedImage image, {
    FoodTextOcrMode mode = FoodTextOcrMode.package,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  }) async {
    final result = await _bridge
        .callMethod<JSPromise<JSString>>(
          'recognizeJapaneseText'.toJS,
          image.dataUrl.toJS,
          mode.name.toJS,
          engine.bridgeValue.toJS,
          scanMode.bridgeValue.toJS,
        )
        .toDart;
    return result.toDart;
  }

  @override
  Future<String?> scanBarcode(FoodCapturedImage image) async {
    final result = await _bridge
        .callMethod<JSPromise<JSString?>>(
          'scanBarcode'.toJS,
          image.dataUrl.toJS,
        )
        .toDart;
    return result?.toDart;
  }

  @override
  Future<FoodBarcodeCandidate?> scanBarcodeLive() async {
    final result = await _bridge
        .callMethod<JSPromise<JSString?>>('scanBarcodeLive'.toJS)
        .toDart;
    if (result == null) return null;
    final payload = jsonDecode(result.toDart) as Map<String, dynamic>;
    return FoodBarcodeCandidate(
      value: payload['value'] as String,
      format: payload['format'] as String,
    );
  }

  @override
  Future<String?> recognizeTextLive({
    required String title,
    required String instruction,
    required FoodOcrLiveCandidate Function(String rawText) describeCandidate,
    FoodOcrEngine engine = FoodOcrEngine.tesseract,
    FoodOcrScanMode scanMode = FoodOcrScanMode.nutritionLabelReader,
  }) async {
    final callback = ((JSString rawText) {
      return jsonEncode(describeCandidate(rawText.toDart).toJson()).toJS;
    }).toJS;
    final result = await _bridge
        .callMethod<JSPromise<JSString?>>(
          'recognizeTextLive'.toJS,
          title.toJS,
          instruction.toJS,
          callback,
          scanMode.bridgeValue.toJS,
        )
        .toDart;
    return result?.toDart;
  }
}
