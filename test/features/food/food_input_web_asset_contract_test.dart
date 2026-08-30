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

  test('live camera bridge throttles work and cleans every session', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    expect(bridge, contains('navigator.mediaDevices.getUserMedia'));
    expect(bridge, contains("video.setAttribute('playsinline', '')"));
    expect(bridge, contains('setInterval(tick, 400)'));
    expect(bridge, contains('setInterval(tick, 1500)'));
    expect(bridge, contains('captureFrame(session.video, true)'));
    expect(bridge, contains('left: 0.04'));
    expect(bridge, contains('top: 0.10'));
    expect(bridge, contains('width: 0.92'));
    expect(bridge, contains('height: 0.80'));
    expect(bridge, contains('video.videoWidth * ocrGuide.left'));
    expect(bridge, contains('video.videoHeight * ocrGuide.top'));
    expect(
      bridge,
      contains("context.getImageData(0, 0, canvas.width, canvas.height)"),
    );
    expect(bridge, contains('canvas.width = Math.max(1'));
    expect(bridge, contains('worker.recognize(dataUrl)'));
    expect(bridge, contains('OCR recognition timed out'));
    expect(bridge, contains('await resetOcrWorker()'));
    expect(bridge, contains('if (finished || running) return'));
    expect(bridge, contains('ocrQueue.then(recognize, recognize)'));
    expect(bridge, contains('barcodeDetectorPromise'));
    expect(bridge, contains('barcodeReaderPromise'));
    expect(bridge, contains('clearInterval(timer)'));
    expect(bridge, contains('getTracks().forEach((track) => track.stop())'));
    expect(bridge, contains("use.textContent = 'USE THIS CODE'"));
    expect(bridge, contains("review.textContent = 'REVIEW RESULT'"));
    expect(bridge, contains("takePhoto.textContent = 'TAKE PHOTO'"));
    expect(bridge, contains("choosePhoto.textContent = 'CHOOSE PHOTO'"));
    expect(bridge, contains('serialized !== latestDescription'));
    expect(bridge, contains('candidate.value !== next.value'));
    expect(bridge, contains('latestRawText = rawText'));
    expect(
      bridge,
      contains('session.guide.firstElementChild.textContent = instruction'),
    );
    expect(bridge, contains('栄養成分を十分に読み取れませんでした'));
    expect(bridge, contains('栄養成分表示全体を枠内に入れてください'));
    expect(bridge, isNot(contains('文字を検出しました。読み取り対象を大きく映してください')));
    expect(bridge, isNot(contains('.reduce(')));
    expect(bridge, isNot(contains('navigator.sendBeacon')));
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
