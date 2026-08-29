(() => {
  'use strict';

  const root = new URL('assets/food_input/', document.baseURI);
  const paths = {
    tesseract: new URL('ocr/tesseract.min.js', root).href,
    worker: new URL('ocr/worker.min.js', root).href,
    core: new URL('ocr/core/', root).href,
    language: new URL('ocr/lang/', root).href,
    zxing: new URL('barcode/zxing-browser.min.js', root).href,
  };
  const loadedScripts = new Map();
  let workerPromise;
  let ocrQueue = Promise.resolve();
  let barcodeDetectorPromise;
  let barcodeReaderPromise;

  function loadScript(url) {
    if (loadedScripts.has(url)) return loadedScripts.get(url);
    const promise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error(`Failed to load ${url}`));
      document.head.appendChild(script);
    });
    loadedScripts.set(url, promise);
    return promise;
  }

  function selectImage(preferCamera) {
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      if (preferCamera) input.setAttribute('capture', 'environment');
      input.style.display = 'none';
      document.body.appendChild(input);
      let finished = false;
      let focusTimer;
      const finish = (value) => {
        if (finished) return;
        finished = true;
        clearTimeout(focusTimer);
        window.removeEventListener('focus', onFocus);
        input.remove();
        resolve(value);
      };
      const onFocus = () => {
        focusTimer = setTimeout(() => {
          if (!input.files || input.files.length === 0) finish(null);
        }, 1000);
      };
      window.addEventListener('focus', onFocus, { once: true });
      input.addEventListener('change', () => {
        const file = input.files && input.files[0];
        if (!file) return finish(null);
        const reader = new FileReader();
        reader.onload = () => finish(String(reader.result));
        reader.onerror = () => finish(null);
        reader.readAsDataURL(file);
      }, { once: true });
      input.click();
    });
  }

  async function ocrWorker() {
    if (!workerPromise) {
      workerPromise = (async () => {
        await loadScript(paths.tesseract);
        return Tesseract.createWorker('jpn', 1, {
          workerPath: paths.worker,
          corePath: paths.core,
          langPath: paths.language,
          gzip: true,
          cacheMethod: 'none',
        });
      })();
    }
    return workerPromise;
  }

  function recognizeJapaneseText(dataUrl) {
    const recognize = async () => {
      const worker = await ocrWorker();
      const result = await worker.recognize(dataUrl);
      return result.data.text || '';
    };
    const result = ocrQueue.then(recognize, recognize);
    ocrQueue = result.catch(() => {});
    return result;
  }

  function barcodeFormat(value) {
    const format = String(value)
      .replace(/^BarcodeFormat\./, '')
      .replace(/_/g, '-')
      .toUpperCase();
    return /^(EAN-13|EAN-8|UPC-A)$/.test(format) ? format : 'UNKNOWN';
  }

  async function barcodeDetector() {
    if (!('BarcodeDetector' in window)) return null;
    if (!barcodeDetectorPromise) {
      barcodeDetectorPromise = (async () => {
        const supported = await BarcodeDetector.getSupportedFormats();
        const formats = ['ean_13', 'ean_8', 'upc_a'].filter((format) =>
          supported.includes(format),
        );
        return formats.length ? new BarcodeDetector({ formats }) : null;
      })();
    }
    return barcodeDetectorPromise;
  }

  async function nativeBarcode(dataUrl) {
    const detector = await barcodeDetector();
    if (!detector) return null;
    const response = await fetch(dataUrl);
    const bitmap = await createImageBitmap(await response.blob());
    try {
      const results = await detector.detect(bitmap);
      return results.length
        ? {
            value: results[0].rawValue,
            format: barcodeFormat(results[0].format),
          }
        : null;
    } finally {
      bitmap.close();
    }
  }

  async function fallbackBarcode(dataUrl) {
    if (!barcodeReaderPromise) {
      barcodeReaderPromise = (async () => {
        await loadScript(paths.zxing);
        return new ZXingBrowser.BrowserMultiFormatReader();
      })();
    }
    const reader = await barcodeReaderPromise;
    try {
      const result = await reader.decodeFromImageUrl(dataUrl);
      const rawFormat = result.getBarcodeFormat();
      const format = ZXingBrowser.BarcodeFormat[rawFormat] || String(rawFormat);
      if (!/EAN_13|EAN_8|UPC_A/.test(format)) return null;
      return {
        value: result.getText(),
        format: barcodeFormat(format),
      };
    } catch (_) {
      return null;
    }
  }

  async function scanBarcode(dataUrl) {
    try {
      const nativeResult = await nativeBarcode(dataUrl);
      if (nativeResult) return nativeResult.value;
    } catch (_) {
      // Continue with the self-hosted decoder.
    }
    const fallbackResult = await fallbackBarcode(dataUrl);
    return fallbackResult && fallbackResult.value;
  }

  async function decodeBarcode(dataUrl) {
    try {
      const nativeResult = await nativeBarcode(dataUrl);
      if (nativeResult) return nativeResult;
    } catch (_) {
      // Continue with the self-hosted decoder.
    }
    return fallbackBarcode(dataUrl);
  }

  function cameraSurface(title) {
    const overlay = document.createElement('div');
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.style.cssText = [
      'position:fixed',
      'inset:0',
      'z-index:2147483647',
      'background:#05080d',
      'color:#fff',
      'display:flex',
      'flex-direction:column',
      'padding:max(16px, env(safe-area-inset-top)) 16px max(16px, env(safe-area-inset-bottom))',
      'box-sizing:border-box',
      'font-family:system-ui,-apple-system,sans-serif',
    ].join(';');

    const header = document.createElement('div');
    header.style.cssText = 'display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px';
    const heading = document.createElement('strong');
    heading.textContent = title;
    const close = document.createElement('button');
    close.type = 'button';
    close.textContent = 'CLOSE';
    styleButton(close, false);
    header.append(heading, close);

    const preview = document.createElement('div');
    preview.style.cssText = 'position:relative;flex:1;min-height:0;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid rgba(255,255,255,.22);border-radius:16px;background:#000';
    const video = document.createElement('video');
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;
    video.setAttribute('playsinline', '');
    video.style.cssText = 'width:100%;height:100%;object-fit:cover';
    preview.appendChild(video);

    const result = document.createElement('div');
    result.style.cssText = 'margin-top:12px;padding:12px;border:1px solid rgba(255,255,255,.22);border-radius:12px;background:#111923;min-height:48px';
    const actions = document.createElement('div');
    actions.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-top:12px';
    overlay.append(header, preview, result, actions);
    document.body.appendChild(overlay);
    return { overlay, video, close, result, actions };
  }

  function styleButton(button, primary) {
    button.style.cssText = [
      'appearance:none',
      'border-radius:10px',
      'border:1px solid rgba(255,255,255,.28)',
      `background:${primary ? '#2f80ed' : '#182231'}`,
      'color:#fff',
      'font-weight:700',
      'min-height:44px',
      'padding:10px 14px',
      'flex:1 1 130px',
    ].join(';');
  }

  async function openCamera(title) {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error('Camera unavailable');
    }
    const surface = cameraSurface(title);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: { ideal: 'environment' } },
      });
      surface.video.srcObject = stream;
      await surface.video.play();
      return { ...surface, stream };
    } catch (error) {
      surface.overlay.remove();
      throw error;
    }
  }

  function captureFrame(video) {
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      return null;
    }
    const maxWidth = 1280;
    const scale = Math.min(1, maxWidth / video.videoWidth);
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(video.videoWidth * scale);
    canvas.height = Math.round(video.videoHeight * scale);
    canvas.getContext('2d', { alpha: false }).drawImage(
      video,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    return canvas.toDataURL('image/jpeg', 0.86);
  }

  function stopCamera(session) {
    session.stream.getTracks().forEach((track) => track.stop());
    session.video.srcObject = null;
    session.overlay.remove();
  }

  async function scanBarcodeLive() {
    const session = await openCamera('SCAN BARCODE');
    session.result.textContent = 'SCANNING...';
    const use = document.createElement('button');
    use.type = 'button';
    use.textContent = 'USE THIS CODE';
    use.disabled = true;
    styleButton(use, true);
    session.actions.appendChild(use);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let candidate = null;
      let finished = false;
      const finish = (value) => {
        if (finished) return;
        finished = true;
        clearInterval(timer);
        stopCamera(session);
        resolve(value);
      };
      session.close.onclick = () => finish(null);
      use.onclick = () => candidate && finish(JSON.stringify(candidate));

      const tick = async () => {
        if (finished || running) return;
        const frame = captureFrame(session.video);
        if (!frame) return;
        running = true;
        try {
          const next = await decodeBarcode(frame);
          if (!finished && next &&
              (!candidate || candidate.value !== next.value || candidate.format !== next.format)) {
            candidate = next;
            session.result.replaceChildren();
            const state = document.createElement('strong');
            state.textContent = 'DETECTED';
            const value = document.createElement('div');
            value.textContent = next.value;
            value.style.cssText = 'font-size:1.25rem;font-weight:800;margin-top:6px;overflow-wrap:anywhere';
            const format = document.createElement('div');
            format.textContent = `FORMAT  ${next.format || 'UNKNOWN'}`;
            format.style.cssText = 'opacity:.78;margin-top:4px';
            session.result.append(state, value, format);
            use.disabled = false;
          }
        } finally {
          running = false;
        }
      };
      timer = setInterval(tick, 400);
      tick();
    });
  }

  function nutritionResultContent(target, candidate) {
    target.replaceChildren();
    const state = document.createElement('strong');
    state.textContent = candidate.state || 'SCANNING...';
    target.appendChild(state);
    const values = [
      ['CALORIES', candidate.calories],
      ['PROTEIN', candidate.protein],
      ['FAT', candidate.fat],
      ['CARBOHYDRATE', candidate.carbohydrate],
      ['BASIS', candidate.basis],
      ['PACKAGE', candidate.package],
    ];
    for (const [label, value] of values) {
      if (!value) continue;
      const row = document.createElement('div');
      row.textContent = `${label}  ${value}`;
      row.style.cssText = 'margin-top:4px';
      target.appendChild(row);
    }
  }

  async function recognizeNutritionLive(describeCandidate) {
    const session = await openCamera('READ NUTRITION LABEL');
    session.result.textContent = 'SCANNING...';
    const review = document.createElement('button');
    review.type = 'button';
    review.textContent = 'REVIEW RESULT';
    review.disabled = true;
    styleButton(review, true);
    const takePhoto = document.createElement('button');
    takePhoto.type = 'button';
    takePhoto.textContent = 'TAKE PHOTO';
    styleButton(takePhoto, false);
    const choosePhoto = document.createElement('button');
    choosePhoto.type = 'button';
    choosePhoto.textContent = 'CHOOSE PHOTO';
    styleButton(choosePhoto, false);
    session.actions.append(review, takePhoto, choosePhoto);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let latestRawText = null;
      let latestDescription = null;
      let finished = false;
      const cleanup = () => {
        if (finished) return false;
        finished = true;
        clearInterval(timer);
        stopCamera(session);
        return true;
      };
      const finish = (value) => {
        if (!cleanup()) return;
        resolve(value);
      };
      const finishWithImage = async (preferCamera) => {
        if (!cleanup()) return;
        try {
          const image = await selectImage(preferCamera);
          resolve(image ? await recognizeJapaneseText(image) : null);
        } catch (_) {
          resolve(null);
        }
      };
      session.close.onclick = () => finish(null);
      review.onclick = () => latestRawText && finish(latestRawText);
      takePhoto.onclick = () => finishWithImage(true);
      choosePhoto.onclick = () => finishWithImage(false);

      const tick = async () => {
        if (finished || running) return;
        const frame = captureFrame(session.video);
        if (!frame) return;
        running = true;
        try {
          const rawText = await recognizeJapaneseText(frame);
          if (finished) return;
          const description = JSON.parse(describeCandidate(rawText));
          const serialized = JSON.stringify(description);
          if (description.state !== 'SCANNING...' &&
              serialized !== latestDescription) {
            latestRawText = rawText;
            latestDescription = serialized;
            nutritionResultContent(session.result, description);
            review.disabled = false;
          }
        } catch (_) {
          if (!finished) {
            clearInterval(timer);
            session.result.textContent = 'OCR PROCESSING FAILED';
          }
        } finally {
          running = false;
        }
      };
      timer = setInterval(tick, 1500);
      tick();
    });
  }

  window.orAppFoodInput = {
    selectImage,
    recognizeJapaneseText,
    scanBarcode,
    scanBarcodeLive,
    recognizeNutritionLive,
    assetState: () => ({
      ocrLoaded: loadedScripts.has(paths.tesseract),
      barcodeFallbackLoaded: loadedScripts.has(paths.zxing),
    }),
  };
})();
