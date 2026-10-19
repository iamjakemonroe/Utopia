// A report's screenshot as a link that opens it: the app calls this right
// after sending a report with a screenshot ({ report_id }). Screenshots
// live in a private bucket, so the link is a signed one, good for a year,
// saved on the report (bug_reports.screenshot_url) for the team to click.
// Only for the player's own report; answers { url } (null without one).
import { createClient } from "jsr:@supabase/supabase-js@2";

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

/** How long a screenshot's link works. */
const YEAR = 365 * 24 * 60 * 60;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);
  const url = Deno.env.get("SUPABASE_URL")!;
  const player = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
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
  const reportId = String(body.report_id ?? "");
  if (!/^[0-9a-f-]{36}$/.test(reportId)) return json({ error: "Bad report" }, 400);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: report, error } = await admin
    .from("bug_reports")
    .select("user_id, screenshot_path")
    .eq("id", reportId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!report || report.user_id !== user.id) return json({ error: "Not your report" }, 403);
  const path = report.screenshot_path as string | null;
  if (!path) return json({ url: null });

  const { data: signed, error: signError } = await admin.storage
    .from("bug-screenshots")
    .createSignedUrl(path, YEAR);
  if (signError || !signed) return json({ error: signError?.message ?? "Couldn't sign" }, 500);

  const { error: saveError } = await admin
    .from("bug_reports")
    .update({ screenshot_url: signed.signedUrl })
    .eq("id", reportId);
  if (saveError) return json({ error: saveError.message }, 500);
  return json({ url: signed.signedUrl });
});
