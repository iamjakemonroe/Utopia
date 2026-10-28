// Chip Study's brain (study.kaivon.app): Chip as a study partner, answered
// by Claude. Two jobs:
//
//   chat  - a message to Chip about one assignment, in one of six modes
//           (explain, plan, write, check, cite, quiz), streamed back as
//           server-sent events. Chip sees the brief, rubric, due date,
//           sources and readings, the conversation so far, and the
//           student's document and selection as they are now. Both sides
//           of the conversation are saved, and every answer goes in the
//           assignment's AI-use record.
//   setup - reads an assignment sheet (the text the app took out of a PDF
//           or Word file, or the file itself when it's a scan or a photo)
//           and answers its title, course, due date, word target, brief,
//           rubric and a first few tasks, as JSON.
//
// The Anthropic key lives only here (ANTHROPIC_API_KEY). Every call is held
// against the student's allowance first (study_allow: dollars of model
// time, by tier) and settled with what it really cost after (study_spend).
// Free accounts get Chip Fast; Chip Study Pro members get Chip's best model
// (and web research in cite mode) until its day or period is used.
//
// Events, each `data: {json}`:
//   {t: "start", thread, message, model, note}  the student's message is saved
//   {t: "think", text}                          a line of Chip's thinking
//   {t: "search"}                               Chip is searching the web
//   {t: "text", text}                           more of Chip's answer
//   {t: "done", message, model, cut}            Chip's answer is saved
//   {t: "refusal"}                              Chip won't answer this one
//   {t: "error", error}
// Before streaming starts, a refusal of the allowance is plain JSON with a
// 429: {error, why, resets_at, max_mb} (why: limit, busy, size, uploads)
// or a 403 {why: "account"} for a guest.

import Anthropic from "npm:@anthropic-ai/sdk@0.135.0";
import { createClient } from "jsr:@supabase/supabase-js@2";

const BEST_MODEL = Deno.env.get("STUDY_BEST_MODEL") ?? "claude-opus-5-5";
const FAST_MODEL = Deno.env.get("STUDY_FAST_MODEL") ?? "claude-haiku-5-5";

const anthropic = new Anthropic();

type Kind = "best" | "fast";
type Mode = "explain" | "plan" | "write" | "check" | "cite" | "quiz";
const MODES: Mode[] = ["explain", "plan", "write", "check", "cite", "quiz"];

/** How long each mode's answers can run, and how hard the best model
 * thinks for them. */
const SHAPES: Record<Mode, { maxTokens: number; effort: "low" | "medium" }> = {
  explain: { maxTokens: 8000, effort: "low" },
  plan: { maxTokens: 10000, effort: "medium" },
  write: { maxTokens: 12000, effort: "medium" },
  check: { maxTokens: 12000, effort: "medium" },
  cite: { maxTokens: 10000, effort: "medium" },
  quiz: { maxTokens: 8000, effort: "low" },
};

/** How much of the student's work Chip reads, by model: the document, the
 * readings together, and the conversation so far (characters). */
const READS: Record<Kind, { doc: number; readings: number; history: number }> = {
  fast: { doc: 16000, readings: 20000, history: 16000 },
  best: { doc: 60000, readings: 80000, history: 40000 },
};

/** Refusal fallback: if a safety classifier declines, the API retries on
 * Anthropic's recommended fallback model inside the same call. Haiku has
 * none, so it goes without. */
// deno-lint-ignore no-explicit-any
function withFallback(params: any): any {
  if (String(params.model).startsWith("claude-haiku")) return params;
  return { ...params, betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" };
}

/** Dollars per million tokens: input, output, cache read, cache write.
 * (Haiku's cache prices are estimates: a tenth and 1.25 times its input.) */
const PRICES: [string, [number, number, number, number]][] = [
  ["claude-opus-5-5", [4, 20, 0.2, 5]],
  ["claude-sonnet-5-5", [2, 10, 0.2, 2.5]],
  ["claude-haiku-5-5", [0.1, 0.5, 0.01, 0.125]],
];
const SEARCH_USD = 0.01;

type Usage = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  searches: number;
};

/** What [u] cost on [model]. A model not in the list (a fallback) is
 * priced as the most expensive, to be safe. */
function priceOf(model: string, u: Usage): number {
  const [inUsd, outUsd, readUsd, writeUsd] = PRICES.find(([id]) => model.startsWith(id))?.[1] ??
    PRICES[0][1];
  return (u.input * inUsd + u.output * outUsd + u.cacheRead * readUsd + u.cacheWrite * writeUsd) /
      1e6 + u.searches * SEARCH_USD;
}

function usageOf(m: Anthropic.Beta.BetaMessage): Usage {
  const u = m.usage;
  return {
    input: u.input_tokens ?? 0,
    output: u.output_tokens ?? 0,
    cacheRead: u.cache_read_input_tokens ?? 0,
    cacheWrite: u.cache_creation_input_tokens ?? 0,
    searches: u.server_tool_use?.web_search_requests ?? 0,
  };
}

function add(a: Usage, b: Usage): Usage {
  return {
    input: a.input + b.input,
    output: a.output + b.output,
    cacheRead: a.cacheRead + b.cacheRead,
    cacheWrite: a.cacheWrite + b.cacheWrite,
    searches: a.searches + b.searches,
  };
}

const NO_USAGE: Usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, searches: 0 };

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
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
}

function clip(value: unknown, max: number): string {
  const s = typeof value === "string" ? value.trim() : "";
  return s.length > max ? s.slice(0, max) : s;
}

/** The end of [s] when it's longer than [max] (a long document's latest
 * part is the most useful), marked as cut. */
function tail(s: string, max: number): string {
  return s.length > max ? `[…the first ${s.length - max} characters are left out…]\n${s.slice(-max)}` : s;
}

// deno-lint-ignore no-explicit-any
type Db = any;
type Who = { db: Db; userId: string };

type Allowance =
  | { ok: true; model: Kind; day: string; hold: number; note: string | null; tier: string }
  | { ok: false; why: string; resetsAt: string | null; maxMb: number | null; tier: string };

/** Takes one call's hold from [who]'s allowance (study_allow). */
async function allow(who: Who, want: Kind, kind: "ask" | "upload", bytes = 0): Promise<Allowance> {
  const { data, error } = await who.db.rpc("study_allow", { p_model: want, p_kind: kind, p_bytes: bytes });
  if (error) throw error;
  const d = (data ?? {}) as Record<string, unknown>;
  const tier = String(d.tier ?? "free");
  if (d.ok === true) {
    return {
      ok: true,
      model: d.model === "best" ? "best" : "fast",
      day: String(d.day),
      hold: Number(d.hold ?? 0),
      note: typeof d.note === "string" ? d.note : null,
      tier,
    };
  }
  return {
    ok: false,
    why: String(d.why ?? "limit"),
    resetsAt: typeof d.resets_at === "string" ? d.resets_at : null,
    maxMb: typeof d.max_mb === "number" ? d.max_mb : null,
    tier,
  };
}

function refused(a: Extract<Allowance, { ok: false }>): Response {
  const error = {
    account: "Save your Kaivon account to use Chip Study.",
    limit: "That's today's Chip time. It's back tomorrow.",
    busy: "Chip is very busy today. Try again tomorrow, or go Pro.",
    size: `That file's too big (up to ${a.maxMb ?? 4} MB).`,
    uploads: "That's today's files for Chip to read.",
  }[a.why] ?? "Chip can't take that just now.";
  return json({ error, why: a.why, resets_at: a.resetsAt, max_mb: a.maxMb, tier: a.tier }, a.why === "account" ? 403 : 429);
}

/** Settles a call's hold with what it cost, and adds it to the day's log.
 * Never throws: the answer matters more than the bookkeeping. */
async function spend(
  who: Who,
  a: Extract<Allowance, { ok: true }>,
  feature: string,
  model: string,
  u: Usage,
): Promise<void> {
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
      p_searches: u.searches,
      p_usd: Number(priceOf(model, u).toFixed(5)),
    });
    if (error) console.error("study_spend", error);
  } catch (e) {
    console.error("study_spend", e);
  }
}

// ── What Chip is ───────────────────────────────────────────────────────

const STUDY_SYSTEM = `You are Chip, the study partner inside Chip Study, made by Kaivon. You help one student with one assignment: you tutor, plan, check and write with them. You're warm, calm and clear, like a brilliant tutor who's on their side. You never leave them knowing less than when they asked.

What you see: the assignment (its brief, rubric, due date, word target, sources and any readings the student added), your conversation so far, and with each message the mode they picked, today's date, their document as it is now, and any text they've selected in it.

How you work
- Teach before you tell. When they're stuck, find out what they already think, then build from there. Short explanations, concrete examples, one idea at a time.
- Ground everything in their brief and rubric. Say which part of the rubric something serves.
- Their voice matters. When you write with them, keep their style and level; suggest, don't take over. Encourage them to rewrite your words in their own.
- Be honest about what you don't know. Never invent quotes, statistics, page numbers, sources or results. If you aren't sure, say so.
- Respect their course's rules. If the brief or rubric says AI may not write for them, don't draft text for submission: explain, plan and give feedback instead, and say why in one line.
- Don't do a live exam or test for them. If it looks like they're sitting one now, gently decline.
- Write in the language the student writes to you in (and drafts in the assignment's language).
- Keep it calm and readable: short paragraphs, a few bullet points where they help, headings only for long answers. Use Markdown. Math in LaTeX: $x^2$ inline, $$\\int_0^1 x\\,dx$$ on its own line. Code in fenced blocks with the language.
- Everything you give them, and anything they put into their document from you, goes in their AI-use record, which they can export as a declaration. You don't need to mention it unless they ask.

Modes (follow the one the student picked):
- explain: help them understand. Socratic when they're working something out: a question back, a hint, then the explanation. If they ask you to check their understanding, end with a quiz block of 3 questions.
- plan: an outline for the work (sections, what each must do for the rubric, rough word counts that add up to the target), then a schedule from today to the due date, as a tasks block. Leave a buffer before the deadline.
- write: draft or improve text with them. If they selected text, work on that selection (rewrite, tighten, extend, fix) and keep its meaning. Put the text meant for their document in one draft block; say anything else briefly outside it. Match their document's style, level and citation style.
- check: mark their document against the rubric, criterion by criterion, as a rubric block, then the two or three changes that would raise the mark most. Be specific (quote short phrases) and kind, not vague.
- cite: help with sources and referencing in their style (APA 7th or Harvard). When you can search the web, find real, reputable sources and give them as a sources block with their links. When you can't, say so in one line, format what they give you, and suggest where and what to search; anything you name from memory is marked "verified": false.
- quiz: test what they know about the assignment's topic or their readings: a quiz block (multiple choice) by default, or a cards block if they ask for flashcards.

Blocks: the app turns these fenced blocks into cards. Write valid JSON exactly in these shapes, with nothing after the closing fence of the block:

\`\`\`tasks
[{"title": "Read chapters 2 and 3", "due": "2026-11-02"}]
\`\`\`
(3 to 10 tasks, due dates as YYYY-MM-DD between today and the due date.)

\`\`\`quiz
{"questions": [{"q": "Question?", "options": ["A", "B", "C", "D"], "answer": 0, "why": "Why A is right."}]}
\`\`\`
(answer is the index of the correct option.)

\`\`\`cards
[{"front": "Term or question", "back": "Definition or answer"}]
\`\`\`

\`\`\`rubric
{"criteria": [{"name": "Argument", "band": "Good", "score": 7, "out_of": 10, "feedback": "What works and what doesn't.", "next": "The one change that would help most."}], "overall": "One or two sentences."}
\`\`\`
(Use the rubric's own criteria, bands and scale; score and out_of may be null if it has no numbers.)

\`\`\`sources
[{"kind": "article", "authors": ["Surname, A. B."], "year": "2021", "title": "Title", "container": "Journal or website", "publisher": "", "volume": "", "issue": "", "pages": "", "doi": "", "url": "https://...", "verified": true}]
\`\`\`
(kind is one of book, chapter, article, web, report, video, other. "verified" is true only for a source you found in this turn's web search.)

The draft block is Markdown, not JSON:

\`\`\`draft
The text for their document.
\`\`\``;

/** The assignment, its sources and readings, for the start of every call. */
async function assignmentContext(
  db: Db,
  assignmentId: string,
  reads: { readings: number },
): Promise<{ text: string; title: string } | null> {
  const { data: a } = await db
    .from("study_assignments")
    .select("id, title, course, brief, rubric, due_at, word_target, style")
    .eq("id", assignmentId)
    .maybeSingle();
  if (!a) return null;
  const { data: sources } = await db
    .from("study_sources")
    .select("kind, data, note, content, file_name")
    .eq("assignment_id", assignmentId)
    .order("created_at");
  const lines: string[] = [];
  lines.push(`<assignment>`);
  lines.push(`Title: ${a.title}`);
  if (a.course) lines.push(`Course: ${a.course}`);
  if (a.due_at) lines.push(`Due: ${a.due_at}`);
  if (a.word_target) lines.push(`Word target: ${a.word_target}`);
  lines.push(`Citation style: ${a.style === "harvard" ? "Harvard" : "APA 7th"}`);
  lines.push(`\n<brief>\n${a.brief || "(none given yet)"}\n</brief>`);
  lines.push(`\n<rubric>\n${a.rubric || "(none given yet)"}\n</rubric>`);
  // deno-lint-ignore no-explicit-any
  const list = (sources ?? []) as any[];
  if (list.length > 0) {
    lines.push(`\n<sources>`);
    for (const s of list) {
      const d = s.data ?? {};
      const authors = Array.isArray(d.authors) ? d.authors.join("; ") : "";
      lines.push(
        `- [${s.kind}] ${[authors, d.year && `(${d.year})`, d.title, d.container, d.url].filter(Boolean).join(" ")}${
          s.note ? ` — note: ${clip(s.note, 400)}` : ""
        }`,
      );
    }
    lines.push(`</sources>`);
    let room = reads.readings;
    const readings = list.filter((s) => s.content);
    for (const s of readings) {
      if (room <= 0) break;
      const body = String(s.content);
      const part = body.length > room ? `${body.slice(0, room)}\n[…the rest is left out…]` : body;
      room -= part.length;
      lines.push(`\n<reading title="${clip(s.data?.title || s.file_name || "Reading", 200).replace(/"/g, "'")}">\n${part}\n</reading>`);
    }
  }
  lines.push(`</assignment>`);
  return { text: lines.join("\n"), title: a.title };
}

/** The conversation so far, newest last, within [room] characters. */
async function history(
  db: Db,
  threadId: string,
  room: number,
): Promise<Anthropic.Beta.BetaMessageParam[]> {
  const { data } = await db
    .from("study_messages")
    .select("role, content, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(30);
  const out: Anthropic.Beta.BetaMessageParam[] = [];
  // deno-lint-ignore no-explicit-any
  for (const m of (data ?? []) as any[]) {
    const text = String(m.content);
    if (text.length > room) break;
    room -= text.length;
    out.unshift({ role: m.role === "chip" ? "assistant" : "user", content: text });
  }
  // A conversation starts with the student.
  while (out.length > 0 && out[0].role !== "user") out.shift();
  return out;
}

/** Web search, in the version the model takes. */
function searchTool(model: string) {
  return {
    type: model.startsWith("claude-haiku") ? "web_search_20250305" : "web_search_20260209",
    name: "web_search",
    max_uses: 3,
  };
}

const ACTION_SUMMARY: Record<Mode, string> = {
  explain: "Asked Chip to explain",
  plan: "Asked Chip to plan",
  write: "Asked Chip to write or improve text",
  check: "Asked Chip to check the work against the rubric",
  cite: "Asked Chip for help with sources and referencing",
  quiz: "Asked Chip to quiz them",
};

// ── chat ───────────────────────────────────────────────────────────────

async function chat(who: Who, body: Record<string, unknown>, signal: AbortSignal): Promise<Response> {
  const mode = MODES.includes(body.mode as Mode) ? body.mode as Mode : "explain";
  const text = clip(body.text, 8000);
  const assignmentId = clip(body.assignment, 64);
  if (!text) return json({ error: "Say something to Chip" }, 400);
  if (!/^[0-9a-f-]{36}$/.test(assignmentId)) return json({ error: "Which assignment?" }, 400);

  const want: Kind = body.model === "best" ? "best" : "fast";
  // The assignment is checked before anything is spent.
  const probe = await who.db.from("study_assignments").select("id").eq("id", assignmentId).maybeSingle();
  if (!probe.data) return json({ error: "That assignment isn't yours" }, 404);

  let threadId = typeof body.thread === "string" ? body.thread : null;
  if (threadId) {
    const { data: t } = await who.db
      .from("study_threads")
      .select("id")
      .eq("id", threadId)
      .eq("assignment_id", assignmentId)
      .maybeSingle();
    if (!t) threadId = null;
  }

  const allowance = await allow(who, want, "ask");
  if (!allowance.ok) return refused(allowance);
  const kind = allowance.model;
  const reads = READS[kind];
  const model = kind === "best" ? BEST_MODEL : FAST_MODEL;

  const context = await assignmentContext(who.db, assignmentId, reads);
  if (!context) return json({ error: "That assignment isn't yours" }, 404);
  const past = threadId ? await history(who.db, threadId, reads.history) : [];

  const service = admin();
  if (!threadId) {
    const { data: t, error } = await service
      .from("study_threads")
      .insert({ assignment_id: assignmentId, user_id: who.userId, title: clip(text, 80) })
      .select("id")
      .single();
    if (error) throw error;
    threadId = t.id as string;
  } else {
    await service.from("study_threads").update({ updated_at: new Date().toISOString() }).eq("id", threadId);
  }
  const selection = clip(body.selection, 6000);
  const { data: asked, error: askError } = await service
    .from("study_messages")
    .insert({
      thread_id: threadId,
      assignment_id: assignmentId,
      user_id: who.userId,
      role: "user",
      mode,
      content: text,
      meta: selection ? { selection: clip(selection, 600) } : {},
    })
    .select("id")
    .single();
  if (askError) throw askError;

  const today = /^\d{4}-\d{2}-\d{2}$/.test(String(body.today)) ? String(body.today) : new Date().toISOString().slice(0, 10);
  const doc = typeof body.doc === "string" ? tail(body.doc, reads.doc) : "";
  const searching = mode === "cite" && kind === "best";
  const now: string[] = [
    `<now>`,
    `Mode: ${mode}`,
    `Today: ${today}`,
    `Web search: ${searching ? "available" : "not available"}`,
    `</now>`,
    `<document>\n${doc || "(empty so far)"}\n</document>`,
  ];
  if (selection) now.push(`<selection>\n${selection}\n</selection>`);
  now.push(text);

  const messages: Anthropic.Beta.BetaMessageParam[] = [
    { role: "user", content: [{ type: "text", text: context.text, cache_control: { type: "ephemeral" } }] },
    ...past,
    { role: "user", content: now.join("\n") },
  ];
  // The conversation so far is cached too, up to its last answer.
  for (let i = messages.length - 2; i > 0; i--) {
    const m = messages[i];
    if (m.role === "assistant" && typeof m.content === "string") {
      messages[i] = { role: "assistant", content: [{ type: "text", text: m.content, cache_control: { type: "ephemeral" } }] };
      break;
    }
  }

  const shape = SHAPES[mode];
  const params = withFallback({
    model,
    max_tokens: shape.maxTokens,
    system: [{ type: "text", text: STUDY_SYSTEM, cache_control: { type: "ephemeral" } }],
    thinking: kind === "best" ? { type: "adaptive", display: "summarized" } : { type: "adaptive" },
    output_config: { effort: kind === "best" ? shape.effort : "low" },
    ...(searching ? { tools: [searchTool(model)] } : {}),
    messages,
  });

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
      send({ t: "start", thread: threadId, message: asked.id, model: kind, note: allowance.note });

      let answer = "";
      let used = NO_USAGE;
      let servedBy = model;
      let stop: string | null = null;
      let stopped = false;
      try {
        let request = params;
        for (let turn = 0; turn < 3; turn++) {
          const run = anthropic.beta.messages.stream(request, { signal: abort.signal });
          for await (const event of run) {
            if (event.type === "message_start") {
              servedBy = String(event.message.model ?? servedBy);
            } else if (event.type === "content_block_start") {
              const type = String(event.content_block.type);
              if (type === "server_tool_use") send({ t: "search" });
            } else if (event.type === "content_block_delta") {
              if (event.delta.type === "text_delta") {
                answer += event.delta.text;
                send({ t: "text", text: event.delta.text });
              } else if (event.delta.type === "thinking_delta" && event.delta.thinking) {
                send({ t: "think", text: event.delta.thinking });
              }
            }
          }
          const final = await run.finalMessage();
          used = add(used, usageOf(final));
          servedBy = String(final.model ?? servedBy);
          stop = final.stop_reason ?? null;
          // A long search can pause the turn: let it carry on.
          if (stop !== "pause_turn") break;
          request = { ...request, messages: [...messages, { role: "assistant", content: final.content }] };
        }
      } catch (e) {
        if (abort.signal.aborted) {
          stopped = true;
          // Stopped by the student: priced from what was written.
          used = add(used, { ...NO_USAGE, output: Math.ceil(answer.length / 3.5) });
        } else {
          console.error("chip-study chat", e);
          await spend(who, allowance, mode, servedBy, used);
          const busy = e instanceof Anthropic.RateLimitError || (e instanceof Anthropic.APIError && e.status === 529);
          send({ t: "error", error: busy ? "Chip needs a breather. Try again in a moment." : "Chip couldn't think just now." });
          open = false;
          controller.close();
          return;
        }
      }

      await spend(who, allowance, mode, servedBy, used);
      if (stop === "refusal") {
        send({ t: "refusal" });
        if (open) controller.close();
        return;
      }
      const content = answer.trim() || (stopped ? "(stopped)" : "");
      const { data: saved } = await service
        .from("study_messages")
        .insert({
          thread_id: threadId,
          assignment_id: assignmentId,
          user_id: who.userId,
          role: "chip",
          mode,
          content: content.slice(0, 120000),
          meta: {
            model: servedBy,
            kind,
            searches: used.searches,
            ...(stopped ? { stopped: true } : {}),
            ...(stop === "max_tokens" ? { cut: true } : {}),
          },
        })
        .select("id")
        .single();
      await service.from("study_ai_log").insert({
        assignment_id: assignmentId,
        user_id: who.userId,
        message_id: saved?.id ?? null,
        action: mode,
        summary: `${ACTION_SUMMARY[mode]}${selection ? " (about a selection of their text)" : ""}${
          used.searches ? `, with ${used.searches} web search${used.searches === 1 ? "" : "es"}` : ""
        }${stopped ? " (stopped early)" : ""}`,
        prompt: text.slice(0, 2000),
        output: content.slice(0, 4000),
        model: servedBy,
      });
      send({ t: "done", message: saved?.id ?? null, model: kind, cut: stop === "max_tokens" });
      if (open) {
        open = false;
        controller.close();
      }
    },
    cancel() {
      abort.abort();
    },
  });

  return new Response(stream, {
    headers: {
      ...cors,
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "X-Accel-Buffering": "no",
    },
  });
}

// ── setup ──────────────────────────────────────────────────────────────

const SETUP_SYSTEM = `You read an assignment sheet a student has been given and set the assignment up for them in Chip Study. Copy, don't invent: take the title, course, due date, word target, brief and marking rubric from the sheet. Leave a field empty (or 0) when the sheet doesn't say. Then suggest 3 to 8 tasks that would get the work done on time, spread from today to the due date (each due as YYYY-MM-DD; none when there's no due date).`;

const setupSchema = {
  type: "object",
  properties: {
    title: { type: "string" },
    course: { type: "string" },
    due: { type: "string" },
    word_target: { type: "integer" },
    brief: { type: "string" },
    rubric: { type: "string" },
    tasks: {
      type: "array",
      items: {
        type: "object",
        properties: { title: { type: "string" }, due: { type: "string" } },
        required: ["title", "due"],
        additionalProperties: false,
      },
    },
  },
  required: ["title", "course", "due", "word_target", "brief", "rubric", "tasks"],
  additionalProperties: false,
};

const FILE_TYPES = ["application/pdf", "image/png", "image/jpeg", "image/webp", "image/gif"];

async function setup(who: Who, body: Record<string, unknown>): Promise<Response> {
  const text = clip(body.text, 60000);
  const file = (body.file ?? null) as Record<string, unknown> | null;
  const media = typeof file?.media_type === "string" ? file.media_type : "";
  const data = typeof file?.data === "string" ? file.data.replace(/\s/g, "") : "";
  if (!text && !(FILE_TYPES.includes(media) && data)) return json({ error: "Nothing to read" }, 400);
  const bytes = Math.floor((data.length * 3) / 4);

  const allowance = file && data ? await allow(who, "fast", "upload", bytes) : await allow(who, "fast", "ask");
  if (!allowance.ok) return refused(allowance);

  const today = /^\d{4}-\d{2}-\d{2}$/.test(String(body.today)) ? String(body.today) : new Date().toISOString().slice(0, 10);
  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  if (data) {
    content.push(
      media === "application/pdf"
        ? { type: "document", source: { type: "base64", media_type: "application/pdf", data } }
        : {
          type: "image",
          source: { type: "base64", media_type: media as "image/png" | "image/jpeg" | "image/webp" | "image/gif", data },
        },
    );
  }
  content.push({
    type: "text",
    text: `Today: ${today}\n${
      text
        ? `The sheet's text is below. Leave "brief" empty: the app keeps the whole text as the brief. Copy the rubric (marking criteria) word for word if there is one.\n\n<sheet>\n${text}\n</sheet>`
        : `The sheet is attached. Copy its brief and its rubric (marking criteria) word for word.`
    }`,
  });

  const params = withFallback({
    model: FAST_MODEL,
    max_tokens: 16000,
    system: [{ type: "text", text: SETUP_SYSTEM }],
    output_config: { effort: "low", format: { type: "json_schema", schema: setupSchema } },
    messages: [{ role: "user", content }],
  });
  const response = await anthropic.beta.messages.stream(params).finalMessage();
  await spend(who, allowance, "setup", String(response.model ?? FAST_MODEL), usageOf(response));
  if (response.stop_reason === "refusal") return json({ error: "Chip couldn't read that one." }, 422);
  const raw = response.content
    .filter((b): b is Anthropic.Beta.BetaTextBlock => b.type === "text")
    .map((b) => b.text)
    .join("");
  let out: Record<string, unknown>;
  try {
    out = JSON.parse(raw);
  } catch {
    return json({ error: "Chip couldn't read that one." }, 422);
  }
  const date = (v: unknown) => (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : "");
  return json({
    title: clip(out.title, 200),
    course: clip(out.course, 120),
    due: date(out.due),
    word_target: Number.isInteger(out.word_target) && (out.word_target as number) > 0
      ? Math.min(out.word_target as number, 200000)
      : null,
    brief: clip(out.brief, 60000),
    rubric: clip(out.rubric, 30000),
    tasks: (Array.isArray(out.tasks) ? out.tasks : [])
      .slice(0, 10)
      // deno-lint-ignore no-explicit-any
      .map((t: any) => ({ title: clip(t?.title, 300), due: date(t?.due) }))
      .filter((t: { title: string }) => t.title),
  });
}

// ── Serving ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);
  const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
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

  const who: Who = { db: userClient, userId: user.id };
  try {
    if (body.action === "chat") return await chat(who, body, req.signal);
    if (body.action === "setup") return await setup(who, body);
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) {
      return json({ error: "Chip needs a breather. Try again in a moment." }, 429);
    }
    if (e instanceof Anthropic.APIError) {
      console.error("anthropic", e.status, e.message);
      return json({ error: "Chip couldn't think just now." }, 502);
    }
    console.error(e);
    return json({ error: "Chip couldn't think just now." }, 500);
  }
});
