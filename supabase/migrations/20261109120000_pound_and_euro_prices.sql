-- Pounds for buyers in the UK and euros for buyers in the euro countries,
-- 2026-11-09.
--
-- Buyers in Nigeria pay in naira; in the UK, the Isle of Man, Jersey and
-- Guernsey in pounds; in the euro countries (the euro area, Bulgaria from
-- 2026, the microstates and territories that use the euro) in euros;
-- everyone else in US dollars. The apps pick the currency from the buyer's
-- country (Cloudflare's, at /api/geo), or from the time zone when that
-- isn't there.
--
-- The founder set these prices. Pounds aren't converted from dollars;
-- euros are about 93% of the dollar price, rounded to .49 or .99, and at
-- least EUR 1 (Flutterwave refuses tiny card charges). A Flutterwave
-- payment plan in each currency is made the first time someone subscribes
-- at that price (flw_plan_id stays null until then), as for naira. Card
-- only in pounds and euros (_shared/flutterwave.ts).
--
-- Every function that lists or checks prices takes any currency with a
-- row here: web_coin_shop and web_plan_shop answer in it (dollars where a
-- pack or plan has none), web_checkout_start and web_subscribe_start charge
-- in it, and study_me lists every currency each plan has a price in.

insert into public.web_coin_prices (product_id, currency, amount) values
  ('utopia.coins.starter', 'GBP', 1.00),
  ('utopia.coins.pouch', 'GBP', 1.00),
  ('utopia.coins.sack', 'GBP', 3.99),
  ('utopia.coins.chest', 'GBP', 7.99),
  ('utopia.coins.vault', 'GBP', 15.99),
  ('utopia.coins.mountain', 'GBP', 39.99),
  ('utopia.coins.hoard', 'GBP', 79.99),
  ('utopia.coins.starter', 'EUR', 1.00),
  ('utopia.coins.pouch', 'EUR', 1.00),
  ('utopia.coins.sack', 'EUR', 4.49),
  ('utopia.coins.chest', 'EUR', 9.49),
  ('utopia.coins.vault', 'EUR', 18.49),
  ('utopia.coins.mountain', 'EUR', 46.49),
  ('utopia.coins.hoard', 'EUR', 92.99)
on conflict (product_id, currency) do update set amount = excluded.amount;

-- A changed price needs a new Flutterwave plan, so its flw_plan_id goes.
insert into public.web_plan_prices (plan_id, currency, amount, flw_plan_id) values
  ('utopia.maestro.monthly', 'GBP', 6.49, null),
  ('study.pro.monthly', 'GBP', 6.49, null),
  ('study.pro.student.monthly', 'GBP', 4.99, null),
  ('rizz.pro.weekly', 'GBP', 2.99, null),
  ('rizz.pro.monthly', 'GBP', 7.99, null),
  ('utopia.maestro.monthly', 'EUR', 7.49, null),
  ('study.pro.monthly', 'EUR', 7.49, null),
  ('study.pro.student.monthly', 'EUR', 5.49, null),
  ('rizz.pro.weekly', 'EUR', 3.49, null),
  ('rizz.pro.monthly', 'EUR', 9.49, null)
on conflict (plan_id, currency) do update
  set amount = excluded.amount,
      flw_plan_id = case when public.web_plan_prices.amount = excluded.amount
                         then public.web_plan_prices.flw_plan_id end;
