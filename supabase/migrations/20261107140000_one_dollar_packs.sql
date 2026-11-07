-- The two smallest coin packs, Starter and Pouch, go from $0.99 to $1.00,
-- and from N990 to N1,000, 2026-11-07.
--
-- Flutterwave's hosted checkout refused every $0.99 payment with "One or
-- more required parameters missing", while the same request at $4.99
-- opened. Dollar charges under $1 don't go through, so the smallest packs
-- are $1.00. Naira stays the dollar digits times 1,000.

update public.web_coin_prices set amount = 1.00
 where currency = 'USD' and amount < 1;

update public.web_coin_prices n set amount = round(u.amount * 1000)
  from public.web_coin_prices u
 where u.product_id = n.product_id and u.currency = 'USD' and n.currency = 'NGN';
