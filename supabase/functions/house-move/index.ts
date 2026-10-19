// A house player's turn in an online chess or checkers game.
//
// The player's app calls this (as the player) while it's the house
// player's turn: { match_id }. One call at a time thinks about each move
// (house_claim_turn); the rest answer straight away. The move comes from
// the app's own engines (brain.js, built by tool/build_house_brain.sh), at
// the house player's strength, and is played after the time a person
// might take over it, through the same functions as anyone's move. A game
// that's over (after their move, or the player's) is reported as the
// house player sees it, the same way players' apps report.
//
// Answers { ok, thinking?: ms } quickly; the move follows in the
// background.
import { createClient } from "jsr:@supabase/supabase-js@2";
import "./brain.js";

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

type Over = { winner: "white" | "black" | null; result: string };
type Turn = {
  over?: Over;
  over_after?: Over;
  think_ms?: number;
  move?: {
    from: string;
    to: string;
    promotion: string | null;
    san: string;
    fen_after: string;
  };
};

// deno-lint-ignore no-explicit-any
const brain = (globalThis as any).utopiaHouseTurn as (ask: string) => string;

/** Keeps [job] running after the answer goes back. */
function inBackground(job: Promise<void>): void {
  // deno-lint-ignore no-explicit-any
  const runtime = (globalThis as any).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(job);
}

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
  const matchId = String(body.match_id ?? "");
  if (!/^[0-9a-f-]{36}$/.test(matchId)) return json({ error: "Bad match" }, 400);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: state, error } = await admin.rpc("house_turn_state", {
    p_match: matchId,
    p_user: user.id,
  });
  if (error) return json({ error: error.message }, 500);
  // Not a house game of theirs, or not the house player's turn: nothing to do.
  if (!state || state.status !== "active" || !state.house_to_move) {
    return json({ ok: true });
  }

  const ply = Number(state.ply);
  const { data: claimed } = await admin.rpc("house_claim_turn", {
    p_match: matchId,
    p_ply: ply,
  });
  if (!claimed) return json({ ok: true, thinking: true });

  let turn: Turn;
  try {
    turn = JSON.parse(brain(JSON.stringify({
      game: state.game,
      position: state.position,
      rating: Number(state.rating),
      ms_left: Number(state.ms_left),
      ply,
      seed: Math.floor(Math.random() * 2 ** 30),
    })));
  } catch (e) {
    console.error("house brain", e);
    return json({ error: "Couldn't think" }, 500);
  }

  const report = (over: Over) =>
    admin.rpc("house_report_result", {
      p_match: matchId,
      p_winner: over.winner,
      p_result: over.result,
    });

  if (turn.over) {
    await report(turn.over);
    return json({ ok: true });
  }
  const move = turn.move!;
  const wait = Math.max(0, Number(turn.think_ms ?? 1500));
  inBackground((async () => {
    await new Promise((resolve) => setTimeout(resolve, wait));
    const { data: played, error: failed } = await admin.rpc("house_play_move", {
      p_match: matchId,
      p_ply: ply,
      p_from: move.from,
      p_to: move.to,
      p_promotion: move.promotion,
      p_san: move.san,
      p_fen_after: move.fen_after,
    });
    if (failed) console.error("house move", failed.message);
    if (played && turn.over_after) await report(turn.over_after);
  })());
  return json({ ok: true, thinking: wait });
});
