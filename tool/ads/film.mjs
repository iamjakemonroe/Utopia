// Films the cinema scene of the perf harness (tool/perf/cinema.dart) frame
// by frame on a clock of its own: each frame is drawn at exactly n/fps
// seconds and photographed once it's on screen, however long it took. So
// the film is smooth at any cost per frame (record.mjs films in real time).
//
// Each frame is drawn at [view]'s pixel density (2: 2160x3840), losslessly,
// and shrunk to [size] as it goes into a lossless video, [out]: the art's
// edges come out cleaner than drawing at [size] would.
//   FFMPEG=<ffmpeg> node film.mjs <build dir> <out.mkv> <query> <seconds> [fps] [WxH@dpr] [size] [warmup s]
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [root, out, query, secs, fps = '60', view = '1080x1920@2', size = '1080x1920', warm = '6'] =
  process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.wav': 'audio/wav', '.m4a': 'audio/mp4', '.jpg': 'image/jpeg' };
const base = path.resolve(root);
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const file = path.join(base, p);
  if (!file.startsWith(base) || !fs.existsSync(file)) return res.writeHead(404).end();
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream',
    'cross-origin-opener-policy': 'same-origin', 'cross-origin-embedder-policy': 'credentialless' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const [vw, vh, vd] = view.split(/[x@]/).map(Number);
const [ow, oh] = size.split('x').map(Number);
const browser = await chromium.launch({ channel: 'chrome',
  args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: vd,
  isMobile: true, hasTouch: true });
const page = await ctx.newPage();

// The page's clock: real until __vt.hold(), then it only moves on
// __vt.step(ms), which runs the frame Flutter asked for at the new time.
// __vt.shown counts frames put on screen (skwasm hands each finished frame
// to its canvas with transferFromImageBitmap).
await page.addInitScript(() => {
  const realRaf = window.requestAnimationFrame.bind(window);
  const realNow = performance.now.bind(performance);
  const realDate = Date.now;
  let held = null;
  let dateAt = 0;
  let queue = [];
  const vt = {
    shown: 0,
    hold() { held = realNow(); dateAt = realDate() - held; },
    step(ms) {
      held += ms;
      const due = queue;
      queue = [];
      for (const cb of due) cb(held);
      return due.length;
    },
    realRaf,
    realNow,
  };
  window.__vt = vt;
  window.requestAnimationFrame = (cb) => {
    if (held === null) return realRaf(cb);
    queue.push(cb);
    return queue.length;
  };
  performance.now = () => (held === null ? realNow() : held);
  Date.now = () => (held === null ? realDate() : dateAt + held);
  const transfer = ImageBitmapRenderingContext.prototype.transferFromImageBitmap;
  ImageBitmapRenderingContext.prototype.transferFromImageBitmap = function (bitmap) {
    const r = transfer.call(this, bitmap);
    if (bitmap && this.canvas instanceof HTMLCanvasElement) vt.shown++;
    return r;
  };
});

await page.goto(`http://localhost:${server.address().port}/?${query}`);
await page.waitForSelector('flutter-view', { timeout: 60000 });
await page.waitForTimeout(Number(warm) * 1000);
const cdp = await ctx.newCDPSession(page);
await page.evaluate(() => { window.__vt.hold(); window.__start(); });

// Frames go in as PNGs, are shrunk with Lanczos, and kept losslessly (RGB).
fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
const ff = spawn(process.env.FFMPEG ?? 'ffmpeg', ['-y', '-loglevel', 'error',
  '-f', 'image2pipe', '-c:v', 'png', '-framerate', fps, '-i', '-',
  '-vf', `scale=${ow}:${oh}:flags=lanczos`, '-c:v', 'libx264rgb', '-qp', '0',
  '-preset', 'veryfast', '-pix_fmt', 'rgb24', out], { stdio: ['pipe', 'inherit', 'inherit'] });
const finished = new Promise((r) => ff.on('close', r));

const total = Math.round(Number(secs) * Number(fps));
const dt = 1000 / Number(fps);
const began = Date.now();
for (let n = 0; n < total; n++) {
  // Draw frame n, wait (up to 5 s) until it's on screen, then a real frame
  // more so the compositor has it.
  await page.evaluate(async (ms) => {
    const vt = window.__vt;
    const before = vt.shown;
    vt.step(ms);
    const t0 = vt.realNow();
    await new Promise((done) => {
      const check = () => {
        if (vt.shown > before) return vt.realRaf(() => done());
        if (vt.realNow() - t0 > 5000) return done();
        setTimeout(check, 1);
      };
      check();
    });
  }, n === 0 ? 0 : dt);
  const shot = await cdp.send('Page.captureScreenshot', { format: 'png', optimizeForSpeed: true });
  if (!ff.stdin.write(Buffer.from(shot.data, 'base64'))) {
    await new Promise((r) => ff.stdin.once('drain', r));
  }
  if (n % 300 === 0) {
    const el = (Date.now() - began) / 1000;
    console.log(`frame ${n}/${total} (${el.toFixed(0)}s, ${(el / (n + 1)).toFixed(2)}s a frame)`);
  }
}
ff.stdin.end();
await finished;
console.log(`${total} frames at ${fps} fps in ${((Date.now() - began) / 1000).toFixed(0)}s -> ${out}`);
await browser.close();
server.close();
