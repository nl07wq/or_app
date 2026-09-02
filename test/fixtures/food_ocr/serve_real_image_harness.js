'use strict';

// Test-only loopback server. It exposes existing repository bytes without
// transforming them so the browser executes the production OCR bridge.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../../..');
const port = Number(process.env.OR_APP_OCR_FIXTURE_PORT || 43127);
const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gz': 'application/gzip',
  '.wasm': 'application/wasm',
};

http.createServer((request, response) => {
  const pathname = decodeURIComponent((request.url || '/').split('?')[0]);
  const relative = pathname === '/' || pathname === '/real_image_harness.html'
    ? 'test/fixtures/food_ocr/real_image_harness.html'
    : pathname.startsWith('/assets/')
      ? `web${pathname}`
      : pathname.startsWith('/fixtures/')
        ? `test${pathname}`
        : `.${pathname}`;
  const target = path.resolve(root, relative);
  if (!target.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end('Forbidden');
    return;
  }
  fs.stat(target, (error, stat) => {
    if (error || !stat.isFile()) {
      response.writeHead(404).end('Not found');
      return;
    }
    response.writeHead(200, {
      'Content-Type': contentTypes[path.extname(target).toLowerCase()] ||
        'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    fs.createReadStream(target).pipe(response);
  });
}).listen(port, '127.0.0.1', () => {
  process.stdout.write(`OR_APP_OCR_FIXTURE_SERVER_READY:${port}\n`);
});
