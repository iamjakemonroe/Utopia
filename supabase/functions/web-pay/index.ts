// Coins bought on the web (the web game's coin shop), through Flutterwave.
//
//   { action: "status" }: { on } whether payments are switched on.
//   { action: "checkout", product, currency }: starts paying for a pack, in
//     the player's currency where it has a price (web_checkout_start), and
//     answers { link } to Flutterwave's checkout page. Accounts only.
//   { action: "confirm", ref, transaction_id }: back from checkout, the
//     game asks: Flutterwave is asked about the payment, and a successful
//     one is paid out (once: the webhook may have done it already).
//     Answers { status: "paid", coins } or { status } as Flutterwave has it.
//
// 503 { error: "off" } until the Flutterwave keys are set
// (tool/push_payment_keys.sh).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { credit, hostedCheckout, PaymentsOff, transaction } from "../_shared/flutterwave.ts";

const GAME_URL = Deno.env.get("WEB_GAME_URL") ?? "https://utopia.kaivon.app/game/";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);
  const player = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await player.auth.getUser();
  if (!user) return json({ error: "Not signed in" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad JSON" }, 400);
  }

  try {
    if (body.action === "status") {
      return json({ on: !!Deno.env.get("FLW_SECRET_KEY") });
    }

    if (body.action === "checkout") {
      if (!Deno.env.get("FLW_SECRET_KEY")) throw new PaymentsOff();
      const { data, error } = await player.rpc("web_checkout_start", {
        p_product: String(body.product ?? ""),
        p_currency: String(body.currency ?? "USD"),
      });
      if (error) {
        const why = error.message.includes("save your account")
          ? "account"
          : error.message.includes("starter")
          ? "starter"
          : "pack";
        return json({ error: why }, 400);
      }
      const start = data as Record<string, unknown>;
      if (!user.email) return json({ error: "account" }, 400);
      const coins = Number(start.coins).toLocaleString("en-US");
      const link = await hostedCheckout({
        ref: String(start.ref),
        amount: Number(start.amount),
        currency: String(start.currency),
        email: user.email,
        name: typeof start.name === "string" ? start.name : undefined,
        title: "Utopia coins",
        description: `${coins} coins for your Utopia account`,
        redirectUrl: GAME_URL,
        meta: { user_id: user.id, product: String(body.product) },
      });
      return json({ link, ref: start.ref });
    }

    if (body.action === "confirm") {
      const id = String(body.transaction_id ?? "");
      if (!/^\d+$/.test(id)) return json({ status: "unknown" });
      const t = await transaction(id);
      if (t.ref !== body.ref) return json({ status: "unknown" });
      if (t.status !== "successful") return json({ status: t.status });
      const paid = await credit(t);
      if (paid.user_id !== user.id) return json({ status: "other" });
      return json({ status: "paid", coins: paid.coins, balance: paid.balance });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    if (e instanceof PaymentsOff) return json({ error: "off" }, 503);
    console.error("web-pay", e);
    return json({ error: "Couldn't reach the payment service" }, 502);
  }
});
