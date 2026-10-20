// How fast the web game draws, and where the time goes, in Chrome at a
// phone's size (390x844 at 3x) with the CPU slowed down (4x by default).
//
//   flutter build web --profile --wasm --no-strip-wasm \
//     --no-web-resources-cdn -t tool/perf/perf_main.dart \
//     --dart-define-from-file=env/local.json -o build/perf
//   cd tool/perf && npm i --no-save playwright@1.55.0   (once)
//   node tool/perf/measure.mjs build/perf world,cards,chess utopia_doodle
//
// Arguments: <build dir> <scene[,scene]> [world id] [cpu slowdown]
// [extra query, e.g. pieces=classic]. Environment:
//   SELF=n     the n functions with the most time of their own
//   TOP=n      the n with the most in all (INCL=<regex> to pick which)
//   FOCUS=f    what f's time goes on; CALLERS=f who calls f
//   ISOLATE=credentialless|require-corp   serve it isolated, as the site
//     does (Flutter then draws on a background thread)
// skwasm's own functions are named from canvaskit/skwasm.js.symbols.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2]);
const scenes = (process.argv[3] ?? 'world').split(',');
const world = process.argv[4] ?? 'utopia';
const slow = Number(process.argv[5] ?? 4);
const extra = process.argv[6] ?? '';

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
  const headers = { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' };
  if (process.env.ISOLATE) {
    headers['cross-origin-opener-policy'] = 'same-origin';
    headers['cross-origin-embedder-policy'] = process.env.ISOLATE;
  }
  res.writeHead(200, headers);
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const port = server.address().port;

const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'],
});
for (const scene of scenes) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e).slice(0, 200)));
  const cdp = await context.newCDPSession(page);
  await page.goto(`http://localhost:${port}/?scene=${scene}&world=${world}${extra ? '&' + extra : ''}`);
  await page.waitForTimeout(7000);
  console.log('isolated:', await page.evaluate(() => window.crossOriginIsolated));
  const gpu = await page.evaluate(() => {
    const gl = document.createElement('canvas').getContext('webgl');
    const ext = gl?.getExtension('WEBGL_debug_renderer_info');
    return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'none';
  });
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: slow });
  if (process.env.PUSH) {
    // The frames just after window.__push() (a screen opening over this one).
    const gaps = await page.evaluate(
      () =>
        new Promise((done) => {
          const out = [];
          let last = performance.now();
          const end = last + 2500;
          const step = (t) => {
            out.push(t - last);
            last = t;
            if (t < end) requestAnimationFrame(step);
            else done(out);
          };
          window.__push();
          requestAnimationFrame(step);
        }),
    );
    const sorted = [...gaps].sort((a, b) => b - a);
    const long = gaps.filter((g) => g > 50).length;
    console.log(`\n=== ${scene}: opening it, cpu x${slow}`);
    console.log(`frames ${gaps.length} in 2.5 s, longest ${sorted.slice(0, 4).map((g) => g.toFixed(0)).join(', ')} ms, ${long} over 50 ms`);
    await page.screenshot({ path: `perf_${scene}_${world}_pushed.png` });
    await context.close();
    continue;
  }
  await cdp.send('Profiler.enable');
  await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
  await cdp.send('Profiler.start');
  const gaps = await page.evaluate(
    () =>
      new Promise((done) => {
        const out = [];
        let last = performance.now();
        const end = last + 6000;
        const step = (t) => {
          out.push(t - last);
          last = t;
          if (t < end) requestAnimationFrame(step);
          else done(out);
        };
        requestAnimationFrame(step);
      }),
  );
  const { profile } = await cdp.send('Profiler.stop');
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 });
  await page.screenshot({ path: `perf_${scene}_${world}.png` });
  await context.close();

  const sorted = [...gaps].sort((a, b) => a - b);
  const avg = gaps.reduce((a, b) => a + b, 0) / gaps.length;
  const pct = (q) => sorted[Math.floor(sorted.length * q)].toFixed(1);
  console.log(`\n=== ${scene} in ${world}, cpu x${slow} (${gpu})`);
  console.log(`fps ${(1000 / avg).toFixed(1)}  frame ms p50 ${pct(0.5)} p90 ${pct(0.9)} p99 ${pct(0.99)}`);

  // skwasm's own functions, named from its symbols file.
  const symbols = new Map();
  const symFile = path.join(root, 'canvaskit/skwasm.js.symbols');
  if (fs.existsSync(symFile)) {
    for (const line of fs.readFileSync(symFile, 'utf8').split('\n')) {
      const at = line.indexOf(':');
      if (at > 0) symbols.set(line.slice(0, at), line.slice(at + 1));
    }
  }
  for (const n of profile.nodes) {
    const m = /^wasm-function\[(\d+)\]$/.exec(n.callFrame.functionName);
    if (m && /skwasm/.test(n.callFrame.url) && symbols.has(m[1])) {
      n.callFrame.functionName = 'sk:' + symbols.get(m[1]);
    }
  }
  // Self time by function.
  const byId = new Map(profile.nodes.map((n) => [n.id, n]));
  const self = new Map();
  const dt = profile.timeDeltas;
  let total = 0;
  profile.samples.forEach((id, i) => {
    const n = byId.get(id);
    const name = n.callFrame.functionName || `(${path.basename(n.callFrame.url) || n.callFrame.url})`;
    self.set(name, (self.get(name) ?? 0) + (dt[i] ?? 0));
    total += dt[i] ?? 0;
  });
  const idle = (self.get('(idle)') ?? 0) / total;
  console.log(`busy ${(100 * (1 - idle)).toFixed(0)}% of the time`);
  [...self.entries()]
    .filter(([k]) => k !== '(idle)')
    .sort((a, b) => b[1] - a[1])
    .slice(0, Number(process.env.SELF ?? 20))
    .forEach(([k, v]) => console.log(`  ${((100 * v) / total).toFixed(1).padStart(5)}%  ${k.slice(0, 110)}`));
  // Inclusive time: a function and everything it calls.
  const parent = new Map();
  for (const n of profile.nodes) for (const c of n.children ?? []) parent.set(c, n.id);
  const incl = new Map();
  profile.samples.forEach((id, i) => {
    const seen = new Set();
    for (let at = id; at != null; at = parent.get(at)) {
      const f = byId.get(at).callFrame.functionName;
      if (!f || seen.has(f)) continue;
      seen.add(f);
      incl.set(f, (incl.get(f) ?? 0) + (dt[i] ?? 0));
    }
  });
  const want = new RegExp(process.env.INCL ?? 'paint|Painter|build|layout|Layout|draw|composite|render|Raster|frame|Frame', '');
  console.log('inclusive:');
  [...incl.entries()]
    .filter(([k]) => want.test(k))
    .sort((a, b) => b[1] - a[1])
    .slice(0, Number(process.env.TOP ?? 45))
    .forEach(([k, v]) => console.log(`  ${((100 * v) / total).toFixed(1).padStart(5)}%  ${k.slice(0, 120)}`));
  // Under FOCUS: where its time goes (by the function at the top of the stack).
  if (process.env.FOCUS) {
    const leaf = new Map();
    let inside = 0;
    profile.samples.forEach((id, i) => {
      let hit = false;
      for (let at = id; at != null; at = parent.get(at)) {
        if (byId.get(at).callFrame.functionName === process.env.FOCUS) { hit = true; break; }
      }
      if (!hit) return;
      const n = byId.get(id).callFrame;
      const name = n.functionName || `(${n.url})`;
      leaf.set(name, (leaf.get(name) ?? 0) + (dt[i] ?? 0));
      inside += dt[i] ?? 0;
    });
    console.log(`inside ${process.env.FOCUS}: ${((100 * inside) / total).toFixed(1)}%`);
    [...leaf.entries()].sort((a, b) => b[1] - a[1]).slice(0, 15)
      .forEach(([k, v]) => console.log(`  ${((100 * v) / inside).toFixed(1).padStart(5)}%  ${k.slice(0, 110)}`));
  }
  // Who calls CALLERS (named Dart frames above it).
  if (process.env.CALLERS) {
    const by = new Map();
    let inside = 0;
    profile.samples.forEach((id, i) => {
      const chain = [];
      let hit = false;
      for (let at = id; at != null; at = parent.get(at)) {
        const f = byId.get(at).callFrame.functionName;
        if (hit && f && !f.startsWith('wasm-function') && !f.includes('trampoline')) chain.push(f);
        if (f === process.env.CALLERS) hit = true;
        if (chain.length >= 3) break;
      }
      if (!hit) return;
      const k = chain.join(' < ');
      by.set(k, (by.get(k) ?? 0) + (dt[i] ?? 0));
      inside += dt[i] ?? 0;
    });
    console.log(`callers of ${process.env.CALLERS}: ${((100 * inside) / total).toFixed(1)}%`);
    [...by.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12)
      .forEach(([k, v]) => console.log(`  ${((100 * v) / total).toFixed(1).padStart(5)}%  ${k.slice(0, 150)}`));
  }
  if (errors.length) console.log('errors: ' + errors.slice(0, 3).join(' | '));
}
await browser.close();
server.close();
