"""Nicknames written any way a player likes (fancy letters, symbols, any
script, emoji), saved exactly as written; only what hides or flips text,
names you can't see and glitch text are turned away."""
import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


me = harness.new_user(db, "me@example.com")


def nick(name):
    """Saves [name]: (what was saved, or the reason it wasn't)."""
    harness.as_user(db, me)
    try:
        with db.cursor() as c:
            c.execute("select set_nickname(%s)", (name,))
            saved = c.fetchone()[0]
        harness.as_admin(db)
        with db.cursor() as c:
            c.execute("select display_name from profiles where id = %s", (me,))
            stored = c.fetchone()[0]
        return ("saved", saved, stored)
    except Exception as e:
        db.rollback() if not db.autocommit else None
        return ("refused", str(e).split("\n")[0], None)


for name in [
    "𝓙𝓪𝓴𝓮 𝓜𝓸𝓷𝓻𝓸𝓮",       # script letters (outside the basic plane)
    "ᴊᴀᴋᴇ",                 # small capitals
    "Ｊａｋｅ",               # full width
    "꧁༺ Jake ༻꧂",           # decorations
    "★彡 ʝαкє 彡★",
    "J\u0337a\u0337k\u0337e\u0337",                # one mark on each letter
    "Jóse Ñúñez",
    "李小龍",
    "محمد",
    "Jake 👑🔥",
    "👨\u200D👩\u200D👧\u200D👦 fam",             # an emoji family (joined with zero-width joiners)
    "🇳🇬 Naija",              # a flag
    "👍🏾 cool",               # a skin tone
    "x_X",
]:
    result = nick(name)
    check(f"saved as written: {name}", result == ("saved", name, name), result)

check("spaces of any kind become one", nick("  Jake\u3000\u00A0\n Monroe ")[1] == "Jake Monroe")
check("empty clears it", nick("   ")[2] is None)

for label, name, why in [
    ("a zero-width space", "Ja\u200Bke", "hidden"),
    ("a right-to-left override", "\u202EkaJ", "hidden"),
    ("a soft hyphen", "Ja\u00ADke", "hidden"),
    ("blank fillers only", "\u3164\u3164\u3164", "see"),
    ("a braille blank only", "\u2800\u2800", "see"),
    ("one character", "J", "see"),
    ("glitch text", "Ja\u0301\u0302\u0303\u0304ke", "stack"),
    ("a wall of text", "a" * 65, "24"),
]:
    result = nick(name)
    check(f"refused: {label}", result[0] == "refused" and why in result[1], result)

sys.exit(1 if fails else 0)
