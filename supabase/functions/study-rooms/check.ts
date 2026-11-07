// Checks for the study-rooms function, kept apart so they can be tested.

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const KINDS = new Set(["doc", "code", "sheet"]);

/** Compares two strings in time that doesn't depend on where they differ. */
export function same(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

type Row = Record<string, unknown>;

/** The save's shape, or why it's wrong. */
export function checkSave(body: Row): string | null {
  const rows = (v: unknown, name: string): string | null => {
    if (v === undefined || v === null) return null;
    if (!Array.isArray(v) || v.length > 500) return `${name} must be a list`;
    for (const r of v) {
      if (!r || typeof r !== "object" || !UUID.test(String((r as Row).id))) return `${name} need ids`;
    }
    return null;
  };
  const bad = rows(body.documents, "documents") ?? rows(body.notes, "notes") ?? rows(body.tasks, "tasks");
  if (bad) return bad;
  for (const d of (body.documents as Row[] | undefined) ?? []) {
    if (!KINDS.has(String(d.kind))) return "documents need a kind";
  }
  return null;
}
