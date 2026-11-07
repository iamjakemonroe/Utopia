// deno test supabase/functions/study-lti/lti_test.ts
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { createLocalJWKSet, exportJWK, generateKeyPair, type JWTPayload, type KeyLike, SignJWT } from "npm:jose@5.9.6";
import { authRedirect, canvasConfig, CLAIM, isTeacher, LaunchError, publicJwks, verifyLaunch } from "./lti.ts";

const platform = {
  issuer: "https://moodle.uni.edu",
  client_id: "client-1",
  auth_url: "https://moodle.uni.edu/mod/lti/auth.php",
};
const { privateKey, publicKey } = await generateKeyPair("RS256", { extractable: true });
const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256" };
const keys = createLocalJWKSet({ keys: [jwk] });
const other = await generateKeyPair("RS256");

const LEARNER = "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner";
const INSTRUCTOR = "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor";

function claims(over: Record<string, unknown> = {}): JWTPayload {
  return {
    iss: platform.issuer,
    aud: platform.client_id,
    sub: "user-42",
    nonce: "n-1",
    email: "Lea@Uni.edu",
    name: "Lea Okafor",
    [`${CLAIM}version`]: "1.3.0",
    [`${CLAIM}message_type`]: "LtiResourceLinkRequest",
    [`${CLAIM}deployment_id`]: "dep-1",
    [`${CLAIM}roles`]: [LEARNER],
    [`${CLAIM}context`]: { id: "course-77", title: "History of Science", label: "HIST 210" },
    ...over,
  };
}

async function sign(c: JWTPayload, opts: { key?: KeyLike; kid?: string; exp?: string | number; iat?: number } = {}) {
  let j = new SignJWT(Object.fromEntries(Object.entries(c).filter(([, v]) => v !== undefined)))
    .setProtectedHeader({ alg: "RS256", kid: opts.kid ?? "k1" })
    .setExpirationTime(opts.exp ?? "5m");
  j = opts.iat !== undefined ? j.setIssuedAt(opts.iat) : j.setIssuedAt();
  return await j.sign(opts.key ?? privateKey);
}

async function rejected(token: string, code: string, nonce = "n-1") {
  const e = await assertRejects(() => verifyLaunch(token, platform, nonce, keys), LaunchError);
  assertEquals((e as LaunchError).code, code, (e as Error).message);
}

Deno.test("a good launch gives who, the course and the role", async () => {
  const l = await verifyLaunch(await sign(claims()), platform, "n-1", keys);
  assertEquals(l, {
    sub: "user-42",
    email: "lea@uni.edu",
    name: "Lea Okafor",
    deploymentId: "dep-1",
    teacher: false,
    contextId: "course-77",
    contextTitle: "History of Science",
  });
});

Deno.test("an instructor is a teacher", async () => {
  const l = await verifyLaunch(await sign(claims({ [`${CLAIM}roles`]: [INSTRUCTOR] })), platform, "n-1", keys);
  assert(l.teacher);
});

Deno.test("a trailing slash on the issuer doesn't matter", async () => {
  await verifyLaunch(await sign(claims({ iss: "https://moodle.uni.edu/" })), platform, "n-1", keys);
});

Deno.test("signed by another key: refused", async () => {
  await rejected(await sign(claims(), { key: other.privateKey }), "bad_token");
});

Deno.test("an unsigned token: refused", async () => {
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const now = Math.floor(Date.now() / 1000);
  await rejected(`${b64({ alg: "none" })}.${b64({ ...claims(), iat: now, exp: now + 300 })}.`, "bad_token");
});

Deno.test("another tool's token: refused", async () => {
  await rejected(await sign(claims({ aud: "client-2" })), "bad_token");
});

Deno.test("several audiences need azp to be this tool", async () => {
  await rejected(await sign(claims({ aud: ["client-1", "client-2"] })), "bad_token");
  await rejected(await sign(claims({ aud: ["client-1", "client-2"], azp: "client-2" })), "bad_token");
  await verifyLaunch(await sign(claims({ aud: ["client-1", "client-2"], azp: "client-1" })), platform, "n-1", keys);
});

Deno.test("another platform's issuer: refused", async () => {
  await rejected(await sign(claims({ iss: "https://evil.example" })), "bad_token");
});

Deno.test("expired, or issued in the future: refused", async () => {
  const now = Math.floor(Date.now() / 1000);
  await rejected(await sign(claims(), { iat: now - 1000, exp: now - 300 }), "bad_token");
  await rejected(await sign(claims(), { iat: now + 600, exp: now + 900 }), "bad_token");
  await rejected(await sign(claims(), { iat: now - 3600, exp: now + 300 }), "bad_token");
});

Deno.test("a nonce from another launch: refused", async () => {
  await rejected(await sign(claims()), "bad_token", "n-2");
  await rejected(await sign(claims({ nonce: undefined })), "bad_token");
});

Deno.test("not LTI 1.3, or not a link launch", async () => {
  await rejected(await sign(claims({ [`${CLAIM}version`]: "1.1" })), "bad_token");
  await rejected(await sign(claims({ [`${CLAIM}message_type`]: "LtiDeepLinkingRequest" })), "unsupported");
});

Deno.test("no deployment: refused", async () => {
  await rejected(await sign(claims({ [`${CLAIM}deployment_id`]: undefined })), "bad_token");
});

Deno.test("no email or course is fine; a missing title falls back to the label", async () => {
  const l = await verifyLaunch(
    await sign(claims({ email: undefined, [`${CLAIM}context`]: { id: "c9", label: "BIO 101" } })),
    platform,
    "n-1",
    keys,
  );
  assertEquals([l.email, l.contextId, l.contextTitle], [null, "c9", "BIO 101"]);
  const n = await verifyLaunch(await sign(claims({ email: "not-an-email", [`${CLAIM}context`]: undefined })), platform, "n-1", keys);
  assertEquals([n.email, n.contextId, n.contextTitle], [null, null, null]);
});

Deno.test("teaching roles", () => {
  const m = "http://purl.imsglobal.org/vocab/lis/v2/membership";
  assert(isTeacher([`${m}#Instructor`]));
  assert(isTeacher([`${m}/Instructor#TeachingAssistant`]));
  assert(isTeacher([`${m}#ContentDeveloper`, `${m}#Learner`]));
  assert(isTeacher(["Instructor"]));
  assert(!isTeacher([`${m}#Learner`]));
  assert(!isTeacher([`${m}/Learner#Learner`]));
  assert(!isTeacher([`${m}#Mentor`]));
  // Institution and system roles don't make someone a teacher in a course.
  assert(!isTeacher(["http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor", `${m}#Learner`]));
  assert(!isTeacher(["http://purl.imsglobal.org/vocab/lis/v2/system/person#Administrator"]));
  assert(!isTeacher(undefined));
  assert(!isTeacher([42, null]));
});

Deno.test("the sign-in redirect carries what the spec asks for", () => {
  const u = new URL(authRedirect(platform, { login_hint: "h", lti_message_hint: "m" }, "https://x/launch", "s", "n"));
  assertEquals(u.origin + u.pathname, platform.auth_url);
  assertEquals(Object.fromEntries(u.searchParams), {
    scope: "openid",
    response_type: "id_token",
    response_mode: "form_post",
    prompt: "none",
    client_id: "client-1",
    redirect_uri: "https://x/launch",
    login_hint: "h",
    state: "s",
    nonce: "n",
    lti_message_hint: "m",
  });
  assert(!new URL(authRedirect(platform, { login_hint: "h" }, "https://x/launch", "s", "n")).searchParams.has("lti_message_hint"));
});

Deno.test("public keys never include the private parts", async () => {
  const priv = { ...(await exportJWK(privateKey)), kid: "k1", alg: "RS256" };
  const pub = publicJwks(JSON.stringify(priv)).keys[0];
  for (const f of ["d", "p", "q", "dp", "dq", "qi"]) assert(!(f in pub), f);
  assertEquals([pub.kid, pub.n, pub.e, pub.use], ["k1", priv.n, priv.e, "sig"]);
  assertEquals(publicJwks(undefined), { keys: [] });
});

Deno.test("Canvas's configuration points at this function", () => {
  const c = canvasConfig("https://ref.supabase.co/functions/v1/study-lti", "https://study.kaivon.app");
  assertEquals(c.oidc_initiation_url, "https://ref.supabase.co/functions/v1/study-lti/login");
  assertEquals(c.target_link_uri, "https://ref.supabase.co/functions/v1/study-lti/launch");
  assertEquals(c.extensions[0].privacy_level, "public");
});
