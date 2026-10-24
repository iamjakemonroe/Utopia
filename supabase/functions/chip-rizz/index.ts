// Chip Rizz (chip.kaivon.app): Chip as a texting wingman.
//
//   reply: replies to a chat (pasted or as screenshots), openers for
//          someone new, or bios, in a tone (sweet, playful, flirty, bold)
//          and toward a goal, with Chip's read of how it's going.
//   learn: reads a chat the user exported (WhatsApp's "Export chat") and
//          keeps Chip's notes on that person (rizz_people.memory). The
//          chat itself is never stored.
//
// Chip Rizz is for adults (18 and over), by the date of birth the user gave
// (rizz_ages). Every call takes one of the
// day's allowance first (chip_allow 'rizz' or 'learn', shared with Utopia's
// Chip: the same tiers, budget and coins), and what it cost goes in the
// day's log (chip_costs).

import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Which brain: Smart Chip (the stronger model) for Chip Rizz Pro members
// and sets paid for with coins; Quick Chip (the fast one, about 20 times
// cheaper) for guests' and free accounts' daily sets. See docs/PRICING.md.
const SMART_MODEL = Deno.env.get("RIZZ_SMART_MODEL") ?? "claude-sonnet-5-5";
const QUICK_MODEL = Deno.env.get("RIZZ_QUICK_MODEL") ?? "claude-haiku-5-5";

type Tier = "guest" | "free" | "pro";
const modelFor = (a: { tier: Tier; paid: boolean }) =>
  a.tier === "pro" || a.paid ? SMART_MODEL : QUICK_MODEL;

/** Dollars per million tokens: input, output, cache read, cache write. */
const PRICES: [string, [number, number, number, number]][] = [
  ["claude-opus-5-5", [4, 20, 0.2, 5]],
  ["claude-sonnet-5-5", [2, 10, 0.2, 2.5]],
  ["claude-haiku-5-5", [0.1, 0.5, 0.01, 0.125]],
];

/** Refusal fallback: if a safety classifier declines, the API retries on
 * Anthropic's recommended fallback model inside the same call. */
// Haiku has no fallback model, so it goes without.
// deno-lint-ignore no-explicit-any
function withFallback(params: any): any {
  if (String(params.model).startsWith("claude-haiku")) return params;
  return { ...params, betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" };
}

const anthropic = new Anthropic();

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

function admin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

function clip(value: unknown, max: number): string {
  const s = typeof value === "string" ? value.trim() : "";
  return s.length > max ? s.slice(0, max) : s;
}

/** What a call cost, added to the day's log. A model not in the list (a
 * fallback) is priced as the most expensive, to be safe. */
async function logCost(feature: string, tier: Tier, response: Anthropic.Beta.BetaMessage) {
  try {
    const u = response.usage;
    const model = String(response.model ?? "unknown");
    const [inUsd, outUsd, readUsd, writeUsd] =
      PRICES.find(([id]) => model.startsWith(id))?.[1] ?? PRICES[0][1];
    const read = u.cache_read_input_tokens ?? 0;
    const write = u.cache_creation_input_tokens ?? 0;
    const usd = (u.input_tokens * inUsd + u.output_tokens * outUsd + read * readUsd +
      write * writeUsd) / 1e6;
    await admin().rpc("chip_log_cost", {
      p_feature: feature,
      p_model: model,
      p_tier: tier,
      p_input: u.input_tokens,
      p_output: u.output_tokens,
      p_cache_read: read,
      p_cache_write: write,
      p_searches: 0,
      p_usd: Number(usd.toFixed(5)),
    });
  } catch (e) {
    console.error("cost log", e);
  }
}

// deno-lint-ignore no-explicit-any
type Who = { db: any; userId: string; device: string | null };

type Allowance = { ok: boolean; tier: Tier; paid: boolean; why: string | null; price: number };

/** Takes one of today's [kind] (chip_allow). [pay]: an account that's out
 * of replies pays coins for a set. */
async function allow(who: Who, kind: "rizz" | "learn", pay: boolean): Promise<Allowance> {
  const { data, error } = await who.db.rpc("chip_allow", {
    p_kind: kind,
    p_device: who.device,
    p_pay: pay,
  });
  if (error) throw error;
  const d = (data ?? {}) as Record<string, unknown>;
  const tier = ["guest", "free", "pro"].includes(d.tier as string) ? d.tier as Tier : "free";
  return {
    ok: d.ok === true,
    tier,
    paid: d.paid === true,
    why: typeof d.why === "string" ? d.why : null,
    price: typeof d.price === "number" ? d.price : 20,
  };
}

/** Why a call wasn't allowed, as the app's status. */
function refused(a: Allowance): Response {
  return json({ status: a.why ?? "limit", price: a.price });
}

/** The user's age in whole years (UTC), or null before they've given it. */
async function ageOf(who: Who): Promise<number | null> {
  const { data } = await who.db.from("rizz_ages").select("born").eq("user_id", who.userId)
    .maybeSingle();
  if (!data?.born) return null;
  const [y, m, d] = String(data.born).split("-").map(Number);
  const now = new Date();
  let age = now.getUTCFullYear() - y;
  if (now.getUTCMonth() + 1 < m || (now.getUTCMonth() + 1 === m && now.getUTCDate() < d)) age--;
  return age;
}

/** Asks Claude for JSON matching [schema]: the parsed result, or "refused". */
async function ask(
  model: string,
  system: string,
  content: Anthropic.Beta.BetaContentBlockParam[],
  schema: Record<string, unknown>,
  maxTokens: number,
  feature: string,
  tier: Tier,
): Promise<Record<string, unknown> | "refused"> {
  const params = withFallback({
    model,
    max_tokens: maxTokens,
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    output_config: { effort: "low", format: { type: "json_schema", schema } },
    messages: [{ role: "user", content }],
  });
  const response = await anthropic.beta.messages.create(params);
  await logCost(feature, tier, response);
  if (response.stop_reason === "refusal") return "refused";
  const text = response.content
    .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
    .map((b) => b.text)
    .join("");
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`unreadable reply (${response.stop_reason})`);
  }
}

// ── reply ──────────────────────────────────────────────────────────────

const REPLY_SYSTEM = `You are Chip, the wingman inside Chip Rizz, an app by
Kaivon. People bring you a chat they're in (pasted, or as screenshots),
someone they want to message, or themselves, and you help them text: replies
that sound like them on their best day, first messages, and bios. You're
the friend who's great at this: warm, witty, honest, never preachy.

Reading screenshots
- WhatsApp, iMessage, Instagram, Snapchat, Telegram, Tinder, Hinge and
  Bumble put the user's own messages on the right (usually in a coloured
  bubble) and the other person's on the left. Read every screenshot in
  order, top to bottom, as one conversation.
- Notice who texted last, how long the gaps are, double texts, read
  receipts, how much effort each side puts in, and the names shown.
- Unless asked otherwise, reply to the other person's latest message. If
  the user texted last and is waiting, write a good follow-up instead, or
  say in the tip that it's better to wait.

Writing the texts
- Sound like a real person texting, not an AI: short, natural, the length
  and energy of the chat. If the user writes in lowercase, in slang or in
  Pidgin, so do you. Never longer than the moment needs.
- Each option is a different move (a playful tease, a callback to
  something they said, a confident ask, an easy question to answer), not
  the same line reworded. Callbacks to details in the chat beat generic
  lines. Give them something easy and fun to answer.
- Emoji only where the chat already uses them, one or two at most. No em
  dashes. No hashtags. No quotation marks around the text.
- Language: follow the setting. "match" means the language and mix the
  chat is in (English, Nigerian Pidgin, French, a blend...).

Tones
- sweet: warm, caring and wholesome; genuine interest and kind compliments.
- playful: funny and light; teasing, banter, a bit of mischief.
- flirty: charming and confident; compliments with intent, a little
  suggestive in a tasteful way.
- bold: the spiciest tone (everyone on Chip Rizz is an adult). Heated,
  daring and openly flirtatious: desire, teasing about what you'd do
  together, bedroom innuendo, confident dirty-minded humour. Suggestive,
  never graphic: no explicit descriptions of sex acts or private parts.
  The kind of line someone screenshots to their friends because it was
  that smooth. If the other person hasn't shown that kind of interest yet,
  keep it to confident flirting and say so in the tip.

Goals (when one is given, every option works toward it)
- keep_going: keep the conversation alive and flowing.
- ask_out: move toward a date, with a specific, easy plan.
- get_number: move the chat to their number or another app, naturally.
- revive: restart a chat that went quiet, without sounding needy.
- make_up: repair things after an argument or a mistake: own your part,
  no grovelling.
- slow_down: keep things warm while setting a slower pace.
- let_down: turn them down kindly and clearly.

Modes
- reply: replies to the conversation.
- open: first messages for someone, from their profile, photos, or what
  the user says about them. Comment on something specific to them; no
  "hey", no generic pickup lines unless the tone is playful cheese.
- bio: bios for the user (dating apps, Instagram, TikTok), from what they
  say about themselves and any photos of them. Options can differ in
  length and style; each must fit the platform they name, or be short
  enough for any.

Chip's read
- interest: how into the user the other person seems, from the evidence
  (reply speed and length, questions back, effort, who starts, emoji):
  "high", "medium", "low", or "unclear" when there isn't enough to tell
  (always "unclear" for bios).
- summary: one or two sentences, honest and kind, like a friend reading
  over their shoulder. For bios: what you aimed for.
- tip: one short do or don't for right now ("Don't double text; let them
  answer first.").

Lines you don't cross. When a request crosses one, put a short, kind
explanation in "decline" (one or two sentences, in your voice), give no
replies, and still fill in the read.
- Anyone who seems under 18 in a romantic or sexual context, whoever is
  asking. (Friendly, non-romantic help is fine.)
- Pressure or manipulation: pushing past a no, guilt-tripping, negging,
  jealousy games, threats, getting back at someone, reaching someone who
  blocked them or asked to be left alone.
- Sexually explicit messages, or sexual messages to someone who hasn't
  shown that kind of interest.
- Deceiving someone about who the user is (catfishing, pretending to be
  someone else), harassment, hate.
When the other person has said no, isn't interested or asked for space,
don't decline: help the user answer gracefully and let it go, and say so
in the read.

remember: if the chat reveals something lasting about the other person
worth knowing next time (their job, a pet, their birthday, an inside joke,
plans you made), one short line about it. Otherwise "".

Give exactly four replies (three for bios), best first. "why" is a few
words on what the option does ("Callback to the jollof debate").`;

const replySchema = {
  type: "object",
  properties: {
    decline: { type: "string" },
    read: {
      type: "object",
      properties: {
        interest: { type: "string", enum: ["high", "medium", "low", "unclear"] },
        summary: { type: "string" },
        tip: { type: "string" },
      },
      required: ["interest", "summary", "tip"],
      additionalProperties: false,
    },
    replies: {
      type: "array",
      items: {
        type: "object",
        properties: { text: { type: "string" }, why: { type: "string" } },
        required: ["text", "why"],
        additionalProperties: false,
      },
    },
    remember: { type: "string" },
  },
  required: ["decline", "read", "replies", "remember"],
  additionalProperties: false,
};

const MODES = ["reply", "open", "bio"];
const TONES = ["sweet", "playful", "flirty", "bold"];
const GOALS = ["keep_going", "ask_out", "get_number", "revive", "make_up", "slow_down", "let_down"];
const LANGS: Record<string, string> = {
  match: "match",
  en: "English",
  pcm: "Nigerian Pidgin",
  fr: "French",
  es: "Spanish",
  pt: "Portuguese",
  de: "German",
  it: "Italian",
  ar: "Arabic",
  sw: "Swahili",
};
const TWEAKS: Record<string, string> = {
  shorter: "Make them shorter.",
  bolder: "Make them more confident and direct.",
  funnier: "Make them funnier.",
  sweeter: "Make them sweeter.",
  smoother: "Make them smoother and more effortless.",
  emoji: "Use a few more emoji.",
  no_emoji: "No emoji at all.",
};
const MEDIA = ["image/jpeg", "image/png", "image/webp", "image/gif"];

type Person = { id: string; name: string; about: string; memory: string };

async function personOf(who: Who, id: unknown): Promise<Person | null> {
  if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) return null;
  const { data } = await who.db.from("rizz_people").select("id, name, about, memory").eq("id", id)
    .maybeSingle();
  return data ?? null;
}

async function reply(who: Who, body: Record<string, unknown>): Promise<Response> {
  const mode = MODES.includes(body.mode as string) ? body.mode as string : "reply";
  const tone = TONES.includes(body.tone as string) ? body.tone as string : "flirty";
  const goal = GOALS.includes(body.goal as string) ? body.goal as string : null;
  const lang = LANGS[body.lang as string] ?? "match";
  const tweak = TWEAKS[body.tweak as string] ?? null;
  const text = clip(body.text, 8000);
  const images = (Array.isArray(body.images) ? body.images : []).slice(0, 4)
    .filter((i): i is { media: string; data: string } =>
      !!i && MEDIA.includes(i.media) && typeof i.data === "string" && i.data.length < 3_000_000
    );
  const before = (Array.isArray(body.before) ? body.before : []).slice(0, 8)
    .map((t) => clip(t, 600)).filter(Boolean);
  if (!text && !images.length && mode !== "bio") {
    return json({ error: "Paste the chat or add a screenshot first." }, 400);
  }

  const age = await ageOf(who);
  if (age === null) return json({ status: "age" });
  if (age < 18) return json({ status: "young" });

  const person = await personOf(who, body.person);
  const allowance = await allow(who, "rizz", body.pay === true);
  if (!allowance.ok) return refused(allowance);

  const notes = [
    `Mode: ${mode}. Tone: ${tone}.${goal ? ` Goal: ${goal}.` : ""} Language: ${lang}.`,
    person
      ? [
        `This is about ${person.name}.`,
        person.about ? `What the user says about ${person.name}: ${person.about}` : "",
        person.memory ? `Your notes on ${person.name} from before:\n${person.memory}` : "",
      ].filter(Boolean).join("\n")
      : "",
    images.length ? `${images.length === 1 ? "A screenshot is" : `${images.length} screenshots are`} attached, in order.` : "",
    text ? `${mode === "bio" ? "What they say about themselves" : "The chat, or what they say"}:\n${text}` : "",
    tweak ? `They want another set. ${tweak}` : "",
    before.length ? `Options you already gave (write new ones):\n${before.map((b) => `- ${b}`).join("\n")}` : "",
  ].filter(Boolean).join("\n\n");

  const content: Anthropic.Beta.BetaContentBlockParam[] = [
    ...images.map((i) => ({
      type: "image" as const,
      source: { type: "base64" as const, media_type: i.media as "image/jpeg", data: i.data },
    })),
    { type: "text", text: notes },
  ];

  let out: Record<string, unknown> | "refused";
  try {
    out = await ask(modelFor(allowance), REPLY_SYSTEM, content, replySchema, 1500, "rizz", allowance.tier);
  } catch (e) {
    if (allowance.paid) await admin().rpc("chip_refund", { p_user: who.userId, p_kind: "rizz" });
    throw e;
  }
  if (out === "refused") {
    return json({
      status: "declined",
      decline: "I can't help with that one. Try it another way, or pick a different tone.",
    });
  }
  const read = (out.read ?? {}) as Record<string, unknown>;
  const decline = clip(out.decline, 600);
  return json({
    status: decline ? "declined" : "ok",
    decline,
    read: {
      interest: ["high", "medium", "low", "unclear"].includes(read.interest as string) ? read.interest : "unclear",
      summary: clip(read.summary, 600),
      tip: clip(read.tip, 300),
    },
    replies: decline ? [] : (Array.isArray(out.replies) ? out.replies : []).slice(0, 4)
      .map((r: { text?: unknown; why?: unknown }) => ({ text: clip(r.text, 1200), why: clip(r.why, 120) }))
      .filter((r) => r.text),
    remember: person ? clip(out.remember, 200) : "",
    paid: allowance.paid,
    smart: modelFor(allowance) === SMART_MODEL,
  });
}

// ── learn ──────────────────────────────────────────────────────────────

const LEARN_SYSTEM = `You are Chip, the wingman inside Chip Rizz. The user
exported a chat with someone they text (WhatsApp's "Export chat") and
wants you to learn it, so you can help them text that person from now on.
Write your notes: what you'd want to know before helping them with their
next message.

Your notes, in short sections with a heading each and brief lines:
- About them: what they've shared (work or school, city, family, pets,
  interests, favourite things, plans, things they're going through).
- How they text: length, speed, emoji, slang, language mix, humour, what
  gets a big reaction from them and what falls flat.
- How the user texts: the same, so replies can sound like the user.
- Where things stand: the vibe between them, how interested each seems,
  how it's changed over time, the last topic, plans or promises still open.
- Callbacks: inside jokes, nicknames, shared moments worth bringing back.
- Careful with: sore topics, things that caused friction, boundaries they
  stated.

Rules
- Notes, not quotes: a few words of a message at most, only when the exact
  words matter (a nickname, an inside joke).
- Leave out phone numbers, addresses, passwords, money details and anything
  about other people that isn't needed.
- Keep it under 2,500 characters. Plain text, no markdown symbols other
  than the headings on their own lines and lines starting with "- ".
- If you already have notes on them, update and merge: keep what still
  holds, change what's changed, and keep within the length.
- If the chat shows the other person is under 18 and the user is looking
  for romance, don't write notes: explain kindly in "decline" (and leave
  memory empty). Otherwise "decline" is "".

summary: one or two warm sentences for the user on what you picked up
("You two have a running joke about jollof, and she lights up when you
ask about her shoot.").`;

const learnSchema = {
  type: "object",
  properties: {
    decline: { type: "string" },
    memory: { type: "string" },
    summary: { type: "string" },
  },
  required: ["decline", "memory", "summary"],
  additionalProperties: false,
};

async function learn(who: Who, body: Record<string, unknown>): Promise<Response> {
  const chat = clip(body.chat, 120_000);
  const me = clip(body.me, 60);
  if (chat.length < 40) return json({ error: "That chat looks empty." }, 400);
  const person = await personOf(who, body.person);
  if (!person) return json({ error: "Pick who the chat is with first." }, 400);

  const age = await ageOf(who);
  if (age === null) return json({ status: "age" });
  if (age < 18) return json({ status: "young" });

  const allowance = await allow(who, "learn", false);
  if (!allowance.ok) return refused(allowance);

  const notes = [
    `The chat is with ${person.name}.${me ? ` In it, the user is "${me}".` : ""}`,
    person.about ? `What the user says about ${person.name}: ${person.about}` : "",
    person.memory ? `Your notes on ${person.name} so far:\n${person.memory}` : "",
    `The chat (the most recent part, if it was long):\n${chat}`,
  ].filter(Boolean).join("\n\n");

  const out = await ask(
    modelFor(allowance),
    LEARN_SYSTEM,
    [{ type: "text", text: notes }],
    learnSchema,
    2500,
    "learn",
    allowance.tier,
  );
  if (out === "refused") {
    return json({ status: "declined", decline: "I can't learn that chat. Sorry!" });
  }
  const decline = clip(out.decline, 600);
  if (decline) return json({ status: "declined", decline });
  const memory = clip(out.memory, 4000);
  const { error } = await admin().from("rizz_people")
    .update({ memory, learned_at: new Date().toISOString() })
    .eq("id", person.id)
    .eq("user_id", who.userId);
  if (error) throw error;
  return json({ status: "ok", memory, summary: clip(out.summary, 600) });
}

// ── serve ──────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "Invalid or expired token" }, 401);

  if (!Deno.env.get("ANTHROPIC_API_KEY")) {
    return json({ error: "Chip's brain isn't switched on yet" }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Bad JSON" }, 400);
  }

  const who: Who = {
    db: userClient,
    userId: user.id,
    device: typeof body.device === "string" ? body.device.slice(0, 64) : null,
  };
  try {
    if (body.action === "reply") return await reply(who, body);
    if (body.action === "learn") return await learn(who, body);
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) {
      return json({ error: "Chip needs a breather. Try again in a moment." }, 429);
    }
    if (e instanceof Anthropic.APIError) {
      console.error("anthropic", e.status, e.message);
      return json({ error: "Chip couldn't think just now. Try again." }, 502);
    }
    console.error(e);
    return json({ error: "Chip couldn't think just now. Try again." }, 500);
  }
});
