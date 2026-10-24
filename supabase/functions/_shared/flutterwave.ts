// Talking to Flutterwave about coins bought on the web.
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
    }),
  });
  return String(data.link);
}

export type Transaction = {
  id: string;
  ref: string;
  status: string;
  amount: number;
  currency: string;
};

/** Transaction [id], as Flutterwave has it now. */
export async function transaction(id: string): Promise<Transaction> {
  const data = await call(`/transactions/${encodeURIComponent(id)}/verify`);
  return {
    id: String(data.id),
    ref: String(data.tx_ref),
    status: String(data.status),
    amount: Number(data.amount),
    currency: String(data.currency),
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
