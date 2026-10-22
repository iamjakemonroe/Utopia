// Films one scene of the perf harness (tool/ads/shoot.sh) as the screen paints it: JPEG frames
// with their timestamps, for tool assembly into video.
//   node record.mjs <build dir> <out dir> <query> <seconds> [WxH@dpr] [warmup s] [roll]
// "roll" calls window.__start() once filming begins (the cinema scene), and
// notes when, in start.json, so the cut lines up with the film's clock.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [root, out, query, secs, view = '405x720@2.6667', warm = '4', roll] = process.argv.slice(2);
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
const browser = await chromium.launch({ channel: 'chrome',
  args: ['--enable-gpu', '--use-angle=metal', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: vd,
  isMobile: true, hasTouch: true });
const page = await ctx.newPage();
await page.goto(`http://localhost:${server.address().port}/?${query}`);
await page.waitForSelector('flutter-view', { timeout: 60000 });
await page.waitForTimeout(Number(warm) * 1000);
fs.mkdirSync(out, { recursive: true });
const cdp = await ctx.newCDPSession(page);
const frames = [];
cdp.on('Page.screencastFrame', async (f) => {
  const n = frames.length;
  fs.writeFileSync(path.join(out, `f${String(n).padStart(5, '0')}.jpg`), Buffer.from(f.data, 'base64'));
  frames.push(f.metadata.timestamp);
  await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }).catch(() => {});
});
await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92,
  maxWidth: Math.round(vw * vd), maxHeight: Math.round(vh * vd), everyNthFrame: 1 });
if (roll === 'roll') {
  await page.waitForTimeout(500);
  const at = await page.evaluate(() => { window.__start(); return Date.now() / 1000; });
  fs.writeFileSync(path.join(out, 'start.json'), JSON.stringify(at));
}
await page.waitForTimeout(Number(secs) * 1000);
await cdp.send('Page.stopScreencast');
fs.writeFileSync(path.join(out, 'times.json'), JSON.stringify(frames));
console.log(`${frames.length} frames over ${secs}s (${(frames.length / secs).toFixed(1)} fps)`);
await browser.close();
server.close();
