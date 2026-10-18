-- Série 4 : 53 nouvelles cartes et le type TikTok.
-- À coller dans Supabase > SQL Editor, puis Run (après schema.sql). Relançable sans risque :
-- une carte déjà présente (même identifiant) n'est pas modifiée.

insert into public.types(id,name,abbr,color,sort,lvl) values ('tiktok','TikTok','TIK','#25e6e0',10,'pvpvp')
on conflict (id) do nothing;

-- TikTok bat YouTube et Snap, Twitch bat TikTok
insert into public.type_matchups(attacker,defender,mult) values ('tiktok','yt',1.5),('tiktok','sn',1.5),('twitch','tiktok',1.5)
on conflict (attacker,defender) do nothing;

insert into public.cards(id,n,name,type,rarity,p,d,v,fx,art,flavor)
select v.id, (select coalesce(max(n),0) from public.cards) + v.ord, v.name, v.type, v.rarity, v.p, v.d, v.v, v.fx, v.art, v.flavor
from (values
  ('salut-a-tous-c-est-ninho',1,'Salut à tous c''est ninho','cu','R',3,3,4,'remontada','🎤','Ninho, en mode présentation.'),
  ('arrete-de-paniquer',2,'Arrête de paniquer','foot','C',3,2,2,'remontada','😰',''),
  ('ehh-nique-ta-mere',3,'Ehh nique ta mère','pol','C',3,2,2,'thorns','🤬',''),
  ('c-est-moi-qui-suis-a-l-envers-ou-c-est-l',4,'C''est moi qui suis à l''envers ou c''est le monde qui est à l''envers','sn','E',4,4,5,'expose','🙃',''),
  ('ballaye-moi-ca',5,'Ballaye moi ça','tiktok','C',3,1,3,'crit','🧹',''),
  ('tu-casses-tu-repars',6,'Tu casses tu repars','pol','C',2,3,2,'expose','💥',''),
  ('salut-c-est-franck-le-buf',7,'Salut c''est Franck le bœuf','tele','E',4,5,4,'shield','🐂',''),
  ('veronique-fait-infarctus',8,'véronique fait Infarctus','tele','C',1,3,3,'shield','💔',''),
  ('un-rond-point',9,'Un rond point','sn','C',2,2,3,'malaise','🔄','Mohamed Henni.'),
  ('quoi',10,'Quoi','yt','R',3,2,5,'hype','❓','Maxime Biaggi.'),
  ('cortex-les-pyramides',11,'Cortex les pyramides','cu','R',3,4,3,'hype','🔺',''),
  ('les-pyramides',12,'Les pyramides','yt','C',2,2,3,'doubletap','🔺','Maître Gims.'),
  ('petite-cochonne',13,'Petite cochonne','pol','C',2,3,2,'thorns','🐷','Jean Lassalle.'),
  ('j-ai-pris-n-importe-quoi',14,'J''ai pris n''importe quoi','tele','R',3,3,4,'shield','💊',''),
  ('tu-peux-perdre-1-carte-mais-pas-15',15,'tu peux perdre 1 carte mais pas 15','fi','R',3,4,3,'shield','🃏',''),
  ('l-alcool-c-est-pas-cool',16,'L''alcool c''est pas cool','fi','E',4,5,4,'remontada','🍷',''),
  ('messire-un-sarrazin',17,'Messire, un sarrazin','fi','E',5,4,4,'landing','⚔️',''),
  ('tu-preferes-moi-ou-ton-pere',18,'Tu préfères moi ou ton père ?','sn','E',4,3,6,'malaise','👨‍👧',''),
  ('pu-pu-y-a-les-schmit',19,'Pu pu y a les schmit','twitch','C',3,1,3,'clash','🚓',''),
  ('y-le-caca-de-toute-ville',20,'Y le caca de toute ville','sn','R',3,2,5,'thorns','💩',''),
  ('y-a-le-mec-a-mila',21,'Y a le mec à Mila','tr','E',4,4,5,'malaise','💘',''),
  ('hurracan',22,'Hurracan','cu','R',4,3,3,'lastword','🌪️',''),
  ('nardinemouk-nardinbebek',23,'Nardinemouk Nardinbebek','cu','E',4,5,4,'crit','🗣️',''),
  ('tu-vois-un-gars-pertube',24,'Tu vois un gars pertubé','foot','C',3,1,3,'clash','😵‍💫',''),
  ('t-as-une-amoureuse',25,'T''as une amoureuse ?','foot','C',2,2,3,'remontada','💌',''),
  ('salut-mon-pote',26,'salut mon pote','tele','C',1,3,3,'lastword','👋',''),
  ('le-bedo-me-fait-mal-au-crane',27,'le bedo me fait mal au crane','twitch','C',2,2,3,'thorns','🤕',''),
  ('loca-la-vida-que',28,'loca la vida qué','fi','C',2,3,2,'crit','💃',''),
  ('je-m-appelle-josiane-pichet',29,'je m''appelle josiane pichet','yt','C',2,1,4,'lifesteal','👵',''),
  ('la-pete-a-la-monique',30,'La pété à la Monique','tele','R',3,3,4,'thorns','💨',''),
  ('c-est-magnifyaque-ma-cherie',31,'C''est magnifyaque ma chérie','tele','C',2,3,2,'lastword','✨',''),
  ('bien-evidement',32,'Bien évidement','yt','C',2,2,3,'lifesteal','☝️',''),
  ('14298',33,'14298','tele','C',2,3,2,'lastword','🔢',''),
  ('je-suis-pamela',34,'Je suis pamela','tele','C',1,3,3,'shield','👱‍♀️',''),
  ('rendez-les-bijous-de-la-couronne',35,'Rendez les bijous de la couronne','tiktok','C',3,1,3,'malaise','👑',''),
  ('tu-vas-repartir-mal-mon-copain',36,'Tu vas repartir mal mon copain','sn','C',3,2,2,'thorns','😤',''),
  ('ta-gueule-moman',37,'Ta gueule moman','yt','R',3,2,5,'crit','🤐',''),
  ('mefiez-vous',38,'Méfiez vous','yt','R',2,3,5,'hype','⚠️',''),
  ('t-avais-dit-que-c-etait-une-balade',39,'t''avais dit que c''était une balade','yt','C',1,2,4,'lifesteal','🥾',''),
  ('la-rando-elle-en-fini-plus',40,'la rando elle en fini plus','yt','R',2,3,5,'buzz','⛰️',''),
  ('je-vais-le-faire-courir-moi-le-rouquin',41,'Je vais le faire courir moi le rouquin','pol','R',3,5,2,'thorns','🏃',''),
  ('t-es-un-delinquant',42,'T''es un délinquant','yt','R',4,1,5,'hype','🚨',''),
  ('j-ai-demoli-la-mauvaise',43,'J''ai démoli la mauvaise','tele','C',3,2,2,'shield','🏚️',''),
  ('dans-ma-cabane',44,'Dans ma cabane','tiktok','C',2,2,3,'malaise','🛖',''),
  ('merd-c-est-con-ca',45,'Merd, c''est con ça','tele','R',3,4,3,'lastword','😑',''),
  ('les-2-boules-d-un-mec',46,'Les 2 boules d''un mec','tiktok','R',4,2,4,'malaise','🎱',''),
  ('griny-la-grande-borne',47,'Griny la grande borne','cu','E',5,4,4,'shield','🏘️',''),
  ('c-est-pas-psible',48,'c''est pas psible','yt','C',2,1,4,'buzz','😲',''),
  ('les-filles-je-suis-tombe',49,'Les filles je suis tombé','cu','R',3,3,4,'remontada','🤕',''),
  ('c-est-la-bagnole-du-taf',50,'C''est la bagnole du taf','yt','E',4,3,6,'lifesteal','🚗',''),
  ('kangoo-bleu-chiotte',51,'Kangoo bleu chiotte','sn','E',4,4,5,'buzz','🚐',''),
  ('j-ai-croise-un-frerot-qui-faisait-du-sto',52,'J''ai croisé un frérot qui faisait du stop','sn','R',3,3,4,'doubletap','👍',''),
  ('la-republique-c-est-moi',53,'La république c''est moi','pol','E',4,6,3,'shield','🇫🇷','Jean-Luc Mélenchon, lors d''une perquisition en 2018.')
) as v(id,ord,name,type,rarity,p,d,v,fx,art,flavor)
where not exists (select 1 from public.cards c where c.id = v.id);
