-- Catalogue de départ : 5 types, 40 cartes. Relançable : met à jour sans dupliquer.
insert into public.types(id,name,abbr,color,sort) values
  ('yt','YouTube','YT','#ff4b4b',0),
  ('tr','Télé-réalité','TV','#ff6fbf',1),
  ('sn','Snap','SNAP','#f5ef3a',2),
  ('fi','Film','FILM','#e9a948',3),
  ('cu','Culte','CULTE','#b48cff',4)
on conflict (id) do update set name=excluded.name, abbr=excluded.abbr, color=excluded.color, sort=excluded.sort;

insert into public.type_matchups(attacker,defender,mult) values
  ('yt','tr',1.5),
  ('tr','sn',1.5),
  ('sn','fi',1.5),
  ('fi','yt',1.5)
on conflict (attacker,defender) do update set mult=excluded.mult;

insert into public.cards(id,n,name,type,rarity,p,d,v,fx,art,flavor) values
  ('salut-geeks',1,'Salut les geeks','yt','R',4,2,4,null,'🤓','Web-série YouTube, 2011. Un geek, son double, et des vidéos absurdes passées au crible.'),
  ('greg',2,'Ouais c''est Greg','yt','C',2,2,3,null,'📞','Un message vocal entré dans la légende. Tout le monde connaît un Greg.'),
  ('kassos',3,'Les Kassos','yt','C',3,1,3,null,'🦊','Série d''animation trash, 2013. Des peluches qui n''auraient jamais dû parler.'),
  ('golden',4,'Golden Moustache','yt','C',3,2,2,null,'🥸','Chaîne humoristique lancée en 2012, la fabrique à sketches.'),
  ('vbb',5,'Very Bad Blagues','yt','R',4,3,3,null,'🃏','Des sketches de deux minutes qui ont fait le tour des cours de récré.'),
  ('wesh',6,'Wesh alors','yt','R',5,1,4,'splash1','🛸','Clip de 2015 devenu cri de ralliement d''une génération.'),
  ('bref',7,'Bref.','yt','E',5,3,5,'pierce','⏱️','Série de 2011 : une vie racontée en accéléré, et un mot pour tout clore.'),
  ('auteuil',8,'Auteuil Neuilly Passy','yt','C',2,3,3,null,'🎤','Le rap des beaux quartiers, 1991. Toujours repartagé trente ans après.'),
  ('allo',9,'Allô quoi','tr','E',5,3,5,'stun','☎️','Télé-réalité, 2013. Quatre syllabes, des millions de détournements.'),
  ('sentence',10,'La sentence est irrévocable','tr','R',4,2,4,'execute','🔥','Koh-Lanta. La phrase qui éteint les flambeaux depuis 2001.'),
  ('voix',11,'La Voix','tr','R',3,3,4,'hidden','🎙️','Secret Story, 2007. Une voix sans visage qui convoque au confessionnal.'),
  ('loft',12,'La piscine du Loft','tr','E',4,4,5,'splash1','🏊','Loft Story, 2001. Le jour où la France a découvert la télé-réalité.'),
  ('madmag',13,'Le Mad Mag','tr','C',3,1,3,null,'📺','Le débrief quotidien de la télé-réalité, à chaud.'),
  ('marseillais',14,'Les Marseillais','tr','C',3,2,3,null,'🌴','Une bande, une villa, une destination exotique par saison.'),
  ('pre',15,'L''amour est dans le pré','tr','C',1,3,4,null,'🐄','Agriculteurs cherchent l''âme sœur, depuis 2005.'),
  ('qvemf',16,'Qui veut épouser mon fils ?','tr','C',2,2,3,null,'💍','Des mères, des fils et des prétendantes, 2010.'),
  ('rose',17,'La rose du Bachelor','tr','C',2,3,2,null,'🌹','Une rose à la fin de chaque soirée : tant qu''on l''a, on reste.'),
  ('scribe',18,'Une bonne situation, ça, scribe ?','fi','E',4,5,4,'heal2','📜','Mission Cléopâtre, 2002. La tirade que tout le monde sait réciter.'),
  ('blanquette',19,'Comment est votre blanquette ?','fi','R',4,3,3,null,'🍲','OSS 117, 2006. Question piège, réponse attendue.'),
  ('leblanc',20,'Il s''appelle Juste Leblanc','fi','R',3,3,4,'hidden','🎩','Le Dîner de cons, 1998. Il n''a pas de prénom.'),
  ('malentendu',21,'Sur un malentendu…','fi','C',3,1,3,null,'⛷️','Les Bronzés font du ski, 1979. L''optimisme incarné.'),
  ('jusquici',22,'Jusqu''ici tout va bien','fi','R',5,2,3,null,'🏙️','La Haine, 1995. L''histoire d''un homme qui tombe d''un immeuble.'),
  ('cestcela',23,'C''est cela, oui','fi','C',2,3,2,null,'🎄','Le Père Noël est une ordure, 1982. L''art de ne croire personne.'),
  ('okay',24,'Okayyy','fi','C',3,2,2,null,'🏰','Les Visiteurs, 1993. Un écuyer découvre le XXe siècle.'),
  ('pasfaux',25,'C''est pas faux','fi','R',3,4,3,null,'⚔️','Kaamelott, 2005. Quand on n''a pas compris mais qu''on ne veut pas le dire.'),
  ('pasbienla',26,'On n''est pas bien là ?','fi','C',2,2,4,null,'🛋️','Les Valseuses, 1974. Le confort élevé au rang de philosophie.'),
  ('quoicoubeh',27,'Quoicoubeh','sn','C',3,1,3,null,'🤡','TikTok, 2023. La réponse automatique à toute phrase finissant par « quoi ».'),
  ('apagnan',28,'Apagnan','sn','C',2,2,3,null,'🐒','Vidéo virale de 2023, reprise dans toutes les stories.'),
  ('seum',29,'Le seum','sn','R',3,2,4,'seum','😤','Argot passé dans le langage courant : la frustration à l''état pur.'),
  ('askip',30,'Askip','sn','R',4,2,3,'hidden','🤫','« À ce qu''il paraît ». La rumeur à la vitesse d''un snap.'),
  ('chocolatine',31,'Chocolatine','sn','R',4,4,3,null,'🥐','Le débat qui divise la France plus sûrement que la politique.'),
  ('ratio',32,'Ratio','sn','R',3,3,4,'reflect','📉','Quand la réponse a plus de likes que le message d''origine.'),
  ('dinguerie',33,'C''est quoi cette dinguerie','sn','C',4,1,2,null,'🤯','Réaction réflexe à toute vidéo trop étrange pour être vraie.'),
  ('vu',34,'Vu à 3h12','sn','C',1,3,3,null,'👀','Le message lu, jamais répondu. Une torture moderne.'),
  ('wizz',35,'Le wizz MSN','sn','E',5,2,5,'stun','📳','Années 2000. La fenêtre qui tremble, ancêtre de la notif.'),
  ('skyblog',36,'Le Skyblog','sn','E',4,4,5,'debuff1','✨','Années 2000. Paillettes, musique automatique et commentaires en chaîne.'),
  ('risitas',37,'Le rire de Risitas','cu','L',6,4,6,'stunall','😂','Un fou rire venu d''une émission espagnole, devenu l''emblème des forums français.'),
  ('aware',38,'Être aware','cu','L',5,5,6,'heal3','🧘','Une interview mémorable, et un mot anglais adopté par toute la France.'),
  ('kamoulox',39,'Kamoulox','cu','L',6,5,5,'absurde','🌀','Fin des années 90 : un jeu télé où rien n''a de sens. Kamoulox !'),
  ('coucou',40,'Ah que coucou','cu','L',6,4,6,'splash2','🎸','La salutation la plus imitée de France, popularisée par les marionnettes du soir.')
on conflict (id) do update set n=excluded.n, name=excluded.name, type=excluded.type, rarity=excluded.rarity, p=excluded.p, d=excluded.d, v=excluded.v, fx=excluded.fx, art=excluded.art, flavor=excluded.flavor;
