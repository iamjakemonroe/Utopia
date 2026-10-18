// Talking to the App Store and the Play Store about coin purchases.
//
// Apple: the App Store Server API, signed in with an In-App Purchase key
// (App Store Connect > Users and Access > Integrations > In-App Purchase).
//   APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID, APPLE_IAP_PRIVATE_KEY (the .p8
//   file's text), APPLE_BUNDLE_ID (defaults to the app's).
// Google: the Play Developer API, signed in as a service account that has
// "View financial data" and "Manage orders" in the Play Console.
//   GOOGLE_PLAY_SERVICE_ACCOUNT (the JSON key file's text),
//   GOOGLE_PLAY_PACKAGE (defaults to the app's).
//
// What the stores answer over these APIs is the truth: nothing the app (or
// a notification) says is trusted on its own.

const APP_ID = "com.iamjakemonroe.utopia";

export class StoreNotConfigured extends Error {}

// ── encoding ───────────────────────────────────────────────────────────

function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlText(text: string): string {
  return base64url(new TextEncoder().encode(text));
}

function fromBase64url(text: string): string {
  const b64 = text.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

/** The payload of a JWS / JWT, without checking its signature. */
export function jwsPayload<T>(jws: string): T {
  const part = jws.split(".")[1];
  if (!part) throw new Error("not a JWS");
  return JSON.parse(fromBase64url(part)) as T;
}

function pemBody(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/-----(BEGIN|END)[^-]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function signJwt(
  header: Record<string, unknown>,
  claims: Record<string, unknown>,
  key: CryptoKey,
  algorithm: AlgorithmIdentifier | EcdsaParams,
): Promise<string> {
  const input = `${base64urlText(JSON.stringify(header))}.${
    base64urlText(JSON.stringify(claims))
  }`;
  const signature = await crypto.subtle.sign(
    algorithm,
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64url(new Uint8Array(signature))}`;
}

// ── Apple ──────────────────────────────────────────────────────────────

/** A decoded JWSTransactionDecodedPayload (the fields we use). */
export interface AppleTransaction {
  transactionId: string;
  originalTransactionId?: string;
  bundleId: string;
  productId: string;
  purchaseDate?: number;
  quantity?: number;
  type?: string;
  appAccountToken?: string;
  environment?: string;
  revocationDate?: number;
  /** Subscriptions: when this period ends. */
  expiresDate?: number;
}

const APPLE_HOSTS = {
  production: "https://api.storekit.itunes.apple.com",
  sandbox: "https://api.storekit-sandbox.itunes.apple.com",
};

export const appleBundleId = () => Deno.env.get("APPLE_BUNDLE_ID") ?? APP_ID;

let appleToken: { jwt: string; until: number } | null = null;

async function appleJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (appleToken && appleToken.until > now + 60) return appleToken.jwt;
  const keyId = Deno.env.get("APPLE_IAP_KEY_ID");
  const issuer = Deno.env.get("APPLE_IAP_ISSUER_ID");
  const pem = Deno.env.get("APPLE_IAP_PRIVATE_KEY");
  if (!keyId || !issuer || !pem) {
    throw new StoreNotConfigured("App Store keys are not set");
  }
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBody(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const until = now + 20 * 60;
  const jwt = await signJwt(
    { alg: "ES256", kid: keyId, typ: "JWT" },
    {
      iss: issuer,
      iat: now,
      exp: until,
      aud: "appstoreconnect-v1",
      bid: appleBundleId(),
    },
    key,
    { name: "ECDSA", hash: "SHA-256" },
  );
  appleToken = { jwt, until };
  return jwt;
}

/**
 * Looks up a transaction with Apple. Tries the live App Store first and
 * then the sandbox (TestFlight, App Review and sandbox testers buy there),
 * unless [environment] says which. Null when Apple has no such purchase.
 */
export async function appleTransaction(
  transactionId: string,
  environment?: "production" | "sandbox",
): Promise<
  { transaction: AppleTransaction; environment: "production" | "sandbox" } | null
> {
  if (!/^\d{1,32}$/.test(transactionId)) return null;
  const order: ("production" | "sandbox")[] = environment
    ? [environment]
    : ["production", "sandbox"];
  for (const env of order) {
    const res = await fetch(
      `${APPLE_HOSTS[env]}/inApps/v1/transactions/${transactionId}`,
      { headers: { Authorization: `Bearer ${await appleJwt()}` } },
    );
    if (res.status === 404) {
      await res.body?.cancel();
      continue;
    }
    if (!res.ok) {
      throw new Error(`App Store answered ${res.status}: ${await res.text()}`);
    }
    const body = await res.json() as { signedTransactionInfo: string };
    return {
      transaction: jwsPayload<AppleTransaction>(body.signedTransactionInfo),
      environment: env,
    };
  }
  return null;
}

/**
 * The latest state of the subscription [transactionId] belongs to (any of
 * its transactions will do): its newest transaction, whether it will renew,
 * and where it was bought. Null when Apple has no such subscription.
 */
export async function appleSubscription(
  transactionId: string,
  environment?: "production" | "sandbox",
): Promise<
  {
    transaction: AppleTransaction;
    autoRenew: boolean;
    environment: "production" | "sandbox";
  } | null
> {
  if (!/^\d{1,32}$/.test(transactionId)) return null;
  const order: ("production" | "sandbox")[] = environment
    ? [environment]
    : ["production", "sandbox"];
  for (const env of order) {
    const res = await fetch(
      `${APPLE_HOSTS[env]}/inApps/v1/subscriptions/${transactionId}`,
      { headers: { Authorization: `Bearer ${await appleJwt()}` } },
    );
    if (res.status === 404) {
      await res.body?.cancel();
      continue;
    }
    if (!res.ok) {
      throw new Error(`App Store answered ${res.status}: ${await res.text()}`);
    }
    const body = await res.json() as {
      data?: {
        lastTransactions?: {
          signedTransactionInfo?: string;
          signedRenewalInfo?: string;
        }[];
      }[];
    };
    let best: { transaction: AppleTransaction; autoRenew: boolean } | null = null;
    for (const group of body.data ?? []) {
      for (const last of group.lastTransactions ?? []) {
        if (!last.signedTransactionInfo) continue;
        const t = jwsPayload<AppleTransaction>(last.signedTransactionInfo);
        const renewal = last.signedRenewalInfo
          ? jwsPayload<{ autoRenewStatus?: number }>(last.signedRenewalInfo)
          : {};
        if (!best || (t.expiresDate ?? 0) > (best.transaction.expiresDate ?? 0)) {
          best = { transaction: t, autoRenew: renewal.autoRenewStatus === 1 };
        }
      }
    }
    if (best) return { ...best, environment: env };
  }
  return null;
}

// ── Google ─────────────────────────────────────────────────────────────

/** A ProductPurchase from the Play Developer API (the fields we use). */
export interface GooglePurchase {
  purchaseTimeMillis?: string;
  /** 0 purchased, 1 canceled, 2 pending. */
  purchaseState?: number;
  /** 0 not yet consumed, 1 consumed. */
  consumptionState?: number;
  orderId?: string;
  /** Absent for a real purchase; 0 for a license tester's test purchase. */
  purchaseType?: number;
  obfuscatedExternalAccountId?: string;
  quantity?: number;
}

export interface GoogleVoided {
  purchaseToken: string;
  orderId?: string;
  voidedTimeMillis?: string;
}

export const googlePackage = () =>
  Deno.env.get("GOOGLE_PLAY_PACKAGE") ?? APP_ID;

const PLAY_API = "https://androidpublisher.googleapis.com/androidpublisher/v3";

let googleToken: { token: string; until: number } | null = null;

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (googleToken && googleToken.until > now + 60) return googleToken.token;
  const raw = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT");
  if (!raw) throw new StoreNotConfigured("Play service account is not set");
  const account = JSON.parse(raw) as {
    client_email: string;
    private_key: string;
    private_key_id?: string;
  };
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBody(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const assertion = await signJwt(
    { alg: "RS256", typ: "JWT", kid: account.private_key_id },
    {
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    key,
    { name: "RSASSA-PKCS1-v1_5" },
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`Google sign-in failed ${res.status}: ${await res.text()}`);
  }
  const body = await res.json() as { access_token: string; expires_in: number };
  googleToken = { token: body.access_token, until: now + body.expires_in };
  return body.access_token;
}

async function play(path: string, init?: RequestInit): Promise<Response> {
  return fetch(`${PLAY_API}/applications/${googlePackage()}${path}`, {
    ...init,
    headers: {
      ...init?.headers,
      Authorization: `Bearer ${await googleAccessToken()}`,
    },
  });
}

/** Looks up a one-time purchase with Google. Null when there's no such purchase. */
export async function googlePurchase(
  productId: string,
  token: string,
): Promise<GooglePurchase | null> {
  const res = await play(
    `/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(token)
    }`,
  );
  if (res.status === 400 || res.status === 404 || res.status === 410) {
    await res.body?.cancel();
    return null;
  }
  if (!res.ok) {
    throw new Error(`Play answered ${res.status}: ${await res.text()}`);
  }
  return await res.json() as GooglePurchase;
}

/**
 * Marks a coin purchase as used up, so the player can buy that pack again
 * (and Google doesn't refund it for never being acknowledged).
 */
export async function consumeGooglePurchase(
  productId: string,
  token: string,
): Promise<boolean> {
  const res = await play(
    `/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(token)
    }:consume`,
    { method: "POST" },
  );
  await res.body?.cancel();
  return res.ok;
}

/** A subscription purchase from the Play Developer API (the fields used). */
export interface GoogleSubscription {
  /** SUBSCRIPTION_STATE_ACTIVE, _CANCELED (still on until it ends),
   * _IN_GRACE_PERIOD, _ON_HOLD, _PAUSED, _EXPIRED, _PENDING... */
  subscriptionState?: string;
  lineItems?: {
    productId?: string;
    expiryTime?: string;
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
  }[];
  acknowledgementState?: string;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  linkedPurchaseToken?: string;
  testPurchase?: Record<string, unknown>;
}

/** Looks up a subscription with Google. Null when there's no such one. */
export async function googleSubscription(
  token: string,
): Promise<GoogleSubscription | null> {
  const res = await play(
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`,
  );
  if (res.status === 400 || res.status === 404 || res.status === 410) {
    await res.body?.cancel();
    return null;
  }
  if (!res.ok) {
    throw new Error(`Play answered ${res.status}: ${await res.text()}`);
  }
  return await res.json() as GoogleSubscription;
}

/** Acknowledges a new subscription, or Google refunds it after 3 days. */
export async function acknowledgeGoogleSubscription(
  productId: string,
  token: string,
): Promise<boolean> {
  const res = await play(
    `/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(token)
    }:acknowledge`,
    { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" },
  );
  await res.body?.cancel();
  return res.ok;
}

/** Every one-time purchase refunded or charged back in the last [days]. */
export async function googleVoided(days = 30): Promise<GoogleVoided[]> {
  const since = Date.now() - days * 24 * 60 * 60 * 1000 + 60_000;
  const out: GoogleVoided[] = [];
  let page: string | undefined;
  do {
    const query = new URLSearchParams({
      startTime: String(since),
      maxResults: "1000",
    });
    if (page) query.set("token", page);
    const res = await play(`/purchases/voidedpurchases?${query}`);
    if (!res.ok) {
      throw new Error(`Play answered ${res.status}: ${await res.text()}`);
    }
    const body = await res.json() as {
      voidedPurchases?: GoogleVoided[];
      tokenPagination?: { nextPageToken?: string };
    };
    out.push(...(body.voidedPurchases ?? []));
    page = body.tokenPagination?.nextPageToken;
  } while (page);
  return out;
}
