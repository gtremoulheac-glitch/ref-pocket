-- =====================================================================
-- Ref Pocket : un pouvoir spécial pour chaque carte
-- Donne un effet à toutes les cartes qui n'en ont pas encore, selon leur type.
-- Les cartes qui ont déjà un effet (choisi dans l'admin) ne sont pas touchées.
-- Relançable sans risque. À lancer APRÈS schema.sql.
-- =====================================================================
with pools(type, fx) as (values
  ('yt', array['buzz', 'hype', 'doubletap', 'crit', 'lifesteal']),
  ('tr', array['clash', 'malaise', 'rage', 'remontada', 'expose']),
  ('sn', array['doubletap', 'buzz', 'malaise', 'expose', 'thorns']),
  ('fi', array['crit', 'lastword', 'landing', 'shield', 'remontada']),
  ('cu', array['hype', 'lastword', 'remontada', 'crit', 'shield']),
  ('foot', array['rage', 'doubletap', 'remontada', 'landing', 'clash']),
  ('pol', array['shield', 'expose', 'malaise', 'lifesteal', 'thorns']),
  ('twitch', array['buzz', 'lifesteal', 'clash', 'thorns', 'hype']),
  ('tele', array['hype', 'shield', 'expose', 'thorns', 'lastword']),
  ('sport', array['rage', 'landing', 'doubletap', 'crit', 'remontada']),
  ('tiktok', array['buzz', 'doubletap', 'hype', 'malaise', 'crit'])
), d as (select array['crit', 'lifesteal', 'thorns', 'rage', 'shield', 'hype', 'lastword', 'clash', 'malaise', 'expose', 'doubletap', 'remontada', 'landing', 'buzz'] as fx)
update public.cards c
   set fx = (select arr[1 + mod(abs(hashtext(c.id)), cardinality(arr))]
               from (select coalesce((select p.fx from pools p where p.type = c.type), (select d.fx from d)) as arr) z)
 where c.fx is null;
