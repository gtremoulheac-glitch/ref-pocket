-- =====================================================================
-- Génération 2 : notes cohérentes avec la rareté
-- Note affichée = 50 + 3 × (Punchline + Aura + Viralité), donc la somme des stats fixe la note :
--   Commune 6 à 8 (note 68-74) · Rare 9 à 11 (77-83) · Épique 12 à 14 (86-92) · Légendaire 15 à 17 (95-99)
--
-- Pour chaque carte de la Gén. 2 :
--   - la somme visée est tirée dans la fourchette de sa rareté (toujours la même pour une carte donnée,
--     d'après son identifiant), pour que toutes les cartes n'aient pas la même note ;
--   - si tu avais déjà réglé ses stats à la main (autre chose que 2/2/3), on garde leurs proportions ;
--   - sinon, la répartition suit sa compétence : Feat / Bad buzz / Cancel misent sur la Punchline ou l'Aura,
--     Ghosting sur l'Aura, En direct / Abonne-toi sur la Viralité.
-- Sont modifiées : les cartes hors de leur fourchette et celles restées aux stats par défaut (2/2/3). À coller dans Supabase > SQL Editor > Run.
-- =====================================================================
do $notes$
declare
  c record; lo int; hi int; tot int; w numeric[]; sh numeric[]; st int[]; fr numeric[]; rest int; k int; j int; best int; n int := 0;
begin
  for c in select * from public.cards where gen = 2 order by id loop
    lo := case c.rarity when 'C' then 6 when 'R' then 9 when 'E' then 12 else 15 end;
    hi := lo + 2;
    -- déjà cohérente et réglée à la main : on n'y touche pas (les 2/2/3 par défaut sont redistribuées)
    continue when c.p + c.d + c.v between lo and hi and (c.p, c.d, c.v) <> (2, 2, 3);
    tot := lo + (('x' || substr(md5(c.id), 1, 8))::bit(32)::bigint % 3)::int;
    if (c.p, c.d, c.v) <> (2, 2, 3) then
      w := array[greatest(c.p, 1), greatest(c.d, 1), greatest(c.v, 1)];   -- stats réglées à la main : même profil
    else
      w := case c.fx
        when 'feat'    then array[4, 2, 3]   -- attaquant
        when 'badbuzz' then array[4, 3, 2]
        when 'cancel'  then array[3, 4, 2]
        when 'ghost'   then array[2, 4, 3]   -- esquive : solide
        when 'live'    then array[2, 3, 4]   -- se soigne : beaucoup de Viralité
        when 'abonne'  then array[3, 2, 4]
        else array[3, 3, 3] end;
    end if;
    -- répartition proportionnelle, arrondie sans changer le total
    sh := array[tot * w[1] / (w[1] + w[2] + w[3]), tot * w[2] / (w[1] + w[2] + w[3]), tot * w[3] / (w[1] + w[2] + w[3])];
    st := array[floor(sh[1])::int, floor(sh[2])::int, floor(sh[3])::int];
    fr := array[sh[1] - st[1], sh[2] - st[2], sh[3] - st[3]];
    rest := tot - (st[1] + st[2] + st[3]);
    while rest > 0 loop
      best := 1; for k in 2..3 loop if fr[k] > fr[best] then best := k; end if; end loop;
      st[best] := st[best] + 1; fr[best] := -1; rest := rest - 1;
    end loop;
    -- aucune stat à 0
    for k in 1..3 loop
      if st[k] < 1 then
        best := 1; for j in 2..3 loop if st[j] > st[best] then best := j; end if; end loop;
        st[best] := st[best] - 1; st[k] := 1;
      end if;
    end loop;
    update public.cards set p = st[1], d = st[2], v = st[3] where id = c.id;
    n := n + 1;
  end loop;
  raise notice '% cartes de la Génération 2 corrigées', n;
end $notes$;

-- Vérification : doit renvoyer 0 ligne
select id, name, rarity, p, d, v, 50 + 3 * (p + d + v) as note from public.cards
where gen = 2 and not (p + d + v between case rarity when 'C' then 6 when 'R' then 9 when 'E' then 12 else 15 end
                                     and case rarity when 'C' then 8 when 'R' then 11 when 'E' then 14 else 17 end);
