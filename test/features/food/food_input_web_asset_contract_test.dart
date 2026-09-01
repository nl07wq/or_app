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
      'PaddleOCR.js',
      'PP-OCRv5_mobile_det',
      'PP-OCRv5_mobile_rec',
      'ONNX Runtime Web',
      'OpenCV.js',
      'Clipper Library',
      'js-yaml',
      'Apache License 2.0',
      'MIT License',
      'Boost Software License 1.0',
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
    expect(bridge, contains('import(paths.paddleModule)'));
    expect(bridge, contains('textDetectionModelAsset:'));
    expect(bridge, contains('textRecognitionModelAsset:'));
    expect(bridge, contains('wasmPaths: paths.paddleWasm'));
    expect(bridge, contains("numThreads: 1"));
    expect(bridge, contains("'BarcodeDetector' in window"));
    expect(bridge, contains("['ean_13', 'ean_8', 'upc_a']"));
    expect(bridge, contains('EAN_13|EAN_8|UPC_A'));
    expect(bridge, isNot(contains('https://')));
  });

  test('visible scan-mode selector keeps hidden engine compatibility', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();
    final scanner = File(
      'lib/features/food/widgets/food_ocr_scanner.dart',
    ).readAsStringSync();

    expect(bridge, contains('function selectedOcrEngine'));
    expect(bridge, contains("window.__OR_APP_OCR_ENGINE__"));
    expect(bridge, contains("get('orOcrEngine')"));
    expect(bridge, contains("? 'paddle'"));
    expect(bridge, contains(": 'tesseract'"));
    expect(bridge, contains("if (mode !== 'nutrition') return 'tesseract'"));
    expect(scanner, contains('SELECT SCAN MODE'));
    expect(scanner, contains('STANDARD OCR'));
    expect(scanner, contains('NUTRITION LABEL READER'));
    expect(scanner, isNot(contains("title: 'PADDLE PoC'")));
    expect(bridge, contains('engineOverride'));
    expect(bridge, contains('selectedOcrEngine(mode, engineOverride)'));
    expect(bridge, contains("scanStrategy = 'nutritionReader'"));
    expect(bridge, contains("scanStrategy === 'standard'"));
  });

  test('Paddle result keeps text geometry confidence and diagnostics', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    expect(bridge, contains("engineId: 'paddle'"));
    expect(bridge, contains('items: result.items'));
    expect(bridge, contains('source: result.image'));
    expect(bridge, contains('durationMs'));
    expect(bridge, contains('paddleItemBox'));
    expect(bridge, contains('confidence: Number(item.score) * 100'));
    expect(bridge, contains('result.metrics.detectedBoxes'));
    expect(bridge, contains('result.metrics.recognizedCount'));
    expect(bridge, contains('paddleQueue.then(recognize, recognize)'));
    expect(bridge, contains('Paddle OCR recognition timed out'));
    expect(bridge, contains('await resetPaddleWorker()'));
  });

  test('Paddle iPhone diagnostic traces stages without formal data', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    for (final stage in [
      'P0',
      'P1',
      'P2',
      'P3',
      'P4',
      'P5',
      'P6',
      'P7',
      'P8',
      'P9',
      'P10',
      'P11',
      'P12',
      'P13',
      'P14',
      'P15',
      'P16',
      'P17',
      'P18',
      'P19',
      'P20',
      'P21',
      'P22',
      'P23',
      'P24',
      'P25',
      'P26',
      'P27',
      'P28',
    ]) {
      expect(bridge, contains('$stage:'));
    }
    expect(bridge, contains('requestedEngine'));
    expect(bridge, contains('resolvedEngine'));
    expect(bridge, contains('actualExecutedEngine'));
    expect(bridge, contains('failureCategory'));
    expect(bridge, contains('errorCategory'));
    expect(bridge, contains('watchdogFired'));
    expect(bridge, contains('memorySnapshot()'));
    expect(bridge, contains("method: 'HEAD'"));
    expect(bridge, contains('content-type'));
    expect(bridge, contains('content-length'));
    expect(bridge, contains("new Worker(paths.paddleWorker"));
    expect(bridge, contains("PADDLE PoC  "));
    expect(bridge, contains('COPY DIAGNOSTICS'));
    expect(bridge, contains('RUN SMALL TEST'));
    expect(bridge, contains('paddleDiagnosticsSnapshot'));
    expect(bridge, contains("maxWidth: 'calc(100vw - 16px)'"));
    expect(bridge, contains("boxSizing: 'border-box'"));
    expect(bridge, contains('env(safe-area-inset-bottom)'));
    expect(bridge, isNot(contains('stack:')));
    final paddleDiagnostics = bridge.substring(
      bridge.indexOf('function startPaddleDiagnostics'),
      bridge.indexOf('function ensurePaddleDiagnostics'),
    );
    expect(paddleDiagnostics, isNot(contains('rawText:')));
  });

  test('nutrition camera uses one-shot shutter and cleans every session', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    expect(bridge, contains('navigator.mediaDevices.getUserMedia'));
    expect(bridge, contains("video.setAttribute('playsinline', '')"));
    expect(bridge, contains('setInterval(tick, 400)'));
    expect(bridge, contains('setInterval(tick, 1500)'));
    expect(bridge, contains("if (mode !== 'nutrition')"));
    expect(bridge, contains('captureOcrFrame(session)'));
    expect(bridge, contains('captureBestFrame(session)'));
    expect(bridge, contains("shutter.dataset.role = 'nutrition-shutter'"));
    expect(
      bridge,
      contains("shutter.setAttribute('aria-label', 'Scan nutrition label')"),
    );
    expect(bridge, contains('if (finished || running) return'));
    expect(bridge, contains('shutter.disabled = busy'));
    expect(bridge, contains('choosePhoto.disabled = busy'));
    expect(bridge, contains('for (const variant of ocrVariants'));
    expect(bridge, contains('await recognizeSinglePass(variant.dataUrl)'));
    expect(bridge, isNot(contains('Promise.all(')));
    expect(bridge, contains("'REVIEW CONFLICT'"));
    expect(bridge, contains('previous !== value'));
    expect(bridge, contains("name: 'original'"));
    expect(bridge, contains("name: 'grayscale'"));
    expect(bridge, contains("name: 'moderate-contrast'"));
    expect(bridge, contains('width: { ideal: 3840 }'));
    expect(bridge, contains('height: { ideal: 2160 }'));
    expect(bridge, contains("focusMode: 'continuous'"));
    expect(bridge, contains('left: 0.04'));
    expect(bridge, contains('top: 0.10'));
    expect(bridge, contains('width: 0.92'));
    expect(bridge, contains('height: 0.80'));
    expect(bridge, contains('width: 0.96'));
    expect(bridge, contains('height: 0.88'));
    expect(
      bridge,
      contains('ocrGeometry(video.videoWidth, video.videoHeight, guide)'),
    );
    expect(bridge, contains('const maxLongEdge = 2560'));
    expect(bridge, contains('const resizeTargetLongEdge = 2048'));
    expect(bridge, contains('const maximumUpscale = 2'));
    expect(bridge, contains("'canvas-image-smoothing-upscale'"));
    expect(bridge, contains('inputWidth: canvas.width'));
    expect(bridge, contains('inputHeight: canvas.height'));
    expect(bridge, contains('devicePixelRatio: window.devicePixelRatio'));
    expect(bridge, contains('function frameQuality(canvas)'));
    expect(bridge, contains('minSharpness: 5'));
    expect(bridge, contains('minEdgeDensity: 0.012'));
    expect(
      bridge,
      contains('return best && best.quality.usable ? best : null'),
    );
    expect(
      bridge,
      contains("context.getImageData(0, 0, canvas.width, canvas.height)"),
    );
    expect(bridge, contains('canvas.width = Math.max(1'));
    expect(bridge, contains('worker.recognize(dataUrl, {}, outputs)'));
    expect(bridge, contains('OCR recognition timed out'));
    expect(bridge, contains('await resetOcrWorker()'));
    expect(bridge, contains('if (finished || running) return'));
    expect(bridge, contains('ocrQueue.then(recognize, recognize)'));
    expect(bridge, contains('barcodeDetectorPromise'));
    expect(bridge, contains('barcodeReaderPromise'));
    expect(bridge, contains('clearInterval(timer)'));
    expect(bridge, contains('getTracks().forEach((track) => track.stop())'));
    expect(bridge, contains("use.textContent = 'USE THIS CODE'"));
    expect(bridge, contains("choosePhoto.textContent = 'CHOOSE PHOTO'"));
    expect(
      bridge,
      isNot(contains("highAccuracy.textContent = 'HIGH ACCURACY SCAN'")),
    );
    expect(bridge, isNot(contains("takePhoto.textContent = 'TAKE PHOTO'")));
    expect(bridge, contains('candidate.value !== next.value'));
    expect(bridge, contains('latestRawText = rawText'));
    expect(
      bridge,
      contains(
        "scanStrategy === 'standard' ? 'STANDARD OCR' : 'NUTRITION LABEL READER'",
      ),
    );
    expect(
      bridge,
      contains('session.guide.firstElementChild.textContent = instruction'),
    );
    expect(bridge, contains('栄養成分を十分に読み取れませんでした'));
    expect(bridge, contains('高精度読み取りを試してください'));
    expect(bridge, isNot(contains('文字を検出しました。読み取り対象を大きく映してください')));
    expect(bridge, isNot(contains('もっと大きく映してください')));
    expect(bridge, isNot(contains('大きく映すか写真を使用してください')));
    expect(bridge, isNot(contains('.reduce(')));
    expect(bridge, isNot(contains('navigator.sendBeacon')));
  });

  test('photo OCR preserves native detail before shared guide resize', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    expect(bridge, contains('async function imageMetadata(dataUrl)'));
    expect(bridge, contains('metadata.orientation'));
    expect(bridge, contains('originalWidth: metadata.width'));
    expect(bridge, contains('decodedWidth: image.naturalWidth'));
    expect(bridge, contains('orientationAppliedByDecoder'));
    expect(bridge, contains('function ocrGeometry(width, height, guide)'));
    expect(bridge, contains('const geometry = ocrGeometry('));
    expect(bridge, contains('image.naturalWidth'));
    expect(bridge, contains('image.naturalHeight'));
    expect(bridge, contains('geometry.sourceWidth'));
    expect(bridge, contains('geometry.inputWidth'));
    expect(bridge, contains('cropWidth: geometry.sourceWidth'));
    expect(bridge, contains('passDurationsMs: []'));
    expect(bridge, contains('structuredDurationMs'));
    expect(bridge, contains('lastPhotoDiagnostics'));
    expect(bridge, contains('lastStructuredDiagnostics'));
  });

  test(
    'developer nutrition diagnostics compare both modes without persistence',
    () {
      final bridge = File(
        'web/assets/food_input/food_input_bridge.js',
      ).readAsStringSync();
      final scanner = File(
        'lib/features/food/widgets/food_ocr_scanner.dart',
      ).readAsStringSync();

      expect(bridge, contains('async function diagnoseNutritionPhoto'));
      expect(bridge, contains("['standard', 'standard']"));
      expect(bridge, contains("['nutritionLabelReader', 'nutritionReader']"));
      for (final field in [
        'sourceDimensions',
        'cropRect',
        'cropDimensions',
        'preResizeDimensions',
        'ocrDimensions',
        'cropApplied',
        'resizeApplied',
        'resizeMethod',
        'resizeScale',
        'sharedOcrArtifact',
        'rotationCorrection',
        'perspectiveCorrection',
        'preprocessVariant',
        'passes',
        'rawText',
        'wordCount',
        'averageConfidence',
        'detectedLabels',
        'numericCandidates',
        'structuredCandidates',
        'selectedMappings',
        'fallbackUsed',
        'fallbackReason',
        'finalResult',
        'timings',
      ]) {
        expect(bridge, contains('$field:'));
      }
      expect(bridge, contains("persistence: 'none'"));
      expect(bridge, contains('createSharedNutritionOcrArtifact'));
      expect(bridge, contains('consumeSharedNutritionOcrArtifact'));
      expect(bridge, contains('collectSharedOcrPasses'));
      expect(bridge, contains('generatedOnce: true'));
      expect(bridge, contains('sameRawOcr: standardRaw === readerRaw'));
      expect(bridge, isNot(contains('localStorage.setItem')));
      expect(scanner, contains('if (diagnosticsAvailable)'));
      expect(scanner, isNot(contains('kDebugMode && diagnosticsAvailable')));
      expect(scanner, contains('COPY OCR DIAGNOSTICS'));
      expect(scanner, contains('VIEW STANDARD INPUT'));
      expect(scanner, contains('VIEW NUTRITION INPUT'));
      expect(scanner, contains('formatFoodOcrDiagnosticReport(diagnostics)'));
    },
  );

  test('structured nutrition OCR uses anchors, layout, and numeric ROI', () {
    final bridge = File(
      'web/assets/food_input/food_input_bridge.js',
    ).readAsStringSync();

    for (final label in [
      'エネルギー',
      '熱量',
      'たんぱく質',
      'タンパク質',
      '蛋白質',
      '脂質',
      '炭水化物',
      '糖質',
      '食物繊維',
      '食塩相当量',
    ]) {
      expect(bridge, contains(label));
    }
    expect(bridge, contains('outputs: { text: true, tsv: true }'));
    expect(bridge, contains('function nutritionAnchors(groups)'));
    expect(bridge, contains('function mapAnchorValues(anchors, values)'));
    expect(bridge, contains('function valueFromRoi(canvas, anchor, field)'));
    expect(bridge, contains("whitelist: '0123456789.,kcalg'"));
    expect(bridge, contains("return 'header-value-row'"));
    expect(bridge, contains("'vertical-list'"));
    expect(bridge, contains("'two-column-table'"));
    expect(bridge, contains("return 'boxed-wrapped'"));
    expect(bridge, contains('structuredMarker'));
    expect(bridge, contains('nutritionBasisPattern'));
    expect(bridge, contains("indexOf('栄養成分表示')"));
    expect(bridge, contains("fieldSources: Object.fromEntries"));
    expect(bridge, isNot(contains('Promise.all(')));
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
      'web/assets/food_input/paddle/paddleocr-engine.mjs',
      'web/assets/food_input/paddle/paddleocr-engine.mjs.LEGAL.txt',
      'web/assets/food_input/paddle/assets/worker-entry-C9UNuyOJ.js',
      'web/assets/food_input/paddle/wasm/ort-wasm-simd-threaded.mjs',
      'web/assets/food_input/paddle/wasm/ort-wasm-simd-threaded.wasm',
      'web/assets/food_input/paddle/wasm/ort-wasm-simd-threaded.jsep.mjs',
      'web/assets/food_input/paddle/wasm/ort-wasm-simd-threaded.jsep.wasm',
      'web/assets/food_input/paddle/models/PP-OCRv5_mobile_det_onnx_infer.tar',
      'web/assets/food_input/paddle/models/PP-OCRv5_mobile_rec_onnx_infer.tar',
      'web/assets/food_input/licenses/PADDLEOCR_LICENSE.txt',
      'web/assets/food_input/licenses/ONNXRUNTIME_LICENSE.txt',
      'web/assets/food_input/licenses/OPENCV_JS_LICENSE.txt',
      'web/assets/food_input/licenses/CLIPPER_LIB_LICENSE.txt',
      'web/assets/food_input/licenses/JS_YAML_LICENSE.txt',
    ]) {
      expect(File(path).lengthSync(), greaterThan(0), reason: path);
    }
  });
}
