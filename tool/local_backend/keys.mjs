// Saves Utopia's anon and service_role keys for the local backend, in the
// main checkout's env/local_backend.env (git-ignored), keeping anything else
// already there (an ANTHROPIC_API_KEY, the return URLs). Nothing is printed.
// Run it yourself, once: node tool/local_backend/keys.mjs
import { execFileSync, execSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const REF = 'atrgasakfnmixhictynh';
const main = execSync('git rev-parse --path-format=absolute --git-common-dir').toString().trim().replace(/\.git$/, '');
const file = `${main}env/local_backend.env`;
const keys = Object.fromEntries(
  JSON.parse(execFileSync('supabase', ['projects', 'api-keys', '--project-ref', REF, '-o', 'json']).toString()).map((k) => [k.name, k.api_key]),
);
if (!keys.anon || !keys.service_role) throw new Error('Supabase didn’t return the keys. Are you logged in (supabase login)?');

const lines = existsSync(file) ? readFileSync(file, 'utf8').split('\n') : readFileSync(new URL('../../env/local_backend.env.example', import.meta.url), 'utf8').split('\n');
const set = (name, value) => {
  const i = lines.findIndex((l) => l.startsWith(`${name}=`));
  if (i >= 0) lines[i] = `${name}=${value}`;
  else lines.push(`${name}=${value}`);
};
set('SUPABASE_ANON_KEY', keys.anon);
set('SUPABASE_SERVICE_ROLE_KEY', keys.service_role);
writeFileSync(file, lines.join('\n'), { mode: 0o600 });
console.log(`Saved Utopia's keys in ${file}.`);
