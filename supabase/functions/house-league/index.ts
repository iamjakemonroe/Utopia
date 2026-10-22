// The house league: games between Utopia's house players, played on the
// server (supabase/migrations/20261022110000_house_league.sql).
//
// pg_cron calls this four times every 15 seconds. Each call may start a
// game (house_league_start decides, at a person's pace), then plays one
// league move that's due (house_league_claim hands each due move to one
// call only): worked out by the app's own engines (../house-move/brain.js)
// at the side to move's strength, played through the same functions as
// anyone's, the next one due after the time a person might think. A game
// the engine sees is over is settled and rated like any game.
//
// It takes no key (verify_jwt is off): all it can do is play the league's
// moves when they're due, so calling it more often changes nothing.
import { createClient } from "jsr:@supabase/supabase-js@2";
import "../house-move/brain.js";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
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
type Due = {
  match: string;
  game: string;
  position: string;
  ply: number;
  rating: number;
  ms_left: number;
};

// deno-lint-ignore no-explicit-any
const brain = (globalThis as any).utopiaHouseTurn as (ask: string) => string;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  await admin.rpc("house_league_tidy");
  const { data: started } = await admin.rpc("house_league_start");

  const { data: due, error } = await admin.rpc("house_league_claim");
  if (error) return json({ error: error.message }, 500);
  if (!due) return json({ ok: true, started });
  const game = due as Due;

  let turn: Turn;
  try {
    turn = JSON.parse(brain(JSON.stringify({
      game: game.game,
      position: game.position,
      rating: Number(game.rating),
      ms_left: Number(game.ms_left),
      ply: Number(game.ply),
      seed: Math.floor(Math.random() * 2 ** 30),
    })));
  } catch (e) {
    console.error("house league brain", e);
    return json({ error: "Couldn't think" }, 500);
  }

  const over = (o: Over) =>
    admin.rpc("house_league_over", {
      p_match: game.match,
      p_winner: o.winner,
      p_result: o.result,
    });

  if (turn.over) {
    await over(turn.over);
    return json({ ok: true, started, ended: game.match });
  }
  const move = turn.move!;
  const { data: played, error: failed } = await admin.rpc("house_league_play", {
    p_match: game.match,
    p_ply: Number(game.ply),
    p_from: move.from,
    p_to: move.to,
    p_promotion: move.promotion,
    p_san: move.san,
    p_fen_after: move.fen_after,
    p_think_ms: Math.round(Number(turn.think_ms ?? 4000)),
  });
  if (failed) console.error("house league move", failed.message);
  if (played && turn.over_after) await over(turn.over_after);
  return json({ ok: true, started, moved: game.match });
});
