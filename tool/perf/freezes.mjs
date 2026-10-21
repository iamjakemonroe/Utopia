// Looks for freezes: a scene left running for a while (45 s by default) in
// Chrome at a phone's size, every frame over 200 ms noted, and what was
// running during each one (from the CPU profile, the functions with the
// most time of their own in that stretch).
//
//   (build as for measure.mjs)
//   node tool/perf/freezes.mjs build/perf cards,ludo,eights utopia [seconds] [cpu slowdown]
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2]);
const scenes = (process.argv[3] ?? 'cards').split(',');
const world = process.argv[4] ?? 'utopia';
const seconds = Number(process.argv[5] ?? 45);
const slow = Number(process.argv[6] ?? 2);
const LONG = Number(process.env.LONG ?? 200);

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
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' });
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

const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'],
});
for (const scene of scenes) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true,
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
  const cdp = await context.newCDPSession(page);
  await page.goto(`http://localhost:${port}/?scene=${scene}&world=${world}`);
  await page.waitForTimeout(6000);
  // A tap, as a player's first touch (it switches the sound on).
  await page.mouse.click(195, 300);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: slow });
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 500 });
  await cdp.send('Profiler.start');
  const t0 = await page.evaluate(() => performance.now());
  const frames = await page.evaluate(
    (ms) =>
      new Promise((done) => {
        const out = [];
        let last = performance.now();
        const end = last + ms;
        const step = (t) => {
          out.push([last, t]);
          last = t;
          if (t < end) requestAnimationFrame(step);
          else done(out);
        };
        requestAnimationFrame(step);
      }),
    seconds * 1000,
  );
  const { profile } = await cdp.send('Profiler.stop');
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await page.screenshot({ path: `freezes_${scene}_${world}.png` });
  await context.close();

  for (const n of profile.nodes) {
    const m = /^wasm-function\[(\d+)\]$/.exec(n.callFrame.functionName);
    if (m && symbols.has(m[1])) n.callFrame.functionName = 'sk:' + symbols.get(m[1]);
  }
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  const parent = new Map();
  for (const n of profile.nodes) for (const c of n.children ?? []) parent.set(c, n.id);
  // Sample times on the page's clock (the profile starts at t0, near enough).
  const times = [];
  let at = profile.startTime;
  for (const d of profile.timeDeltas) {
    at += d;
    times.push(t0 + (at - profile.startTime) / 1000);
  }
  const gaps = frames.map(([a, b]) => b - a);
  const long = frames.filter(([a, b]) => b - a >= LONG);
  const sorted = [...gaps].sort((x, y) => x - y);
  console.log(`\n=== ${scene} in ${world}, ${seconds} s, cpu x${slow}`);
  console.log(`frames ${gaps.length}, p50 ${sorted[Math.floor(sorted.length / 2)].toFixed(1)} ms, ` +
    `p99 ${sorted[Math.floor(sorted.length * 0.99)].toFixed(1)} ms, ${long.length} over ${LONG} ms`);
  if (errors.length) console.log('errors:', errors.slice(0, 3));
  for (const [a, b] of long) {
    const self = new Map();
    const incl = new Map();
    profile.samples.forEach((id, i) => {
      if (times[i] < a || times[i] > b) return;
      const n = byId.get(id).callFrame;
      const name = n.functionName || `(${path.basename(n.url) || n.url})`;
      if (name === '(idle)') return;
      self.set(name, (self.get(name) ?? 0) + 1);
      const seen = new Set();
      for (let x = id; x != null; x = parent.get(x)) {
        const f = byId.get(x).callFrame.functionName;
        if (!f || seen.has(f)) continue;
        seen.add(f);
        incl.set(f, (incl.get(f) ?? 0) + 1);
      }
    });
    const total = [...self.values()].reduce((x, y) => x + y, 0) || 1;
    console.log(`\n  ${(b - a).toFixed(0)} ms at ${((a - t0) / 1000).toFixed(1)} s:`);
    [...self.entries()].sort((x, y) => y[1] - x[1]).slice(0, 8)
      .forEach(([k, v]) => console.log(`    self ${((100 * v) / total).toFixed(0).padStart(3)}%  ${k.slice(0, 100)}`));
    [...incl.entries()]
      .filter(([k]) => !/^\(|^sk:|^wasm-function/.test(k))
      .sort((x, y) => y[1] - x[1]).slice(0, 14)
      .forEach(([k, v]) => console.log(`    in   ${((100 * v) / total).toFixed(0).padStart(3)}%  ${k.slice(0, 100)}`));
  }
}
await browser.close();
server.close();
