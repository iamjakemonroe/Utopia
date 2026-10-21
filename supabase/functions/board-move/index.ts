// A player's move in an online chess or checkers game, checked by the
// server: { match_id, from, to, promotion?, notation? }.
//
// The move is worked out with the apps' own rules (the referee in
// brain.js, built by tool/build_house_brain.sh from
// lib/features/house/domain/board_referee.dart) on the board the server
// holds, not the one the app says it has, and saved with board_play_move:
// the clocks as for any move, and the game settled if the move ended it.
//
// Answers { ok: true, ply, over? }, or { error } with 409 (not your turn,
// out of sync, or the clock ran out) or 422 (a move the rules don't
// allow).
import { createClient } from "jsr:@supabase/supabase-js@2";
import "../house-move/brain.js";

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

type Ruling = {
  legal: boolean;
  san?: string;
  fen_after?: string;
  over?: { winner: "white" | "black" | null; result: string } | null;
};

// deno-lint-ignore no-explicit-any
const referee = (globalThis as any).utopiaReferee as (ask: string) => string;

const square = /^([a-h][1-8]|[1-9]|[12][0-9]|3[0-2])$/;

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
  const from = String(body.from ?? "");
  const to = String(body.to ?? "");
  const promotion = body.promotion == null ? null : String(body.promotion);
  const notation = body.notation == null
    ? null
    : String(body.notation).slice(0, 80);
  if (!/^[0-9a-f-]{36}$/.test(matchId)) {
    return json({ error: "Bad match" }, 400);
  }
  if (!square.test(from) || !square.test(to)) {
    return json({ error: "Bad move" }, 400);
  }
  if (promotion != null && !/^[qrbnk]$/.test(promotion)) {
    return json({ error: "Bad move" }, 400);
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: match, error } = await admin
    .from("matches")
    .select("game, status, board_fen, ply_count, player_white, player_black")
    .eq("id", matchId)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!match) return json({ error: "match not found" }, 404);
  if (match.status !== "active") {
    return json({ error: "match is not active" }, 409);
  }
  const mover = match.ply_count % 2 === 0
    ? match.player_white
    : match.player_black;
  if (user.id !== match.player_white && user.id !== match.player_black) {
    return json({ error: "not a player in this match" }, 403);
  }
  if (user.id !== mover) return json({ error: "not your turn" }, 409);

  let ruling: Ruling;
  try {
    ruling = JSON.parse(referee(JSON.stringify({
      game: match.game,
      position: match.board_fen,
      from,
      to,
      promotion,
      notation,
    })));
  } catch (e) {
    console.error("referee", e);
    return json({ error: "Couldn't check the move" }, 500);
  }
  if (!ruling.legal) return json({ error: "illegal move" }, 422);

  const { data: played, error: failed } = await admin.rpc("board_play_move", {
    p_match: matchId,
    p_mover: user.id,
    p_ply: match.ply_count,
    p_from: from,
    p_to: to,
    p_promotion: promotion,
    p_san: ruling.san,
    p_fen_after: ruling.fen_after,
    p_winner: ruling.over?.winner ?? null,
    p_result: ruling.over?.result ?? null,
  });
  if (failed) {
    const message = failed.message ?? "";
    const conflict = /out of sync|not your turn|not active/.test(message);
    return json({ error: message }, conflict ? 409 : 500);
  }
  if (!played) return json({ error: "out of time" }, 409);
  return json({
    ok: true,
    ply: match.ply_count + 1,
    over: ruling.over ?? null,
  });
});
