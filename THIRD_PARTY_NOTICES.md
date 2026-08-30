# Third-Party Notices

OR-APP self-hosts the following components for local, in-browser food-label
recognition. Runtime assets are served from `web/assets/food_input/`; captured
images and recognized text are not sent to an external OCR or product API.

## Tesseract.js

- Version: 7.0.0
- Project: https://github.com/naptha/tesseract.js
- License: Apache License 2.0
- Copyright: Tesseract.js contributors
- Bundled assets: `ocr/tesseract.min.js`, `ocr/worker.min.js`
- License copy: `web/assets/food_input/licenses/TESSERACT_JS_LICENSE.txt`

## Tesseract.js Core

- Version: 7.0.0
- Project: https://github.com/naptha/tesseract.js-core
- License: Apache License 2.0
- Copyright: Tesseract.js Core contributors and the Tesseract OCR project
- Bundled assets: `ocr/core/tesseract-core*`
- License copy: `web/assets/food_input/licenses/TESSDATA_FAST_LICENSE.txt`

## Tesseract tessdata_fast Japanese model

- Source revision: Git object `c4178f89991bde90b7fdc647e3e1901868423bd0`
- Project: https://github.com/tesseract-ocr/tessdata_fast
- License: Apache License 2.0
- Copyright: Tesseract OCR contributors
- Bundled asset: `ocr/lang/jpn.traineddata.gz`
- License copy: `web/assets/food_input/licenses/TESSERACT_CORE_LICENSE.txt`

## ZXing Browser

- Version: 0.2.1
- Project: https://github.com/zxing-js/browser
- License: MIT License
- Copyright: Copyright (c) 2018 ZXing for JS
- Bundled asset: `barcode/zxing-browser.min.js`
- License copy: `web/assets/food_input/licenses/ZXING_BROWSER_LICENSE.txt`

ZXing Browser's distributed UMD bundle includes the decoding implementation
from ZXing for JS. It is loaded only as the fallback when the browser-native
`BarcodeDetector` path cannot return a supported EAN-13, EAN-8, or UPC-A code.

## PaddleOCR.js and PP-OCRv5 mobile models

- PaddleOCR.js version: 0.4.2
- Models: `PP-OCRv5_mobile_det` and `PP-OCRv5_mobile_rec`
- Project: https://github.com/PaddlePaddle/PaddleOCR
- License: Apache License 2.0
- Copyright: PaddlePaddle Authors
- Bundled assets: `paddle/paddleocr-engine.mjs`, `paddle/assets/worker-entry-C9UNuyOJ.js`, and `paddle/models/PP-OCRv5_mobile_*_onnx_infer.tar`
- License copy: `web/assets/food_input/licenses/PADDLEOCR_LICENSE.txt`

The Paddle assets are an internal, nutrition-only feasibility path. They are
loaded lazily only when the hidden development engine flag selects `paddle`;
Tesseract remains the production default.

## ONNX Runtime Web

- Version: 1.24.3
- Project: https://github.com/microsoft/onnxruntime
- License: MIT License
- Copyright: Microsoft Corporation
- Bundled assets: ONNX Runtime code inside the Paddle bundles and `paddle/wasm/ort-wasm-simd-threaded.*`
- License copy: `web/assets/food_input/licenses/ONNXRUNTIME_LICENSE.txt`

## OpenCV.js

- Version: 4.10.0-release.1 (`@techstark/opencv-js` distribution)
- Project: https://github.com/TechStark/opencv-js
- License: Apache License 2.0
- Bundled asset: OpenCV.js runtime inside the Paddle engine and worker bundles
- License copy: `web/assets/food_input/licenses/OPENCV_JS_LICENSE.txt`

## Clipper Library

- Version: 6.4.2 (`clipper-lib`)
- Project: https://github.com/junmer/clipper-lib
- License: Boost Software License 1.0
- Bundled asset: polygon processing code inside the Paddle engine bundle
- License copy: `web/assets/food_input/licenses/CLIPPER_LIB_LICENSE.txt`

## js-yaml

- Version: 4.3.2
- Project: https://github.com/nodeca/js-yaml
- License: MIT License
- Copyright: Vitaly Puzrin and contributors
- Bundled asset: YAML model-configuration parser inside the Paddle engine bundle
- License copy: `web/assets/food_input/licenses/JS_YAML_LICENSE.txt`
