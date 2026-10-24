// A local backend for trying payments (Flutterwave test mode) and Chip Rizz
// without deploying anything:
//
//   * web-pay, web-pay-hook and chip-rizz run here, under Deno, with the
//     keys in env/local_backend.env and env/flutterwave.test.env;
//   * everything else (the database, sign-in, storage, realtime) is the live
//     project, reached through this proxy at http://localhost:54321.
//
// Point an app at http://localhost:54321 instead of the project's URL (the
// game: --dart-define=SUPABASE_URL=http://localhost:54321; Chip Rizz:
// VITE_SUPABASE_URL in .env.development.local) and pay with Flutterwave's
// test cards. Flutterwave's webhook can't reach this Mac, so a payment is
// credited when the app comes back from checkout (the "confirm" step).
//
// Run from the repo: node tool/local_backend/serve.mjs
import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import tls from 'node:tls';

const root = new URL('../../', import.meta.url).pathname;
const PORT = 54321;
const FUNCTIONS = { 'web-pay': 54401, 'web-pay-hook': 54402, 'chip-rizz': 54403 };

function readEnv(file) {
  const path = `${root}${file}`;
  if (!existsSync(path)) return {};
  return Object.fromEntries(
    readFileSync(path, 'utf8')
      .split('\n')
      .map((l) => l.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*?)\s*$/))
      .filter(Boolean)
      .map((m) => [m[1], m[2].replace(/^['"]|['"]$/g, '')]),
  );
}

const project = JSON.parse(readFileSync(`${root}env/local.json`, 'utf8')).SUPABASE_URL;
const remote = new URL(project);
const keys = readEnv('env/local_backend.env');
const pay = readEnv('env/flutterwave.test.env');
const missing = ['SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY'].filter((k) => !keys[k]);
if (missing.length) {
  console.error(`Fill in ${missing.join(' and ')} in env/local_backend.env (see env/local_backend.env.example).`);
  process.exit(1);
}
if (!pay.FLW_SECRET_KEY?.includes('_TEST')) {
  console.error('env/flutterwave.test.env needs a TEST secret key (FLWSECK_TEST-...). Live keys are never used here.');
  process.exit(1);
}

const env = {
  ...process.env,
  SUPABASE_URL: project,
  SUPABASE_ANON_KEY: keys.SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY: keys.SUPABASE_SERVICE_ROLE_KEY,
  ANTHROPIC_API_KEY: keys.ANTHROPIC_API_KEY ?? '',
  FLW_SECRET_KEY: pay.FLW_SECRET_KEY,
  FLW_WEBHOOK_HASH: pay.FLW_WEBHOOK_HASH ?? '',
  UTOPIA_RETURN_URL: keys.UTOPIA_RETURN_URL || 'http://localhost:8080/',
  CHIP_RETURN_URL: keys.CHIP_RETURN_URL || 'http://localhost:5180/',
};

const children = Object.entries(FUNCTIONS).map(([name, port]) =>
  spawn('deno', ['run', '--allow-net', '--allow-env', '--allow-read', 'tool/local_backend/boot.ts'], {
    cwd: root,
    env: { ...env, FN_PORT: String(port), FN_PATH: `supabase/functions/${name}/index.ts` },
    stdio: ['ignore', 'inherit', 'inherit'],
  }),
);
const stop = () => {
  children.forEach((c) => c.kill());
  process.exit(0);
};
process.on('SIGINT', stop);
process.on('SIGTERM', stop);

/** Which local function a path is for, if any. */
function local(path) {
  const m = path.match(/^\/functions\/v1\/([a-z-]+)/);
  return m && FUNCTIONS[m[1]] ? FUNCTIONS[m[1]] : null;
}

const server = http.createServer((req, res) => {
  const port = local(req.url);
  const target = port
    ? { protocol: 'http:', hostname: '127.0.0.1', port, path: '/' }
    : { protocol: 'https:', hostname: remote.hostname, port: 443, path: req.url };
  const headers = { ...req.headers, host: port ? `127.0.0.1:${port}` : remote.hostname };
  const out = (port ? http : https).request({ ...target, method: req.method, headers }, (up) => {
    res.writeHead(up.statusCode ?? 502, up.headers);
    up.pipe(res);
  });
  out.on('error', (e) => {
    res.writeHead(502, { 'content-type': 'application/json', 'access-control-allow-origin': '*' });
    res.end(JSON.stringify({ error: `local backend: ${e.message}` }));
  });
  req.pipe(out);
});

// Realtime (websockets) goes straight through to the live project.
server.on('upgrade', (req, socket, head) => {
  const up = tls.connect(443, remote.hostname, { servername: remote.hostname }, () => {
    const lines = [`${req.method} ${req.url} HTTP/1.1`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      const name = req.rawHeaders[i];
      lines.push(`${name}: ${name.toLowerCase() === 'host' ? remote.hostname : req.rawHeaders[i + 1]}`);
    }
    up.write(`${lines.join('\r\n')}\r\n\r\n`);
    if (head?.length) up.write(head);
    up.pipe(socket);
    socket.pipe(up);
  });
  up.on('error', () => socket.destroy());
  socket.on('error', () => up.destroy());
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Local backend on http://localhost:${PORT} (functions here: ${Object.keys(FUNCTIONS).join(', ')}; everything else: ${remote.hostname})`);
  console.log(`Flutterwave: TEST mode. Checkout returns to ${env.UTOPIA_RETURN_URL} (game) and ${env.CHIP_RETURN_URL} (Chip Rizz).`);
  if (!env.ANTHROPIC_API_KEY) console.log('No ANTHROPIC_API_KEY: Chip Rizz will say its brain is switched off; payments still work.');
});
