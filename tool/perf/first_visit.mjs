// A first visit to the live game (nothing cached, no account), in Chrome
// at a phone's size with the CPU slowed down: when the loading page gives
// way to the game, how smoothly the splash plays, and what the main thread
// is busy with while it does. Nothing is signed into or created.
//
//   cd <dir with playwright> && node <repo>/tool/perf/first_visit.mjs \
//     [url] [cpu slowdown] [seconds]
import { chromium } from 'playwright';

const url = process.argv[2] ?? 'https://utopia.kaivon.app/game/';
const slow = Number(process.argv[3] ?? 4);
const seconds = Number(process.argv[4] ?? 16);

const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist', '--enable-unsafe-swiftshader'],
});
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 3,
  isMobile: true,
  hasTouch: true,
});
await context.addInitScript(() => {
  window.__shown = [];
  window.__long = [];
  window.__marks = {};
  const proto = window.ImageBitmapRenderingContext?.prototype;
  if (proto) {
    const put = proto.transferFromImageBitmap;
    proto.transferFromImageBitmap = function (bitmap) {
      window.__shown.push(performance.now());
      return put.call(this, bitmap);
    };
  }
  window.addEventListener('flutter-first-frame', () => {
    window.__marks.firstFrame = performance.now();
  });
  new PerformanceObserver((list) => {
    for (const e of list.getEntries()) window.__long.push([e.startTime, e.duration]);
  }).observe({ type: 'longtask', buffered: true });
  // The main thread's own frames (the page's, whoever draws them).
  window.__raf = [];
  const tick = (t) => {
    window.__raf.push(t);
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
});
const page = await context.newPage();
const cdp = await context.newCDPSession(page);
await cdp.send('Emulation.setCPUThrottlingRate', { rate: slow });
const loaded = [];
const started = Date.now();
page.on('requestfinished', async (req) => {
  const u = req.url();
  if (!/\.(wasm|mjs|js|ttf|otf|json|png|wav)$/.test(u)) return;
  const s = await req.sizes().catch(() => null);
  loaded.push(`${u.split('/').pop()} ${((s?.responseBodySize ?? 0) / 1024).toFixed(0)}KB done@${Date.now() - started}ms`);
});
page.on('console', (m) => { if (/error|warn/i.test(m.type())) loaded.push('console ' + m.type() + ': ' + m.text().slice(0, 160)); });
await page.goto(url);
await page.waitForTimeout(seconds * 1000);
const r = await page.evaluate(() => ({
  shown: window.__shown,
  long: window.__long,
  raf: window.__raf,
  marks: window.__marks,
  isolated: window.crossOriginIsolated,
  renderer: window._flutter?.buildConfig?.builds?.map((b) => b.renderer),
}));
await page.screenshot({ path: 'first_visit.png' });
console.log(`isolated ${r.isolated}, cpu x${slow}, first frame at ${(r.marks.firstFrame ?? NaN).toFixed(0)} ms`);
console.log('files:\n  ' + loaded.join('\n  '));
const gaps = (ts, from) => {
  const out = [];
  let last = from;
  for (const t of ts) {
    if (t < from) continue;
    out.push([last, t - last]);
    last = t;
  }
  return out;
};
const first = r.marks.firstFrame ?? 0;
const shownGaps = gaps(r.shown, first);
console.log(`\nframes shown after the first: ${r.shown.length}, waits over 100 ms:`);
for (const [at, g] of shownGaps.filter(([, g]) => g > 100)) {
  console.log(`  at ${at.toFixed(0)} ms waited ${g.toFixed(0)} ms`);
}
console.log('\nmain thread: page frames waiting over 100 ms (the loading page itself before the first frame):');
for (const [at, g] of gaps(r.raf, 0).filter(([, g]) => g > 100)) {
  console.log(`  at ${at.toFixed(0)} ms waited ${g.toFixed(0)} ms`);
}
console.log('\nlong tasks over 100 ms:');
for (const [at, d] of r.long.filter(([, d]) => d > 100)) {
  console.log(`  at ${at.toFixed(0)} ms, ${d.toFixed(0)} ms`);
}
await browser.close();
