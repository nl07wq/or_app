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
  let workerInstance;
  let ocrQueue = Promise.resolve();
  let barcodeDetectorPromise;
  let barcodeReaderPromise;
  const ocrPassSeparator = '\u001e';
  const ocrGuide = Object.freeze({ left: 0.04, top: 0.10, width: 0.92, height: 0.80 });
  const packageGuide = Object.freeze({ left: 0.02, top: 0.06, width: 0.96, height: 0.88 });
  const frameQualityThreshold = Object.freeze({
    minBrightness: 28,
    maxBrightness: 232,
    minContrast: 16,
    minSharpness: 5,
    minEdgeDensity: 0.012,
  });
  let lastCaptureDiagnostics;

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
        workerInstance = await Tesseract.createWorker('jpn', 1, {
          workerPath: paths.worker,
          corePath: paths.core,
          langPath: paths.language,
          gzip: true,
          cacheMethod: 'none',
        });
        return workerInstance;
      })();
    }
    return workerPromise;
  }

  async function resetOcrWorker() {
    const worker = workerInstance;
    workerPromise = undefined;
    workerInstance = undefined;
    if (worker) {
      try {
        await worker.terminate();
      } catch (_) {
        // The worker may already have stopped after a runtime failure.
      }
    }
  }

  function recognizeSinglePass(dataUrl) {
    const recognize = async () => {
      const worker = await ocrWorker();
      let timeout;
      try {
        const result = await Promise.race([
          worker.recognize(dataUrl),
          new Promise((_, reject) => {
            timeout = setTimeout(
              () => reject(new Error('OCR recognition timed out')),
              25000,
            );
          }),
        ]);
        return result.data.text || '';
      } catch (error) {
        await resetOcrWorker();
        throw error;
      } finally {
        clearTimeout(timeout);
      }
    };
    const result = ocrQueue.then(recognize, recognize);
    ocrQueue = result.catch(() => {});
    return result;
  }

  function canvasFromImage(dataUrl) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        const maxWidth = 2560;
        const scale = Math.min(1, maxWidth / image.naturalWidth);
        const canvas = document.createElement('canvas');
        canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
        canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
        const context = canvas.getContext('2d', { alpha: false });
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        resolve(canvas);
      };
      image.onerror = reject;
      image.src = dataUrl;
    });
  }

  function processedVariant(source, contrast) {
    const canvas = document.createElement('canvas');
    canvas.width = source.width;
    canvas.height = source.height;
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(source, 0, 0);
    const image = context.getImageData(0, 0, canvas.width, canvas.height);
    for (let index = 0; index < image.data.length; index += 4) {
      const luminance =
        image.data[index] * 0.299 +
        image.data[index + 1] * 0.587 +
        image.data[index + 2] * 0.114;
      const value = Math.max(0, Math.min(255, (luminance - 128) * contrast + 128));
      image.data[index] = value;
      image.data[index + 1] = value;
      image.data[index + 2] = value;
    }
    context.putImageData(image, 0, 0);
    return canvas.toDataURL('image/png');
  }

  function ocrVariants(canvas, mode) {
    return [
      { name: 'original', dataUrl: canvas.toDataURL('image/jpeg', 0.94) },
      { name: 'grayscale', dataUrl: processedVariant(canvas, 1) },
      {
        name: 'moderate-contrast',
        dataUrl: processedVariant(canvas, mode === 'nutrition' ? 1.35 : 1.22),
      },
    ];
  }

  async function recognizeJapaneseText(dataUrl, mode = 'package') {
    const canvas = await canvasFromImage(dataUrl);
    const texts = [];
    for (const variant of ocrVariants(canvas, mode)) {
      const text = await recognizeSinglePass(variant.dataUrl);
      if (text.trim() && !texts.includes(text)) texts.push(text);
    }
    return texts.join(ocrPassSeparator);
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

  function cameraSurface(title, guideSpec) {
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
    const guide = document.createElement('div');
    guide.style.cssText = [
      'display:none',
      'position:absolute',
      `left:${guideSpec.left * 100}%`,
      `top:${guideSpec.top * 100}%`,
      `width:${guideSpec.width * 100}%`,
      `height:${guideSpec.height * 100}%`,
      'box-sizing:border-box',
      'border:2px solid rgba(255,255,255,.9)',
      'border-radius:12px',
      'box-shadow:0 0 0 9999px rgba(0,0,0,.18)',
      'pointer-events:none',
    ].join(';');
    const guideLabel = document.createElement('span');
    guideLabel.textContent = '読み取り対象をこの枠内に合わせてください';
    guideLabel.style.cssText = 'position:absolute;left:8px;right:8px;top:8px;padding:6px 8px;border-radius:8px;background:rgba(0,0,0,.68);font-size:.82rem;text-align:center';
    guide.appendChild(guideLabel);
    preview.append(video, guide);

    const result = document.createElement('div');
    result.style.cssText = 'margin-top:12px;padding:12px;border:1px solid rgba(255,255,255,.22);border-radius:12px;background:#111923;min-height:48px';
    const actions = document.createElement('div');
    actions.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;margin-top:12px';
    overlay.append(header, preview, result, actions);
    document.body.appendChild(overlay);
    return { overlay, video, guide, close, result, actions };
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

  async function openCamera(title, mode = 'package') {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error('Camera unavailable');
    }
    const guideSpec = mode === 'nutrition' ? ocrGuide : packageGuide;
    const surface = cameraSurface(title, guideSpec);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 3840 },
          height: { ideal: 2160 },
        },
      });
      surface.video.srcObject = stream;
      await surface.video.play();
      const track = stream.getVideoTracks()[0];
      try {
        const capabilities = track.getCapabilities ? track.getCapabilities() : {};
        if (capabilities.focusMode && capabilities.focusMode.includes('continuous')) {
          await track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] });
        }
      } catch (_) {
        // Continuous autofocus is optional and not exposed by every iOS release.
      }
      const settings = track.getSettings ? track.getSettings() : {};
      return { ...surface, stream, mode, guideSpec, settings };
    } catch (error) {
      surface.overlay.remove();
      throw error;
    }
  }

  function captureFrame(video) {
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      return null;
    }
    const sourceWidth = video.videoWidth;
    const sourceHeight = video.videoHeight;
    const scale = Math.min(1, 1280 / sourceWidth);
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(sourceWidth * scale));
    canvas.height = Math.max(1, Math.round(sourceHeight * scale));
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(
      video,
      0,
      0,
      sourceWidth,
      sourceHeight,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    return canvas.toDataURL('image/jpeg', 0.86);
  }

  function frameQuality(canvas) {
    const sample = document.createElement('canvas');
    sample.width = Math.min(192, canvas.width);
    sample.height = Math.max(1, Math.round(sample.width * canvas.height / canvas.width));
    const context = sample.getContext('2d', { alpha: false, willReadFrequently: true });
    context.drawImage(canvas, 0, 0, sample.width, sample.height);
    const pixels = context.getImageData(0, 0, sample.width, sample.height).data;
    const gray = new Float32Array(sample.width * sample.height);
    let sum = 0;
    for (let index = 0; index < gray.length; index += 1) {
      const offset = index * 4;
      const value =
        pixels[offset] * 0.299 +
        pixels[offset + 1] * 0.587 +
        pixels[offset + 2] * 0.114;
      gray[index] = value;
      sum += value;
    }
    const brightness = sum / gray.length;
    let variance = 0;
    let sharpness = 0;
    let edges = 0;
    let samples = 0;
    for (let y = 1; y < sample.height - 1; y += 1) {
      for (let x = 1; x < sample.width - 1; x += 1) {
        const index = y * sample.width + x;
        const delta = gray[index] - brightness;
        variance += delta * delta;
        const laplacian = Math.abs(
          gray[index - 1] + gray[index + 1] +
          gray[index - sample.width] + gray[index + sample.width] -
          4 * gray[index],
        );
        sharpness += laplacian;
        if (laplacian >= 18) edges += 1;
        samples += 1;
      }
    }
    const contrast = Math.sqrt(variance / Math.max(1, samples));
    sharpness /= Math.max(1, samples);
    const edgeDensity = edges / Math.max(1, samples);
    const usable =
      brightness >= frameQualityThreshold.minBrightness &&
      brightness <= frameQualityThreshold.maxBrightness &&
      contrast >= frameQualityThreshold.minContrast &&
      sharpness >= frameQualityThreshold.minSharpness &&
      edgeDensity >= frameQualityThreshold.minEdgeDensity;
    return {
      brightness: Number(brightness.toFixed(2)),
      contrast: Number(contrast.toFixed(2)),
      sharpness: Number(sharpness.toFixed(2)),
      edgeDensity: Number(edgeDensity.toFixed(4)),
      usable,
      score: contrast + sharpness * 4 + edgeDensity * 200,
    };
  }

  function captureOcrFrame(session) {
    const video = session.video;
    if (video.readyState < 2 || !video.videoWidth || !video.videoHeight) {
      return null;
    }
    const guide = session.guideSpec;
    const sourceX = Math.round(video.videoWidth * guide.left);
    const sourceY = Math.round(video.videoHeight * guide.top);
    const sourceWidth = Math.max(1, Math.round(video.videoWidth * guide.width));
    const sourceHeight = Math.max(1, Math.round(video.videoHeight * guide.height));
    const maxWidth = 2560;
    const scale = Math.min(1, maxWidth / sourceWidth);
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(sourceWidth * scale));
    canvas.height = Math.max(1, Math.round(sourceHeight * scale));
    const context = canvas.getContext('2d', { alpha: false });
    context.drawImage(
      video,
      sourceX,
      sourceY,
      sourceWidth,
      sourceHeight,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    const quality = frameQuality(canvas);
    lastCaptureDiagnostics = {
      mode: session.mode,
      videoWidth: video.videoWidth,
      videoHeight: video.videoHeight,
      readyState: video.readyState,
      devicePixelRatio: window.devicePixelRatio || 1,
      facingMode: session.settings.facingMode || 'unknown',
      sourceX,
      sourceY,
      sourceWidth,
      sourceHeight,
      inputWidth: canvas.width,
      inputHeight: canvas.height,
      quality,
    };
    return { canvas, quality };
  }

  const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 120));

  async function captureBestFrame(session) {
    let best;
    for (let index = 0; index < 3; index += 1) {
      if (index) await nextFrame();
      const frame = captureOcrFrame(session);
      if (frame && (!best || frame.quality.score > best.quality.score)) best = frame;
    }
    return best && best.quality.usable ? best : null;
  }

  function stopCamera(session) {
    session.stream.getTracks().forEach((track) => track.stop());
    session.video.srcObject = null;
    session.overlay.remove();
  }

  async function scanBarcodeLive() {
    const session = await openCamera('SCAN BARCODE');
    session.result.textContent = '読み取り中...';
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
            state.textContent = '読み取り完了';
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

  function ocrResultContent(target, candidate, mode) {
    target.replaceChildren();
    const state = document.createElement('strong');
    state.textContent = mode === 'nutrition'
      ? candidate.state === 'detected'
        ? '読み取り完了'
        : candidate.state === 'partial'
          ? '一部読み取り'
          : candidate.state === 'insufficient'
            ? '栄養項目不足'
            : '読み取り中...'
      : candidate.state === 'partial' || candidate.state === 'detected'
        ? '商品情報候補が見つかりました'
        : '商品情報候補を検索中...';
    target.appendChild(state);
    if (candidate.state === 'insufficient') {
      const guidance = document.createElement('div');
      guidance.textContent = mode === 'nutrition'
        ? '文字を検出しましたが、栄養成分を十分に読み取れませんでした。表全体を枠内に入れ、高精度読み取りを試してください。'
        : '文字を検出しました。商品表面全体を枠内に入れ、高精度読み取りを試してください。';
      guidance.style.cssText = 'margin-top:4px';
      target.appendChild(guidance);
    }
    const values = Object.entries(candidate.fields || {});
    for (const [label, value] of values) {
      if (!value) continue;
      const row = document.createElement('div');
      row.textContent = `${label}  ${value}`;
      row.style.cssText = 'margin-top:4px';
      target.appendChild(row);
    }
  }

  async function recognizeTextLive(title, instruction, describeCandidate) {
    const mode = title.includes('NUTRITION') ? 'nutrition' : 'package';
    const session = await openCamera(title, mode);
    session.guide.style.display = 'block';
    session.guide.firstElementChild.textContent = instruction;
    session.result.textContent = instruction;
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
    const highAccuracy = document.createElement('button');
    highAccuracy.type = 'button';
    highAccuracy.textContent = 'HIGH ACCURACY SCAN';
    styleButton(highAccuracy, true);
    session.actions.append(highAccuracy, review, takePhoto, choosePhoto);

    return new Promise((resolve) => {
      let timer;
      let running = false;
      let latestRawText = null;
      let latestDescription = null;
      let unsuccessfulScans = 0;
      const highAccuracyValues = new Map();
      const highAccuracyConflicts = new Set();
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
          resolve(image ? await recognizeJapaneseText(image, mode) : null);
        } catch (_) {
          resolve(null);
        }
      };
      session.close.onclick = () => finish(null);
      review.onclick = () => latestRawText && finish(latestRawText);
      takePhoto.onclick = () => finishWithImage(true);
      choosePhoto.onclick = () => finishWithImage(false);

      const present = (rawText, trackConflicts = false) => {
        const description = JSON.parse(describeCandidate(rawText));
        if (trackConflicts) {
          for (const [field, value] of Object.entries(description.fields || {})) {
            if (!value) continue;
            const previous = highAccuracyValues.get(field);
            if (previous && previous !== value) highAccuracyConflicts.add(field);
            if (!previous) highAccuracyValues.set(field, value);
          }
          if (highAccuracyConflicts.size) {
            description.fields = {
              ...description.fields,
              'REVIEW CONFLICT': [...highAccuracyConflicts].join(', '),
            };
          }
        }
        const serialized = JSON.stringify(description);
        const hasCandidate = description.state === 'partial' ||
          description.state === 'detected';
        if (hasCandidate) {
          latestDescription = serialized;
          ocrResultContent(session.result, description, mode);
          review.disabled = false;
        } else if (review.disabled) {
          ocrResultContent(session.result, description, mode);
        }
        return hasCandidate;
      };

      highAccuracy.onclick = async () => {
        if (finished || running) return;
        running = true;
        highAccuracy.disabled = true;
        highAccuracyValues.clear();
        highAccuracyConflicts.clear();
        session.result.textContent = '高精度で読み取り中...';
        try {
          const frame = await captureBestFrame(session);
          if (!frame) {
            session.result.textContent = 'カメラを静止させ、反射を避けてもう一度お試しください。';
            return;
          }
          const texts = [];
          for (const variant of ocrVariants(frame.canvas, mode)) {
            const rawText = await recognizeSinglePass(variant.dataUrl);
            if (!rawText.trim() || texts.includes(rawText)) continue;
            texts.push(rawText);
            present(rawText, true);
          }
          if (texts.length) latestRawText = texts.join(ocrPassSeparator);
          if (review.disabled) {
            session.result.textContent = mode === 'nutrition'
              ? '栄養成分を認識できませんでした。反射を避けて再度お試しください。'
              : '商品情報候補を認識できませんでした。反射を避けて再度お試しください。';
          }
        } catch (_) {
          if (!finished) {
            session.result.textContent = '高精度読み取りを完了できません。写真での読み取りをお試しください。';
          }
        } finally {
          running = false;
          highAccuracy.disabled = false;
        }
      };

      const tick = async () => {
        if (finished || running) return;
        const frame = captureOcrFrame(session);
        if (!frame) return;
        if (!frame.quality.usable) {
          session.result.textContent = 'カメラを静止させ、反射を避けてください。';
          return;
        }
        running = true;
        session.result.textContent = '読み取り中...';
        try {
          const rawText = await recognizeSinglePass(
            frame.canvas.toDataURL('image/jpeg', 0.92),
          );
          if (finished) return;
          const description = JSON.parse(describeCandidate(rawText));
          const serialized = JSON.stringify(description);
          const hasCandidate = description.state === 'partial' ||
            description.state === 'detected';
          if (hasCandidate &&
              serialized !== latestDescription) {
            unsuccessfulScans = 0;
            latestRawText = rawText;
            latestDescription = serialized;
            ocrResultContent(session.result, description, mode);
            review.disabled = false;
          } else if (description.state === 'insufficient') {
            unsuccessfulScans += 1;
            ocrResultContent(session.result, description, mode);
          } else if (description.state === 'scanning') {
            unsuccessfulScans += 1;
            session.result.textContent = unsuccessfulScans >= 3
                ? '高精度読み取り、または写真での読み取りをお試しください。'
                : '読み取り中...';
          }
        } catch (_) {
          if (!finished) {
            clearInterval(timer);
            session.result.textContent = '読み取り処理を完了できません。写真での読み取りをお試しください';
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
    recognizeTextLive,
    assetState: () => ({
      ocrLoaded: loadedScripts.has(paths.tesseract),
      barcodeFallbackLoaded: loadedScripts.has(paths.zxing),
      ocrGuide: { ...ocrGuide },
      packageGuide: { ...packageGuide },
      frameQualityThreshold: { ...frameQualityThreshold },
      ocrPasses: ['original', 'grayscale', 'moderate-contrast'],
      lastCaptureDiagnostics,
    }),
  };
})();
