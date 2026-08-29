// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'food_input_capture_gateway.dart';

FoodInputCaptureGateway createPlatformFoodInputCaptureGateway() =>
    WebFoodInputCaptureGateway();

@JS('window')
external JSObject get _window;

class WebFoodInputCaptureGateway implements FoodInputCaptureGateway {
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
  Future<String> recognizeJapaneseText(FoodCapturedImage image) async {
    final result = await _bridge
        .callMethod<JSPromise<JSString>>(
          'recognizeJapaneseText'.toJS,
          image.dataUrl.toJS,
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
}
