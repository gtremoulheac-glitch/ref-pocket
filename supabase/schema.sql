-- =====================================================================
--  REF MASTER — base de données Supabase
--  À coller en entier dans Supabase > SQL Editor, puis "Run".
--  Le script peut être relancé sans danger : il ne supprime aucune donnée.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catalogue (modifiable depuis le Table Editor de Supabase)
-- ---------------------------------------------------------------------
create table if not exists public.types (
  id    text primary key,
  name  text not null,
  abbr  text not null,
  color text not null,
  sort  int  not null default 0
);

-- Progression des niveaux propre à chaque type : 5 lettres, une par niveau (p = Punchline, d = Aura, v = Viralité)
alter table public.types add column if not exists lvl text not null default 'vpvdp';
do $lvl$ begin
  if not exists (select 1 from pg_constraint where conname = 'types_lvl_check') then
    alter table public.types add constraint types_lvl_check check (lvl ~ '^[pdv]{5}$');
  end if;
end $lvl$;
update public.types t set lvl = x.lvl from (values
  ('yt','vvpvd'), ('tr','vdvdp'), ('sn','ppvpv'), ('fi','dpdvp'), ('cu','dvdpv'),
  ('foot','ppvpd'), ('pol','ddvdp'), ('twitch','vpvpv'), ('tele','vdvpd'), ('sport','pvpdp')
) as x(id, lvl) where t.id = x.id and t.lvl = 'vpvdp';

create table if not exists public.type_matchups (
  attacker text references public.types(id) on delete cascade,
  defender text references public.types(id) on delete cascade,
  mult     numeric not null default 1.5,
  primary key (attacker, defender)
);

create table if not exists public.cards (
  id     text primary key,
  n      int  not null,
  name   text not null,
  type   text not null references public.types(id),
  rarity text not null check (rarity in ('C','R','E','L')),
  p      int  not null check (p >= 0),
  d      int  not null check (d >= 0),
  v      int  not null check (v > 0),
  fx     text,
  art    text not null default '❔',
  flavor text not null default '',
  active boolean not null default true
);
alter table public.cards add column if not exists image text;
alter table public.cards add column if not exists audio text;
alter table public.cards add column if not exists video text;   -- vidéo des légendaires

-- ---------------------------------------------------------------------
-- 2. Joueurs et cartes possédées
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  pseudo      text not null unique check (char_length(pseudo) between 3 and 20),
  kheys       int  not null default 200 check (kheys >= 0),
  boosters    int  not null default 3 check (boosters >= 0),
  last_refill timestamptz not null default now(),
  pity        int  not null default 0,
  daily_day   date,
  daily_n     int  not null default 0,
  wins        int  not null default 0,
  losses      int  not null default 0,
  opened      int  not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists last_seen timestamptz not null default now();
alter table public.profiles add column if not exists showcase text[] not null default '{}';   -- les 4 cartes mises en avant sur la page perso

create table if not exists public.card_instances (
  id          bigint generated always as identity primary key,
  card_id     text not null references public.cards(id),
  owner       uuid not null references public.profiles(id) on delete cascade,
  holo        boolean not null default false,
  lock        text check (lock in ('listing','trade')),
  obtained_at timestamptz not null default now()
);
create index if not exists card_instances_owner_idx on public.card_instances(owner);

-- Journal de chaque mouvement de Kheys (pour retrouver un bug ou une triche)
create table if not exists public.ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  amount     int  not null,
  reason     text not null,
  ref        text,
  created_at timestamptz not null default now()
);
create index if not exists ledger_user_idx on public.ledger(user_id);

-- ---------------------------------------------------------------------
-- 3. Marché et échanges
-- ---------------------------------------------------------------------
create table if not exists public.listings (
  id          bigint generated always as identity primary key,
  instance_id bigint not null references public.card_instances(id) on delete cascade,
  seller      uuid not null references public.profiles(id) on delete cascade,
  price       int  not null check (price between 1 and 1000000),
  status      text not null default 'open' check (status in ('open','sold','cancelled')),
  buyer       uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  closed_at   timestamptz
);
create index if not exists listings_open_idx on public.listings(status) where status = 'open';
create unique index if not exists listings_one_open_per_card on public.listings(instance_id) where status = 'open';

create table if not exists public.trades (
  id          bigint generated always as identity primary key,
  from_user   uuid not null references public.profiles(id) on delete cascade,
  to_user     uuid not null references public.profiles(id) on delete cascade,
  kheys_give  int  not null default 0 check (kheys_give >= 0),
  kheys_take  int  not null default 0 check (kheys_take >= 0),
  status      text not null default 'open' check (status in ('open','accepted','refused','cancelled','expired','failed')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '48 hours',
  closed_at   timestamptz
);
-- Échanges en deux temps : « open » = attend la contre-proposition, « countered » = attend la réponse finale
alter table public.trades drop constraint if exists trades_status_check;
alter table public.trades add constraint trades_status_check
  check (status in ('open','countered','accepted','refused','cancelled','expired','failed'));

create table if not exists public.trade_items (
  trade_id    bigint not null references public.trades(id) on delete cascade,
  instance_id bigint not null references public.card_instances(id) on delete cascade,
  side        text not null check (side in ('give','take')),
  primary key (trade_id, instance_id)
);

-- ---------------------------------------------------------------------
-- 4. Sécurité : tout le monde peut lire, personne n'écrit directement.
--    Toute écriture passe par les fonctions plus bas.
-- ---------------------------------------------------------------------
alter table public.types          enable row level security;
alter table public.type_matchups  enable row level security;
alter table public.cards          enable row level security;
alter table public.profiles       enable row level security;
alter table public.card_instances enable row level security;
alter table public.ledger         enable row level security;
alter table public.listings       enable row level security;
alter table public.trades         enable row level security;
alter table public.trade_items    enable row level security;

drop policy if exists "lecture types"     on public.types;
drop policy if exists "lecture matchups"  on public.type_matchups;
drop policy if exists "lecture cartes"    on public.cards;
drop policy if exists "lecture profils"   on public.profiles;
drop policy if exists "lecture exemplaires" on public.card_instances;
drop policy if exists "lecture journal"   on public.ledger;
drop policy if exists "lecture annonces"  on public.listings;
drop policy if exists "lecture echanges"  on public.trades;
drop policy if exists "lecture items"     on public.trade_items;

create policy "lecture types"       on public.types          for select using (true);
create policy "lecture matchups"    on public.type_matchups  for select using (true);
create policy "lecture cartes"      on public.cards          for select using (true);
create policy "lecture profils"     on public.profiles       for select to authenticated using (true);
-- On ne voit que ses propres cartes, celles en vente et celles des échanges auxquels on participe
create policy "lecture exemplaires" on public.card_instances for select to authenticated using (
  owner = auth.uid()
  or exists (select 1 from public.listings l where l.instance_id = card_instances.id
              and (l.status = 'open' or auth.uid() in (l.seller, l.buyer)))
  or exists (select 1 from public.trade_items ti join public.trades t on t.id = ti.trade_id
              where ti.instance_id = card_instances.id and auth.uid() in (t.from_user, t.to_user)));
create policy "lecture journal"     on public.ledger         for select to authenticated using (user_id = auth.uid());
create policy "lecture annonces"    on public.listings       for select to authenticated using (true);
create policy "lecture echanges"    on public.trades         for select to authenticated using (auth.uid() in (from_user, to_user));
create policy "lecture items"       on public.trade_items    for select to authenticated using (
  exists (select 1 from public.trades t where t.id = trade_id and auth.uid() in (t.from_user, t.to_user)));

-- Les administrateurs (colonne is_admin de profiles) peuvent modifier le catalogue
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false) $$;

drop policy if exists "admin cartes"   on public.cards;
drop policy if exists "admin types"    on public.types;
drop policy if exists "admin matchups" on public.type_matchups;
create policy "admin cartes"   on public.cards         for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin types"    on public.types         for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin matchups" on public.type_matchups for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Dossier public "cartes" pour les images (Supabase Storage)
do $storage$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public) values ('cartes', 'cartes', true)
      on conflict (id) do update set public = true;
    execute 'drop policy if exists "cartes admin ajout" on storage.objects';
    execute 'drop policy if exists "cartes admin modif" on storage.objects';
    execute 'drop policy if exists "cartes admin suppr" on storage.objects';
    execute 'drop policy if exists "cartes admin lecture" on storage.objects';
    execute $p$create policy "cartes admin ajout" on storage.objects for insert to authenticated with check (bucket_id = 'cartes' and public.is_admin())$p$;
    execute $p$create policy "cartes admin modif" on storage.objects for update to authenticated using (bucket_id = 'cartes' and public.is_admin())$p$;
    execute $p$create policy "cartes admin suppr" on storage.objects for delete to authenticated using (bucket_id = 'cartes' and public.is_admin())$p$;
    execute $p$create policy "cartes admin lecture" on storage.objects for select to authenticated using (bucket_id = 'cartes' and public.is_admin())$p$;
  end if;
end $storage$;

-- ---------------------------------------------------------------------
-- 5. Règles du jeu (constantes)
-- ---------------------------------------------------------------------
create or replace function public._rarity_value(r text) returns int language sql immutable as $$
  select case r when 'C' then 5 when 'R' then 15 when 'E' then 50 when 'L' then 200 end $$;

create or replace function public._uid() returns uuid language plpgsql stable as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Connexion requise'; end if;
  return u;
end $$;

create or replace function public._move_kheys(p_user uuid, p_amount int, p_reason text, p_ref text default null)
returns void language plpgsql as $$
begin
  if p_amount = 0 then return; end if;
  update public.profiles set kheys = kheys + p_amount where id = p_user;
  if (select kheys from public.profiles where id = p_user) < 0 then
    raise exception 'Pas assez de Kheys';
  end if;
  insert into public.ledger(user_id, amount, reason, ref) values (p_user, p_amount, p_reason, p_ref);
end $$;

-- Niveaux des cartes (fusion des doubles) : le bonus de chaque niveau dépend du type (colonne types.lvl)
create table if not exists public.card_levels (
  owner   uuid not null references public.profiles(id) on delete cascade,
  card_id text not null references public.cards(id) on delete cascade,
  level   int  not null default 0 check (level between 0 and 5),
  primary key (owner, card_id)
);
create or replace function public._lvl_v(l int) returns int language sql immutable as $$ select (l >= 1)::int + (l >= 3)::int $$;
create or replace function public._lvl_p(l int) returns int language sql immutable as $$ select (l >= 2)::int + (l >= 5)::int $$;
create or replace function public._lvl_d(l int) returns int language sql immutable as $$ select (l >= 4)::int $$;
-- Doubles à fusionner pour passer au niveau l (1 → 5)
create or replace function public._lvl_cost(l int) returns int language sql immutable as $$ select l $$;
create or replace function public._lvl_of(u uuid, cid text) returns int language sql stable as $$
  select coalesce((select level from public.card_levels where owner = u and card_id = cid), 0) $$;

-- Recharge des boosters : 1 par heure, 2 maximum en réserve
create or replace function public._refill(p_user uuid) returns void language plpgsql as $$
declare pr public.profiles; n int;
begin
  select * into pr from public.profiles where id = p_user for update;
  if pr.boosters >= 2 then
    update public.profiles set last_refill = now() where id = p_user;
    return;
  end if;
  n := floor(extract(epoch from (now() - pr.last_refill)) / 3600);
  if n > 0 then
    update public.profiles
       set boosters = least(2, pr.boosters + n),
           last_refill = case when pr.boosters + n >= 2 then now() else pr.last_refill + make_interval(hours => n) end
     where id = p_user;
  end if;
end $$;

create or replace function public._expire_trades() returns void language plpgsql as $$
declare t public.trades;
begin
  for t in select * from public.trades where status in ('open','countered') and expires_at < now() for update skip locked loop
    perform public._close_trade(t, 'expired');
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 6. Fonctions appelées par l'appli
-- ---------------------------------------------------------------------

-- Création du profil à la première connexion
create or replace function public.create_profile(p_pseudo text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); pr public.profiles;
begin
  select * into pr from profiles where id = u;
  if found then return pr; end if;
  p_pseudo := trim(p_pseudo);
  if p_pseudo !~ '^[A-Za-z0-9_.\-À-ÿ]{3,20}$' then
    raise exception 'Pseudo invalide : 3 à 20 caractères, lettres, chiffres, point, tiret ou underscore';
  end if;
  if exists (select 1 from profiles where lower(pseudo) = lower(p_pseudo)) then
    raise exception 'Ce pseudo est déjà pris';
  end if;
  -- Le tout premier compte créé devient administrateur
  insert into profiles(id, pseudo, is_admin)
  values (u, p_pseudo, not exists (select 1 from profiles where is_admin)) returning * into pr;
  insert into ledger(user_id, amount, reason) values (u, 200, 'solde_depart');
  return pr;
end $$;

-- Rafraîchit les boosters et renvoie le profil
create or replace function public.my_profile() returns public.profiles
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); pr public.profiles;
begin
  if not exists (select 1 from profiles where id = u) then return null; end if;
  update profiles set last_seen = now() where id = u;
  perform _refill(u);
  perform _expire_trades();
  select * into pr from profiles where id = u;
  return pr;
end $$;

-- Ouvre un booster (gratuit ou acheté 100 K). Tout le tirage se fait ici.
create or replace function public.open_booster(p_paid boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u uuid := public._uid();
  pr profiles;
  rs text[] := array[]::text[];
  r text; x float; i int;
  c text; h boolean; is_new boolean; inst bigint;
  out jsonb := '[]'::jsonb;
begin
  perform _refill(u);
  select * into pr from profiles where id = u for update;
  if not found then raise exception 'Profil introuvable'; end if;

  if p_paid then
    perform _move_kheys(u, -100, 'achat_booster');
  else
    if pr.boosters < 1 then raise exception 'Aucun booster disponible pour l''instant'; end if;
    update profiles set boosters = boosters - 1,
                        last_refill = case when pr.boosters >= 2 then now() else last_refill end
     where id = u;
  end if;

  -- Taux de tirage par emplacement
  for i in 1..4 loop
    x := random() * 100;
    if i <= 2 then r := case when x < 85 then 'C' else 'R' end;
    -- Légendaire : 0,8 % sur la 3e carte et 3,2 % sur la 4e, soit environ 4 % par booster
    elsif i = 3 then r := case when x < 80 then 'R' when x < 99.2 then 'E' else 'L' end;
    else r := case when x < 62 then 'R' when x < 96.8 then 'E' else 'L' end;
    end if;
    rs := rs || r;
  end loop;

  -- Compteur de pitié : une légendaire au plus tard au 60e booster
  if 'L' = any(rs) then
    update profiles set pity = 0 where id = u;
  elsif pr.pity >= 59 then
    rs[4] := 'L'; update profiles set pity = 0 where id = u;
  else
    update profiles set pity = pity + 1 where id = u;
  end if;

  for i in 1..4 loop
    select id into c from cards where rarity = rs[i] and active order by random() limit 1;
    if c is null then raise exception 'Aucune carte active de rareté %', rs[i]; end if;
    h := random() < 0.05;
    is_new := not exists (select 1 from card_instances where owner = u and card_id = c);
    insert into card_instances(card_id, owner, holo) values (c, u, h) returning id into inst;
    out := out || jsonb_build_object('instance_id', inst, 'card_id', c, 'holo', h, 'is_new', is_new);
  end loop;

  update profiles set opened = opened + 1 where id = u;
  return out;
end $$;

-- Défausse un exemplaire contre des Kheys
create or replace function public.discard_card(p_instance bigint) returns int
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); ci card_instances; val int;
begin
  select * into ci from card_instances where id = p_instance for update;
  if not found or ci.owner <> u then raise exception 'Cette carte ne t''appartient pas'; end if;
  if ci.lock is not null then raise exception 'Cette carte est en vente ou dans un échange'; end if;
  select _rarity_value(rarity) * (case when ci.holo then 3 else 1 end) into val from cards where id = ci.card_id;
  delete from card_instances where id = p_instance;
  perform _move_kheys(u, val, 'defausse', ci.card_id);
  return val;
end $$;

-- Met un exemplaire en vente (gratuit)
create or replace function public.list_card(p_instance bigint, p_price int) returns bigint
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); ci card_instances; lid bigint;
begin
  if p_price is null or p_price < 1 or p_price > 1000000 then raise exception 'Prix invalide'; end if;
  select * into ci from card_instances where id = p_instance for update;
  if not found or ci.owner <> u then raise exception 'Cette carte ne t''appartient pas'; end if;
  if ci.lock is not null then raise exception 'Cette carte est déjà en vente ou dans un échange'; end if;
  update card_instances set lock = 'listing' where id = p_instance;
  insert into listings(instance_id, seller, price) values (p_instance, u, p_price) returning id into lid;
  return lid;
end $$;

create or replace function public.cancel_listing(p_listing bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); l listings;
begin
  select * into l from listings where id = p_listing for update;
  if not found or l.seller <> u then raise exception 'Annonce introuvable'; end if;
  if l.status <> 'open' then raise exception 'Cette annonce est déjà terminée'; end if;
  update listings set status = 'cancelled', closed_at = now() where id = p_listing;
  update card_instances set lock = null where id = l.instance_id;
end $$;

-- Achat : le vendeur touche le prix affiché
create or replace function public.buy_listing(p_listing bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); l listings;
begin
  select * into l from listings where id = p_listing for update;
  if not found or l.status <> 'open' then raise exception 'Cette carte vient d''être vendue ou retirée'; end if;
  if l.seller = u then raise exception 'Tu ne peux pas acheter ta propre carte'; end if;
  perform _move_kheys(u, -l.price, 'achat_marche', l.id::text);
  perform _move_kheys(l.seller, l.price, 'vente_marche', l.id::text);
  update card_instances set owner = u, lock = null, obtained_at = now() where id = l.instance_id;
  update listings set status = 'sold', buyer = u, closed_at = now() where id = p_listing;
end $$;

-- Proposer un échange : je propose mes cartes (+ Kheys). L'autre répond ensuite avec les siennes (counter_trade).
-- On ne choisit plus dans la collection de l'autre : p_take et p_kheys_take sont ignorés.
create or replace function public.propose_trade(p_to uuid, p_give bigint[], p_take bigint[],
                                                p_kheys_give int default 0, p_kheys_take int default 0)
returns bigint language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); tid bigint; bad int;
begin
  perform _expire_trades();
  p_give := coalesce(p_give, '{}'); p_take := '{}';
  p_kheys_give := coalesce(p_kheys_give, 0); p_kheys_take := 0;
  if p_to = u then raise exception 'Tu ne peux pas échanger avec toi-même'; end if;
  if not exists (select 1 from profiles where id = p_to) then raise exception 'Joueur introuvable'; end if;
  if not _are_friends(u, p_to) then raise exception 'Ajoute ce joueur en ami pour échanger avec lui'; end if;
  if p_kheys_give < 0 or p_kheys_take < 0 then raise exception 'Montant invalide'; end if;
  if cardinality(p_give) = 0 then raise exception 'Propose au moins une carte'; end if;
  if cardinality(p_give) > 10 or cardinality(p_take) > 10 then raise exception '10 cartes maximum de chaque côté'; end if;
  if (select count(*) from trades where from_user = u and status in ('open','countered')) >= 5 then
    raise exception 'Tu as déjà 5 offres en attente';
  end if;

  select count(*) into bad from card_instances
   where id = any(p_give) and (owner <> u or lock is not null);
  if bad > 0 or (select count(*) from card_instances where id = any(p_give)) <> cardinality(p_give) then
    raise exception 'Une de tes cartes n''est pas disponible';
  end if;
  select count(*) into bad from card_instances
   where id = any(p_take) and (owner <> p_to or lock is not null);
  if bad > 0 or (select count(*) from card_instances where id = any(p_take)) <> cardinality(p_take) then
    raise exception 'Une des cartes demandées n''est plus disponible';
  end if;

  insert into trades(from_user, to_user, kheys_give, kheys_take)
  values (u, p_to, p_kheys_give, p_kheys_take) returning id into tid;
  perform _move_kheys(u, -p_kheys_give, 'echange_reserve', tid::text);
  update card_instances set lock = 'trade' where id = any(p_give);
  insert into trade_items(trade_id, instance_id, side)
    select tid, unnest(p_give), 'give' union all select tid, unnest(p_take), 'take';
  return tid;
end $$;

create or replace function public._close_trade(t trades, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update card_instances set lock = null
   where id in (select instance_id from trade_items where trade_id = t.id and side = 'give') and lock = 'trade';
  perform _move_kheys(t.from_user, t.kheys_give, 'echange_rembourse', t.id::text);
  -- Contre-proposition en cours : on libère aussi les cartes et les Kheys de l'autre
  if t.status = 'countered' then
    update card_instances set lock = null
     where id in (select instance_id from trade_items where trade_id = t.id and side = 'take') and lock = 'trade' and owner = t.to_user;
    perform _move_kheys(t.to_user, t.kheys_take, 'echange_rembourse', t.id::text);
  end if;
  update trades set status = p_status, closed_at = now() where id = t.id;
end $$;

-- Répondre à une offre avec ses propres cartes (+ Kheys) : c'est ensuite à l'auteur de l'offre d'accepter ou non
create or replace function public.counter_trade(p_trade bigint, p_give bigint[], p_kheys int default 0) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); t trades; bad int;
begin
  perform _expire_trades();
  p_give := coalesce(p_give, '{}'); p_kheys := coalesce(p_kheys, 0);
  select * into t from trades where id = p_trade for update;
  if not found or t.to_user <> u then raise exception 'Échange introuvable'; end if;
  if t.status <> 'open' then raise exception 'Cet échange n''attend plus de réponse'; end if;
  if exists (select 1 from trade_items where trade_id = t.id and side = 'take') then raise exception 'Cet échange a déjà une contrepartie'; end if;
  if p_kheys < 0 then raise exception 'Montant invalide'; end if;
  if cardinality(p_give) > 10 then raise exception '10 cartes maximum'; end if;
  if cardinality(p_give) = 0 and p_kheys = 0 then raise exception 'Propose au moins une carte ou des Kheys'; end if;
  select count(*) into bad from card_instances where id = any(p_give) and (owner <> u or lock is not null);
  if bad > 0 or (select count(*) from card_instances where id = any(p_give)) <> cardinality(p_give) then
    raise exception 'Une de tes cartes n''est pas disponible';
  end if;
  if (select kheys from profiles where id = u) < p_kheys then raise exception 'Tu n''as pas assez de Kheys'; end if;
  perform _move_kheys(u, -p_kheys, 'echange_reserve', t.id::text);
  update card_instances set lock = 'trade' where id = any(p_give);
  insert into trade_items(trade_id, instance_id, side) select t.id, unnest(p_give), 'take';
  update trades set status = 'countered', kheys_take = p_kheys, expires_at = now() + interval '48 hours' where id = t.id;
end $$;

-- Accepter ou refuser (destinataire)
create or replace function public.respond_trade(p_trade bigint, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); t trades; bad int;
begin
  perform _expire_trades();
  select * into t from trades where id = p_trade for update;
  if not found or u not in (t.from_user, t.to_user) then raise exception 'Échange introuvable'; end if;
  if t.status not in ('open','countered') then raise exception 'Cet échange est déjà terminé'; end if;

  -- Contre-proposition : l'auteur de l'offre accepte ou refuse ; le destinataire peut seulement la retirer
  if t.status = 'countered' then
    if not p_accept then perform _close_trade(t, 'refused'); return 'refused'; end if;
    if u <> t.from_user then raise exception 'C''est à l''autre joueur de répondre'; end if;
    if exists (select 1 from trade_items ti left join card_instances ci on ci.id = ti.instance_id
                where ti.trade_id = t.id and (ci.id is null or ci.lock is distinct from 'trade'
                  or ci.owner <> (case when ti.side = 'give' then t.from_user else t.to_user end))) then
      perform _close_trade(t, 'failed'); return 'failed';
    end if;
    update card_instances set owner = t.to_user, lock = null, obtained_at = now()
     where id in (select instance_id from trade_items where trade_id = t.id and side = 'give');
    update card_instances set owner = t.from_user, lock = null, obtained_at = now()
     where id in (select instance_id from trade_items where trade_id = t.id and side = 'take');
    perform _move_kheys(t.to_user, t.kheys_give, 'echange_recu', t.id::text);
    perform _move_kheys(t.from_user, t.kheys_take, 'echange_recu', t.id::text);
    update trades set status = 'accepted', closed_at = now() where id = t.id;
    return 'accepted';
  end if;

  if u <> t.to_user then raise exception 'C''est à l''autre joueur de répondre'; end if;
  if not p_accept then
    perform _close_trade(t, 'refused');
    return 'refused';
  end if;

  -- Les cartes demandées doivent toujours être à toi et libres
  select count(*) into bad from trade_items ti join card_instances ci on ci.id = ti.instance_id
   where ti.trade_id = t.id and ti.side = 'take' and (ci.owner <> u or ci.lock is not null);
  if bad > 0 or (select count(*) from trade_items ti join card_instances ci on ci.id = ti.instance_id
                  where ti.trade_id = t.id and ti.side = 'take')
              <> (select count(*) from trade_items where trade_id = t.id and side = 'take') then
    perform _close_trade(t, 'failed');
    return 'failed';
  end if;
  if (select kheys from profiles where id = u) < t.kheys_take then
    raise exception 'Il te manque des Kheys pour accepter';
  end if;

  update card_instances set owner = u, lock = null, obtained_at = now()
   where id in (select instance_id from trade_items where trade_id = t.id and side = 'give');
  update card_instances set owner = t.from_user, lock = null, obtained_at = now()
   where id in (select instance_id from trade_items where trade_id = t.id and side = 'take');
  perform _move_kheys(u, t.kheys_give, 'echange_recu', t.id::text);
  perform _move_kheys(u, -t.kheys_take, 'echange_paye', t.id::text);
  perform _move_kheys(t.from_user, t.kheys_take, 'echange_recu', t.id::text);
  update trades set status = 'accepted', closed_at = now() where id = t.id;
  return 'accepted';
end $$;

-- Annuler sa propre offre
create or replace function public.cancel_trade(p_trade bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); t trades;
begin
  select * into t from trades where id = p_trade for update;
  if not found or t.from_user <> u then raise exception 'Échange introuvable'; end if;
  if t.status not in ('open','countered') then raise exception 'Cet échange est déjà terminé'; end if;
  perform _close_trade(t, 'cancelled');
end $$;

-- L'ancienne récompense des duels contre le bot est supprimée : seuls les duels en ligne rapportent des Kheys.
drop function if exists public.duel_reward(boolean);

-- ---------------------------------------------------------------------
-- 7. Amis
-- ---------------------------------------------------------------------
create table if not exists public.friendships (
  id         bigint generated always as identity primary key,
  requester  uuid not null references public.profiles(id) on delete cascade,
  addressee  uuid not null references public.profiles(id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  check (requester <> addressee)
);
create unique index if not exists friendships_pair on public.friendships (least(requester, addressee), greatest(requester, addressee));
alter table public.friendships enable row level security;
drop policy if exists "lecture amis" on public.friendships;
create policy "lecture amis" on public.friendships for select to authenticated using (auth.uid() in (requester, addressee));

-- On ajoute en ami seulement les joueurs qu'on veut (demande puis acceptation)
create or replace function public._are_friends(x uuid, y uuid) returns boolean language sql stable as $$
  select exists (select 1 from public.friendships
                  where status = 'accepted' and least(requester, addressee) = least(x, y)
                    and greatest(requester, addressee) = greatest(x, y)) $$;

-- Demande d'ami par pseudo (si l'autre t'avait déjà demandé, c'est accepté directement)
create or replace function public.friend_request(p_pseudo text) returns text
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); o uuid; f friendships;
begin
  select id into o from profiles where lower(pseudo) = lower(trim(p_pseudo));
  if o is null then raise exception 'Aucun joueur ne s''appelle « % »', trim(p_pseudo); end if;
  if o = u then raise exception 'Tu ne peux pas t''ajouter toi-même'; end if;
  select * into f from friendships
   where least(requester, addressee) = least(u, o) and greatest(requester, addressee) = greatest(u, o) for update;
  if found then
    if f.status = 'accepted' then raise exception 'Vous êtes déjà amis'; end if;
    if f.addressee = u then update friendships set status = 'accepted' where id = f.id; return 'accepted'; end if;
    raise exception 'Demande déjà envoyée';
  end if;
  if (select count(*) from friendships where requester = u and status = 'pending') >= 30 then
    raise exception 'Trop de demandes en attente';
  end if;
  insert into friendships(requester, addressee) values (u, o);
  return 'pending';
end $$;

create or replace function public.friend_respond(p_id bigint, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); f friendships;
begin
  select * into f from friendships where id = p_id for update;
  if not found or f.addressee <> u or f.status <> 'pending' then raise exception 'Demande introuvable'; end if;
  if p_accept then update friendships set status = 'accepted' where id = p_id;
  else delete from friendships where id = p_id; end if;
end $$;

create or replace function public.friend_remove(p_other uuid) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  delete from friendships
   where least(requester, addressee) = least(u, p_other) and greatest(requester, addressee) = greatest(u, p_other);
end $$;

-- ---------------------------------------------------------------------
-- 8. Duels en ligne (tout le combat est calculé ici, le navigateur ne fait qu'afficher)
--    Les effets reprennent les clés FX de web/cartes.js : garder les deux alignés.
-- ---------------------------------------------------------------------
create table if not exists public.duels (
  id              bigint generated always as identity primary key,
  player_a        uuid not null references public.profiles(id) on delete cascade,
  player_b        uuid references public.profiles(id) on delete cascade,
  mode            text not null check (mode in ('random','friend')),
  status          text not null default 'waiting' check (status in ('waiting','invited','active','finished','cancelled')),
  deck_a          text[] not null,
  deck_b          text[],
  state           jsonb,
  move_no         int not null default 0,
  turn_started_at timestamptz,
  winner          uuid,
  gain_a          int,
  gain_b          int,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists duels_waiting_idx on public.duels(status) where status in ('waiting','invited','active');
alter table public.duels enable row level security;
drop policy if exists "lecture duels" on public.duels;
create policy "lecture duels" on public.duels for select to authenticated using (auth.uid() in (player_a, player_b));

drop function if exists public._check_deck(uuid, text[]);
-- Un deck : 6 cartes différentes possédées, 1 légendaire et 2 épiques au maximum.
-- Une carte suivie de « * » est jouée en version holo (il faut en posséder un exemplaire holo).
create or replace function public._check_deck(u uuid, p_deck text[]) returns void language plpgsql as $$
declare ids text[];
begin
  ids := array(select rtrim(x, '*') from unnest(p_deck) x);
  if p_deck is null or cardinality(ids) <> 6 or (select count(distinct x) from unnest(ids) x) <> 6 then
    raise exception 'Ton deck doit contenir 6 cartes différentes';
  end if;
  if (select count(distinct ci.card_id) from card_instances ci where ci.owner = u and ci.card_id = any(ids)) <> 6 then
    raise exception 'Ton deck contient une carte que tu ne possèdes plus';
  end if;
  if exists (select 1 from unnest(p_deck) x where x like '%*'
               and not exists (select 1 from card_instances ci where ci.owner = u and ci.card_id = rtrim(x, '*') and ci.holo)) then
    raise exception 'Ton deck contient une holo que tu ne possèdes plus';
  end if;
  p_deck := ids;
  if (select count(*) from cards c where c.id = any(p_deck) and c.rarity = 'L') > 1 then raise exception '1 légendaire maximum par deck'; end if;
  if (select count(*) from cards c where c.id = any(p_deck) and c.rarity = 'E') > 2 then raise exception '2 épiques maximum par deck'; end if;
end $$;

-- Événements du dernier coup : le navigateur les rejoue pour les animations
create or replace function public._du_ev(st jsonb, e jsonb) returns jsonb language sql immutable as $$
  select jsonb_set(st, '{ev}', coalesce(st->'ev', '[]'::jsonb) || jsonb_build_array(e)) $$;
create or replace function public._du_fxev(st jsonb, s int, i int, t text, sub text default null) returns jsonb language sql immutable as $$
  select public._du_ev(st, jsonb_strip_nulls(jsonb_build_object('k', 'fx', 's', s, 'i', i, 't', t, 'sub', sub))) $$;

-- Bonus de niveau selon le type : nombre de fois où la stat k apparaît dans les l premières lettres de la progression du type
create or replace function public._lvl_b(seq text, l int, k text) returns int language sql immutable as $$
  select length(left(coalesce(seq, 'vpvdp'), greatest(0, l))) - length(replace(left(coalesce(seq, 'vpvdp'), greatest(0, l)), k, '')) $$;

drop function if exists public._du_unit(text);
-- Une carte en duel, avec les bonus de niveau de son propriétaire (la progression dépend du type)
create or replace function public._du_unit(cid text, lvl int default 0) returns jsonb language sql stable as $$
  select jsonb_build_object('c', c.id, 'name', c.name, 'type', c.type, 'r', c.rarity, 'art', c.art, 'img', c.image,
    'p', c.p + public._lvl_b(t.lvl, $2, 'p'), 'd', c.d + public._lvl_b(t.lvl, $2, 'd'),
    'hp', c.v + public._lvl_b(t.lvl, $2, 'v'), 'max', c.v + public._lvl_b(t.lvl, $2, 'v'),
    'fx', c.fx, 'lvl', $2,
    'hidden', coalesce(c.fx in ('hidden','absurde'), false), 'reflect', coalesce(c.fx = 'reflect', false),
    'shield', coalesce(c.fx = 'shield', false), 'cb', false, 'holo', false, 'hu', false,
    'stun', 0, 'used', false)
  from public.cards c left join public.types t on t.id = c.type where c.id = cid $$;

create or replace function public._du_get(st jsonb, s int, i int) returns jsonb language sql immutable as $$
  select case when jsonb_typeof(st #> array['sides', s::text, 'active', i::text]) = 'object'
              then st #> array['sides', s::text, 'active', i::text] end $$;

create or replace function public._du_set(st jsonb, s int, i int, u jsonb) returns jsonb language sql immutable as $$
  select jsonb_set(st, array['sides', s::text, 'active', i::text], coalesce(u, 'null'::jsonb)) $$;

create or replace function public._du_log(st jsonb, m text) returns jsonb language sql immutable as $$
  select jsonb_set(st, '{log}', (
    select coalesce(jsonb_agg(x order by o), '[]'::jsonb)
      from jsonb_array_elements(jsonb_build_array(m) || coalesce(st->'log', '[]'::jsonb)) with ordinality t(x, o)
     where o <= 8)) $$;

create or replace function public._du_mult(a text, d text) returns numeric language sql stable as $$
  select coalesce((select mult from public.type_matchups where attacker = a and defender = d), 1) $$;

create or replace function public._du_can_act(st jsonb, s int) returns boolean language sql immutable as $$
  select exists (select 1 from generate_series(0, 2) k
                  where public._du_get(st, s, k) is not null and (public._du_get(st, s, k)->>'stun')::int = 0) $$;

-- Jauge de Hype (pour le Choc viral) : se remplit quand ses cartes encaissent des coups ou tombent
create or replace function public._du_hype(st jsonb, s int, n int) returns jsonb language plpgsql immutable as $$
declare h jsonb := coalesce(st->'hype', '[0,0]'::jsonb); used jsonb := coalesce(st->'cused', '[false,false]'::jsonb);
begin
  if (used->>s)::boolean then return st; end if;
  -- Chaque camp a sa propre « ferveur » tirée au début du duel : la jauge ne se remplit pas au même rythme à chaque partie
  n := round(n * coalesce((st #>> array['hm', s::text])::numeric, 1));
  return jsonb_set(st, '{hype}', jsonb_set(h, array[s::text], to_jsonb(least(100, (h->>s)::int + n))));
end $$;

-- Dégâts sur une carte, avec les effets défensifs (Fake news, Vénère, Remontada)
create or replace function public._du_dmg(st jsonb, s int, i int, n int, crit boolean default false) returns jsonb language plpgsql as $$
declare u jsonb := public._du_get(st, s, i); hp int;
begin
  if u is null or n <= 0 then return st; end if;
  if coalesce((u->>'shield')::boolean, false) then
    st := public._du_set(st, s, i, jsonb_set(u, '{shield}', 'false'));
    st := public._du_log(st, format('Fake news ! « %s » ne subit aucun dégât.', u->>'name'));
    return public._du_fxev(st, s, i, 'Fake news', 'Bloqué');
  end if;
  hp := (u->>'hp')::int - n;
  u := jsonb_set(u, '{hp}', to_jsonb(hp));
  st := public._du_ev(st, jsonb_build_object('k', 'dmg', 's', s, 'i', i, 'n', n, 'crit', crit));
  st := public._du_hype(st, s, n);
  if hp > 0 and u->>'fx' = 'rage' then
    u := jsonb_set(u, '{p}', to_jsonb((u->>'p')::int + 1));
    st := public._du_fxev(st, s, i, 'Vénère', '+1 PUN');
  end if;
  if hp > 0 and hp <= 3 and u->>'fx' = 'remontada' and not coalesce((u->>'cb')::boolean, false) then
    u := jsonb_set(jsonb_set(u, '{cb}', 'true'), '{hp}', to_jsonb(least((u->>'max')::int, hp + 4)));
    st := public._du_log(st, format('Remontada ! « %s » récupère 4 de Viralité.', u->>'name'));
    st := public._du_ev(st, jsonb_build_object('k', 'heal', 's', s, 'i', i, 'n', 4));
    st := public._du_fxev(st, s, i, 'Remontada', '+4 VIR');
  end if;
  return public._du_set(st, s, i, u);
end $$;

create or replace function public._du_heal(st jsonb, s int, i int, n int) returns jsonb language plpgsql as $$
declare u jsonb := public._du_get(st, s, i); g int;
begin
  if u is null or n <= 0 then return st; end if;
  g := least((u->>'max')::int, (u->>'hp')::int + n) - (u->>'hp')::int;
  if g <= 0 then return st; end if;
  st := public._du_set(st, s, i, jsonb_set(u, '{hp}', to_jsonb((u->>'hp')::int + g)));
  return public._du_ev(st, jsonb_build_object('k', 'heal', 's', s, 'i', i, 'n', g));
end $$;

-- Change une stat (p ou d) d'une carte, sans descendre sous 0
create or replace function public._du_stat(st jsonb, s int, i int, k text, n int) returns jsonb language plpgsql as $$
declare u jsonb := public._du_get(st, s, i);
begin
  if u is null then return st; end if;
  return public._du_set(st, s, i, jsonb_set(u, array[k], to_jsonb(greatest(0, (u->>k)::int + n))));
end $$;

-- Effets à l'entrée sur le terrain
create or replace function public._du_enter(st jsonb, s int, i int) returns jsonb language plpgsql as $$
declare u jsonb := public._du_get(st, s, i); fx text; k int; x jsonb; n int; cands int[]; pick int;
begin
  if u is null then return st; end if;
  fx := u->>'fx';
  if fx in ('heal2','heal3') then
    n := case fx when 'heal2' then 2 else 3 end;
    st := public._du_fxev(st, s, i, case fx when 'heal2' then 'Tirade' else 'Aware' end, format('+%s VIR alliés', n));
    for k in 0..2 loop st := public._du_heal(st, s, k, n); end loop;
    st := public._du_log(st, format('« %s » : son camp récupère %s de Viralité.', u->>'name', n));
  elsif fx = 'debuff1' then
    st := public._du_fxev(st, s, i, 'Lâchez vos com''s', '−1 AUR adverses');
    for k in 0..2 loop st := public._du_stat(st, 1 - s, k, 'd', -1); end loop;
    st := public._du_log(st, format('« %s » : le camp adverse perd 1 en Aura.', u->>'name'));
  elsif fx = 'stunall' then
    st := public._du_fxev(st, s, i, 'Fou rire', 'Tout le monde étourdi');
    for k in 0..2 loop
      x := public._du_get(st, 1 - s, k);
      if x is not null then
        st := public._du_set(st, 1 - s, k, jsonb_set(x, '{stun}', '1'));
        st := public._du_ev(st, jsonb_build_object('k', 'stun', 's', 1 - s, 'i', k));
      end if;
    end loop;
    st := public._du_log(st, format('Fou rire ! « %s » étourdit tout le camp adverse.', u->>'name'));
  elsif fx = 'hype' then
    st := public._du_fxev(st, s, i, 'Hype', '+1 PUN alliés');
    for k in 0..2 loop if k <> i then st := public._du_stat(st, s, k, 'p', 1); end if; end loop;
    st := public._du_log(st, format('Hype ! Les alliées de « %s » gagnent +1 en Punchline.', u->>'name'));
  elsif fx = 'landing' then
    cands := array(select g from generate_series(0, 2) g where public._du_get(st, 1 - s, g) is not null and (public._du_get(st, 1 - s, g)->>'hp')::int > 0);
    if cardinality(cands) > 0 then
      pick := cands[1 + floor(random() * cardinality(cands))::int];
      st := public._du_fxev(st, s, i, 'Débarquement', '2 dégâts');
      st := public._du_log(st, format('Débarquement ! « %s » inflige 2 dégâts à « %s ».', u->>'name', public._du_get(st, 1 - s, pick)->>'name'));
      st := public._du_dmg(st, 1 - s, pick, 2);
    end if;
  end if;
  return st;
end $$;

-- Éliminations, remplacements depuis la réserve, et fin de partie
create or replace function public._du_resolve(st jsonb) returns jsonb language plpgsql as $$
declare again boolean := true; s int; i int; k int; u jsonb; x jsonb; nx jsonb; guard int := 0;
begin
  while again and guard < 30 loop
    again := false; guard := guard + 1;
    for s in 0..1 loop
      for i in 0..2 loop
        u := public._du_get(st, s, i);
        if u is not null and (u->>'hp')::int <= 0 then
          st := public._du_log(st, format('« %s » est éliminée.', u->>'name'));
          st := public._du_ev(st, jsonb_build_object('k', 'ko', 's', s, 'i', i));
          st := public._du_set(st, s, i, null);
          st := public._du_hype(st, s, 22);
          if u->>'fx' = 'lastword' then
            st := public._du_fxev(st, s, i, 'Dernier mot', '2 dégâts à tous');
            st := public._du_log(st, format('Dernier mot de « %s » : 2 dégâts à tout le camp adverse.', u->>'name'));
            for k in 0..2 loop
              x := public._du_get(st, 1 - s, k);
              if x is not null and (x->>'hp')::int > 0 then st := public._du_dmg(st, 1 - s, k, 2); end if;
            end loop;
          end if;
          for k in 0..2 loop
            x := public._du_get(st, s, k);
            if x is not null and x->>'fx' = 'seum' then
              st := public._du_stat(st, s, k, 'p', 2);
              st := public._du_fxev(st, s, k, 'Le seum', '+2 PUN');
              st := public._du_log(st, format('Le seum monte : « %s » gagne +2 en Punchline.', x->>'name'));
            end if;
          end loop;
          nx := st #> array['sides', s::text, 'reserve', '0'];
          if jsonb_typeof(nx) = 'object' then
            st := jsonb_set(st, array['sides', s::text, 'reserve'], (st #> array['sides', s::text, 'reserve']) - 0);
            st := public._du_set(st, s, i, nx);
            st := public._du_log(st, format('« %s » entre sur le terrain.', nx->>'name'));
            st := public._du_ev(st, jsonb_build_object('k', 'enter', 's', s, 'i', i));
            st := public._du_enter(st, s, i);
          end if;
          again := true;
        end if;
      end loop;
    end loop;
  end loop;
  for s in 0..1 loop
    if public._du_get(st, s, 0) is null and public._du_get(st, s, 1) is null and public._du_get(st, s, 2) is null
       and jsonb_array_length(st #> array['sides', s::text, 'reserve']) = 0 then
      st := jsonb_set(st, '{winner}', to_jsonb(1 - s));
    end if;
  end loop;
  return st;
end $$;

-- Une attaque de la carte (s, ai) sur la carte adverse ti
create or replace function public._du_attack(st jsonb, s int, ai int, ti int) returns jsonb language plpgsql as $$
declare a jsonb := public._du_get(st, s, ai); t jsonb := public._du_get(st, 1 - s, ti); o int := 1 - s;
        fx text; tfx text; raw int; dmg int; adv boolean; crit boolean := false; shielded boolean; dealt int; holo boolean := false;
        spl int; cands int[]; pick int; x jsonb; alive boolean;
begin
  if a is null or t is null then raise exception 'Coup impossible'; end if;
  if (a->>'stun')::int > 0 then raise exception 'Cette carte est étourdie ce tour-ci'; end if;
  fx := a->>'fx'; tfx := t->>'fx';
  st := public._du_set(st, s, ai, jsonb_set(a, '{hidden}', 'false'));
  adv := public._du_mult(a->>'type', t->>'type') > 1;
  raw := round((a->>'p')::int * public._du_mult(a->>'type', t->>'type'));
  if fx = 'clash' and t->>'r' in ('E','L') then raw := raw + 2; end if;
  if coalesce((a->>'holo')::boolean, false) and not coalesce((a->>'hu')::boolean, false) then
    raw := raw + 3; holo := true;
    st := public._du_set(st, s, ai, jsonb_set(jsonb_set(a, '{hidden}', 'false'), '{hu}', 'true'));
  end if;
  dmg := case when fx in ('pierce','absurde') then greatest(1, raw) else greatest(1, raw - (t->>'d')::int) end;
  if fx = 'crit' and random() < 0.25 then dmg := dmg * 2; crit := true; end if;
  st := public._du_ev(st, jsonb_build_object('k', 'atk', 's', s, 'a', ai, 't', ti, 'adv', adv));
  if holo then
    st := public._du_fxev(st, s, ai, 'Éclat holo', '+3 dégâts');
    st := public._du_log(st, format('Éclat holo de « %s » : +3 dégâts !', a->>'name'));
  end if;
  if crit then
    st := public._du_fxev(st, s, ai, 'Masterclass', 'Dégâts ×2');
    st := public._du_log(st, format('Masterclass de « %s » : dégâts doublés !', a->>'name'));
  end if;
  if fx = 'execute' and (t->>'hp')::int <= 3 then
    dmg := (t->>'hp')::int;
    st := public._du_fxev(st, s, ai, 'Irrévocable', 'Exécution');
    st := public._du_log(st, format('Sentence irrévocable : « %s » est exécutée.', t->>'name'));
  end if;
  -- Ratio : la première attaque subie est renvoyée
  if coalesce((t->>'reflect')::boolean, false) then
    st := public._du_set(st, o, ti, jsonb_set(t, '{reflect}', 'false'));
    st := public._du_fxev(st, o, ti, 'Ratio', 'Renvoyé !');
    st := public._du_log(st, format('Ratio ! « %s » renvoie %s dégât%s à « %s ».', t->>'name', dmg, case when dmg > 1 then 's' else '' end, a->>'name'));
    st := public._du_dmg(st, s, ai, dmg);
    st := jsonb_set(st, '{hit}', jsonb_build_object('s', s, 'i', ai, 'dmg', dmg));
    return public._du_resolve(st);
  end if;
  shielded := coalesce((t->>'shield')::boolean, false);
  st := public._du_log(st, format('« %s » attaque « %s » : −%s%s.', a->>'name', t->>'name', dmg, case when adv then ' (avantage de type)' else '' end));
  st := public._du_dmg(st, o, ti, dmg, crit);
  st := jsonb_set(st, '{hit}', jsonb_build_object('s', o, 'i', ti, 'dmg', case when shielded then 0 else dmg end));
  dealt := case when shielded then 0 else dmg end;
  alive := (public._du_get(st, o, ti)->>'hp')::int > 0;
  if dealt > 0 then
    if fx = 'lifesteal' and dealt >= 2 then
      st := public._du_fxev(st, s, ai, 'Gratte', format('+%s VIR', dealt / 2));
      st := public._du_heal(st, s, ai, dealt / 2);
    end if;
    if fx = 'malaise' and alive then
      st := public._du_stat(st, o, ti, 'p', -1);
      st := public._du_fxev(st, o, ti, 'Malaise', '−1 PUN');
    end if;
    if fx = 'expose' and alive then
      st := public._du_stat(st, o, ti, 'd', -1);
      st := public._du_fxev(st, o, ti, 'Exposé', '−1 AUR');
    end if;
    a := public._du_get(st, s, ai);
    if fx = 'stun' and not (a->>'used')::boolean and alive then
      x := public._du_get(st, o, ti);
      st := public._du_set(st, o, ti, jsonb_set(x, '{stun}', '1'));
      st := public._du_set(st, s, ai, jsonb_set(a, '{used}', 'true'));
      st := public._du_ev(st, jsonb_build_object('k', 'stun', 's', o, 'i', ti));
      st := public._du_fxev(st, s, ai, 'Allô ?', 'Étourdie');
      st := public._du_log(st, format('« %s » est étourdie et passera son tour.', x->>'name'));
    end if;
    if fx = 'doubletap' and alive then
      st := public._du_fxev(st, s, ai, 'Double tap', '+1 dégât');
      st := public._du_dmg(st, o, ti, 1);
    end if;
  end if;
  if tfx = 'thorns' then
    st := public._du_fxev(st, o, ti, 'Piquant', '1 dégât renvoyé');
    st := public._du_dmg(st, s, ai, 1);
  end if;
  if fx = 'buzz' and (public._du_get(st, s, ai)->>'hp')::int > 0 then
    st := public._du_stat(st, s, ai, 'p', 1);
    st := public._du_fxev(st, s, ai, 'Buzz', '+1 PUN');
  end if;
  spl := case fx when 'splash1' then 1 when 'splash2' then 2 else 0 end;
  if spl > 0 then
    cands := array(select k from generate_series(0, 2) k
                    where k <> ti and public._du_get(st, o, k) is not null and (public._du_get(st, o, k)->>'hp')::int > 0);
    if cardinality(cands) > 0 then
      pick := cands[1 + floor(random() * cardinality(cands))::int];
      x := public._du_get(st, o, pick);
      st := public._du_fxev(st, s, ai, case spl when 1 then 'Éclaboussure' else 'Coucou général' end, format('%s dégât%s', spl, case when spl > 1 then 's' else '' end));
      st := public._du_log(st, format('Éclaboussure : « %s » perd %s.', x->>'name', spl));
      st := public._du_dmg(st, o, pick, spl);
    end if;
  end if;
  return public._du_resolve(st);
end $$;

-- Fin du tour : les cartes étourdies du camp qui vient de jouer récupèrent, puis l'autre camp joue
create or replace function public._du_end_turn(st jsonb, s int) returns jsonb language plpgsql as $$
declare k int; x jsonb; n int; c int := s;
begin
  for n in 1..3 loop
    for k in 0..2 loop
      x := public._du_get(st, c, k);
      if x is not null and (x->>'stun')::int > 0 then st := public._du_set(st, c, k, jsonb_set(x, '{stun}', '0')); end if;
    end loop;
    if jsonb_typeof(st->'winner') = 'number' then return st; end if;
    c := 1 - c;
    st := jsonb_set(st, '{turn}', to_jsonb(c));
    if public._du_can_act(st, c) then return st; end if;
    st := public._du_log(st, 'Toutes les cartes de ce camp sont étourdies : tour passé.');
  end loop;
  return st;
end $$;

drop function if exists public._du_start(text[], text[]);
create or replace function public._du_start(da text[], db text[], pa uuid, pb uuid) returns jsonb language plpgsql as $$
declare ua jsonb; ub jsonb; st jsonb; s int; k int; t int := floor(random() * 2)::int;
begin
  select jsonb_agg(public._du_unit(rtrim(x, '*'), public._lvl_of(pa, rtrim(x, '*'))) || jsonb_build_object('holo', x like '%*') order by random()) into ua from unnest(da) x;
  select jsonb_agg(public._du_unit(rtrim(x, '*'), public._lvl_of(pb, rtrim(x, '*'))) || jsonb_build_object('holo', x like '%*') order by random()) into ub from unnest(db) x;
  st := jsonb_build_object(
    'sides', jsonb_build_array(
      jsonb_build_object('active', jsonb_build_array(ua->0, ua->1, ua->2), 'reserve', jsonb_build_array(ua->3, ua->4, ua->5)),
      jsonb_build_object('active', jsonb_build_array(ub->0, ub->1, ub->2), 'reserve', jsonb_build_array(ub->3, ub->4, ub->5))),
    'turn', t, 'log', '[]'::jsonb, 'winner', null, 'hit', null,
    'hype', '[0,0]'::jsonb, 'cused', '[false,false]'::jsonb,
    'hm', jsonb_build_array(round((0.55 + random() * 0.45)::numeric, 2), round((0.55 + random() * 0.45)::numeric, 2)));
  st := public._du_log(st, 'Le duel commence !');
  for s in 0..1 loop for k in 0..2 loop st := public._du_enter(st, s, k); end loop; end loop;
  if not public._du_can_act(st, t) then st := public._du_end_turn(st, t); end if;
  return jsonb_set(st, '{ev}', '[]'::jsonb);
end $$;

-- Récompense : 30 K la victoire, 10 K la défaite, 10 duels récompensés par jour
create or replace function public._duel_gain(p_user uuid, p_won boolean) returns int language plpgsql as $$
declare pr profiles; gain int := 0;
begin
  select * into pr from profiles where id = p_user for update;
  if pr.daily_day is distinct from current_date then
    update profiles set daily_day = current_date, daily_n = 0 where id = p_user;
    pr.daily_n := 0;
  end if;
  if p_won then update profiles set wins = wins + 1 where id = p_user;
  else update profiles set losses = losses + 1 where id = p_user; end if;
  if pr.daily_n < 10 then
    gain := case when p_won then 30 else 10 end;
    update profiles set daily_n = daily_n + 1 where id = p_user;
    perform _move_kheys(p_user, gain, 'duel', case when p_won then 'victoire' else 'defaite' end);
  end if;
  return gain;
end $$;

create or replace function public._du_finish(p_id bigint, p_winner int) returns void language plpgsql as $$
declare d duels; w uuid; l uuid;
begin
  select * into d from duels where id = p_id for update;
  if d.status <> 'active' then return; end if;
  w := case when p_winner = 0 then d.player_a else d.player_b end;
  l := case when p_winner = 0 then d.player_b else d.player_a end;
  update duels set status = 'finished', winner = w, updated_at = now(),
         state = jsonb_set(state, '{winner}', to_jsonb(p_winner)),
         gain_a = public._duel_gain(d.player_a, w = d.player_a),
         gain_b = public._duel_gain(d.player_b, w = d.player_b)
   where id = p_id;
  -- Butin : le gagnant pourra prendre une carte face cachée du deck adverse (à chaque victoire en ligne, sans limite)
  update duels set state = jsonb_set(state, '{prize}', jsonb_build_object('w', p_winner, 'got', null)) where id = p_id;
end $$;

-- Le gagnant retourne une des 6 cartes du deck adverse et la prend au perdant.
-- En réalité le tirage se fait ici, pondéré par la rareté : légendaire très rare, épique rare.
-- On ne prend qu'un exemplaire libre (ni en vente ni dans un échange) ; la version holo si elle a été jouée.
create or replace function public.duel_prize(p_duel bigint, p_pick int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int; pz jsonb; deck text[]; loser uuid; got text; want_holo boolean; inst bigint; others jsonb; stolen boolean := true;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'finished' then raise exception 'Duel introuvable'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  pz := d.state->'prize';
  if pz is null or (pz->>'w')::int <> me then raise exception 'Pas de carte à gagner'; end if;
  if jsonb_typeof(pz->'got') = 'string' then raise exception 'Tu as déjà choisi ta carte'; end if;
  loser := case when me = 0 then d.player_b else d.player_a end;
  deck := case when me = 0 then d.deck_b else d.deck_a end;
  -- Cartes du deck dont le perdant possède encore un exemplaire libre
  select c.id, x like '%*' into got, want_holo
    from unnest(deck) x join cards c on c.id = rtrim(x, '*')
   where exists (select 1 from card_instances ci where ci.owner = loser and ci.card_id = c.id and ci.lock is null)
   order by -ln(1 - random()) / (case c.rarity when 'L' then 1 when 'E' then 6 when 'R' then 30 else 60 end) limit 1;
  if got is null then
    -- Le perdant n'a plus aucune de ces cartes : le gagnant reçoit quand même une copie
    stolen := false;
    select c.id into got from unnest(deck) x join cards c on c.id = rtrim(x, '*')
     order by -ln(1 - random()) / (case c.rarity when 'L' then 1 when 'E' then 6 when 'R' then 30 else 60 end) limit 1;
    insert into card_instances(card_id, owner) values (got, u);
  else
    select ci.id into inst from card_instances ci
     where ci.owner = loser and ci.card_id = got and ci.lock is null
     order by (ci.holo = want_holo) desc, ci.obtained_at limit 1 for update;
    update card_instances set owner = u, obtained_at = now() where id = inst;
    -- La carte volée garde ses améliorations : le gagnant prend au moins le niveau du perdant
    if _lvl_of(loser, got) > 0 then
      insert into card_levels(owner, card_id, level) values (u, got, _lvl_of(loser, got))
        on conflict (owner, card_id) do update set level = greatest(card_levels.level, excluded.level);
      -- Si le perdant n'a plus aucun exemplaire, il perd aussi les améliorations
      if not exists (select 1 from card_instances where owner = loser and card_id = got) then
        delete from card_levels where owner = loser and card_id = got;
      end if;
    end if;
  end if;
  select coalesce(jsonb_agg(z.x order by random()), '[]'::jsonb) into others
    from (select rtrim(x, '*') x from unnest(deck) x where rtrim(x, '*') <> got) z;
  pz := jsonb_build_object('w', me, 'got', got, 'pick', p_pick, 'others', others, 'stolen', stolen);
  update duels set state = jsonb_set(state, '{prize}', pz), updated_at = now() where id = p_duel;
  return pz;
end $$;

create or replace function public._du_expire() returns void language sql as $$
  update public.duels set status = 'cancelled', updated_at = now()
   where (status = 'waiting' and updated_at < now() - interval '30 seconds')
      or (status = 'invited' and created_at < now() - interval '10 minutes') $$;

-- Chercher un adversaire au hasard : rejoint un joueur qui attend, sinon se met en attente
create or replace function public.duel_find(p_deck text[]) returns bigint
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; nid bigint;
begin
  perform _check_deck(u, p_deck);
  perform _du_expire();
  if exists (select 1 from duels where status = 'active' and u in (player_a, player_b)) then
    raise exception 'Tu as déjà un duel en cours';
  end if;
  update duels set status = 'cancelled', updated_at = now() where player_a = u and status = 'waiting';
  select * into d from duels
   where status = 'waiting' and player_a <> u
   order by created_at for update skip locked limit 1;
  if found then
    update duels set player_b = u, deck_b = p_deck, status = 'active', state = _du_start(d.deck_a, p_deck, d.player_a, u),
           move_no = 1, turn_started_at = now(), updated_at = now()
     where id = d.id;
    return d.id;
  end if;
  insert into duels(player_a, mode, status, deck_a) values (u, 'random', 'waiting', p_deck) returning id into nid;
  return nid;
end $$;

-- Défier un ami
create or replace function public.duel_challenge(p_friend uuid, p_deck text[]) returns bigint
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); nid bigint;
begin
  perform _check_deck(u, p_deck);
  perform _du_expire();
  if not _are_friends(u, p_friend) then raise exception 'Vous devez être amis pour vous défier'; end if;
  if exists (select 1 from duels where status in ('invited','active')
              and ((player_a = u and player_b = p_friend) or (player_a = p_friend and player_b = u))) then
    raise exception 'Un défi est déjà en cours avec ce joueur';
  end if;
  insert into duels(player_a, player_b, mode, status, deck_a) values (u, p_friend, 'friend', 'invited', p_deck) returning id into nid;
  return nid;
end $$;

create or replace function public.duel_accept(p_duel bigint, p_deck text[]) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels;
begin
  perform _check_deck(u, p_deck);
  perform _du_expire();
  select * into d from duels where id = p_duel for update;
  if not found or d.player_b <> u or d.status <> 'invited' then raise exception 'Ce défi n''est plus valable'; end if;
  if exists (select 1 from duels where status = 'active' and u in (player_a, player_b)) then
    raise exception 'Tu as déjà un duel en cours';
  end if;
  update duels set deck_b = p_deck, status = 'active', state = _du_start(d.deck_a, p_deck, d.player_a, u),
         move_no = 1, turn_started_at = now(), updated_at = now()
   where id = p_duel;
end $$;

-- Annuler une recherche, retirer un défi ou le refuser
create or replace function public.duel_cancel(p_duel bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid();
begin
  update duels set status = 'cancelled', updated_at = now()
   where id = p_duel and status in ('waiting','invited') and u in (player_a, player_b);
end $$;

-- Suivi d'un duel : signale que le joueur est toujours là et renvoie l'état
create or replace function public.duel_poll(p_duel bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels;
begin
  update profiles set last_seen = now() where id = u;
  update duels set updated_at = now() where id = p_duel and status = 'waiting' and player_a = u;
  if exists (select 1 from duels where id = p_duel and status = 'active' and state ? 'choc' and u in (player_a, player_b)) then perform _du_choc_try(p_duel); end if;
  select * into d from duels where id = p_duel and u in (player_a, player_b);
  if not found then raise exception 'Duel introuvable'; end if;
  return to_jsonb(d);
end $$;

-- Jouer un coup : la carte n° p_a attaque la carte adverse n° p_t (0, 1 ou 2)
create or replace function public.duel_play(p_duel bigint, p_a int, p_t int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int; st jsonb;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  if (d.state->>'turn')::int <> me then raise exception 'Ce n''est pas ton tour'; end if;
  if d.state ? 'choc' then raise exception 'Un Choc viral est en cours'; end if;
  if p_a not between 0 and 2 or p_t not between 0 and 2 then raise exception 'Coup impossible'; end if;
  st := _du_attack(jsonb_set(d.state, '{ev}', '[]'::jsonb), me, p_a, p_t);
  st := _du_end_turn(st, me);
  update duels set state = st, move_no = move_no + 1, turn_started_at = now(), updated_at = now() where id = p_duel;
  update profiles set last_seen = now() where id = u;
  if jsonb_typeof(st->'winner') = 'number' then perform _du_finish(p_duel, (st->>'winner')::int); end if;
  return (select to_jsonb(x) from duels x where id = p_duel);
end $$;

-- ---------------------------------------------------------------------
-- Choc viral : quand sa jauge de Hype est pleine, un joueur lance une confrontation.
-- Les deux joueurs secouent leur téléphone pendant 3 secondes ; le plus fort gagne.
-- Attaquant gagnant : la carte ciblée est pulvérisée. Sinon : choc bloqué, la carte de l'attaquant perd 2.
-- ---------------------------------------------------------------------
create or replace function public.duel_choc(p_duel bigint, p_a int, p_t int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int; st jsonb; a jsonb; t jsonb;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  st := d.state;
  if (st->>'turn')::int <> me then raise exception 'Ce n''est pas ton tour'; end if;
  if st ? 'choc' then raise exception 'Un choc est déjà en cours'; end if;
  if coalesce((st #>> array['cused', me::text])::boolean, false) then raise exception 'Tu as déjà utilisé ton Choc viral'; end if;
  if coalesce((st #>> array['hype', me::text])::int, 0) < 100 then raise exception 'Ta jauge de Hype n''est pas encore pleine'; end if;
  if p_a not between 0 and 2 or p_t not between 0 and 2 then raise exception 'Coup impossible'; end if;
  a := _du_get(st, me, p_a); t := _du_get(st, 1 - me, p_t);
  if a is null or t is null then raise exception 'Coup impossible'; end if;
  if (a->>'stun')::int > 0 then raise exception 'Cette carte est étourdie ce tour-ci'; end if;
  st := jsonb_set(st, '{cused}', jsonb_set(coalesce(st->'cused', '[false,false]'::jsonb), array[me::text], 'true'));
  st := jsonb_set(st, '{hype}', jsonb_set(coalesce(st->'hype', '[0,0]'::jsonb), array[me::text], '0'));
  st := jsonb_set(st, '{choc}', jsonb_build_object('by', me, 'a', p_a, 't', p_t, 'at', extract(epoch from now()), 'sc', '[null,null]'::jsonb));
  st := jsonb_set(st, '{ev}', jsonb_build_array(jsonb_build_object('k', 'chocstart', 's', me, 'a', p_a, 't', p_t)));
  st := _du_log(st, format('CHOC VIRAL ! « %s » défie « %s ».', a->>'name', t->>'name'));
  update duels set state = st, move_no = move_no + 1, turn_started_at = now(), updated_at = now() where id = p_duel;
  return (select to_jsonb(x) from duels x where id = p_duel);
end $$;

-- Applique le résultat d'un choc (win : l'attaquant gagne) puis passe le tour
create or replace function public._du_choc_apply(p_id bigint, win boolean, info jsonb) returns void language plpgsql as $$
declare d duels; st jsonb; c jsonb; who int; t jsonb;
begin
  select * into d from duels where id = p_id for update;
  st := d.state; c := st->'choc'; who := (c->>'by')::int;
  st := jsonb_set(st - 'choc', '{ev}', jsonb_build_array(jsonb_build_object('k', 'choc', 's', who, 'a', (c->>'a')::int, 't', (c->>'t')::int, 'win', win) || info));
  if win then
    t := _du_get(st, 1 - who, (c->>'t')::int);
    if t is not null then
      st := _du_log(st, format('Choc viral réussi : « %s » est pulvérisée !', t->>'name'));
      st := _du_ev(st, jsonb_build_object('k', 'dmg', 's', 1 - who, 'i', (c->>'t')::int, 'n', greatest(1, (t->>'hp')::int), 'crit', true));
      st := _du_set(st, 1 - who, (c->>'t')::int, jsonb_set(t, '{hp}', '0'));
    end if;
  else
    st := _du_log(st, 'Choc bloqué ! L''attaquante encaisse le contrecoup.');
    st := _du_dmg(st, who, (c->>'a')::int, 2);
  end if;
  st := _du_resolve(st);
  st := _du_end_turn(st, who);
  update duels set state = st, move_no = move_no + 1, turn_started_at = now(), updated_at = now() where id = p_id;
  if jsonb_typeof(st->'winner') = 'number' then perform _du_finish(p_id, (st->>'winner')::int); end if;
end $$;

-- Résout le choc si les deux scores sont arrivés, ou si le temps est écoulé (25 s : score manquant = 0).
-- Égalité : l'attaquant doit reproduire un rythme de secousses (ex. 1-2-2-1), 20 s maximum.
create or replace function public._du_choc_try(p_id bigint) returns void language plpgsql as $$
declare d duels; st jsonb; c jsonb; who int; sa int; sd int; pat jsonb;
begin
  select * into d from duels where id = p_id for update;
  if not found or d.status <> 'active' or not (d.state ? 'choc') then return; end if;
  st := d.state; c := st->'choc'; who := (c->>'by')::int;
  if c->>'phase' = 'pattern' then
    if extract(epoch from now()) - (c->>'pat_at')::numeric >= 20 then
      perform _du_choc_apply(p_id, false, jsonb_build_object('sa', (c->>'sa')::int, 'sd', (c->>'sd')::int, 'tie', true, 'pat', false));
    end if;
    return;
  end if;
  if jsonb_typeof(c #> array['sc', '0']) = 'null' or jsonb_typeof(c #> array['sc', '1']) = 'null' then
    if extract(epoch from now()) - (c->>'at')::numeric < 25 then return; end if;
  end if;
  sa := coalesce((c #>> array['sc', who::text])::int, 0);
  sd := coalesce((c #>> array['sc', (1 - who)::text])::int, 0);
  if sa = sd and sa >= 15 then
    -- Égalité : place au rythme
    select jsonb_agg(1 + floor(random() * 3)::int) into pat from generate_series(1, 4);
    c := c || jsonb_build_object('phase', 'pattern', 'pat', pat, 'pat_at', extract(epoch from now()), 'sa', sa, 'sd', sd);
    st := jsonb_set(st, '{choc}', c);
    st := jsonb_set(st, '{ev}', jsonb_build_array(jsonb_build_object('k', 'choctie', 's', who, 'sa', sa, 'sd', sd)));
    st := _du_log(st, format('Égalité au Choc viral (%s partout) : place au rythme !', sa));
    update duels set state = st, move_no = move_no + 1, turn_started_at = now(), updated_at = now() where id = p_id;
    return;
  end if;
  perform _du_choc_apply(p_id, sa >= 15 and sa > sd, jsonb_build_object('sa', sa, 'sd', sd));
end $$;

-- Égalité : l'attaquant envoie le résultat de son rythme
create or replace function public.duel_choc_pattern(p_duel bigint, p_ok boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int; c jsonb;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  c := d.state->'choc';
  if c is null or c->>'phase' is distinct from 'pattern' or (c->>'by')::int <> me then raise exception 'Pas de rythme à faire'; end if;
  perform _du_choc_apply(p_duel, coalesce(p_ok, false), jsonb_build_object('sa', (c->>'sa')::int, 'sd', (c->>'sd')::int, 'tie', true, 'pat', coalesce(p_ok, false)));
  return (select to_jsonb(x) from duels x where id = p_duel);
end $$;

-- Envoyer son score de secousse (0 à 100)
create or replace function public.duel_choc_score(p_duel bigint, p_score int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  if d.state ? 'choc' and d.state->'choc'->>'phase' is null and jsonb_typeof(d.state #> array['choc', 'sc', me::text]) = 'null' then
    update duels set state = jsonb_set(state, array['choc', 'sc', me::text], to_jsonb(least(100, greatest(0, coalesce(p_score, 0))))), updated_at = now()
     where id = p_duel;
  end if;
  perform _du_choc_try(p_duel);
  return (select to_jsonb(x) from duels x where id = p_duel);
end $$;

-- Abandonner
create or replace function public.duel_forfeit(p_duel bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  update duels set state = public._du_log(state, 'Abandon.') where id = p_duel;
  perform _du_finish(p_duel, 1 - me);
end $$;

-- Gagner par forfait si l'adversaire ne joue plus depuis 90 secondes
create or replace function public.duel_claim(p_duel bigint) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; me int;
begin
  select * into d from duels where id = p_duel for update;
  if not found or d.status <> 'active' then raise exception 'Ce duel est terminé'; end if;
  me := case when u = d.player_a then 0 when u = d.player_b then 1 else null end;
  if me is null then raise exception 'Duel introuvable'; end if;
  if (d.state->>'turn')::int = me then raise exception 'C''est à toi de jouer'; end if;
  if d.state ? 'choc' then raise exception 'Un Choc viral est en cours'; end if;
  if d.turn_started_at > now() - interval '90 seconds' then raise exception 'Ton adversaire a encore le temps de jouer'; end if;
  update duels set state = public._du_log(state, 'Victoire par forfait : l''adversaire ne joue plus.') where id = p_duel;
  perform _du_finish(p_duel, me);
end $$;

-- ---------------------------------------------------------------------
-- 9. Administration
-- ---------------------------------------------------------------------
-- Renumérote les cartes 1, 2, 3… sans trou (après une suppression)
create or replace function public._renumber_cards() returns void language sql as $$
  update public.cards c set n = x.rn
    from (select id, row_number() over (order by n, id) as rn from public.cards) x
   where c.id = x.id and c.n <> x.rn $$;
select public._renumber_cards();
-- ---------------------------------------------------------------------
create or replace function public.set_admin(p_pseudo text, p_admin boolean) returns void
language plpgsql security definer set search_path = public as $$
declare o profiles;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  select * into o from profiles where lower(pseudo) = lower(trim(p_pseudo)) for update;
  if not found then raise exception 'Aucun joueur ne s''appelle « % »', trim(p_pseudo); end if;
  if not p_admin and o.is_admin and (select count(*) from profiles where is_admin) <= 1 then
    raise exception 'Il doit rester au moins un administrateur';
  end if;
  update profiles set is_admin = p_admin where id = o.id;
end $$;

-- Supprime une carte du jeu : les exemplaires disparaissent des collections,
-- leurs propriétaires récupèrent la valeur de défausse, les ventes et échanges liés sont annulés.
create or replace function public.delete_card(p_id text) returns int
language plpgsql security definer set search_path = public as $$
declare t trades; r record; n int := 0;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if not exists (select 1 from cards where id = p_id) then raise exception 'Carte introuvable'; end if;
  for t in select tr.* from trades tr
            where tr.status in ('open','countered')
              and exists (select 1 from trade_items ti join card_instances ci on ci.id = ti.instance_id
                           where ti.trade_id = tr.id and ci.card_id = p_id)
            for update of tr loop
    perform _close_trade(t, 'cancelled');
  end loop;
  update duels set status = 'cancelled', updated_at = now()
   where status in ('waiting','invited') and (p_id = any(deck_a) or p_id = any(coalesce(deck_b, '{}')));
  for r in select ci.owner, sum(_rarity_value(c.rarity) * (case when ci.holo then 3 else 1 end))::int as val, count(*)::int as nb
             from card_instances ci join cards c on c.id = ci.card_id
            where ci.card_id = p_id group by ci.owner loop
    perform _move_kheys(r.owner, r.val, 'carte_supprimee', p_id);
    n := n + r.nb;
  end loop;
  delete from card_instances where card_id = p_id;
  delete from cards where id = p_id;
  perform _renumber_cards();
  return n;
end $$;

-- ---------------------------------------------------------------------
-- 11. Progression : niveaux de cartes et albums
-- ---------------------------------------------------------------------
alter table public.card_levels enable row level security;
drop policy if exists "lecture niveaux" on public.card_levels;
create policy "lecture niveaux" on public.card_levels for select to authenticated using (true);

-- Fusionne des doubles pour faire monter une carte d'une étoile.
-- On ne prend jamais les holos, ni les cartes en vente ou dans un échange, et on garde toujours au moins un exemplaire.
create or replace function public.upgrade_card(p_card text) returns int
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); lvl int; cost int; total int; fuel int;
begin
  perform 1 from profiles where id = u for update;
  lvl := _lvl_of(u, p_card);
  if lvl >= 5 then raise exception 'Cette carte est déjà au niveau maximum'; end if;
  cost := _lvl_cost(lvl + 1);
  select count(*) into total from card_instances where owner = u and card_id = p_card;
  select count(*) into fuel from card_instances where owner = u and card_id = p_card and not holo and lock is null;
  fuel := least(fuel, total - 1);
  if fuel < cost then raise exception 'Il te faut % double% de cette carte (hors holos et cartes en vente)', cost, case when cost > 1 then 's' else '' end; end if;
  delete from card_instances where id in (
    select id from card_instances where owner = u and card_id = p_card and not holo and lock is null
     order by obtained_at desc limit cost);
  insert into card_levels(owner, card_id, level) values (u, p_card, lvl + 1)
    on conflict (owner, card_id) do update set level = excluded.level;
  -- Améliorer rapporte un peu de Kheys : 0,6 × la valeur de défausse × le nouveau niveau (épique niveau 1 = 30 K)
  perform _move_kheys(u, round(_rarity_value((select rarity from cards where id = p_card)) * (lvl + 1) * 0.6)::int, 'amelioration', p_card);
  return lvl + 1;
end $$;

-- Albums : avoir toutes les cartes d'un type (ou toutes les cartes du jeu, p_type = '*') rapporte des Kheys, une seule fois.
create table if not exists public.album_claims (
  owner      uuid not null references public.profiles(id) on delete cascade,
  album      text not null,
  reward     int  not null,
  claimed_at timestamptz not null default now(),
  primary key (owner, album)
);
alter table public.album_claims enable row level security;
drop policy if exists "lecture albums" on public.album_claims;
create policy "lecture albums" on public.album_claims for select to authenticated using (owner = auth.uid());

create or replace function public._album_reward(p_type text) returns int language sql stable as $$
  select case when p_type = '*' then 3000
              else least(1500, greatest(150, 15 * (select count(*) from public.cards where type = p_type and active)))::int end $$;

create or replace function public.claim_album(p_type text) returns int
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); total int; missing int; rw int;
begin
  perform 1 from profiles where id = u for update;
  if exists (select 1 from album_claims where owner = u and album = p_type) then raise exception 'Récompense déjà récupérée'; end if;
  select count(*), count(*) filter (where not exists (select 1 from card_instances ci where ci.owner = u and ci.card_id = c.id))
    into total, missing from cards c where c.active and (p_type = '*' or c.type = p_type);
  if total = 0 then raise exception 'Album introuvable'; end if;
  if missing > 0 then raise exception 'Il te manque encore % carte%', missing, case when missing > 1 then 's' else '' end; end if;
  rw := _album_reward(p_type);
  insert into album_claims(owner, album, reward) values (u, p_type, rw);
  perform _move_kheys(u, rw, 'album', p_type);
  return rw;
end $$;


-- ---------------------------------------------------------------------
-- 9 bis. Page perso (vitrine de 4 cartes) et suppression de joueurs
-- ---------------------------------------------------------------------
-- Vitrine : 4 cartes maximum, qu'on possède ; « id* » = la version holo
create or replace function public.set_showcase(p_cards text[]) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); x text;
begin
  p_cards := coalesce(p_cards, '{}');
  if cardinality(p_cards) > 4 then raise exception '4 cartes maximum'; end if;
  if (select count(distinct rtrim(v, '*')) from unnest(p_cards) v) <> cardinality(p_cards) then raise exception 'Une carte en double'; end if;
  foreach x in array p_cards loop
    if not exists (select 1 from card_instances where owner = u and card_id = rtrim(x, '*') and (x not like '%*' or holo)) then
      raise exception 'Tu ne possèdes pas cette carte';
    end if;
  end loop;
  update profiles set showcase = p_cards where id = u;
end $$;

-- Infos de la page perso d'un joueur (sans dévoiler sa collection)
create or replace function public.player_page(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr profiles; r jsonb;
begin
  if public._uid() is null then raise exception 'Connecte-toi'; end if;
  select * into pr from profiles where id = p_user;
  if not found then raise exception 'Joueur introuvable'; end if;
  if p_user <> public._uid() and not _are_friends(public._uid(), p_user) then raise exception 'Ajoute ce joueur en ami pour voir sa page'; end if;
  select jsonb_build_object(
    'distinct', count(distinct ci.card_id),
    'total', count(ci.id),
    'holos', count(ci.id) filter (where ci.holo),
    'legendaires', count(distinct ci.card_id) filter (where c.rarity = 'L'),
    'album', (select count(*) from cards where active),
    'albums', (select count(*) from album_claims where owner = p_user),
    'since', pr.created_at)
    into r
    from card_instances ci join cards c on c.id = ci.card_id
   where ci.owner = p_user;
  -- La vitrine ne garde que les cartes encore possédées
  r := r || jsonb_build_object('showcase', coalesce((select jsonb_agg(v order by o) from unnest(pr.showcase) with ordinality s(v, o)
         where exists (select 1 from card_instances where owner = p_user and card_id = rtrim(v, '*') and (v not like '%*' or holo))), '[]'::jsonb));
  return r;
end $$;

-- Supprimer un joueur (admin) : ses échanges en cours sont annulés proprement, puis tout son compte est effacé
create or replace function public.admin_delete_user(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t trades;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if p_user = public._uid() then raise exception 'Tu ne peux pas supprimer ton propre compte'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'Joueur introuvable'; end if;
  if (select is_admin from profiles where id = p_user) and (select count(*) from profiles where is_admin) <= 1 then
    raise exception 'Il doit rester au moins un administrateur';
  end if;
  for t in select * from trades where status in ('open','countered') and p_user in (from_user, to_user) for update loop
    perform _close_trade(t, 'cancelled');
  end loop;
  update duels set status = 'cancelled', updated_at = now()
   where status in ('waiting','invited','active') and p_user in (player_a, player_b);
  delete from profiles where id = p_user;
  begin
    delete from auth.users where id = p_user;
  exception when others then null;   -- si le compte de connexion ne peut pas être effacé ici, le profil l'est quand même
  end;
end $$;


-- ---------------------------------------------------------------------
-- 9 ter. Regarder les duels de ses amis et talkie-walkie
-- ---------------------------------------------------------------------
-- Duels en cours de mes amis (pour les regarder)
create or replace function public.live_duels() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'a', d.player_a, 'b', d.player_b, 'at', d.updated_at) order by d.updated_at desc), '[]'::jsonb)
    from duels d
   where d.status = 'active' and auth.uid() not in (d.player_a, d.player_b)
     and (public._are_friends(auth.uid(), d.player_a) or public._are_friends(auth.uid(), d.player_b)) $$;

-- Regarder un duel (spectateur) : réservé aux amis d'un des deux joueurs
create or replace function public.duel_watch(p_duel bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels;
begin
  update profiles set last_seen = now() where id = u;
  select * into d from duels where id = p_duel;
  if not found or d.status not in ('active','finished') then raise exception 'Ce duel est terminé'; end if;
  if u not in (d.player_a, coalesce(d.player_b, u)) and not _are_friends(u, d.player_a) and not _are_friends(u, d.player_b) then
    raise exception 'Tu peux seulement regarder les duels de tes amis';
  end if;
  return to_jsonb(d) - 'deck_a' - 'deck_b';
end $$;

-- Talkie-walkie : messages vocaux courts envoyés pendant un duel
create table if not exists public.duel_voice (
  id         bigint generated always as identity primary key,
  duel_id    bigint not null references public.duels(id) on delete cascade,
  sender     uuid not null references public.profiles(id) on delete cascade,
  url        text not null,
  dur        real not null default 0,
  created_at timestamptz not null default now()
);
-- Les deux joueurs du duel, recopiés ici pour que les spectateurs (amis) puissent lire les messages
alter table public.duel_voice add column if not exists pa uuid;
alter table public.duel_voice add column if not exists pb uuid;
create index if not exists duel_voice_duel_idx on public.duel_voice(duel_id, id);
alter table public.duel_voice enable row level security;
drop policy if exists "lecture voix" on public.duel_voice;
create policy "lecture voix" on public.duel_voice for select to authenticated using (
  auth.uid() in (pa, pb)
  or exists (select 1 from public.friendships f where f.status = 'accepted'
              and ((f.requester = auth.uid() and f.addressee in (pa, pb))
                or (f.addressee = auth.uid() and f.requester in (pa, pb)))));

create or replace function public.duel_voice_send(p_duel bigint, p_url text, p_dur real) returns bigint
language plpgsql security definer set search_path = public as $$
declare u uuid := public._uid(); d duels; nid bigint;
begin
  select * into d from duels where id = p_duel;
  if not found or u not in (d.player_a, d.player_b) then raise exception 'Duel introuvable'; end if;
  if d.status not in ('active','finished') then raise exception 'Le duel est terminé'; end if;
  if p_url !~ ('/storage/v1/object/public/voix/' || u::text || '/') then raise exception 'Message invalide'; end if;
  if exists (select 1 from duel_voice where sender = u and created_at > now() - interval '2 seconds') then raise exception 'Doucement !'; end if;
  if (select count(*) from duel_voice where duel_id = p_duel and sender = u) >= 60 then raise exception 'Trop de messages dans ce duel'; end if;
  insert into duel_voice(duel_id, sender, url, dur, pa, pb)
  values (p_duel, u, p_url, least(greatest(coalesce(p_dur, 0), 0), 10), d.player_a, d.player_b) returning id into nid;
  return nid;
end $$;

do $voix$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public) values ('voix', 'voix', true)
      on conflict (id) do update set public = true;
    execute 'drop policy if exists "voix ajout" on storage.objects';
    execute $p$create policy "voix ajout" on storage.objects for insert to authenticated
      with check (bucket_id = 'voix' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
  end if;
end $voix$;

-- ---------------------------------------------------------------------
-- 10. Droits : seules les fonctions publiques sont appelables
-- ---------------------------------------------------------------------
do $droits$
declare f record;
begin
  -- Fonctions internes (nom commençant par _) : personne ne peut les appeler directement
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname like '\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $droits$;

revoke all on function public.create_profile(text), public.my_profile(), public.open_booster(boolean),
  public.discard_card(bigint), public.list_card(bigint,int), public.cancel_listing(bigint), public.buy_listing(bigint),
  public.propose_trade(uuid,bigint[],bigint[],int,int), public.respond_trade(bigint,boolean), public.cancel_trade(bigint),
  public.friend_request(text), public.friend_respond(bigint,boolean), public.friend_remove(uuid),
  public.duel_find(text[]), public.duel_challenge(uuid,text[]), public.duel_accept(bigint,text[]), public.duel_cancel(bigint),
  public.duel_poll(bigint), public.duel_play(bigint,int,int), public.duel_forfeit(bigint), public.duel_claim(bigint),
  public.set_admin(text,boolean), public.delete_card(text), public.upgrade_card(text), public.claim_album(text),
  public.duel_choc(bigint,int,int), public.duel_choc_score(bigint,int), public.duel_choc_pattern(bigint,boolean), public.duel_prize(bigint,int),
  public.counter_trade(bigint,bigint[],int), public.set_showcase(text[]), public.player_page(uuid), public.admin_delete_user(uuid),
  public.live_duels(), public.duel_watch(bigint), public.duel_voice_send(bigint,text,real)
  from public, anon;
grant execute on function public.create_profile(text), public.my_profile(), public.open_booster(boolean),
  public.discard_card(bigint), public.list_card(bigint,int), public.cancel_listing(bigint), public.buy_listing(bigint),
  public.propose_trade(uuid,bigint[],bigint[],int,int), public.respond_trade(bigint,boolean), public.cancel_trade(bigint),
  public.friend_request(text), public.friend_respond(bigint,boolean), public.friend_remove(uuid),
  public.duel_find(text[]), public.duel_challenge(uuid,text[]), public.duel_accept(bigint,text[]), public.duel_cancel(bigint),
  public.duel_poll(bigint), public.duel_play(bigint,int,int), public.duel_forfeit(bigint), public.duel_claim(bigint),
  public.set_admin(text,boolean), public.delete_card(text), public.upgrade_card(text), public.claim_album(text),
  public.duel_choc(bigint,int,int), public.duel_choc_score(bigint,int), public.duel_choc_pattern(bigint,boolean), public.duel_prize(bigint,int),
  public.counter_trade(bigint,bigint[],int), public.set_showcase(text[]), public.player_page(uuid), public.admin_delete_user(uuid),
  public.live_duels(), public.duel_watch(bigint), public.duel_voice_send(bigint,text,real)
  to authenticated;
