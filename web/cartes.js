/* =========================================================
   CARTES : code partagé entre le jeu (index.html) et la page admin (admin.html)
   Chaque page définit TYPES (types chargés depuis la base) et albumSize().
   ========================================================= */
const esc = s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const RARITIES = {
  C:{name:"Commune",   pip:"●", value:20,  discard:5},
  R:{name:"Rare",      pip:"◆", value:60,  discard:15},
  E:{name:"Épique",    pip:"★", value:200, discard:50},
  L:{name:"Légendaire",pip:"♛", value:800, discard:200},
};
const RORDER = ["C","R","E","L"];
// Effets spéciaux (la colonne "fx" d'une carte dans la base renvoie à une de ces clés)
const FX = {
  pierce:{name:"Bref.",           desc:"Ignore l'Aura de la cible.", pierce:true},
  stun:{name:"Allô ?",            desc:"Sa première attaque étourdit la cible, qui passe son prochain tour.", stunFirst:true},
  execute:{name:"Irrévocable",    desc:"Élimine directement une cible qui a 3 de Viralité ou moins.", execute:true},
  hidden:{name:"Nul ne sait",     desc:"Ses stats restent cachées à l'adversaire jusqu'à sa première attaque.", hidden:true},
  splash1:{name:"Éclaboussure",   desc:"Chaque attaque inflige aussi 1 dégât à une autre carte adverse.", splash:1},
  splash2:{name:"Coucou général", desc:"Chaque attaque inflige aussi 2 dégâts à une autre carte adverse.", splash:2},
  heal2:{name:"Tirade",           desc:"À son entrée, rend 2 de Viralité à toutes les cartes alliées.", healEnter:2},
  heal3:{name:"Aware",            desc:"À son entrée, rend 3 de Viralité à toutes les cartes alliées.", healEnter:3},
  debuff1:{name:"Lâchez vos com's",desc:"À son entrée, toutes les cartes adverses perdent 1 en Aura.", debuffEnter:1},
  seum:{name:"Le seum",           desc:"Chaque fois qu'une carte alliée est éliminée, gagne +2 en Punchline.", seum:true},
  reflect:{name:"Ratio",          desc:"Renvoie la première attaque subie à son auteur.", reflect:true},
  stunall:{name:"Fou rire",       desc:"À son entrée, étourdit toutes les cartes adverses pendant un tour.", stunAllEnter:true},
  absurde:{name:"Kamoulox",       desc:"Stats cachées jusqu'à sa première attaque, et ignore l'Aura.", hidden:true, pierce:true},
  crit:{name:"Masterclass",       desc:"Une chance sur 4 d'infliger le double de dégâts.", crit:true},
  lifesteal:{name:"Gratte",       desc:"Récupère la moitié des dégâts qu'elle inflige (arrondie en dessous).", lifesteal:true},
  thorns:{name:"Piquant",         desc:"Chaque carte qui l'attaque perd 1 de Viralité.", thorns:true},
  rage:{name:"Vénère",            desc:"Gagne +1 en Punchline chaque fois qu'elle encaisse un coup sans tomber.", rage:true},
  shield:{name:"Fake news",       desc:"La première attaque qu'elle subit ne lui fait aucun dégât.", shield:true},
  hype:{name:"Hype",              desc:"À son entrée, les autres cartes alliées gagnent +1 en Punchline.", hypeEnter:1},
  lastword:{name:"Dernier mot",   desc:"Quand elle est éliminée, inflige 2 dégâts à toutes les cartes adverses.", lastword:2},
  clash:{name:"Clash",            desc:"+2 dégâts contre les épiques et les légendaires.", clash:2},
  malaise:{name:"Malaise",        desc:"Chaque attaque fait perdre 1 en Punchline à sa cible.", malaise:true},
  expose:{name:"Exposé",          desc:"Chaque attaque fait perdre 1 en Aura à sa cible.", expose:true},
  doubletap:{name:"Double tap",   desc:"Après son attaque, inflige 1 dégât de plus à la même cible.", doubletap:true},
  remontada:{name:"Remontada",    desc:"La première fois qu'elle tombe à 3 de Viralité ou moins, récupère 4 de Viralité.", remontada:true},
  landing:{name:"Débarquement",   desc:"À son entrée, inflige 2 dégâts à une carte adverse au hasard.", landing:2},
  buzz:{name:"Buzz",              desc:"Après chaque attaque, gagne +1 en Punchline.", buzz:true},
};
// Effets proposés par type (utilisés pour donner un pouvoir aux cartes qui n'en ont pas)
const FX_POOLS = {
  yt:["buzz", "hype", "doubletap", "crit", "lifesteal"],
  tr:["clash", "malaise", "rage", "remontada", "expose"],
  sn:["doubletap", "buzz", "malaise", "expose", "thorns"],
  fi:["crit", "lastword", "landing", "shield", "remontada"],
  cu:["hype", "lastword", "remontada", "crit", "shield"],
  foot:["rage", "doubletap", "remontada", "landing", "clash"],
  pol:["shield", "expose", "malaise", "lifesteal", "thorns"],
  twitch:["buzz", "lifesteal", "clash", "thorns", "hype"],
  tele:["hype", "shield", "expose", "thorns", "lastword"],
  sport:["rage", "landing", "doubletap", "crit", "remontada"],
  tiktok:["buzz", "doubletap", "hype", "malaise", "crit"]
};
const FX_DEFAULT_POOL = ["crit", "lifesteal", "thorns", "rage", "shield", "hype", "lastword", "clash", "malaise", "expose", "doubletap", "remontada", "landing", "buzz"];
function suggestFx(c){const p=FX_POOLS[c.type]||FX_DEFAULT_POOL;let h=0;for(const ch of String(c.id||c.name||""))h=(h*31+ch.charCodeAt(0))|0;return p[Math.abs(h)%p.length];}
// Total de stats conseillé par rareté (Punchline + Aura + Viralité)
const STAT_RANGE = {C:[6,8], R:[9,11], E:[12,14], L:[15,17]};
// Ligne de la table "cards" -> objet carte utilisé partout dans l'appli
function cardFromRow(x){return {id:x.id,n:x.n,name:x.name,type:x.type,r:x.rarity,p:x.p,d:x.d,v:x.v,fx:x.fx&&FX[x.fx]?x.fx:null,art:x.art||"❔",fl:x.flavor||"",active:x.active!==false,image:x.image||null,audio:x.audio||null,video:x.video||null};}
// Niveaux (fusion des doubles), notés ✦ : chaque type a sa propre progression (5 lettres p/d/v, une par niveau)
const LVL_MAX = 5;
const STAT_NAME = {p:"Punchline", d:"Aura", v:"Viralité"}, STAT_ABBR = {p:"PUN", d:"AUR", v:"VIR"};
function lvlSeq(type){const s=(TYPES[type]&&TYPES[type].lvl)||"vpvdp";return /^[pdv]{5}$/.test(s)?s:"vpvdp";}
function lvlBonus(l,type){l=l||0;const s=lvlSeq(type).slice(0,l);return {p:s.split("p").length-1,d:s.split("d").length-1,v:s.split("v").length-1};}
function lvlGain(l,type){return l>=1&&l<=LVL_MAX?`+1 ${STAT_NAME[lvlSeq(type)[l-1]]}`:"";}
function lvlCost(l){return l;} // doubles à fusionner pour atteindre le niveau l
function boosted(c,l){if(!c||!l) return c;const b=lvlBonus(l,c.type);return {...c,p:c.p+b.p,d:c.d+b.d,v:c.v+b.v,lvl:l,bonus:b};}
// Numéro affiché : rang parmi les cartes actives (pas de trou après une suppression ou un retrait)
function numberCards(list){list.filter(c=>c.active).sort((a,b)=>a.n-b.n).forEach((c,i)=>c.no=i+1);list.filter(c=>!c.active).forEach(c=>c.no=null);}
function cardNo(c){return c.no===undefined?String(c.n).padStart(3,"0"):c.no?String(c.no).padStart(3,"0"):"HS";}
function ovr(c){return Math.min(99,50+(c.p+c.d+c.v)*3);}
function abbr(t){const x=TYPES[t];return x?(x.abbr||x.name.slice(0,4).toUpperCase()):String(t).slice(0,4).toUpperCase();}
function typeOf(t){return TYPES[t]||{name:t,abbr:String(t).slice(0,4).toUpperCase(),color:"#8d84a3",bat:[]};}
function yearOf(c){const m=(c.fl||"").match(/Années \d{4}|\b(19|20)\d{2}\b/);return m?m[0]:null;}
function cardHTML(c,opt={}){
  if(!c) return "";
  if(opt.unknown) return `<div class="card unknown" style="--tc:${esc(typeOf(c.type).color)}"><div class="cf"><div class="ctz"><div class="chead"><span class="ovr">?</span><span class="ctyp">${esc(abbr(c.type))}</span></div><div class="art">?</div></div>
    <div class="cname">???</div><div class="stats"><span><i>PUN</i>–</span><span><i>AUR</i>–</span><span><i>VIR</i>–</span></div><div class="cfoot"><span>${cardNo(c)}/${albumSize()}</span></div></div></div>`;
  const f=c.fx?FX[c.fx]:null;
  return `<div class="card r-${c.r}${opt.holo?" holo":""}${c.image?" hasimg":""}" style="--tc:${esc(typeOf(c.type).color)}">
    <div class="cf">
      <div class="ctz">
        <div class="chead"><span class="ovr">${ovr(c)}</span><span class="ctyp">${esc(abbr(c.type))}</span><span class="rar" title="${RARITIES[c.r].name}">${RARITIES[c.r].pip}</span>${c.lvl?`<span class="lvl" title="Niveau ${c.lvl}">${"✦".repeat(c.lvl)}</span>`:""}</div>
        ${opt.video&&c.video?`<video class="artimg" src="${esc(c.video)}" ${c.image?`poster="${esc(c.image)}"`:""} muted loop playsinline autoplay preload="auto"></video>`:c.image?`<img class="artimg" src="${esc(c.image)}" alt="" loading="lazy" draggable="false">`:`<div class="art" aria-hidden="true">${esc(c.art)}</div>`}
      </div>
      <div class="cname${c.name.length>52?" xlong":c.name.length>36?" long":""}">${esc(c.name)}</div>
      <div class="stats"><span title="Punchline"${c.bonus?.p?' class="up"':""}><i>PUN</i>${c.p}</span><span title="Aura"${c.bonus?.d?' class="up"':""}><i>AUR</i>${c.d}</span><span title="Viralité"${c.bonus?.v?' class="up"':""}><i>VIR</i>${c.v}</span></div>
      <div class="cfoot"><span>${cardNo(c)}/${albumSize()}</span>${f?`<span class="fxn">${esc(f.name)}</span>`:""}</div>
    </div>
    ${opt.holo?'<span class="holotag">HOLO</span>':""}
    ${opt.count>1?`<span class="count">×${opt.count}</span>`:""}
  </div>`;
}

// Dos de carte Ref Pocket
function cardBackHTML(){return '<div class="cardback" aria-hidden="true"><span>RP</span></div>';}
