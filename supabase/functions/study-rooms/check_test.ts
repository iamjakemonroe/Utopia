// deno test supabase/functions/study-rooms/check_test.ts
import { assert, assertEquals } from "jsr:@std/assert@1";
import { checkSave, same } from "./check.ts";

const id = "6b29b222-febd-4a33-b399-6e1951fc3898";

Deno.test("the secret check", () => {
  assert(same("a".repeat(40), "a".repeat(40)));
  assert(!same("a".repeat(40), "a".repeat(39) + "b"));
  assert(!same("a".repeat(40), "a".repeat(41)));
  assert(!same("", "a"));
});

Deno.test("a save's shape", () => {
  assertEquals(checkSave({ documents: [{ id, kind: "doc" }], notes: [{ id }], tasks: [] }), null);
  assertEquals(checkSave({}), null);
  assertEquals(checkSave({ documents: [{ id, kind: "video" }] }), "documents need a kind");
  assertEquals(checkSave({ notes: [{ id: "x" }] }), "notes need ids");
  assertEquals(checkSave({ tasks: "all" }), "tasks must be a list");
  assertEquals(checkSave({ documents: Array.from({ length: 501 }, () => ({ id, kind: "doc" })) }), "documents must be a list");
});
