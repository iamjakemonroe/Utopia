// The pool coin tables, where a player plays Chip for coins: { action, ... }.
//
//   start { table }                          a new game, its entry paid
//         -> { game }
//   shot  { game, shots, shot, place?, called? }    the player's shot
//         -> { state, shots, status, prize, over }
//   chip  { game, shots }                     Chip's turn
//         -> { move, state, shots, status, prize, over }
//
// Every shot is played by the referee (referee.js, built by
// tool/build_pool_referee.sh from the apps' own physics, rules and Chip) on
// the table the server holds, with the cues the game began with, then saved
// with pool_record, which pays the winner. The app plays the same shot out
// with the same physics to show it, and it lands the same; what's saved
// here is what happened. `shots` is how many shots the app has seen: a
// shot sent for an older table is refused (409) and the app catches up.
import { createClient } from "jsr:@supabase/supabase-js@2";
import "./referee.js";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type Over = { winner: number; win: string } | null;
type Ruling = {
  legal: boolean;
  reason?: string;
  state?: unknown;
  over?: Over;
  move?: { shot: unknown; place: unknown; called: number | null };
};

// deno-lint-ignore no-explicit-any
const referee = (globalThis as any).utopiaPool as (ask: string) => string;

function rule(ask: Record<string, unknown>): Ruling {
  return JSON.parse(referee(JSON.stringify(ask)));
}

/** A fresh random seed (for the rack, and Chip's hand). */
function seed(): number {
  return crypto.getRandomValues(new Uint32Array(1))[0] & 0x3fffffff;
}

const uuid = /^[0-9a-f-]{36}$/;

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
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  if (body.action === "start") {
    const table = String(body.table ?? "");
    if (!/^[a-z]{1,20}$/.test(table)) return json({ error: "Bad table" }, 400);
    const rack = rule({ do: "rack", seed: seed() });
    const { data: id, error } = await admin.rpc("pool_open", {
      p_user: user.id,
      p_table: table,
      p_state: rack.state,
    });
    if (error) {
      const message = error.message ?? "";
      const known = /insufficient balance|unknown table/.test(message);
      return json({ error: message }, known ? 409 : 500);
    }
    const { data: game, error: failed } = await admin
      .from("pool_games")
      .select("*")
      .eq("id", id)
      .single();
    if (failed) return json({ error: failed.message }, 500);
    return json({ game });
  }

  if (body.action !== "shot" && body.action !== "chip") {
    return json({ error: "Unknown action" }, 400);
  }
  const gameId = String(body.game ?? "");
  const shots = Number(body.shots);
  if (!uuid.test(gameId) || !Number.isInteger(shots) || shots < 0) {
    return json({ error: "Bad game" }, 400);
  }
  const { data: game, error } = await admin
    .from("pool_games")
    .select(
      "user_id, status, shots, state, cue_id, cue_level, bot, bot_cue, bot_cue_level",
    )
    .eq("id", gameId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!game || game.user_id !== user.id) {
    return json({ error: "game not found" }, 404);
  }
  if (game.status !== "active") return json({ error: "game is over" }, 409);
  if (game.shots !== shots) return json({ error: "out of sync" }, 409);

  let ruling: Ruling;
  let play: Record<string, unknown>;
  try {
    if (body.action === "shot") {
      ruling = rule({
        do: "shot",
        state: game.state,
        shot: body.shot,
        place: body.place ?? null,
        called: body.called ?? null,
        cue: game.cue_id,
        level: game.cue_level,
      });
      play = {
        by: "you",
        shot: body.shot,
        place: body.place ?? null,
        called: body.called ?? null,
      };
    } else {
      ruling = rule({
        do: "chip",
        state: game.state,
        bot: game.bot,
        seed: seed(),
        cue: game.bot_cue,
        level: game.bot_cue_level,
      });
      play = { by: "chip", ...ruling.move };
    }
  } catch (e) {
    console.error("referee", e);
    return json({ error: "Couldn't play the shot" }, 500);
  }
  if (!ruling.legal) {
    return json(
      { error: ruling.reason ?? "illegal shot" },
      body.action === "chip" ? 409 : 422,
    );
  }

  const { data: saved, error: failed } = await admin.rpc("pool_record", {
    p_game: gameId,
    p_shots: shots,
    p_state: ruling.state,
    p_play: play,
    p_winner: ruling.over?.winner ?? null,
    p_win: ruling.over?.win ?? null,
  });
  if (failed) {
    const message = failed.message ?? "";
    const conflict = /out of sync|game is over/.test(message);
    return json({ error: message }, conflict ? 409 : 500);
  }
  return json({
    ...(body.action === "chip" ? { move: ruling.move } : {}),
    state: ruling.state,
    over: ruling.over ?? null,
    ...saved,
  });
});
