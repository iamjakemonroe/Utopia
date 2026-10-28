// Coins and subscriptions bought on the web, through Flutterwave: in the web
// game's coin shop, in Chip Rizz (the same Kaivon account and coins) and in
// Chip Study (Chip Study Pro).
//
//   { action: "status" }: { on, test } whether payments are switched on,
//     and whether they're Flutterwave's test mode (no real money).
//   { action: "checkout", product, currency, app }: starts paying for a
//     pack, in the player's currency where it has a price
//     (web_checkout_start), and answers { link } to Flutterwave's checkout
//     page, which comes back to the app it was started from ("utopia", the
//     default, "chip" or "study"). Accounts only.
//   { action: "subscribe", plan, currency, app }: starts a subscription
//     (web_subscribe_start): Flutterwave's payment plan for its price (made
//     the first time), and { link } to checkout, which charges the card again
//     each period. Accounts only, and not while already a member.
//   { action: "confirm", ref, transaction_id }: back from checkout, the
//     app asks: Flutterwave is asked about the payment, and a successful one
//     is paid out (once: the webhook may have done it already). Answers
//     { status: "paid", coins } for coins, { status: "paid", product, until }
//     for a subscription, or { status } as Flutterwave has it.
//   { action: "cancel", product }: cancels the member's own subscription to
//     "maestro", "rizz_pro" or "study_pro" with Flutterwave; they keep what
//     they paid for.
//
// 503 { error: "off" } until the Flutterwave keys are set
// (tool/push_payment_keys.sh).
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  cancelSubscriptions,
  createPlan,
  credit,
  creditSubscription,
  endSubscription,
  environment,
  hostedCheckout,
  keepPlan,
  PaymentsOff,
  transaction,
} from "../_shared/flutterwave.ts";

/** Each app's checkout: where it comes back to, and how it's named. Local
 * testing (tool/local_backend) points the returns at localhost. */
const APPS = {
  utopia: {
    returnUrl: Deno.env.get("UTOPIA_RETURN_URL") ?? Deno.env.get("WEB_GAME_URL") ??
      "https://utopia.kaivon.app/game/",
    title: "Utopia coins",
    description: (coins: string) => `${coins} coins for your Utopia account`,
    logo: "https://utopia.kaivon.app/logo.png",
  },
  chip: {
    returnUrl: Deno.env.get("CHIP_RETURN_URL") ?? "https://chip.kaivon.app/",
    title: "Chip Rizz coins",
    description: (coins: string) => `${coins} coins for your Kaivon account (Chip Rizz and Utopia)`,
    logo: "https://chip.kaivon.app/icon-192.png",
  },
  study: {
    returnUrl: Deno.env.get("STUDY_RETURN_URL") ?? "https://study.kaivon.app/app/plan",
    title: "Chip Study",
    description: (coins: string) => `${coins} coins for your Kaivon account`,
    logo: "https://study.kaivon.app/icon-192.png",
  },
};

/** Which app a checkout was started from. */
function appOf(value: unknown): keyof typeof APPS {
  return value === "chip" || value === "study" ? value : "utopia";
}

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
      const on = !!Deno.env.get("FLW_SECRET_KEY");
      return json({ on, test: on && environment() === "sandbox" });
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
      const app = appOf(body.app);
      const look = APPS[app];
      const link = await hostedCheckout({
        ref: String(start.ref),
        amount: Number(start.amount),
        currency: String(start.currency),
        email: user.email,
        name: typeof start.name === "string" ? start.name : undefined,
        title: look.title,
        description: look.description(coins),
        logo: look.logo,
        redirectUrl: look.returnUrl,
        meta: { user_id: user.id, product: String(body.product), app },
      });
      return json({ link, ref: start.ref });
    }

    if (body.action === "subscribe") {
      if (!Deno.env.get("FLW_SECRET_KEY")) throw new PaymentsOff();
      const { data, error } = await player.rpc("web_subscribe_start", {
        p_plan: String(body.plan ?? ""),
        p_currency: String(body.currency ?? "USD"),
      });
      if (error) {
        const why = error.message.includes("save your account")
          ? "account"
          : error.message.includes("already a member")
          ? "member"
          : "plan";
        return json({ error: why }, 400);
      }
      const start = data as Record<string, unknown>;
      const currency = String(start.currency);
      const amount = Number(start.amount);
      let flwPlan = start.flw_plan_id ? String(start.flw_plan_id) : "";
      if (!flwPlan) {
        flwPlan = await createPlan({
          name: `${start.title} ${currency} ${amount}`,
          amount,
          currency,
          interval: start.period === "weekly" ? "weekly" : "monthly",
        });
        await keepPlan(String(start.plan), currency, flwPlan, String(start.ref));
      }
      const app = appOf(body.app);
      const look = APPS[app];
      const link = await hostedCheckout({
        ref: String(start.ref),
        amount,
        currency,
        email: String(start.email),
        name: typeof start.name === "string" ? start.name : undefined,
        title: String(start.title),
        description: `${start.title}: renews every ${start.period === "weekly" ? "week" : "month"} until you cancel`,
        logo: look.logo,
        redirectUrl: look.returnUrl,
        meta: { user_id: user.id, plan: String(start.plan), app },
        paymentPlan: flwPlan,
      });
      return json({ link, ref: start.ref });
    }

    if (body.action === "confirm") {
      const id = String(body.transaction_id ?? "");
      if (!/^\d+$/.test(id)) return json({ status: "unknown" });
      const t = await transaction(id);
      if (t.ref !== body.ref) return json({ status: "unknown" });
      if (t.status !== "successful") return json({ status: t.status });
      if (t.ref.startsWith("kaivon-sub-")) {
        const paid = await creditSubscription(t);
        if (paid.user_id !== user.id) return json({ status: "other" });
        return json({ status: "paid", product: paid.product, until: paid.until });
      }
      const paid = await credit(t);
      if (paid.user_id !== user.id) return json({ status: "other" });
      return json({ status: "paid", coins: paid.coins, balance: paid.balance });
    }

    if (body.action === "cancel") {
      if (!Deno.env.get("FLW_SECRET_KEY")) throw new PaymentsOff();
      const { data } = await player.rpc("web_subscription_mine", {
        p_product: body.product === "maestro" || body.product === "study_pro" ? body.product : "rizz_pro",
      });
      const mine = data as Record<string, unknown> | null;
      if (!mine?.flw_plan_id) return json({ status: "none" });
      await cancelSubscriptions(String(mine.email), String(mine.flw_plan_id));
      const ended = await endSubscription(String(mine.flw_plan_id), String(mine.email));
      return json({ status: "cancelled", until: ended.until ?? mine.until });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    if (e instanceof PaymentsOff) return json({ error: "off" }, 503);
    console.error("web-pay", e);
    return json({ error: "Couldn't reach the payment service" }, 502);
  }
});
