// Deletes the signed-in player's account (Settings > Delete account).
//
// 1. Forgets everything personal (anonymize_account: name, username,
//    picture, friends, chats, invites, notifications...), and the
//    pictures Chip drew from their photos.
// 2. Removes their pictures and report screenshots from storage.
// 3. Deletes the sign-in itself. It's a soft delete: the email and every
//    way to sign in are gone for good, while the anonymous row stays for
//    the coin ledger and other players' finished games to point at.
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const asPlayer = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user } } = await asPlayer.auth.getUser();
  if (!user) return json({ error: "Not signed in" }, 401);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // Their voice notes' files (the messages go with anonymize_account, so
  // find them first): "voice:<match>/<note>.m4a|<length>|<waveform>".
  const voicePaths: string[] = [];
  for (
    const table of [
      "chess_chat_messages",
      "ludo_chat_messages",
      "eights_chat_messages",
      "doodle_messages",
    ]
  ) {
    const { data: notes } = await admin
      .from(table)
      .select("body")
      .eq("sender_id", user.id)
      .eq("kind", "voice");
    for (const note of notes ?? []) {
      const path = /^voice:([^|]+)\|/.exec(note.body as string)?.[1];
      if (path) voicePaths.push(path);
    }
  }
  if (voicePaths.length > 0) {
    await admin.storage.from("voice-notes").remove(voicePaths);
  }

  const { error: forgetError } = await admin.rpc("anonymize_account", {
    p_user: user.id,
  });
  if (forgetError) {
    console.error("anonymize_account", forgetError);
    return json({ error: "Couldn't delete the account" }, 500);
  }

  // Pictures Chip drew from their photos are theirs alone: gone with them.
  await admin.from("coloring_pages").delete().eq("owner", user.id);

  // Their files: profile pictures, bug-report screenshots, portrait line
  // art and their sketchbook live in a folder named after them.
  for (
    const bucket of ["avatars", "bug-screenshots", "coloring-art", "sketchbook"]
  ) {
    const { data: files } = await admin.storage.from(bucket).list(user.id, {
      limit: 1000,
    });
    const paths = (files ?? []).map((f) => `${user.id}/${f.name}`);
    if (paths.length > 0) await admin.storage.from(bucket).remove(paths);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    user.id,
    true,
  );
  if (deleteError) {
    console.error("deleteUser", deleteError);
    return json({ error: "Couldn't delete the account" }, 500);
  }
  return json({ deleted: true });
});
