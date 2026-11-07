// Chip Study inside a university's learning platform (Moodle, Canvas,
// Blackboard, Brightspace) through LTI 1.3. The institution's admin registers
// the platform in Chip Study (study_lti_platform_set); a lecturer adds Chip
// Study to a course; clicking it lands here.
//
//   GET|POST /study-lti/login   the platform starts a launch (OIDC login):
//     remembers a state and nonce, and sends the browser to the platform's
//     sign-in page.
//   POST /study-lti/launch      the platform posts its signed id_token: it is
//     checked (lti.ts), the person is put in the institution and in a class
//     for the course (study_lti_enrol), and sent to Chip Study signed in.
//   GET /study-lti/jwks         the tool's public keys (from LTI_PRIVATE_JWK).
//   GET /study-lti/canvas.json  Canvas's developer key, from one address.
//
// Who is signed in (see 20261107200000_study_lti.sql): a platform user
// already linked to a Chip Study account is that account; otherwise an email
// on the institution's confirmed domain is taken at the platform's word (the
// account is made if new). Anyone else is sent to Chip Study to sign in
// themselves once, which links the two.
//
// Every outcome goes to Chip Study's /lti page, in the address's fragment (so
// no server logs it):
//   #token_hash=…&type=…&inst=…&class=…&role=…   sign in with
//     supabase.auth.verifyOtp({ token_hash, type: "email" }), then open the
//     class. "&confirm=<email>" is added when the browser couldn't keep the
//     launch's cookie (some browsers block it inside a platform's frame): the
//     page then asks "Continue as <email>?" before signing in, so a launch
//     can't be pushed into someone else's browser.
//   #link=<token>   sign in (any way), then study_lti_link(token).
//     study_lti_pending_peek(token) says what it's for.
//   #error=<code>   unknown_platform, bad_login, expired, bad_token,
//     unknown_deployment, unsupported, anonymous, no_seats, inactive,
//     linked_elsewhere, failed.
//
// Supabase serves HTML from functions as plain text, so every page is Chip
// Study's; this only redirects.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createRemoteJWKSet, type JWTVerifyGetKey } from "npm:jose@5.9.6";
import { authRedirect, canvasConfig, LaunchError, publicJwks, verifyLaunch } from "./lti.ts";

const SITE = (Deno.env.get("STUDY_SITE_URL") ?? "https://study.kaivon.app").replace(/\/+$/, "");
const BASE = (Deno.env.get("STUDY_LTI_URL") ?? `${Deno.env.get("SUPABASE_URL")}/functions/v1/study-lti`)
  .replace(/\/+$/, "");
const COOKIE_PATH = new URL(BASE).pathname;
const STATE_MINUTES = 10;

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const keySets = new Map<string, JWTVerifyGetKey>();
function platformKeys(url: string): JWTVerifyGetKey {
  let k = keySets.get(url);
  if (!k) {
    k = createRemoteJWKSet(new URL(url), { timeoutDuration: 5000, cooldownDuration: 30_000 });
    keySets.set(url, k);
  }
  return k;
}

function token(bytes = 32): string {
  const b = crypto.getRandomValues(new Uint8Array(bytes));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function redirect(to: string, headers: Record<string, string> = {}): Response {
  return new Response(null, {
    status: 302,
    headers: { Location: to, "Cache-Control": "no-store", "Referrer-Policy": "no-referrer", ...headers },
  });
}

const page = (fragment: Record<string, string>) => `${SITE}/lti#${new URLSearchParams(fragment)}`;
const fail = (code: string, why?: unknown) => {
  if (why) console.error(`study-lti ${code}:`, why instanceof Error ? why.message : why);
  return redirect(page({ error: code }));
};

/** The query and (for a POST) the form, as one set of parameters. */
async function params(req: Request): Promise<URLSearchParams> {
  const p = new URL(req.url).searchParams;
  if (req.method === "POST") {
    const type = req.headers.get("content-type") ?? "";
    if (type.includes("application/x-www-form-urlencoded") || type.includes("multipart/form-data")) {
      for (const [k, v] of await req.formData()) if (typeof v === "string") p.set(k, v);
    }
  }
  return p;
}

async function login(req: Request): Promise<Response> {
  const p = await params(req);
  const iss = p.get("iss")?.replace(/\/+$/, "");
  const loginHint = p.get("login_hint");
  if (!iss || !loginHint || !p.get("target_link_uri")) return fail("bad_login");
  let q = admin.from("study_lti_platforms").select("id, issuer, client_id, auth_url").eq("issuer", iss);
  const clientId = p.get("client_id");
  const deployment = p.get("lti_deployment_id");
  if (clientId) q = q.eq("client_id", clientId);
  if (deployment) q = q.eq("deployment_id", deployment);
  const { data, error } = await q.limit(20);
  if (error) return fail("failed", error);
  // Several deployments of one registration share its client ID and sign-in
  // page; the launch picks the deployment from the signed token.
  const clients = new Set((data ?? []).map((r) => `${r.client_id}\n${r.auth_url}`));
  if (!data?.length) return fail("unknown_platform", `no platform for ${iss} ${clientId ?? ""}`);
  if (clients.size > 1) return fail("unknown_platform", `several registrations for ${iss}: needs client_id`);
  const platform = data[0];

  const state = token();
  const nonce = token();
  await admin.from("study_lti_states").delete().lt(
    "created_at",
    new Date(Date.now() - STATE_MINUTES * 60_000).toISOString(),
  );
  const { error: e2 } = await admin.from("study_lti_states").insert({ state, nonce, platform_id: platform.id });
  if (e2) return fail("failed", e2);
  return redirect(
    authRedirect(platform, { login_hint: loginHint, lti_message_hint: p.get("lti_message_hint") }, `${BASE}/launch`, state, nonce),
    {
      "Set-Cookie": `lti-${state}=1; Path=${COOKIE_PATH}; Max-Age=${STATE_MINUTES * 60}; Secure; HttpOnly; SameSite=None`,
    },
  );
}

/** A database error's message, for the few the launch explains. */
function dbFail(e: { message?: string } | null, fallback = "failed"): Response {
  const m = e?.message ?? "";
  if (m.includes("no seats left")) return fail("no_seats");
  if (m.includes("institution not active")) return fail("inactive");
  if (m.includes("linked to another account")) return fail("linked_elsewhere");
  return fail(fallback, e);
}

async function launch(req: Request): Promise<Response> {
  if (req.method !== "POST") return fail("bad_login");
  const p = await params(req);
  if (p.get("error")) return fail("bad_login", `platform said ${p.get("error")}: ${p.get("error_description") ?? ""}`);
  const state = p.get("state");
  const idToken = p.get("id_token");
  if (!state || !idToken) return fail("bad_login");

  // A state works once, for a few minutes.
  const { data: st } = await admin.from("study_lti_states").delete().eq("state", state)
    .select("nonce, platform_id, created_at").maybeSingle();
  if (!st || Date.now() - Date.parse(st.created_at) > STATE_MINUTES * 60_000) return fail("expired");
  const sameBrowser = (req.headers.get("cookie") ?? "").split(/;\s*/).includes(`lti-${state}=1`);

  const { data: first } = await admin.from("study_lti_platforms")
    .select("id, issuer, client_id, auth_url, jwks_url").eq("id", st.platform_id).maybeSingle();
  if (!first) return fail("unknown_platform");

  let l;
  try {
    l = await verifyLaunch(idToken, first, st.nonce, platformKeys(first.jwks_url));
  } catch (e) {
    return fail(e instanceof LaunchError ? e.code : "bad_token", e);
  }
  const { data: plat } = await admin.from("study_lti_platforms").select("id")
    .eq("issuer", first.issuer).eq("client_id", first.client_id).eq("deployment_id", l.deploymentId).maybeSingle();
  if (!plat) return fail("unknown_deployment", `deployment ${l.deploymentId} of ${first.issuer} is not registered`);

  // Who this is.
  let userId: string | null = null;
  let email: string | null = null;
  const { data: linked } = await admin.from("study_lti_users").select("user_id")
    .eq("platform_id", plat.id).eq("sub", l.sub).maybeSingle();
  if (linked) {
    const { data: u, error } = await admin.auth.admin.getUserById(linked.user_id);
    if (error || !u.user?.email) return fail("failed", error ?? "linked account has no email");
    userId = u.user.id;
    email = u.user.email;
  } else if (l.email) {
    const { data: trusted, error } = await admin.rpc("study_lti_trusts_email", { p_platform: plat.id, p_email: l.email });
    if (error) return fail("failed", error);
    if (trusted) email = l.email;
  }
  if (!email) {
    const { data: link, error } = await admin.rpc("study_lti_pending_add", {
      p_platform: plat.id,
      p_sub: l.sub,
      p_email: l.email,
      p_teacher: l.teacher,
      p_context_id: l.contextId,
      p_context_title: l.contextTitle,
    });
    if (error) return fail("failed", error);
    return redirect(page({ link }));
  }

  // A one-time sign-in for them (made into an account if new; nothing is emailed).
  const { data: gen, error: genErr } = await admin.auth.admin.generateLink({ type: "magiclink", email });
  if (genErr || !gen.properties?.hashed_token) return fail("failed", genErr ?? "no sign-in made");
  userId ??= gen.user.id;
  if (!linked) {
    const { error } = await admin.rpc("study_lti_bind", { p_platform: plat.id, p_sub: l.sub, p_user: userId });
    if (error) return dbFail(error);
  }
  const { data: enrol, error: enrolErr } = await admin.rpc("study_lti_enrol", {
    p_platform: plat.id,
    p_user: userId,
    p_teacher: l.teacher,
    p_context_id: l.contextId,
    p_context_title: l.contextTitle,
  });
  if (enrolErr) return dbFail(enrolErr);

  const f: Record<string, string> = {
    token_hash: gen.properties.hashed_token,
    type: gen.properties.verification_type ?? "magiclink",
    inst: enrol.institution_id,
    role: enrol.role,
  };
  if (enrol.class_id) f.class = enrol.class_id;
  if (!sameBrowser) f.confirm = email;
  return redirect(page(f), { "Set-Cookie": `lti-${state}=; Path=${COOKIE_PATH}; Max-Age=0; Secure; HttpOnly; SameSite=None` });
}

Deno.serve(async (req: Request) => {
  const route = new URL(req.url).pathname.replace(/\/+$/, "").split("/").pop();
  try {
    switch (route) {
      case "login":
        return await login(req);
      case "launch":
        return await launch(req);
      case "jwks":
        return Response.json(publicJwks(Deno.env.get("LTI_PRIVATE_JWK")), {
          headers: { "Access-Control-Allow-Origin": "*", "Cache-Control": "public, max-age=3600" },
        });
      case "canvas.json":
        return Response.json(canvasConfig(BASE, SITE), { headers: { "Access-Control-Allow-Origin": "*" } });
      default:
        return Response.json({ error: "not found" }, { status: 404 });
    }
  } catch (e) {
    return fail("failed", e);
  }
});
