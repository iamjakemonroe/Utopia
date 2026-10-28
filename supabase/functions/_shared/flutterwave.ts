// Talking to Flutterwave about coins and subscriptions bought on the web.
//
//   FLW_SECRET_KEY: the secret key (Settings > API keys). A test key
//     (FLWSECK_TEST-...) makes test payments, recorded as sandbox.
//   FLW_WEBHOOK_HASH: the secret hash set with the webhook URL (Settings >
//     Webhooks); Flutterwave sends it back in the verif-hash header.
//
// What Flutterwave answers over its API is the truth: a webhook or a
// redirect only says which payment to look up.

import { createClient } from "jsr:@supabase/supabase-js@2";

const API = "https://api.flutterwave.com/v3";

export class PaymentsOff extends Error {}

function secretKey(): string {
  const key = Deno.env.get("FLW_SECRET_KEY");
  if (!key) throw new PaymentsOff("FLW_SECRET_KEY isn't set");
  return key;
}

/** 'sandbox' with a test key, 'production' with a live one. */
export function environment(): "sandbox" | "production" {
  return secretKey().includes("_TEST") ? "sandbox" : "production";
}

async function call(path: string, init: RequestInit = {}): Promise<Record<string, unknown>> {
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${secretKey()}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.status !== "success") {
    throw new Error(`flutterwave ${path} ${res.status}: ${body.message ?? "no answer"}`);
  }
  return body.data as Record<string, unknown>;
}

/** A hosted checkout for [amount] [currency], returning its link. */
export async function hostedCheckout(p: {
  ref: string;
  amount: number;
  currency: string;
  email: string;
  name?: string;
  title: string;
  description: string;
  logo?: string;
  redirectUrl: string;
  meta: Record<string, unknown>;
  /** A Flutterwave payment plan: the card is charged again each period. */
  paymentPlan?: string;
}): Promise<string> {
  const data = await call("/payments", {
    method: "POST",
    body: JSON.stringify({
      tx_ref: p.ref,
      amount: p.amount,
      currency: p.currency,
      redirect_url: p.redirectUrl,
      customer: { email: p.email, ...(p.name ? { name: p.name } : {}) },
      customizations: {
        title: p.title,
        description: p.description,
        logo: p.logo ?? "https://utopia.kaivon.app/logo.png",
      },
      meta: p.meta,
      ...(p.paymentPlan ? { payment_plan: p.paymentPlan, payment_options: "card" } : {}),
    }),
  });
  return String(data.link);
}

/** A payment plan charging [amount] [currency] every [interval]: its id. */
export async function createPlan(p: {
  name: string;
  amount: number;
  currency: string;
  interval: "weekly" | "monthly";
}): Promise<string> {
  const data = await call("/payment-plans", {
    method: "POST",
    body: JSON.stringify({ name: p.name, amount: p.amount, currency: p.currency, interval: p.interval }),
  });
  return String(data.id);
}

/** Cancels [email]'s active subscriptions on plan [plan]: how many. */
export async function cancelSubscriptions(email: string, plan: string): Promise<number> {
  const res = await fetch(
    `${API}/subscriptions?email=${encodeURIComponent(email)}&plan=${encodeURIComponent(plan)}&status=active`,
    { headers: { Authorization: `Bearer ${secretKey()}` } },
  );
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.status !== "success") {
    throw new Error(`flutterwave /subscriptions ${res.status}: ${body.message ?? "no answer"}`);
  }
  const subs = (Array.isArray(body.data) ? body.data : []) as { id: number | string }[];
  for (const sub of subs) {
    await call(`/subscriptions/${encodeURIComponent(String(sub.id))}/cancel`, { method: "PUT" });
  }
  return subs.length;
}

export type Transaction = {
  id: string;
  ref: string;
  status: string;
  amount: number;
  currency: string;
  /** The payment plan a subscription's charge was for, and its email. */
  plan: string | null;
  email: string | null;
};

/** Transaction [id], as Flutterwave has it now. */
export async function transaction(id: string): Promise<Transaction> {
  const data = await call(`/transactions/${encodeURIComponent(id)}/verify`);
  const customer = (data.customer ?? {}) as Record<string, unknown>;
  const plan = data.plan ?? data.payment_plan;
  return {
    id: String(data.id),
    ref: String(data.tx_ref),
    status: String(data.status),
    amount: Number(data.amount),
    currency: String(data.currency),
    plan: plan == null || plan === "" ? null : String(plan),
    email: typeof customer.email === "string" ? customer.email : null,
  };
}

/** Adds the coins for a confirmed, successful [t], once. */
export async function credit(t: Transaction): Promise<Record<string, unknown>> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const { data, error } = await admin.rpc("credit_web_payment", {
    p_ref: t.ref,
    p_provider_id: t.id,
    p_amount: t.amount,
    p_currency: t.currency,
    p_environment: environment(),
  });
  if (error) throw new Error(`credit ${t.ref}: ${error.message}`);
  return data as Record<string, unknown>;
}

function admin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/** A subscription's payment, confirmed and successful: its first one (by
 * checkout reference) or a renewal (by plan and email). Once each. */
export async function creditSubscription(t: Transaction): Promise<Record<string, unknown>> {
  const { data, error } = t.ref.startsWith("kaivon-sub-")
    ? await admin().rpc("credit_web_subscription", {
      p_ref: t.ref,
      p_provider_id: t.id,
      p_amount: t.amount,
      p_currency: t.currency,
      p_environment: environment(),
    })
    : await admin().rpc("renew_web_subscription", {
      p_flw_plan_id: t.plan,
      p_email: t.email,
      p_provider_id: t.id,
      p_amount: t.amount,
      p_currency: t.currency,
      p_environment: environment(),
    });
  if (error) throw new Error(`subscription ${t.ref}: ${error.message}`);
  return data as Record<string, unknown>;
}

/** A subscription cancelled (with Flutterwave already): paid-up time is kept. */
export async function endSubscription(plan: string, email: string): Promise<Record<string, unknown>> {
  const { data, error } = await admin().rpc("end_web_subscription", { p_flw_plan_id: plan, p_email: email });
  if (error) throw new Error(`end subscription ${plan}: ${error.message}`);
  return data as Record<string, unknown>;
}

/** The web-pay function made a payment plan for [plan]'s price in [currency]. */
export async function keepPlan(plan: string, currency: string, flwPlan: string, ref: string) {
  const { error } = await admin().rpc("web_plan_flw", {
    p_plan: plan,
    p_currency: currency,
    p_flw_plan_id: flwPlan,
    p_ref: ref,
  });
  if (error) throw new Error(`keep plan ${plan}: ${error.message}`);
}

/** Whether [given] is the webhook's secret hash (compared in constant time). */
export function webhookHashMatches(given: string | null): boolean {
  const hash = Deno.env.get("FLW_WEBHOOK_HASH");
  if (!hash || !given) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(hash);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
