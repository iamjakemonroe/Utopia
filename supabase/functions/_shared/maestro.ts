// Chip Maestro (the monthly art plan): a subscription's state, checked with
// the store itself, written to maestro_subscriptions (maestro_record).
// Used when the app reports a purchase (verify-purchase) and when the store
// says something changed: a renewal, a cancellation, a refund
// (store-notifications).
import {
  acknowledgeGoogleSubscription,
  appleBundleId,
  appleSubscription,
  googleSubscription,
} from "./stores.ts";

export const MAESTRO_PREFIX = "utopia.maestro.";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type MaestroResult = {
  /** active / expired: recorded. pending: Google's still waiting for the
   * money. unknown: no such subscription (yet). other: it's another
   * account's. */
  status: "active" | "expired" | "pending" | "unknown" | "other";
  until?: string;
  owner?: string;
};

// deno-lint-ignore no-explicit-any
type Db = any;

/** Who [original] belongs to: the account the app set on the purchase,
 * else whoever has it already, else [fallback]. */
async function ownerOf(
  service: Db,
  original: string,
  token?: string,
  fallback?: string,
): Promise<string | undefined> {
  if (token && UUID.test(token)) return token.toLowerCase();
  const { data } = await service
    .from("maestro_subscriptions")
    .select("user_id")
    .eq("original_id", original)
    .maybeSingle();
  return data?.user_id ?? fallback;
}

async function record(
  service: Db,
  r: {
    user: string;
    platform: "ios" | "android";
    product: string;
    original: string;
    expires: string;
    autoRenew: boolean;
    environment: "production" | "sandbox";
  },
): Promise<MaestroResult> {
  const { data, error } = await service.rpc("maestro_record", {
    p_user: r.user,
    p_platform: r.platform,
    p_product: r.product,
    p_original: r.original,
    p_expires: r.expires,
    p_auto_renew: r.autoRenew,
    p_environment: r.environment,
  });
  if (error) {
    if (error.message.includes("another account")) return { status: "other" };
    throw error;
  }
  return {
    status: (data as { active: boolean }).active ? "active" : "expired",
    until: r.expires,
    owner: r.user,
  };
}

/** The subscription Apple transaction [transactionId] is part of. */
export async function maestroFromApple(
  service: Db,
  transactionId: string,
  fallbackOwner?: string,
  environment?: "production" | "sandbox",
): Promise<MaestroResult> {
  const sub = await appleSubscription(transactionId, environment);
  if (!sub) return { status: "unknown" };
  const t = sub.transaction;
  if (t.bundleId !== appleBundleId() || !t.productId.startsWith(MAESTRO_PREFIX)) {
    return { status: "unknown" };
  }
  const original = t.originalTransactionId ?? t.transactionId;
  const owner = await ownerOf(service, original, t.appAccountToken, fallbackOwner);
  if (!owner) return { status: "unknown" };
  const ends = t.revocationDate ?? t.expiresDate ?? Date.now();
  return await record(service, {
    user: owner,
    platform: "ios",
    product: t.productId,
    original,
    expires: new Date(ends).toISOString(),
    autoRenew: sub.autoRenew && !t.revocationDate,
    environment: sub.environment,
  });
}

/** The Google subscription with purchase token [token]. */
export async function maestroFromGoogle(
  service: Db,
  token: string,
  productId?: string,
  fallbackOwner?: string,
): Promise<MaestroResult> {
  const s = await googleSubscription(token);
  if (!s) return { status: "unknown" };
  if (s.subscriptionState === "SUBSCRIPTION_STATE_PENDING") return { status: "pending" };
  const item = s.lineItems?.[0];
  const product = item?.productId ?? productId ?? "";
  if (!product.startsWith(MAESTRO_PREFIX)) return { status: "unknown" };
  const owner =
    (await ownerOf(service, token, s.externalAccountIdentifiers?.obfuscatedExternalAccountId)) ??
      (s.linkedPurchaseToken ? await ownerOf(service, s.linkedPurchaseToken) : undefined) ??
      fallbackOwner;
  if (!owner) return { status: "unknown" };
  const result = await record(service, {
    user: owner,
    platform: "android",
    product,
    original: token,
    expires: item?.expiryTime ?? new Date().toISOString(),
    autoRenew: item?.autoRenewingPlan?.autoRenewEnabled ?? false,
    environment: s.testPurchase ? "sandbox" : "production",
  });
  if (s.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING") {
    await acknowledgeGoogleSubscription(product, token).catch(() => false);
  }
  return result;
}
