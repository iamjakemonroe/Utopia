// Kaivon Ready (ready.kaivon.app): answers in live interviews, and the coach.
// The desktop app holds no keys and no instructions; they're here, so the app
// can't be used as a free route to Claude. Deployed as a Supabase function
// beside Kaivon's others, by tools/sync-server.sh in the kaivon-ready repo.
//
// Jobs:
//   otp, verify, refresh - signing in by emailed code. No sign-in needed.
//   me       - the account's tier and what's left of today's allowance.
//   answer   - {question, history, profile, speed}: the answer, streamed as
//              server-sent events, as soon as the interviewer finishes.
//   plan     - {profile}: the coach's plan for the candidate's field, as JSON.
//   feedback - {profile, question, transcript, delivery}: scores for a
//              practice answer, as JSON.
//
// One Kaivon account, one allowance: each call is held against study_allow
// first and settled with what it really cost (study_spend, features
// ready.answer, ready.plan and ready.feedback), as Kaivon Code does.
//
// Answer events, each `data: {json}`:
//   {t: "start", model}   {t: "text", text}   {t: "done"}
//   {t: "refusal"}        {t: "error", error, retry}
//
// Deploy with --no-verify-jwt: signing in happens before there's a token.

import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  cleanFeedback,
  cleanPlan,
  FEEDBACK_INSTRUCTIONS,
  FEEDBACK_SCHEMA,
  feedbackRequest,
  PLAN_INSTRUCTIONS,
  PLAN_SCHEMA,
  planRequest,
} from "./shared/coach.ts";
import { INSTRUCTIONS, profileText, questionText } from "./shared/prompt.ts";
import type { Exchange, Profile } from "./shared/types.ts";

const FAST_MODEL = Deno.env.get("READY_FAST_MODEL") ?? "claude-haiku-5-5";
const BEST_MODEL = Deno.env.get("READY_BEST_MODEL") ?? "claude-sonnet-5-5";

const anthropic = new Anthropic({ maxRetries: 1 });

type Kind = "best" | "fast";

const MOST_BYTES = 400_000;

/** Dollars per million tokens: input, output, cache read, cache write. */
const PRICES: [string, [number, number, number, number]][] = [
  ["claude-opus-5-5", [4, 20, 0.2, 5]],
  ["claude-sonnet-5-5", [2, 10, 0.2, 2.5]],
  ["claude-haiku-5-5", [0.1, 0.5, 0.01, 0.125]],
];

type Usage = { input: number; output: number; cacheRead: number; cacheWrite: number };
const NO_USAGE: Usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

function priceOf(model: string, u: Usage): number {
  const [i, o, r, w] = PRICES.find(([id]) => model.startsWith(id))?.[1] ?? PRICES[0][1];
  return (u.input * i + u.output * o + u.cacheRead * r + u.cacheWrite * w) / 1e6;
}

// deno-lint-ignore no-explicit-any
function usageOf(m: any): Usage {
  const u = m.usage ?? {};
  return {
    input: u.input_tokens ?? 0,
    output: u.output_tokens ?? 0,
    cacheRead: u.cache_read_input_tokens ?? 0,
    cacheWrite: u.cache_creation_input_tokens ?? 0,
  };
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

function admin() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

function publicClient() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function clip(value: unknown, max: number): string {
  const s = typeof value === "string" ? value : "";
  return s.length > max ? s.slice(0, max) : s;
}

const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);

/** The candidate's material, trimmed to sane sizes. It's data, never instructions. */
function profileFrom(v: unknown): Profile {
  const p = (v && typeof v === "object" ? v : {}) as Record<string, unknown>;
  const stories = Array.isArray(p.stories) ? p.stories.slice(0, 40) : [];
  return {
    name: clip(p.name, 200),
    targetRole: clip(p.targetRole, 300),
    company: clip(p.company, 300),
    jobDescription: clip(p.jobDescription, 20000),
    resume: clip(p.resume, 40000),
    stories: stories.map((s: Record<string, unknown>, i: number) => ({
      id: String(i),
      title: clip(s?.title, 200),
      text: clip(s?.text, 6000),
    })),
    notes: clip(p.notes, 20000),
    words: "",
  };
}

function historyFrom(v: unknown): Exchange[] {
  if (!Array.isArray(v)) return [];
  return v.slice(-20).map((e: Record<string, unknown>) => ({
    speaker: e?.speaker === "you" ? "you" : "them",
    text: clip(e?.text, 2000),
  }));
}

// deno-lint-ignore no-explicit-any
type Db = any;
type Who = { db: Db; userId: string };

type Allowance =
  | { ok: true; model: Kind; day: string; hold: number; tier: string }
  | { ok: false; why: string; resetsAt: string | null; tier: string };

async function allow(who: Who, want: Kind): Promise<Allowance> {
  const { data, error } = await who.db.rpc("study_allow", { p_model: want, p_kind: "ask", p_bytes: 0 });
  if (error) throw error;
  const d = (data ?? {}) as Record<string, unknown>;
  const tier = String(d.tier ?? "free");
  if (d.ok === true) {
    return { ok: true, model: d.model === "best" ? "best" : "fast", day: String(d.day), hold: Number(d.hold ?? 0), tier };
  }
  return { ok: false, why: String(d.why ?? "limit"), resetsAt: typeof d.resets_at === "string" ? d.resets_at : null, tier };
}

function refused(a: Extract<Allowance, { ok: false }>): Response {
  const error = {
    account: "Sign in with your Kaivon account to get answers.",
    limit: "That's today's allowance. It's back tomorrow.",
    busy: "Kaivon Ready is very busy today. Try again tomorrow.",
  }[a.why] ?? "Kaivon Ready can't answer just now.";
  return json({ error, why: a.why, resets_at: a.resetsAt, tier: a.tier }, a.why === "account" ? 403 : 429);
}

/** Settles a hold with what the call cost. Never throws. */
async function spend(who: Who, a: Extract<Allowance, { ok: true }>, feature: string, model: string, u: Usage) {
  try {
    const { error } = await admin().rpc("study_spend", {
      p_user: who.userId,
      p_day: a.day,
      p_kind: a.model,
      p_hold: a.hold,
      p_feature: feature,
      p_model: model,
      p_input: u.input,
      p_output: u.output,
      p_cache_read: u.cacheRead,
      p_cache_write: u.cacheWrite,
      p_searches: 0,
      p_usd: Number(priceOf(model, u).toFixed(5)),
    });
    if (error) console.error("study_spend", error);
  } catch (e) {
    console.error("study_spend", e);
  }
}

const system = (instructions: string, profile: Profile) => [
  { type: "text", text: instructions },
  { type: "text", text: profileText(profile), cache_control: { type: "ephemeral", ttl: "1h" } },
];

// ── Live answers ───────────────────────────────────────────────────────

async function answer(who: Who, body: Record<string, unknown>, signal: AbortSignal): Promise<Response> {
  const question = clip(body.question, 4000).trim();
  if (!question) return json({ error: "No question" }, 400);
  const allowance = await allow(who, body.speed === "deep" ? "best" : "fast");
  if (!allowance.ok) return refused(allowance);
  const kind = allowance.model;
  const model = kind === "best" ? BEST_MODEL : FAST_MODEL;
  const params = {
    model,
    max_tokens: 400,
    // The first words matter more than depth: thinking off, low effort.
    thinking: kind === "best" ? { type: "between_tools" } : { type: "disabled" },
    output_config: { effort: "low" },
    system: system(INSTRUCTIONS, profileFrom(body.profile)),
    messages: [{ role: "user", content: questionText(question, historyFrom(body.history)) }],
  };

  const encoder = new TextEncoder();
  const abort = new AbortController();
  signal.addEventListener("abort", () => abort.abort());
  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      let open = true;
      const send = (event: Record<string, unknown>) => {
        if (!open) return;
        try {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
        } catch {
          open = false;
        }
      };
      send({ t: "start", model: kind });
      let written = 0;
      try {
        // deno-lint-ignore no-explicit-any
        const run = anthropic.messages.stream(params as any, { signal: abort.signal });
        for await (const event of run) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            written += event.delta.text.length;
            send({ t: "text", text: event.delta.text });
          }
        }
        const final = await run.finalMessage();
        await spend(who, allowance, "ready.answer", String(final.model ?? model), usageOf(final));
        send(final.stop_reason === "refusal" ? { t: "refusal" } : { t: "done" });
      } catch (e) {
        await spend(who, allowance, "ready.answer", model, { ...NO_USAGE, output: Math.ceil(written / 3.5) });
        if (!abort.signal.aborted) {
          console.error("kaivon-ready answer", e);
          const busy = e instanceof Anthropic.RateLimitError || (e instanceof Anthropic.APIError && e.status === 529);
          send({ t: "error", error: busy ? "Busy for a moment. Ask again." : "Couldn't write an answer just now.", retry: busy });
        }
      } finally {
        if (open) {
          open = false;
          controller.close();
        }
      }
    },
    cancel() {
      abort.abort();
    },
  });
  return new Response(stream, {
    headers: { ...cors, "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-cache, no-transform", "X-Accel-Buffering": "no" },
  });
}

// ── Coach ──────────────────────────────────────────────────────────────

async function structured(
  who: Who,
  feature: string,
  instructions: string,
  profile: Profile,
  user: string,
  schema: Record<string, unknown>,
  maxTokens: number,
): Promise<Response | unknown> {
  const allowance = await allow(who, "best");
  if (!allowance.ok) return refused(allowance);
  const model = allowance.model === "best" ? BEST_MODEL : FAST_MODEL;
  let final;
  try {
    const run = anthropic.messages.stream({
      model,
      max_tokens: maxTokens,
      output_config: { effort: "medium", format: { type: "json_schema", schema } },
      system: system(instructions, profile),
      messages: [{ role: "user", content: user }],
      // deno-lint-ignore no-explicit-any
    } as any);
    final = await run.finalMessage();
  } catch (e) {
    console.error(`kaivon-ready ${feature}`, e);
    await spend(who, allowance, feature, model, NO_USAGE);
    return json({ error: "Couldn't reach Claude just now. Try again." }, 502);
  }
  await spend(who, allowance, feature, String(final.model ?? model), usageOf(final));
  if (final.stop_reason === "refusal") return json({ error: "Claude didn't answer this one." }, 422);
  if (final.stop_reason === "max_tokens") return json({ error: "The answer was cut short. Try again." }, 502);
  // deno-lint-ignore no-explicit-any
  const text = final.content.map((b: any) => (b.type === "text" ? b.text : "")).join("");
  try {
    return JSON.parse(text);
  } catch {
    return json({ error: "The answer came back garbled. Try again." }, 502);
  }
}

async function plan(who: Who, body: Record<string, unknown>): Promise<Response> {
  const profile = profileFrom(body.profile);
  const out = await structured(who, "ready.plan", PLAN_INSTRUCTIONS, profile, planRequest(profile), PLAN_SCHEMA, 16000);
  if (out instanceof Response) return out;
  // deno-lint-ignore no-explicit-any
  return json({ plan: cleanPlan(out as any) });
}

async function feedback(who: Who, body: Record<string, unknown>): Promise<Response> {
  const d = (body.delivery ?? {}) as Record<string, unknown>;
  const delivery = {
    words: num(d.words),
    seconds: num(d.seconds),
    wordsPerMinute: num(d.wordsPerMinute),
    fillers: (Array.isArray(d.fillers) ? d.fillers.slice(0, 20) : []).map((f: Record<string, unknown>) => ({
      word: clip(f?.word, 30),
      count: num(f?.count),
    })),
    fillerCount: num(d.fillerCount),
    hedges: num(d.hedges),
    longestPause: num(d.longestPause),
  };
  const question = clip(body.question, 4000);
  const transcript = clip(body.transcript, 20000);
  const out = await structured(
    who,
    "ready.feedback",
    FEEDBACK_INSTRUCTIONS,
    profileFrom(body.profile),
    feedbackRequest(question, transcript, delivery),
    FEEDBACK_SCHEMA,
    3000,
  );
  if (out instanceof Response) return out;
  // deno-lint-ignore no-explicit-any
  return json({ feedback: cleanFeedback(out as any) });
}

// ── Signing in ─────────────────────────────────────────────────────────

const sessionOf = (s: { access_token: string; refresh_token: string; expires_at?: number }, email?: string) => ({
  access_token: s.access_token,
  refresh_token: s.refresh_token,
  expires_at: s.expires_at ?? 0,
  email: email ?? null,
});

async function signIn(body: Record<string, unknown>): Promise<Response> {
  const auth = publicClient().auth;
  if (body.action === "otp") {
    const email = clip(body.email, 320).trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: "That email doesn't look right." }, 400);
    const { error } = await auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
    if (error) {
      console.error("otp", error.message);
      return json({ error: "Couldn't send the code. Wait a minute and try again." }, 429);
    }
    return json({ ok: true });
  }
  if (body.action === "verify") {
    const email = clip(body.email, 320).trim().toLowerCase();
    const { data, error } = await auth.verifyOtp({ email, token: clip(body.code, 20).trim(), type: "email" });
    if (error || !data.session) return json({ error: "That code didn't work." }, 400);
    return json(sessionOf(data.session, data.user?.email));
  }
  const { data, error } = await auth.refreshSession({ refresh_token: clip(body.refresh_token, 4000) });
  if (error || !data.session) return json({ error: "Please sign in again." }, 401);
  return json(sessionOf(data.session, data.user?.email));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const raw = await req.text();
  if (raw.length > MOST_BYTES) return json({ error: "That's too much to send at once." }, 413);
  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "Bad JSON" }, 400);
  }
  try {
    if (body.action === "otp" || body.action === "verify" || body.action === "refresh") return await signIn(body);
    const header = req.headers.get("Authorization");
    if (!header) return json({ error: "Please sign in." }, 401);
    const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: header } },
      auth: { persistSession: false },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Please sign in again." }, 401);
    const who: Who = { db: userClient, userId: user.id };
    if (body.action === "me") {
      const { data, error } = await who.db.rpc("study_me");
      if (error) throw error;
      return json({ ...data, email: user.email ?? null });
    }
    if (!Deno.env.get("ANTHROPIC_API_KEY")) return json({ error: "Answers aren't switched on yet." }, 503);
    if (body.action === "answer") return await answer(who, body, req.signal);
    if (body.action === "plan") return await plan(who, body);
    if (body.action === "feedback") return await feedback(who, body);
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "Kaivon Ready couldn't answer just now." }, 500);
  }
});
