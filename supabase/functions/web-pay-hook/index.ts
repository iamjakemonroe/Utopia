// Flutterwave's webhook (Settings > Webhooks: this function's URL, with the
// secret hash in FLW_WEBHOOK_HASH). A completed charge is looked up with
// Flutterwave itself and, when successful, its coins are added: so a
// player who closes the tab before coming back to the game still gets them.
// No player is signed in here (verify_jwt is off): the secret hash is the
// check, and the lookup is the truth.
import { credit, PaymentsOff, transaction, webhookHashMatches } from "../_shared/flutterwave.ts";

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
  if (body.event !== "charge.completed" || data.id == null) {
    return new Response("ignored", { status: 200 });
  }
  try {
    const t = await transaction(String(data.id));
    if (t.status === "successful" && t.ref.startsWith("utopia-")) await credit(t);
    return new Response("ok", { status: 200 });
  } catch (e) {
    if (e instanceof PaymentsOff) return new Response("off", { status: 503 });
    // Flutterwave tries again later.
    console.error("web-pay-hook", e);
    return new Response("error", { status: 500 });
  }
});
