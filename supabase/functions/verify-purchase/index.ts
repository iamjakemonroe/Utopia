// Adds the coins for a coin pack bought in the app, once Apple or Google
// confirms the payment.
//
// The app sends which store, the pack, and the store's id for the purchase
// (Apple's transaction id, or Google's purchase token). The coins come from
// the coin_packs table and the purchase is looked up with the store itself,
// so the app can't claim a pack it didn't pay for. Each purchase pays out
// once (coin_purchases), to the account it was bought for: the app sets
// that account on every purchase (Apple's appAccountToken, Google's
// obfuscated account id), so a purchase handed back on a phone where
// someone else has since signed in still goes to the buyer.
//
// Answers:
//   200 { status: "credited", coins, balance, mine }: paid (now or before).
//   202 { status: "pending" }: Google is still waiting for the payment
//       (cash or bank transfer); the app tries again when it goes through.
//   410 { status: "void" }: cancelled or refunded; no coins, and the app
//       can stop asking.
//   404 { status: "unknown" }: the store doesn't know this purchase (yet).
//   503 { status: "unavailable" }: store keys not set up, or the store
//       didn't answer. The app keeps the purchase and tries again later.
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  appleBundleId,
  appleTransaction,
  consumeGooglePurchase,
  googlePurchase,
  StoreNotConfigured,
} from "../_shared/stores.ts";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The account a purchase was bought for, or [caller] when it doesn't say. */
function ownerOf(token: string | undefined, caller: string): string {
  return token && UUID.test(token) ? token.toLowerCase() : caller;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const asPlayer = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await asPlayer.auth.getUser();
  if (!user) return json({ error: "Not signed in" }, 401);

  let body: { platform?: string; product_id?: string; purchase_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad request" }, 400);
  }
  const { platform, product_id: productId, purchase_id: purchaseId } = body;
  if (
    (platform !== "ios" && platform !== "android") ||
    typeof productId !== "string" || !productId.startsWith("utopia.coins.") ||
    typeof purchaseId !== "string" || purchaseId.length === 0 ||
    purchaseId.length > 1000
  ) {
    return json({ error: "Bad request" }, 400);
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const me = user.id.toLowerCase();

  async function credit(args: {
    owner: string;
    transactionId: string;
    orderId?: string;
    product: string;
    quantity?: number;
    environment: "production" | "sandbox";
    purchasedAt?: number;
  }) {
    const { data, error } = await admin.rpc("credit_coin_purchase", {
      p_user_id: args.owner,
      p_platform: platform,
      p_transaction_id: args.transactionId,
      p_order_id: args.orderId ?? null,
      p_product_id: args.product,
      p_quantity: args.quantity ?? 1,
      p_environment: args.environment,
      p_purchased_at: args.purchasedAt
        ? new Date(args.purchasedAt).toISOString()
        : null,
    });
    if (error) {
      // Already paid out to whoever it was bought for.
      if (error.message.includes("belongs to another account")) {
        return json({ status: "credited", coins: 0, balance: null, mine: false });
      }
      console.error("credit_coin_purchase", error);
      return json({ status: "unavailable" }, 503);
    }
    const result = data as { coins: number; balance: number; credited: boolean };
    const mine = args.owner === me;
    return json({
      status: "credited",
      coins: result.coins,
      // Only their own balance: a purchase made for another account says
      // nothing about that account.
      balance: mine ? result.balance : null,
      credited: result.credited,
      mine,
    });
  }

  try {
    if (platform === "ios") {
      const found = await appleTransaction(purchaseId);
      if (!found) return json({ status: "unknown" }, 404);
      const t = found.transaction;
      if (t.bundleId !== appleBundleId() || t.productId !== productId) {
        return json({ status: "unknown" }, 404);
      }
      if (t.revocationDate) return json({ status: "void" }, 410);
      return await credit({
        owner: ownerOf(t.appAccountToken, me),
        transactionId: t.transactionId,
        orderId: t.originalTransactionId,
        product: t.productId,
        quantity: t.quantity,
        environment: found.environment,
        purchasedAt: t.purchaseDate,
      });
    }

    const p = await googlePurchase(productId, purchaseId);
    if (!p) return json({ status: "unknown" }, 404);
    if (p.purchaseState === 2) return json({ status: "pending" }, 202);
    if (p.purchaseState !== 0) return json({ status: "void" }, 410);
    const answer = await credit({
      owner: ownerOf(p.obfuscatedExternalAccountId, me),
      transactionId: purchaseId,
      orderId: p.orderId,
      product: productId,
      quantity: p.quantity,
      environment: p.purchaseType === 0 ? "sandbox" : "production",
      purchasedAt: p.purchaseTimeMillis ? Number(p.purchaseTimeMillis) : undefined,
    });
    // Paid out, so use it up: the pack can be bought again, and Google
    // won't refund it for never being acknowledged. The app does this too,
    // in case this fails.
    if (answer.status === 200 && p.consumptionState !== 1) {
      await consumeGooglePurchase(productId, purchaseId).catch(() => false);
    }
    return answer;
  } catch (e) {
    if (!(e instanceof StoreNotConfigured)) console.error("verify", e);
    return json({ status: "unavailable" }, 503);
  }
});
