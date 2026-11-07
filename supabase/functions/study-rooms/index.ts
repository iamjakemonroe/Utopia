// Chip Study rooms: the room server's door into the database. The room
// server (a Cloudflare Durable Object per room, in the chip-study repo's
// worker/) calls this with the shared ROOM_SERVER_SECRET in the
// x-room-secret header, never with a person's sign-in; people reach rooms
// through the study_room_* RPCs as themselves.
//
//   { action: "save", room_id, documents?, notes?, tasks? }: the shared
//     work, saved to the host's assignment (study_room_save). Notes and
//     tasks, when given, replace the assignment's.
//   { action: "close", room_id }: the room has ended (time up, or everyone
//     left) (study_room_close).
//   { action: "roster", room_id }: everyone in the room and what they may
//     do now (study_room_roster).
import { createClient } from "jsr:@supabase/supabase-js@2";

import { checkSave, same, UUID } from "./check.ts";

const MAX_BODY = 8_000_000;

type Row = Record<string, unknown>;

const json = (body: unknown, status = 200) => Response.json(body, { status });

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const secret = Deno.env.get("ROOM_SERVER_SECRET") ?? "";
  if (secret.length < 32 || !same(req.headers.get("x-room-secret") ?? "", secret)) {
    return json({ error: "not allowed" }, 401);
  }
  const raw = await req.text();
  if (raw.length > MAX_BODY) return json({ error: "too big" }, 413);
  let body: Row;
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "bad json" }, 400);
  }
  const room = String(body.room_id ?? "");
  if (!UUID.test(room)) return json({ error: "bad room" }, 400);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    switch (body.action) {
      case "save": {
        const bad = checkSave(body);
        if (bad) return json({ error: bad }, 400);
        const { error } = await admin.rpc("study_room_save", {
          p_room: room,
          p_documents: body.documents ?? null,
          p_notes: body.notes ?? null,
          p_tasks: body.tasks ?? null,
        });
        if (error) throw error;
        return json({ ok: true });
      }
      case "close": {
        const { error } = await admin.rpc("study_room_close", { p_room: room });
        if (error) throw error;
        return json({ ok: true });
      }
      case "roster": {
        const { data, error } = await admin.rpc("study_room_roster", { p_room: room });
        if (error) {
          if (error.message.includes("no such room")) return json({ error: "no such room" }, 404);
          throw error;
        }
        return json(data);
      }
      default:
        return json({ error: "unknown action" }, 400);
    }
  } catch (e) {
    console.error("study-rooms", body.action, room, e instanceof Error ? e.message : e);
    return json({ error: "failed" }, 500);
  }
});
