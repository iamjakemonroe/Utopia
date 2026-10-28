// Flutterwave's webhook (Settings > Webhooks: this function's URL, with the
// secret hash in FLW_WEBHOOK_HASH). A completed charge is looked up with
// Flutterwave itself and, when successful, paid out: coins (so a player who
// closes the tab before coming back still gets them), a subscription's
// first payment, or a renewal. A cancelled subscription keeps what's paid.
// No player is signed in here (verify_jwt is off): the secret hash is the
// check, and the lookup is the truth.
//
// A Flutterwave account has one webhook, and Kaivon's apps share one
// account: Wavee's events (its references start "wavee-", or a plan that
// isn't one of ours) are passed on to Wavee's (WAVEE_HOOK_URL).
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  credit,
  creditSubscription,
  endSubscription,
  PaymentsOff,
  transaction,
  webhookHashMatches,
} from "../_shared/flutterwave.ts";

const WAVEE_HOOK_URL = Deno.env.get("WAVEE_HOOK_URL") ?? "https://wavee.kaivon.app/api/pay/hook";

/** Whether Flutterwave plan [plan] is one of ours (Chip Maestro, Chip Rizz Pro). */
async function ourPlan(plan: string): Promise<boolean> {
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data } = await admin.from("web_plan_prices").select("plan_id").eq("flw_plan_id", plan).limit(1);
  return (data ?? []).length > 0;
}

/** Wavee's event, passed on as it came (with the same secret hash). */
async function toWavee(raw: string, hash: string): Promise<Response> {
  const res = await fetch(WAVEE_HOOK_URL, {
    method: "POST",
    headers: { "content-type": "application/json", "verif-hash": hash },
    body: raw,
  });
  // Flutterwave retries if Wavee didn't take it.
  return new Response(res.ok ? "passed to wavee" : "wavee error", { status: res.ok ? 200 : 502 });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  if (!webhookHashMatches(req.headers.get("verif-hash"))) {
    return new Response("Unauthorized", { status: 401 });
  }
  const raw = await req.text();
  const hash = req.headers.get("verif-hash")!;
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
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
        if (!(await ourPlan(String(planId)))) return await toWavee(raw, hash);
        await endSubscription(String(planId), customer.email);
      }
      return new Response("ok", { status: 200 });
    }
    if (body.event !== "charge.completed" || data.id == null) {
      return new Response("ignored", { status: 200 });
    }
    if (String(data.tx_ref ?? "").startsWith("wavee-")) return await toWavee(raw, hash);
    const t = await transaction(String(data.id));
    if (t.ref.startsWith("wavee-") || (t.plan && !t.ref.startsWith("kaivon-sub-") && !(await ourPlan(t.plan)))) {
      return await toWavee(raw, hash);
    }
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
