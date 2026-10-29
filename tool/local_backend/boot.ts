// Runs one edge function (FN_PATH) on its own port (FN_PORT) instead of the
// one every Deno.serve() would share: tool/local_backend/serve.mjs starts
// one of these per function.
const real = Deno.serve.bind(Deno);
const port = Number(Deno.env.get("FN_PORT"));
// deno-lint-ignore no-explicit-any
(Deno as any).serve = (handler: any) =>
  real({ port, hostname: "127.0.0.1", onListen() {} }, handler);
await import(new URL(Deno.env.get("FN_PATH")!, `file://${Deno.cwd()}/`).href);
