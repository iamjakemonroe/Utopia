// Refunds, from the stores themselves.
//
// Apple sends App Store Server Notifications (version 2) here, and Google
// sends Real-time developer notifications through a Pub/Sub push
// subscription. When a coin purchase is refunded or charged back, its coins
// are taken back (as many as the player still has), and given back if
// Apple reverses the refund.
//
// A notification is only a nudge: nobody has to sign in to send one, so
// what it says is checked with the store's API before anything changes.
// Google's are answered by going through every purchase Google voided in
// the last 30 days, so a missed one is caught by the next.
//
// Optional STORE_NOTIFY_TOKEN: when set, the URLs given to Apple and
// Google must end in ?token=<it>.
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  appleTransaction,
  googlePackage,
  googleVoided,
  jwsPayload,
  StoreNotConfigured,
} from "../_shared/stores.ts";

const ok = () => new Response("ok");

function admin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

async function takeBack(
  platform: "ios" | "android",
  transactionId: string,
  revokedAt?: number,
) {
  const { data, error } = await admin().rpc("take_back_coin_purchase", {
    p_platform: platform,
    p_transaction_id: transactionId,
    p_revoked_at: revokedAt ? new Date(revokedAt).toISOString() : null,
  });
  if (error) throw error;
  const result = data as { found: boolean; already?: boolean; taken_back?: number };
  if (result.found && !result.already) {
    console.log("refund", platform, transactionId, "took back", result.taken_back);
  }
}

// ── Apple ──────────────────────────────────────────────────────────────

const APPLE_TYPES = new Set(["REFUND", "REVOKE", "REFUND_REVERSED"]);

async function fromApple(signedPayload: string): Promise<Response> {
  const note = jwsPayload<{
    notificationType: string;
    data?: { environment?: string; signedTransactionInfo?: string };
  }>(signedPayload);
  const signed = note.data?.signedTransactionInfo;
  if (!APPLE_TYPES.has(note.notificationType) || !signed) return ok();

  const claimed = jwsPayload<{ transactionId: string }>(signed);
  const environment = note.data?.environment === "Sandbox"
    ? "sandbox"
    : "production";
  const found = await appleTransaction(claimed.transactionId, environment);
  if (!found) return ok();
  const t = found.transaction;

  if (t.revocationDate) {
    await takeBack("ios", t.transactionId, t.revocationDate);
  } else if (note.notificationType === "REFUND_REVERSED") {
    const { error } = await admin().rpc("return_coin_purchase", {
      p_platform: "ios",
      p_transaction_id: t.transactionId,
    });
    if (error) throw error;
  }
  return ok();
}

// ── Google ─────────────────────────────────────────────────────────────

async function fromGoogle(data: string): Promise<Response> {
  const note = JSON.parse(atob(data)) as { packageName?: string };
  if (note.packageName && note.packageName !== googlePackage()) return ok();
  for (const v of await googleVoided()) {
    await takeBack(
      "android",
      v.purchaseToken,
      v.voidedTimeMillis ? Number(v.voidedTimeMillis) : undefined,
    );
  }
  return ok();
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  const expected = Deno.env.get("STORE_NOTIFY_TOKEN");
  if (expected && new URL(req.url).searchParams.get("token") !== expected) {
    return new Response("Forbidden", { status: 403 });
  }

  let body: { signedPayload?: string; message?: { data?: string } };
  try {
    body = await req.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }

  try {
    if (typeof body.signedPayload === "string") {
      return await fromApple(body.signedPayload);
    }
    if (typeof body.message?.data === "string") {
      return await fromGoogle(body.message.data);
    }
    return new Response("Bad request", { status: 400 });
  } catch (e) {
    // A failure answers 500, so Apple and Google send it again later.
    if (!(e instanceof StoreNotConfigured)) console.error("store notification", e);
    return new Response("Try again", { status: 500 });
  }
});
