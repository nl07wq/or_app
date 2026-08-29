import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('third-party notices identify every self-hosted runtime', () {
    final notice = File('THIRD_PARTY_NOTICES.md').readAsStringSync();
    for (final value in [
      'Tesseract.js',
      'Tesseract.js Core',
      'tessdata_fast',
      'ZXing Browser',
      'Apache License 2.0',
      'MIT License',
    ]) {
      expect(notice, contains(value));
    }
  });

  test('OCR and barcode assets are self-hosted and lazy-loaded', () {
    final index = File('web/index.html').readAsStringSync();
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    expect(index, contains('food_input_bridge.js'));
    expect(index, isNot(contains('tesseract.min.js')));
    expect(index, isNot(contains('zxing-browser.min.js')));
    expect(bridge, contains("loadScript(paths.tesseract)"));
    expect(bridge, contains("loadScript(paths.zxing)"));
    expect(bridge, contains("'BarcodeDetector' in window"));
    expect(bridge, contains("['ean_13', 'ean_8', 'upc_a']"));
    expect(bridge, contains('EAN_13|EAN_8|UPC_A'));
    expect(bridge, isNot(contains('https://')));
  });

  test('required OCR worker core model and license files exist', () {
    for (final path in [
      'web/assets/food_input/ocr/tesseract.min.js',
      'web/assets/food_input/ocr/worker.min.js',
      'web/assets/food_input/ocr/core/tesseract-core-lstm.wasm.js',
      'web/assets/food_input/ocr/core/tesseract-core-simd-lstm.wasm.js',
      'web/assets/food_input/ocr/core/tesseract-core-relaxedsimd-lstm.wasm.js',
      'web/assets/food_input/ocr/lang/jpn.traineddata.gz',
      'web/assets/food_input/barcode/zxing-browser.min.js',
      'web/assets/food_input/licenses/TESSERACT_JS_LICENSE.txt',
      'web/assets/food_input/licenses/TESSERACT_CORE_LICENSE.txt',
      'web/assets/food_input/licenses/TESSDATA_FAST_LICENSE.txt',
      'web/assets/food_input/licenses/ZXING_BROWSER_LICENSE.txt',
    ]) {
      expect(File(path).lengthSync(), greaterThan(0), reason: path);
    }
  });
}
