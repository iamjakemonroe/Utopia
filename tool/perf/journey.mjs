// Where the web game stalls along a player's way through it: home, the
// side menu (the first time and again), then Collection, Store and Profile
// from the menu (each twice), in Chrome at a phone's size with the CPU
// slowed down, served isolated as the site is (Flutter draws on a
// background thread, so frames are counted as they're handed over).
//
//   (build as for measure.mjs)
//   node tool/perf/journey.mjs build/perf [world id] [cpu slowdown]
//
// For each step: frames shown, the longest wait between two, and what the
// main thread spent its time on (SELF=n functions).
import { chromium, webkit } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2]);
const world = process.argv[3] ?? 'utopia';
const slow = Number(process.argv[4] ?? 4);

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.wav': 'audio/wav', '.m4a': 'audio/mp4',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css', '.svg': 'image/svg+xml',
};
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const file = path.join(root, p);
  if (!file.startsWith(root) || !fs.existsSync(file)) return res.writeHead(404).end();
  res.writeHead(200, {
    'content-type': types[path.extname(file)] ?? 'application/octet-stream',
    'cross-origin-opener-policy': 'same-origin',
    'cross-origin-embedder-policy': process.env.ISOLATE ?? 'require-corp',
  });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const symbols = new Map();
const symFile = path.join(root, 'canvaskit/skwasm.js.symbols');
if (fs.existsSync(symFile)) {
  for (const line of fs.readFileSync(symFile, 'utf8').split('\n')) {
    const at = line.indexOf(':');
    if (at > 0) symbols.set(line.slice(0, at), line.slice(at + 1));
  }
}

// BROWSER=webkit: Safari's engine (every iPhone and iPad browser), at an
// iPad's size unless VIEW=<w>x<h>@<dpr> says otherwise. No CPU slowdown
// there (Chrome only).
const onWebKit = process.env.BROWSER === 'webkit';
const view = /^(\d+)x(\d+)@([\d.]+)$/.exec(process.env.VIEW ?? (onWebKit ? '820x1180@2' : '390x844@3'));
const browser = onWebKit
  ? await webkit.launch()
  : await chromium.launch({
      channel: 'chrome',
      args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'],
    });
const context = await browser.newContext({
  viewport: { width: Number(view[1]), height: Number(view[2]) },
  deviceScaleFactor: Number(view[3]),
  isMobile: !onWebKit,
  hasTouch: true,
});
// Every frame the drawing thread hands over, as it's put on screen.
await context.addInitScript(() => {
  window.__shown = [];
  const proto = window.ImageBitmapRenderingContext?.prototype;
  if (!proto) return;
  const put = proto.transferFromImageBitmap;
  proto.transferFromImageBitmap = function (bitmap) {
    window.__shown.push(performance.now());
    return put.call(this, bitmap);
  };
});
const page = await context.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
const cdp = onWebKit ? null : await context.newCDPSession(page);
await page.goto(`http://localhost:${port}/?scene=home&world=${world}`);
await page.waitForTimeout(9000);
console.log('isolated:', await page.evaluate(() => window.crossOriginIsolated));
if (cdp) {
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: slow });
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 250 });
}

async function step(name, action, ms, arg) {
  await cdp?.send('Profiler.start');
  const from = await page.evaluate(() => performance.now());
  await page.evaluate(action, arg);
  await page.waitForTimeout(ms);
  const profile = cdp ? (await cdp.send('Profiler.stop')).profile : null;
  const shown = await page.evaluate((from) => window.__shown.filter((t) => t >= from), from);
  const gaps = [];
  let last = from;
  for (const t of shown) {
    gaps.push(t - last);
    last = t;
  }
  const longest = [...gaps].sort((a, b) => b - a).slice(0, 3).map((g) => g.toFixed(0));
  const over = gaps.filter((g) => g > 50).length;
  console.log(`\n=== ${name}: ${shown.length} frames in ${(ms / 1000).toFixed(1)} s, longest waits ${longest.join(', ')} ms, ${over} over 50 ms`);
  if (!profile) return;
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  for (const n of profile.nodes) {
    const m = /^wasm-function\[(\d+)\]$/.exec(n.callFrame.functionName);
    if (m && /skwasm/.test(n.callFrame.url) && symbols.has(m[1])) {
      n.callFrame.functionName = 'sk:' + symbols.get(m[1]);
    }
  }
  const self = new Map();
  let total = 0;
  profile.samples.forEach((id, i) => {
    const n = byId.get(id);
    const d = profile.timeDeltas[i] ?? 0;
    const f = n.callFrame.functionName || `(${path.basename(n.callFrame.url) || n.callFrame.url})`;
    self.set(f, (self.get(f) ?? 0) + d);
    total += d;
  });
  const idle = (self.get('(idle)') ?? 0) / total;
  console.log(`main thread busy ${(100 * (1 - idle)).toFixed(0)}%`);
  [...self.entries()]
    .filter(([k]) => k !== '(idle)')
    .sort((a, b) => b[1] - a[1])
    .slice(0, Number(process.env.SELF ?? 8))
    .forEach(([k, v]) => console.log(`  ${(v / 1000).toFixed(0).padStart(5)} ms  ${k.slice(0, 110)}`));
}

const settle = () => page.waitForTimeout(1500);
await step('home, still', () => {}, 2000);
await step('side menu, first time', () => window.__menu(), 2500);
await step('side menu closing', () => window.__back(), 1500);
await settle();
await step('side menu, again', () => window.__menu(), 2500);
await step('side menu closing', () => window.__back(), 1500);
// ONLY=menu: just the side menu steps.
for (const round of process.env.ONLY === 'menu' ? [] : [1, 2]) {
  for (const where of ['collection', 'store', 'profile']) {
    await page.evaluate(() => window.__menu());
    await page.waitForTimeout(1200);
    await step(`${where} from the menu (${round})`, (w) => window.__go('/' + w), 3000, where);
    await page.screenshot({ path: `journey_${where}_${round}.png` });
    await step(`${where} closing`, () => window.__back(), 1500);
    await settle();
  }
}
if (errors.length) console.log('\nerrors: ' + errors.slice(0, 3).join(' | '));
await browser.close();
server.close();
