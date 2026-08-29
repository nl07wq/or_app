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
