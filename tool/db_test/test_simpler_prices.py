import sys
import harness
db = harness.fresh()
fails = []
def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond: fails.append(name)
def q(sql, *a):
    with db.cursor() as c:
        c.execute(sql, a)
        try: return c.fetchall()
        except Exception: return None
def raises(sql, *a):
    try: q(sql, *a); return None
    except Exception as e: return str(e).splitlines()[0]

u = harness.new_user(db, "a@example.com")
harness.as_admin(db)
q("update profiles set balance = 1000000 where id = %s", u)
check("no pack above $99.99", q("select count(*) from coin_packs where product_id in ('utopia.coins.treasury','utopia.coins.kingdom')")[0][0] == 0)
check("the rest are still there", q("select count(*) from coin_packs")[0][0] >= 6)
check("a week's rent", q("select _world_rent_price('utopia_alien', 7)")[0][0] == 6000)
check("no 3-day rent", q("select _world_rent_price('utopia_alien', 3)")[0][0] is None)
check("no month's rent", q("select _world_rent_price('utopia_alien', 30)")[0][0] is None)
check("colors by the week", q("select _world_rent_price('ruby_dawn', 7)")[0][0] == 3000)
harness.as_user(db, u)
check("renting a week works", raises("select rent_world('utopia_alien', 7)") is None)
check("renting 3 days is refused", raises("select rent_world('utopia_tech', 3)") is not None)
check("a frame for a week", raises("select buy_aura('flame', 7)") is None)
check("a frame for a month", raises("select buy_aura('flame', 30)") is None)
check("no 3-day frames", "a week or a month" in (raises("select buy_aura('flame', 3)") or ""))
print("ALL PASSED" if not fails else f"{len(fails)} FAILED")
sys.exit(1 if fails else 0)
