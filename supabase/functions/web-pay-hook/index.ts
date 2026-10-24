// Flutterwave's webhook (Settings > Webhooks: this function's URL, with the
// secret hash in FLW_WEBHOOK_HASH). A completed charge is looked up with
// Flutterwave itself and, when successful, paid out: coins (so a player who
// closes the tab before coming back still gets them), a subscription's
// first payment, or a renewal. A cancelled subscription keeps what's paid.
// No player is signed in here (verify_jwt is off): the secret hash is the
// check, and the lookup is the truth.
import {
  credit,
  creditSubscription,
  endSubscription,
  PaymentsOff,
  transaction,
  webhookHashMatches,
} from "../_shared/flutterwave.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  if (!webhookHashMatches(req.headers.get("verif-hash"))) {
    return new Response("Unauthorized", { status: 401 });
  }
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  const data = (body.data ?? {}) as Record<string, unknown>;
  try {
    if (body.event === "subscription.cancelled") {
      const customer = (data.customer ?? {}) as Record<string, unknown>;
      const plan = (data.plan ?? {}) as Record<string, unknown>;
      const planId = plan.id ?? data.plan_id ?? data.payment_plan;
      if (planId != null && typeof customer.email === "string") {
        await endSubscription(String(planId), customer.email);
      }
      return new Response("ok", { status: 200 });
    }
    if (body.event !== "charge.completed" || data.id == null) {
      return new Response("ignored", { status: 200 });
    }
    const t = await transaction(String(data.id));
    if (t.status === "successful") {
      if (t.ref.startsWith("utopia-")) await credit(t);
      else if (t.ref.startsWith("kaivon-sub-") || (t.plan && t.email)) await creditSubscription(t);
    }
    return new Response("ok", { status: 200 });
  } catch (e) {
    if (e instanceof PaymentsOff) return new Response("off", { status: 503 });
    // Flutterwave tries again later.
    console.error("web-pay-hook", e);
    return new Response("error", { status: 500 });
  }
});
