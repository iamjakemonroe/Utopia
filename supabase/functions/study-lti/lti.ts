// LTI 1.3 (IMS Global / 1EdTech) for Chip Study: the parts with no database
// or network in them, so they can be tested on their own (lti_test.ts).
//
// The spec: https://www.imsglobal.org/spec/lti/v1p3 and its security
// framework https://www.imsglobal.org/spec/security/v1p0.
import { jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "npm:jose@5.9.6";

export const CLAIM = "https://purl.imsglobal.org/spec/lti/claim/";

/** A registered platform as the launch needs it. */
export interface Platform {
  issuer: string;
  client_id: string;
  auth_url: string;
}

/** What Chip Study takes from a verified launch. */
export interface Launch {
  sub: string;
  email: string | null;
  name: string | null;
  deploymentId: string;
  teacher: boolean;
  contextId: string | null;
  contextTitle: string | null;
}

export class LaunchError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

const trimSlash = (s: string) => s.replace(/\/+$/, "");

/** The platform's sign-in page, from the login it started (OIDC third-party
 * initiated login, LTI 1.3 section 5.1.1). */
export function authRedirect(
  platform: Platform,
  login: { login_hint: string; lti_message_hint?: string | null },
  redirectUri: string,
  state: string,
  nonce: string,
): string {
  const url = new URL(platform.auth_url);
  const q: Record<string, string> = {
    scope: "openid",
    response_type: "id_token",
    response_mode: "form_post",
    prompt: "none",
    client_id: platform.client_id,
    redirect_uri: redirectUri,
    login_hint: login.login_hint,
    state,
    nonce,
  };
  if (login.lti_message_hint) q.lti_message_hint = login.lti_message_hint;
  for (const [k, v] of Object.entries(q)) url.searchParams.set(k, v);
  return url.toString();
}

/** Teaching roles in the course: instructors (teaching assistants are an
 * instructor sub-role), content developers and course administrators.
 * Everyone else is a learner. Only course ("membership") roles count, not
 * institution or system ones: a lecturer taking a course as a student is a
 * student in it. LTI 1.1-style short names are accepted too. */
const TEACHING = new Set(["Instructor", "ContentDeveloper", "Administrator"]);
export function isTeacher(roles: unknown): boolean {
  if (!Array.isArray(roles)) return false;
  return roles.some((r) => {
    if (typeof r !== "string") return false;
    // ".../membership#Instructor" or ".../membership/Instructor#TeachingAssistant"
    const m = r.match(/\/lis\/v2\/membership(?:\/(\w+))?#(\w+)$/);
    if (m) return TEACHING.has(m[1] ?? m[2]);
    return !/[/#]/.test(r) && TEACHING.has(r);
  });
}

/** Checks the platform's signed launch (LTI 1.3 section 5.1.3 and the
 * security framework section 5.1.3): signature by the platform's key, issuer,
 * audience (and azp when there are several), times, nonce, version, message
 * type and deployment. */
export async function verifyLaunch(
  idToken: string,
  platform: Platform,
  nonce: string,
  keys: JWTVerifyGetKey,
  now: Date = new Date(),
): Promise<Launch> {
  let p: JWTPayload;
  try {
    ({ payload: p } = await jwtVerify(idToken, keys, {
      algorithms: ["RS256", "RS384", "RS512", "ES256", "ES384"],
      audience: platform.client_id,
      clockTolerance: 60,
      // Issued in the last ten minutes, and not in the future.
      maxTokenAge: "10m",
      currentDate: now,
      requiredClaims: ["iss", "sub", "aud", "exp", "iat", "nonce"],
    }));
  } catch (e) {
    throw new LaunchError("bad_token", `id_token rejected: ${(e as Error).message}`);
  }
  if (trimSlash(String(p.iss)) !== trimSlash(platform.issuer)) {
    throw new LaunchError("bad_token", "issuer does not match the platform");
  }
  const aud = Array.isArray(p.aud) ? p.aud : [p.aud];
  if (aud.length > 1 && p.azp !== platform.client_id) {
    throw new LaunchError("bad_token", "azp missing or not this tool");
  }
  if (p.azp !== undefined && p.azp !== platform.client_id) {
    throw new LaunchError("bad_token", "azp is not this tool");
  }
  if (p.nonce !== nonce) throw new LaunchError("bad_token", "nonce does not match");
  if (p[`${CLAIM}version`] !== "1.3.0") throw new LaunchError("bad_token", "not an LTI 1.3 launch");
  const type = p[`${CLAIM}message_type`];
  if (type !== "LtiResourceLinkRequest") {
    throw new LaunchError("unsupported", `message type ${String(type)} is not supported`);
  }
  const deploymentId = p[`${CLAIM}deployment_id`];
  if (typeof deploymentId !== "string" || !deploymentId) {
    throw new LaunchError("bad_token", "no deployment_id");
  }
  if (typeof p.sub !== "string" || !p.sub || p.sub.length > 255) {
    throw new LaunchError("anonymous", "the platform did not say who is launching");
  }
  const ctx = p[`${CLAIM}context`] as { id?: unknown; title?: unknown; label?: unknown } | undefined;
  const email = typeof p.email === "string" && /^[^@\s]+@[^@\s]+$/.test(p.email.trim())
    ? p.email.trim().toLowerCase()
    : null;
  const name = typeof p.name === "string" ? p.name.trim().slice(0, 120) || null : null;
  const title = typeof ctx?.title === "string" && ctx.title.trim()
    ? ctx.title.trim()
    : typeof ctx?.label === "string" && ctx.label.trim()
    ? ctx.label.trim()
    : null;
  return {
    sub: p.sub,
    email,
    name,
    deploymentId,
    teacher: isTeacher(p[`${CLAIM}roles`]),
    contextId: typeof ctx?.id === "string" && ctx.id ? ctx.id.slice(0, 255) : null,
    contextTitle: title ? title.slice(0, 120) : null,
  };
}

/** The tool's public keys, from its private JWK (the LTI_PRIVATE_JWK secret).
 * Platforms ask for this address when the tool is set up; Chip Study only
 * signs anything with it once it calls platform services. */
export function publicJwks(privateJwk: string | undefined): { keys: Record<string, unknown>[] } {
  if (!privateJwk) return { keys: [] };
  const k = JSON.parse(privateJwk) as Record<string, unknown>;
  const pub: Record<string, unknown> = { kty: k.kty, kid: k.kid, use: "sig", alg: k.alg ?? "RS256" };
  for (const f of ["n", "e", "crv", "x", "y"]) if (k[f] !== undefined) pub[f] = k[f];
  return { keys: [pub] };
}

/** Canvas's developer key, filled in from one address ("Enter URL"). */
export function canvasConfig(base: string, site: string) {
  const launch = `${base}/launch`;
  return {
    title: "Chip Study",
    description: "A study partner that teaches instead of doing the work. Students revise, practise and plan; " +
      "the course's teachers see activity and each assignment's AI-use record, never chats.",
    oidc_initiation_url: `${base}/login`,
    target_link_uri: launch,
    public_jwk_url: `${base}/jwks`,
    scopes: [],
    extensions: [{
      domain: new URL(site).host,
      tool_id: "chip-study",
      platform: "canvas.instructure.com",
      privacy_level: "public",
      settings: {
        text: "Chip Study",
        icon_url: `${site}/icon-192.png`,
        placements: [{
          placement: "course_navigation",
          message_type: "LtiResourceLinkRequest",
          target_link_uri: launch,
          text: "Chip Study",
          windowTarget: "_blank",
          default: "enabled",
        }],
      },
    }],
    custom_fields: {},
  };
}
