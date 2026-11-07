"""Paying for an institution's seats (20261107190000_study_institution_invoices.sql):
staff issue an invoice, the institution's admin starts paying it, and a
payment Flutterwave confirms in full moves the institution to paid, once."""

import sys

import harness

db = harness.fresh()
fails = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  [{detail}]"))
    if not cond:
        fails.append(name)


def run(user, sql, *args):
    harness.as_admin(db)
    if user:
        harness.as_user(db, user)
    with db.cursor() as c:
        c.execute(sql, args)
        try:
            rows = c.fetchall()
        except Exception:
            rows = []
    db.commit()
    return rows[0][0] if rows else None


def refused(user, sql, *args):
    try:
        run(user, sql, *args)
        return None
    except Exception as e:
        db.rollback()
        return str(e).split("\n")[0]


kaivon = harness.new_user(db, "jake@kaivon.app")
run(None, "insert into public.study_staff (user_id) values (%s)", kaivon)
ada = harness.new_user(db, "ada@school.edu")
tom = harness.new_user(db, "tom@school.edu")
inst = run(ada, "select study_institution_register('North College', 'GH', 'college')")
check("no invoice before approval",
      "not approved" in (refused(kaivon, "select study_staff_invoice_create(%s, 'Term 1', 200, 4, 'USD', 1600)", inst) or ""))
run(kaivon, "select study_staff_review(%s, 'approved', 50, 90)", inst)
check("only staff issue invoices",
      "not allowed" in (refused(ada, "select study_staff_invoice_create(%s, 'Term 1', 200, 4, 'USD', 1600)", inst) or ""))
inv = run(kaivon, "select study_staff_invoice_create(%s, 'Term 1: 200 students', 200, 4, 'USD', 1600)", inst)
check("an invoice has a payment reference", inv["ref"].startswith("kaivon-inv-") and inv["status"] == "open", inv)
check("the admin sees it", len(run(ada, "select study_institution_invoices(%s)", inst)) == 1)
tt = run(ada, "select token from study_institution_invite(%s, array['tom@school.edu'], 'teacher')", inst)
run(tom, "select study_invite_accept(%s)", tt)
check("a teacher doesn't", "not allowed" in (refused(tom, "select study_institution_invoices(%s)", inst) or ""))
start = run(ada, "select study_invoice_checkout_start(%s)", inv["id"])
check("the admin can start paying", start["ref"] == inv["ref"] and float(start["amount"]) == 1600, start)
check("a teacher can't", "not allowed" in (refused(tom, "select study_invoice_checkout_start(%s)", inv["id"]) or ""))
check("users can't credit invoices themselves",
      refused(ada, "select credit_institution_invoice(%s, 'flw-1', 1600, 'USD', 'production')", inv["ref"]) is not None)
check("part payment is refused",
      "not paid in full" in (refused(None, "select credit_institution_invoice(%s, 'flw-1', 1000, 'USD', 'production')", inv["ref"]) or ""))
check("another currency is refused",
      "not paid in full" in (refused(None, "select credit_institution_invoice(%s, 'flw-1', 1600, 'NGN', 'production')", inv["ref"]) or ""))
paid = run(None, "select credit_institution_invoice(%s, 'flw-1', 1600, 'USD', 'production')", inv["ref"])
row = run(None, "select jsonb_build_object('plan', plan, 'seats', seats, 'until', paid_until) from study_institutions where id = %s", inst)
check("paid: the institution moves to paid, 200 seats, 4 months",
      row["plan"] == "paid" and row["seats"] == 200 and paid["paid_until"] == row["until"], (row, paid))
again = run(None, "select credit_institution_invoice(%s, 'flw-1', 1600, 'USD', 'production')", inv["ref"])
check("crediting twice changes nothing", again.get("already") is True
      and run(None, "select paid_until from study_institutions where id = %s", inst).isoformat() == row["until"])
check("a paid invoice can't be paid again", "not open" in (refused(ada, "select study_invoice_checkout_start(%s)", inv["id"]) or ""))
inv2 = run(kaivon, "select study_staff_invoice_create(%s, 'Term 2', 150, 4, 'NGN', 2400000)", inst)
run(None, "select credit_institution_invoice(%s, 'flw-2', 2400000, 'NGN', 'production')", inv2["ref"])
check("a second term adds 4 more months and keeps the larger seat count",
      run(None, "select seats from study_institutions where id = %s", inst) == 200
      and (run(None, "select paid_until from study_institutions where id = %s", inst)
           - run(None, "select (current_date + interval '8 months')::date"))
          .days == 0)
inv3 = run(kaivon, "select study_staff_invoice_create(%s, 'Mistake', 10, 1, 'USD', 10)", inst)
run(kaivon, "select study_staff_invoice_void(%s)", inv3["id"])
check("a void invoice can't be paid", "invoice not open" in (refused(None, "select credit_institution_invoice(%s, 'flw-3', 10, 'USD', 'production')", inv3["ref"]) or ""))

gbp = run(kaivon, "select study_staff_invoice_create(%s, 'Year 1: 60 students', 60, 12, 'GBP', 2160)", inst)
check("invoices can be in pounds", gbp["currency"] == "GBP", gbp)
check("and in euros", run(kaivon, "select study_staff_invoice_create(%s, 'x', 50, 12, 'EUR', 2100)", inst)["currency"] == "EUR")
check("but not any currency", refused(kaivon, "select study_staff_invoice_create(%s, 'x', 50, 12, 'JPY', 1)", inst) is not None)
check("admins see their own under-18 setting",
      run(ada, "select study_institution_overview(%s)", inst)["institution"]["minors_consent"] is False)

print()
print("All invoice checks passed." if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
