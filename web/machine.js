/* =========================================================
   MACHINE À SOUS « FORTUNE KHEY »
   Le tirage se fait sur le serveur (slot_spin) : ici, on ne fait que l'animer.
   15 réfs qui changent toutes les 6 heures (deux générations) :
     0-5 communes, 6-9 rares, 10-12 épiques, 13 légendaire, 14 joker
   + 15 pièce « Khey d'or », 16 appareil photo de Nils, 17 booster.
   243 façons de gagner : la même réf sur des rouleaux voisins depuis la gauche, n'importe quelle ligne.
   ========================================================= */
const SJ=14, SCOIN=15, SCAM=16, SBST=17;
const SLOT_W=[20,20,20,20,20,20,6,6,6,6,3,3,3,2.2,9,22,1.2,1.5];   // seulement pour l'aspect des rouleaux qui défilent
const SLOT_PAY={3:[1,1,1,1,1,1,1,1,1,1,2,2,2,4,5],4:[1,1,1,1,1,1,2,2,2,2,5,5,5,10,15],5:[2,2,2,2,2,2,4,4,4,4,12,12,12,30,60]};
const SLOT_JP={101:["MINI",20],102:["MINOR",50],103:["MAJOR",250],104:["GRAND",0]};
const SLOT_ROLE=["Commune","Commune","Commune","Commune","Commune","Commune","Rare","Rare","Rare","Rare","Épique","Épique","Épique","Légendaire","Joker"];

const Slot={
  info:null, bet:1, busy:false, fast:false, cam:0,
  sym(i){const id=this.info?.symbols?.[i];return id&&BYID[id]||null;},
  alive(){return !!document.getElementById("reels");},
  wait(ms){return new Promise(r=>{if(!this.alive())return r();setTimeout(r,this.fast?ms*.25:ms);});},
  fmtK(n){return `${fmt(Math.round(n))} K`;},
  cab(){return document.querySelector(".cab");},
  party(cls,ms){const c=this.cab();if(!c)return;c.classList.remove(cls);void c.offsetWidth;c.classList.add(cls);clearTimeout(this["_t"+cls]);this["_t"+cls]=setTimeout(()=>c.classList.remove(cls),ms);},

  async load(){
    const r=await sb.rpc("slot_info");
    if(r.error){toast("Machine indisponible : relance schema.sql dans Supabase ("+errMsg(r.error)+")");return;}
    this.info=r.data; this.cam=r.data.cam||0; this.preload();
    if(tab==="machine"&&!this.busy) render();
  },
  preload(){(this.info?.symbols||[]).forEach(id=>{const c=BYID[id];if(!c)return;if(c.image){const im=new Image();im.src=c.image;}if(c.audio&&(c.r==="E"||c.r==="L"))Sfx.preload(c.audio);});},

  /* ---------- Rendu ---------- */
  tile(sym,coin){
    if(sym===SCOIN){const v=coin||[1,2,3,5][Math.floor(Math.random()*4)],jp=SLOT_JP[v];
      return `<div class="tl coin${jp?" jp jp-"+jp[0].toLowerCase():""}"><span class="cn"><i class="shine"></i><b>${jp?jp[0]:this.fmtK(v*this.curBet())}</b></span></div>`;}
    if(sym===SCAM) return `<div class="tl camt">${CAM_SVG}</div>`;
    if(sym===SBST) return `<div class="tl bst">${BOOSTER_SVG}</div>`;
    const c=this.sym(sym); if(!c) return `<div class="tl ref"><span class="em">❔</span></div>`;
    const t=typeOf(c.type);
    return `<div class="tl ref r-${c.r}${sym===SJ?" wild":""}" style="--tc:${esc(t.color)}">${c.image?`<img src="${esc(c.image)}" alt="" draggable="false">`:`<span class="em">${esc(c.art||"❔")}</span>`}${sym===SJ?'<i class="wt">JOKER</i>':""}</div>`;
  },
  curBet(){return this.info&&this.info.free?this.info.fbet:this.bet;},
  randSym(r){const w=SLOT_W.slice();if(r===0||r===4)w[SJ]=0;let t=Math.random()*w.reduce((a,b)=>a+b,0);for(let i=0;i<w.length;i++){t-=w[i];if(t<0)return i;}return 0;},
  camsHTML(n){
    return [0,1,2].map(i=>{const hits=Math.max(0,Math.min(3,n-i*3));return `<div class="cam h${hits}" data-cam="${i}" aria-label="Appareil ${i+1} : ${hits} coup${hits>1?"s":""} sur 3"><div class="camin">${CAM_SVG}${CRACK_SVG}</div></div>`;}).join("");
  },
  nextIn(){const n=this.info?.next?new Date(this.info.next)-Date.now():0;return n>0?dur(n):"bientôt";},
  view(){
    if(!this._b){this._b=1;if([1,5,10].includes(L.sbet))this.bet=L.sbet;}
    const I=this.info;
    if(!I){this.load();return `<div class="cab"><p class="note" style="text-align:center;margin:auto">Chargement de la machine…</p></div>`;}
    const free=I.free||0, bet=this.curBet();
    const g0=Array.from({length:15},(_,i)=>this.lastGrid?this.lastGrid[i]:this.randSym(Math.floor(i/3)));
    const reels=[0,1,2,3,4].map(r=>`<div class="reel" data-r="${r}"><div class="strip">${[0,1,2].map(k=>this.tile(g0[r*3+k],this.lastCoins?.[r*3+k])).join("")}</div></div>`).join("");
    const w=(I.wins||[])[0];
    return `<div class="cab${free?" freemode":""}">
      <canvas class="slotfx" id="slotfx" aria-hidden="true"></canvas>
      <div class="marquee"><div class="mq-in">
        <div class="mq-title" aria-label="Fortune Khey"><span class="f1">FORTUNE</span><span class="f2">KHEY</span></div>
        <div class="jp-grand"><span>GRAND</span><b id="jpg">${this.fmtK(I.pool)}</b></div></div></div>
      <div class="jp-row"><div class="j3"><span>MAJOR</span><b>${fmt(250*bet)}</b></div><div class="j2"><span>MINOR</span><b>${fmt(50*bet)}</b></div><div class="j1"><span>MINI</span><b>${fmt(20*bet)}</b></div></div>
      <div class="camrow"><div class="cams" id="cams">${this.camsHTML(this.cam)}</div>
        <span class="camlab"><b>Casse les 3 appareils de Nils</b><br>→ Roue de Nils<br><small>Nouvelles réfs dans ${this.nextIn()}</small></span></div>
      <div class="reelbox"><div class="reelframe"><div class="reels" id="reels">${reels}
        <div class="slotbanner" id="sbanner" hidden></div></div></div></div>
      <div class="led" id="smsg" role="status">${free?`🎡 ${free} TOUR${free>1?"S":""} GRATUIT${free>1?"S":""} · ${bet} K`:w?`🏆 ${esc(pseudoOf(w.user))} : ${esc(w.label)}${w.amount?` · ${fmt(w.amount)} K`:""}`:"243 FAÇONS DE GAGNER"}</div>
      <div class="slotctl">
        <div class="bets" role="radiogroup" aria-label="Mise">${[1,5,10].map(b=>`<button role="radio" data-sbet="${b}" aria-checked="${bet===b}" ${free?"disabled":""}>${b} K</button>`).join("")}</div>
        <button class="spinbtn" id="spin" data-act="slotspin" ${!free&&S.me.kheys<bet?"disabled":""}><i class="gloss"></i><span>${free?"GRATUIT":"TOURNER"}</span><small>${free?`${free} restant${free>1?"s":""}`:`mise ${bet} K`}</small></button>
        <button class="iconbtn" data-act="slotpay" aria-label="Règles et gains">ⓘ</button>
      </div>
      <p class="slotfoot">${I.spins||0} / ${I.cap||500} tours aujourd'hui · Retour moyen ≈ 92 %</p>
    </div>`;
  },
  mount(){
    const cv=document.getElementById("slotfx"); if(cv){SFx.detach();SFx.attach(cv);}
    this.size(); if(!this._rs){this._rs=()=>this.size();addEventListener("resize",this._rs);}
  },
  size(){const r=document.querySelector("#reels .reel");if(r)document.getElementById("reels").style.setProperty("--th",(r.clientHeight/3)+"px");},

  /* ---------- Un tour ---------- */
  async spin(){
    if(this.busy){this.fast=true;return;}
    if(!this.info) return;
    const free=this.info.free||0, bet=this.curBet();
    if(!free&&S.me.kheys<bet){toast("Pas assez de Kheys.");return;}
    Sfx.unlock(); Sfx.stopClip(); Sfx.p("click"); this.busy=true; this.fast=false;
    const btn=document.getElementById("spin"); if(btn) btn.classList.add("going");
    this.msg(free?"TOUR GRATUIT…":"BONNE CHANCE…");
    this.clearWins();
    if(!free){S.me.kheys-=bet;renderTop();}
    const spinning=this.startReels();
    const r=await sb.rpc("slot_spin",{p_bet:bet});
    if(r.error){this.stopReels(spinning);if(!free)S.me.kheys+=bet;renderTop();this.busy=false;btn?.classList.remove("going");toast(errMsg(r.error));return;}
    const o=r.data;
    if(o.symbols&&JSON.stringify(o.symbols)!==JSON.stringify(this.info.symbols)){this.info.symbols=o.symbols;this.preload();}
    try{ await this.play(o,spinning); }
    catch(e){ console.error(e); }
    finally{
      clearInterval(this._loop);
      const poolBefore=this.info.pool;
      S.me.kheys=o.kheys; this.info.free=o.free; this.info.fbet=o.bet; this.info.spins=o.spins; this.info.pool=o.pool; this.cam=o.cam; this.info.cam=o.cam;
      this.lastGrid=o.grid; this.lastCoins=o.coins;
      if(o.prize||o.win>=50*o.bet) this.load();
      this.busy=false; this.fast=false; renderTop();
      if(tab==="machine"&&this.alive()){this.refreshCtl(o);this.rollPool(poolBefore,o.pool);}
      if(o.prize) sync().then(renderTop).catch(()=>{});
    }
  },
  rollPool(a,b){const el=document.getElementById("jpg");if(!el||a===b)return;const t0=performance.now();
    const f=now=>{const k=Math.min(1,(now-t0)/600);el.textContent=this.fmtK(a+(b-a)*k);if(k<1&&el.isConnected)requestAnimationFrame(f);};requestAnimationFrame(f);},
  refreshCtl(o){
    const v=$("#view"), tmp=document.createElement("div"); tmp.innerHTML=this.view();
    for(const sel of [".slotctl",".slotfoot",".jp-row",".led"]){const a=v.querySelector(sel),b=tmp.querySelector(sel);if(a&&b)a.replaceWith(b);}
    this.cab()?.classList.toggle("freemode",!!this.info.free);
    if(o&&o.win>0) this.msg(`GAGNÉ : ${this.fmtK(o.win)}`); else if(o&&!this.info.free) this.msg(o.prize?"🎁 CADEAU !":"RETENTE TA CHANCE !");
  },
  msg(t){const m=document.getElementById("smsg");if(m)m.textContent=t;},

  startReels(){
    const reels=[...document.querySelectorAll("#reels .reel")];
    clearInterval(this._loop); this._loop=setInterval(()=>Sfx.p("tick"),95);
    return reels.map((el,r)=>{
      const strip=el.querySelector(".strip"), th=el.clientHeight/3;
      const filler=Array.from({length:12},()=>this.tile(this.randSym(r))).join("");
      strip.innerHTML=filler+strip.innerHTML; strip.style.transform=`translateY(${-12*th}px)`;
      el.classList.add("spinning");
      // petit élan vers le haut avant de tomber, puis défilement en boucle
      const a=strip.animate([{transform:`translateY(${-12*th}px)`},{transform:`translateY(0px)`}],{duration:340,iterations:Infinity,delay:r*45});
      return {el,strip,a,th};
    });
  },
  stopReels(sp){clearInterval(this._loop);sp.forEach(s=>{s.a.cancel();s.el.classList.remove("spinning");s.strip.style.transform="";const k=[...s.strip.children].slice(-3).map(x=>x.outerHTML).join("");s.strip.innerHTML=k;});},

  async play(o,sp){
    const g=o.grid, coins=o.coins||{};
    const coinsUpTo=r=>g.slice(0,(r+1)*3).filter(x=>x===SCOIN).length;
    let t=this.fast?150:520;
    for(let r=0;r<5;r++){
      const s=sp[r]; if(!s||!s.el.isConnected) break;
      const tease=r>=3&&coinsUpTo(r-1)>=4;
      if(tease){s.el.classList.add("tease");this.party("hot",2000);Sfx.p("riser");await this.wait(1000);}
      await this.landReel(s,g.slice(r*3,r*3+3),coins,r,t);
      s.el.classList.remove("tease");
      t=this.fast?70:170;
    }
    clearInterval(this._loop);
    if(!this.alive()) return;
    if(o.cams>0) await this.camHits(o);
    if(o.lines&&o.lines.length) await this.showWins(o);
    if(o.bonus&&typeof o.bonus==="object") await this.pluie(o);
    if(o.wheel) await this.wheel(o);
    if(o.prize) await this.prize(o);
    if(o.win>=20*o.bet&&o.win>0) await this.bigWin(o.win,o.bet,o.events&&o.events.length?"GRAND JACKPOT":null);
  },
  async landReel(s,col,coins,r,delay){
    await this.wait(delay);
    if(!s.el.isConnected) return;
    s.a.cancel();
    const th=s.el.clientHeight/3, finals=col.map((x,k)=>this.tile(x,coins[r*3+k])).join("");
    const fill=Array.from({length:6},()=>this.tile(this.randSym(r))).join("");
    s.strip.innerHTML=finals+fill;
    const d=this.fast?120:300;
    const an=s.strip.animate([{transform:`translateY(${-6*th}px)`},{transform:`translateY(${th*.14}px)`,offset:.82},{transform:`translateY(${-th*.04}px)`,offset:.93},{transform:"translateY(0px)"}],{duration:d,easing:"cubic-bezier(.3,.7,.4,1)"});
    await new Promise(res=>{an.onfinish=res;an.oncancel=res;setTimeout(res,d+60);});
    s.strip.innerHTML=finals; s.strip.style.transform=""; s.el.classList.remove("spinning");
    s.el.classList.remove("thud"); void s.el.offsetWidth; s.el.classList.add("thud");
    Sfx.p("stop"); buzz(8);
    if(col.includes(SCAM)){Sfx.p("shutter");s.el.querySelectorAll(".camt").forEach(x=>{x.classList.add("flash");this.flashAt(x);});}
    if(col.includes(SCOIN)){Sfx.p("coin");s.el.querySelectorAll(".coin").forEach(x=>x.classList.add("land"));}
    if(col.includes(SBST)) Sfx.p("ding");
    if(col.includes(SJ)) s.el.querySelectorAll(".wild").forEach(x=>x.classList.add("land"));
  },
  flashAt(el){const r=el.getBoundingClientRect();SFx.burst(r.left+r.width/2,r.top+r.height/2,["#ffffff","#e6f9ff"],18,{speed:5,g:0,life:22,size:3});},
  cell(p){const r=Math.floor(p/3),k=p%3;return document.querySelector(`#reels .reel[data-r="${r}"] .strip`)?.children[k]||null;},

  /* ---------- Appareils photo de Nils ---------- */
  async camHits(o){
    const cams=document.getElementById("cams"); if(!cams) return;
    let n=this.cam; const total=n+o.cams;
    const pos=o.grid.map((x,i)=>x===SCAM?i:-1).filter(i=>i>=0);
    for(const p of pos){
      if(n>=9) break;
      const el=this.cell(p), ci=Math.floor(n/3), cam=cams.querySelector(`[data-cam="${ci}"]`);
      if(el&&cam) await this.flyTo(el,cam);
      n++;
      const hits=n-ci*3;
      if(cam){cam.className=`cam h${hits} hit`;void cam.offsetWidth;
        const rc=cam.getBoundingClientRect(), cx=rc.left+rc.width/2, cy=rc.top+rc.height/2;
        SFx.burst(cx,cy,["#ffffff","#dff6ff"],22,{speed:4,g:0,life:18,size:3.4});   // flash
        if(hits>=3){cam.classList.add("boom");this.shards(cam);Sfx.p("smash");buzz([20,30,80]);
          SFx.burst(cx,cy,["#c9d3e6","#7d879c","#21d4fd","#ffffff","#1f1a33"],46,{speed:7,g:.25,life:70,conf:true,size:3});}
        else{Sfx.p("crack");buzz(15);}}
      await this.wait(300);
    }
    this.cam=Math.min(9,total);
  },
  shards(cam){
    const r=cam.getBoundingClientRect();
    for(let i=0;i<7;i++){const d=document.createElement("i");d.className="shard"+(i===0?" lens":"");
      d.style.left=(r.left+r.width/2)+"px";d.style.top=(r.top+r.height/2)+"px";
      d.style.setProperty("--dx",((Math.random()-.5)*160)+"px");d.style.setProperty("--dy",(60+Math.random()*120)+"px");d.style.setProperty("--rot",((Math.random()-.5)*720)+"deg");
      document.body.appendChild(d);setTimeout(()=>d.remove(),1100);}
  },
  flyTo(from,to){
    return new Promise(res=>{
      const a=from.getBoundingClientRect(), b=to.getBoundingClientRect();
      const d=document.createElement("div"); d.className="flydot";
      d.style.left=(a.left+a.width/2)+"px"; d.style.top=(a.top+a.height/2)+"px"; document.body.appendChild(d);
      const dx=b.left+b.width/2-(a.left+a.width/2), dy=b.top+b.height/2-(a.top+a.height/2);
      const an=d.animate([{transform:"translate(-50%,-50%) scale(1.5)",opacity:1},{transform:`translate(calc(-50% + ${dx*.5}px),calc(-50% + ${dy*.5-40}px)) scale(1)`,opacity:1,offset:.5},{transform:`translate(calc(-50% + ${dx}px),calc(-50% + ${dy}px)) scale(.5)`,opacity:.9}],{duration:this.fast?130:440,easing:"ease-in"});
      an.onfinish=()=>{d.remove();res();}; setTimeout(()=>{d.remove();res();},700);
    });
  },
  repairCams(left){const cams=document.getElementById("cams");if(!cams)return;cams.innerHTML=this.camsHTML(left);cams.querySelectorAll(".cam").forEach(c=>c.classList.add("repair"));},

  /* ---------- Gains (243 façons) ---------- */
  clearWins(){const r=document.getElementById("reels");if(!r)return;r.classList.remove("dim");r.querySelectorAll(".tl.win").forEach(x=>x.classList.remove("win"));},
  async showWins(o){
    const reels=document.getElementById("reels"); if(!reels) return;
    const all=[...o.lines].sort((a,b)=>b.w-a.w), sum=all.reduce((s,x)=>s+x.w,0);
    reels.classList.add("dim");
    const mark=L=>L.cells.forEach(p=>this.cell(p)?.classList.add("win"));
    all.forEach(mark);
    const x=sum/o.bet;
    Sfx.p(x>=10?"bigjingle":x>=3?"win":"smallwin");
    this.party(x>=10?"party":"glow",x>=10?2600:1300);
    this.countUp(sum,x>=10?1400:600);
    // une épique ou une légendaire alignée : on joue le son de la carte et on la met en avant
    const star=all.filter(L=>L.s>=10).sort((a,b)=>b.s-a.s)[0];
    if(star) await this.spotlight(star,o);
    await this.wait(all.length>1?700:900);
    if(all.length>1&&!this.fast){
      for(const L of all.slice(0,5)){
        if(!this.alive()) break;
        reels.querySelectorAll(".tl.win").forEach(e=>e.classList.remove("win"));
        mark(L); const c=this.sym(L.s);
        this.msg(`${L.n}× ${(c?c.name:"réf").toUpperCase()}${L.m>1?` ×${L.m}`:""} : ${this.fmtK(L.w)}`); Sfx.p("tick");
        await this.wait(560);
      }
      all.forEach(mark);
    }
  },
  countUp(to,ms,from=0){const m=document.getElementById("smsg");if(!m)return;const t0=performance.now();let lastTick=0;
    const f=now=>{const k=Math.min(1,(now-t0)/(this.fast?ms*.3:ms));m.textContent=`GAGNÉ : ${this.fmtK(from+(to-from)*k)}`;
      if(now-lastTick>70&&k<1){lastTick=now;Sfx.p("tick");}
      if(k<1&&m.isConnected)requestAnimationFrame(f);};requestAnimationFrame(f);},
  async spotlight(L,o){
    const c=this.sym(L.s); if(!c) return;
    const legend=c.r==="L";
    if(c.audio) Sfx.clip(c.audio); else (legend?Sfx.L():Sfx.E());
    buzz(legend?[60,40,120]:[40,30,60]);
    const ov=document.createElement("div"); ov.className="slotstar r-"+c.r;
    ov.innerHTML=`<div class="ss-rays"></div><div class="ss-card">${cardHTML(c)}</div><p class="ss-t">${legend?"LÉGENDAIRE":"ÉPIQUE"} ALIGNÉE !</p><p class="ss-w">${L.n}× · ${this.fmtK(L.w)}</p>`;
    document.body.appendChild(ov);
    const r=ov.querySelector(".ss-card").getBoundingClientRect();
    SFx.burst(r.left+r.width/2,r.top+r.height/2,legend?["#ffd23f","#fff1a8","#ff9a3d","#ffffff"]:["#c06bff","#e3b8ff","#21d4fd","#ffffff"],90,{speed:9,g:.1,life:90,conf:true});
    let done=false; ov.onclick=()=>{done=true;};
    const t0=performance.now();
    while(!done&&performance.now()-t0<(this.fast?600:2600)&&ov.isConnected) await new Promise(r=>setTimeout(r,80));
    ov.classList.add("out"); setTimeout(()=>ov.remove(),300);
  },
  banner(html,cls,ms){
    const b=document.getElementById("sbanner"); if(!b) return Promise.resolve();
    b.className="slotbanner "+(cls||""); b.innerHTML=html; b.hidden=false; void b.offsetWidth; b.classList.add("on");
    return this.wait(ms||1300).then(()=>{b.classList.remove("on");return this.wait(200);}).then(()=>{b.hidden=true;});
  },

  /* ---------- Pluie de Kheys (6 pièces ou plus) ---------- */
  async pluie(o){
    const B=o.bonus, reels=document.getElementById("reels"); if(!reels) return;
    reels.classList.remove("dim"); reels.querySelectorAll(".tl.win").forEach(x=>x.classList.remove("win"));
    reels.classList.add("bonusmode"); this.party("party",3000); Sfx.p("fanfare"); buzz([40,40,80]);
    const rc=reels.getBoundingClientRect();
    const rain=setInterval(()=>SFx.burst(rc.left+Math.random()*rc.width,rc.top-10,["#ffd23f","#fff1a8","#ff9a3d"],6,{speed:2,g:.25,life:90,conf:true,size:3.2}),90);
    await this.banner(`<b>PLUIE DE KHEYS</b><span>Chaque nouvelle pièce relance le compteur</span>`,"gold",1700);
    clearInterval(rain);
    const coins={...o.coins};
    const rs=document.createElement("div"); rs.className="respins"; reels.appendChild(rs);
    const setR=n=>{rs.innerHTML=`RELANCES <b>${"●".repeat(n)}${"○".repeat(3-n)}</b>`;};
    let n=3; setR(n);
    for(const step of B.steps){
      if(!this.alive()) break;
      for(let p=0;p<15;p++) if(!(String(p) in coins)) this.cell(p)?.classList.add("rs");
      clearInterval(this._loop); this._loop=setInterval(()=>Sfx.p("tick"),80);
      await this.wait(700);
      clearInterval(this._loop);
      for(let p=0;p<15;p++) this.cell(p)?.classList.remove("rs");
      if(step.length){
        for(const c of step){coins[c.p]=c.v;const el=this.cell(c.p);if(el){el.outerHTML=this.tile(SCOIN,c.v);const ne=this.cell(c.p);ne?.classList.add("drop");
          const r=ne?.getBoundingClientRect(); if(r) SFx.burst(r.left+r.width/2,r.top+r.height/2,["#ffd23f","#ffffff"],24,{speed:5,g:.1,life:40});}
          Sfx.p("coin");buzz(12);await this.wait(200);}
        n=3; setR(n); rs.classList.remove("pulse"); void rs.offsetWidth; rs.classList.add("pulse"); Sfx.p("ding");
      } else { n--; setR(n); Sfx.p("stop"); }
      await this.wait(320);
    }
    rs.remove();
    let tot=0; const order=Object.keys(coins).map(Number).sort((a,b)=>a-b);
    for(const p of order){
      if(!this.alive()) break;
      const v=coins[p], el=this.cell(p); el?.classList.add("tally");
      if(v<100) tot+=v*o.bet;
      else if(v<104){tot+=SLOT_JP[v][1]*o.bet; await this.jackpot(SLOT_JP[v][0],SLOT_JP[v][1]*o.bet);}
      this.msg(`PLUIE : ${this.fmtK(tot)}`); Sfx.p("coin"); await this.wait(order.length>10?120:180);
    }
    const gr=(o.events||[]).find(e=>e.t==="grand");
    if(gr){tot+=gr.v; await this.jackpot("GRAND",gr.v);}
    reels.classList.remove("bonusmode");
    await this.wait(300);
  },
  async jackpot(name,amount){
    Sfx.p("jackpot"); buzz([60,40,60,40,120]); this.party("party",3500); this.party("shake",600);
    const rc=document.getElementById("reels")?.getBoundingClientRect();
    if(rc) for(let i=0;i<4;i++) setTimeout(()=>SFx.burst(rc.left+rc.width*(0.15+0.23*i),rc.top+rc.height*(.3+.4*Math.random()),["#ffd23f","#ffffff","#ff3bd5","#21d4fd"],70,{speed:9,g:.12,life:90,conf:true}),i*180);
    await this.banner(`<small>JACKPOT</small><b>${name}</b><span>+ ${this.fmtK(amount)}</span>`,"jackpot jp-"+name.toLowerCase(),name==="GRAND"?3400:2000);
  },

  /* ---------- Roue de Nils : le grand show ---------- */
  async wheel(o){
    const W=this.info.wheel||[], seg=o.wheel, n=W.length||8, step=360/n;
    await this.wait(250);
    const cols=["#21d4fd","#ff3bd5","#ffd23f","#3dffa8","#8b7bff","#ff8a3d","#ff4f6d","#c6ff3d"];
    const grad=W.map((s,i)=>`${s.t==="w"?cols[i%cols.length]:"#1b1440"} ${i*step}deg ${(i+1)*step}deg`).join(",");
    const bulbs=Array.from({length:24},(_,i)=>`<i class="wb" style="transform:rotate(${i*15}deg)"></i>`).join("");
    const ov=document.createElement("div"); ov.className="wheelov"; ov.setAttribute("role","dialog"); ov.setAttribute("aria-label","Roue de Nils");
    ov.innerHTML=`<div class="wh-rays"></div><div class="wh-in"><p class="wh-t">📸 Les 3 appareils sont détruits !</p><h2 class="wh-h">ROUE DE NILS</h2>
      <div class="wh-box"><div class="wh-bulbs">${bulbs}</div><div class="wh-ptr"></div><div class="wh-spin" id="wh"><div class="wh-face" style="background:conic-gradient(${grad})"></div>
        ${W.map((s,i)=>`<span class="ws ${s.t}" style="transform:rotate(${i*step+step/2}deg)"><b>${s.t==="w"?`×${s.v}`:`${s.v}<small>TOURS</small>`}</b></span>`).join("")}</div>
        <div class="wh-win" id="whwin" style="transform:rotate(${seg.i*step}deg);--a:${step}deg"></div>
        <div class="wh-hub">${CAM_SVG}</div></div>
      <p class="wh-res" id="whres">&nbsp;</p></div>`;
    document.body.appendChild(ov);
    Sfx.p("fanfare"); this.party("party",9000);
    await this.wait(900);
    const wh=ov.querySelector("#wh"), turns=this.fast?2:6, target=turns*360+(360-(seg.i*step+step/2));
    const dur=this.fast?1300:5200;
    ov.classList.add("spinning");
    wh.style.transition=`transform ${dur}ms cubic-bezier(.1,.55,.08,1)`; void wh.offsetWidth; wh.style.transform=`rotate(${target}deg)`;
    const ptr=ov.querySelector(".wh-ptr");
    let last=-1; const t0=performance.now();
    await new Promise(res=>{const f=()=>{const m=getComputedStyle(wh).transform;let a=0;if(m&&m!=="none"){const v=m.split("(")[1].split(",");a=Math.atan2(+v[1],+v[0])*180/Math.PI;}
      const k=Math.floor((((a%360)+360)%360+step/2)/step);
      if(k!==last){last=k;Sfx.p("tick");ptr.classList.remove("kick");void ptr.offsetWidth;ptr.classList.add("kick");}
      if(performance.now()-t0>dur*.55) ov.classList.remove("spinning");
      if(performance.now()-t0<dur+60&&ov.isConnected)requestAnimationFrame(f);else res();};requestAnimationFrame(f);});
    ov.classList.add("landed");
    const res=ov.querySelector("#whres");
    if(seg.t==="w"){res.innerHTML=`<b>×${seg.v}</b><span>${this.fmtK(seg.amount)}</span>`;Sfx.p("bigjingle");}
    else{res.innerHTML=`<b>${seg.v} TOURS GRATUITS</b><span>à ${o.bet} K</span>`;Sfx.p("jackpot");}
    res.classList.add("on"); buzz([30,30,90]);
    const r=ov.querySelector(".wh-box").getBoundingClientRect();
    const fw=setInterval(()=>SFx.burst(r.left+Math.random()*r.width,r.top+Math.random()*r.height*.6,cols,50,{speed:8,g:.1,life:80}),260);
    SFx.burst(r.left+r.width/2,r.top+r.height/2,cols,120,{speed:11,g:.15,life:100,conf:true});
    await this.wait(2600);
    clearInterval(fw);
    ov.classList.add("out"); await this.wait(350); ov.remove();
    this.repairCams(o.cam);
    if(seg.t==="f"){this.info.free=o.free;this.info.fbet=o.bet;}
  },

  async prize(o){
    document.querySelectorAll("#reels .bst").forEach(x=>x.classList.add("win"));
    const c=o.prize.t==="card"?BYID[o.prize.card]:null;
    Sfx.p("fanfare"); buzz([30,30,60]); this.party("party",2000);
    await this.banner(c?`<small>CARTE OFFERTE</small><b>${esc(c.name)}</b><span>Épique · ajoutée à ta collection</span>`
      :`<small>CADEAU</small><b>${BOOSTER_SVG} ${o.prize.n} BOOSTER${o.prize.n>1?"S":""}</b><span>ajouté${o.prize.n>1?"s":""} à ta réserve</span>`,"gift",1900);
  },

  async bigWin(win,bet,label){
    const x=win/bet, name=label||(x>=100?"MÉGA GAIN":x>=50?"SUPER GAIN":"GROS GAIN");
    const ov=document.createElement("div"); ov.className="bigwin"; ov.innerHTML=`<div class="bw-rays"></div><b>${name}</b><span id="bwv">0 K</span><small>Touche pour continuer</small>`;
    document.body.appendChild(ov); Sfx.p("jackpot"); buzz([50,30,50,30,150]); this.party("party",4000);
    let stop=false; ov.onclick=()=>{stop=true;};
    const t0=performance.now(), dur=this.fast?600:Math.min(4200,1600+x*18), v=ov.querySelector("#bwv");
    let lastTick=0;
    const rain=setInterval(()=>SFx.burst(Math.random()*innerWidth,-10,["#ffd23f","#fff1a8","#ff9a3d","#ffffff"],14,{speed:3,g:.25,life:120,conf:true,size:3.4}),110);
    await new Promise(res=>{const f=now=>{const k=stop?1:Math.min(1,(now-t0)/dur);v.textContent=this.fmtK(win*(1-Math.pow(1-k,3)));
      if(now-lastTick>60&&k<1){lastTick=now;Sfx.p("coin");}
      if(k<1&&ov.isConnected)requestAnimationFrame(f);else res();};requestAnimationFrame(f);});
    await new Promise(res=>{const tm=setTimeout(res,stop?200:1500);ov.onclick=()=>{clearTimeout(tm);res();};});
    clearInterval(rain); ov.classList.add("out"); setTimeout(()=>ov.remove(),300);
  },

  /* ---------- Règles ---------- */
  paytable(){
    const dlg=$("#dlg"), I=this.info; if(!I) return;
    const row=i=>{const c=this.sym(i);if(!c)return"";return `<div class="ptr">${this.tile(i)}<div class="ptn"><b>${esc(c.name)}</b><span class="note">${i===SJ?"Joker · remplace toutes les réfs":SLOT_ROLE[i]+(c.gen===2?" · Gén. 2":" · Gén. 1")}${c.audio&&(c.r==="E"||c.r==="L")?" · 🔊":""}</span></div><div class="ptp">${[3,4,5].map(k=>`<span>${k}× <b>${SLOT_PAY[k][i]}</b></span>`).join("")}</div></div>`;};
    dlg.innerHTML=`<div class="dlg paytbl"><p class="eyebrow">Fortune Khey</p><h2>Règles et gains</h2>
      <p class="note"><b>243 façons de gagner</b> : la même réf sur 3 rouleaux voisins ou plus, en partant de la gauche, sur n'importe quelle ligne. Si une réf apparaît plusieurs fois sur un rouleau, le gain est multiplié d'autant. Gains en multiples de ta mise (1, 5 ou 10 K).
      Les réfs changent toutes les 6 heures (prochain changement dans ${this.nextIn()}). Aligner une épique ou une légendaire joue son son.</p>
      <div class="ptlist">${[14,13,12,11,10,9,8,7,6,5,4,3,2,1,0].map(row).join("")}</div>
      <div class="ptx"><div class="ptr">${this.tile(SCOIN,3)}<div class="ptn"><b>Khey d'or</b><span class="note">6 pièces ou plus : <b>Pluie de Kheys</b>. Les pièces restent, 3 relances, chaque nouvelle pièce remet les relances à 3. Grille pleine = GRAND.</span></div></div>
      <div class="ptr">${this.tile(SCAM)}<div class="ptn"><b>Appareil photo</b><span class="note">Chaque appareil qui tombe abîme ceux de Nils (3 coups chacun). Les 3 détruits : <b>roue de Nils</b> (×8 à ×60 ou 6 à 15 tours gratuits).</span></div></div>
      <div class="ptr">${this.tile(SBST)}<div class="ptn"><b>Booster</b><span class="note">3 n'importe où : 1 booster · 4 : 3 boosters · 5 : une carte épique.</span></div></div></div>
      <p class="note">Jackpots sur les pièces : MINI 20×, MINOR 50×, MAJOR 250× la mise. <b>GRAND</b> = la cagnotte partagée (3 % de toutes les mises) : en entier à 10 K, la moitié à 5 K, 10 % à 1 K.
      Retour moyen ≈ 92 % : sur la durée, la machine garde environ 8 % des mises. 500 tours payants par jour.</p>
      <div class="row" style="justify-content:flex-end"><button type="button" class="btn ghost" id="ptclose">Fermer</button></div></div>`;
    $("#ptclose").onclick=()=>dlg.close(); dlg.showModal();
  },
};
const SFx=makeFx();
// Appareil photo rétro (celui de Nils)
const CAM_SVG=`<svg class="camsvg" viewBox="0 0 100 76" aria-hidden="true">
  <defs><linearGradient id="cpl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f7fc"/><stop offset=".5" stop-color="#b9c2d3"/><stop offset="1" stop-color="#7f889c"/></linearGradient>
  <linearGradient id="cbd" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#34303f"/><stop offset="1" stop-color="#121018"/></linearGradient>
  <radialGradient id="cgl" cx=".38" cy=".35" r=".75"><stop offset="0" stop-color="#9fe8ff"/><stop offset=".35" stop-color="#2a5ea8"/><stop offset=".7" stop-color="#140b3a"/><stop offset="1" stop-color="#05030d"/></radialGradient>
  <pattern id="clt" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="4" fill="none"/><circle cx="1" cy="1" r=".7" fill="rgba(255,255,255,.07)"/></pattern></defs>
  <rect x="1" y="27" width="6" height="12" rx="2" fill="url(#cpl)"/><rect x="93" y="27" width="6" height="12" rx="2" fill="url(#cpl)"/>
  <path d="M33 15 L39 4 H61 L67 15 Z" fill="url(#cpl)" stroke="#5c6475" stroke-width="1"/><rect x="43" y="7" width="14" height="5" rx="1" fill="#1a1a24"/>
  <rect x="12" y="5" width="15" height="9" rx="2" fill="#e8eef8" stroke="#5c6475" stroke-width="1"/><rect x="14" y="7" width="11" height="5" rx="1" fill="#fffbe6"/>
  <rect x="71" y="7" width="11" height="7" rx="2" fill="#ff3b5c" stroke="#8a1028" stroke-width="1"/>
  <rect x="5" y="13" width="90" height="15" rx="5" fill="url(#cpl)" stroke="#5c6475" stroke-width="1"/>
  <rect x="5" y="24" width="90" height="48" rx="7" fill="url(#cbd)"/><rect x="5" y="24" width="90" height="48" rx="7" fill="url(#clt)"/>
  <text x="84" y="22.5" font-size="6" font-weight="900" fill="#3a4152" text-anchor="middle" font-family="Arial">NILS</text>
  <circle cx="50" cy="48" r="25" fill="url(#cpl)" stroke="#4a5263" stroke-width="1.2"/><circle cx="50" cy="48" r="21" fill="#1b1a24"/>
  <circle cx="50" cy="48" r="19" fill="none" stroke="#3b3a48" stroke-width="1.5" stroke-dasharray="1.5 2"/>
  <circle cx="50" cy="48" r="15.5" fill="url(#cgl)"/><circle cx="50" cy="48" r="6.5" fill="#030208"/>
  <ellipse cx="44" cy="41" rx="5" ry="3" fill="#fff" opacity=".55" transform="rotate(-30 44 41)"/><circle cx="57" cy="54" r="1.6" fill="#fff" opacity=".35"/>
  <circle cx="86" cy="34" r="3" fill="#ff3bd5"/></svg>`;
const CRACK_SVG=`<svg class="crack" viewBox="0 0 100 76" aria-hidden="true"><path class="c1" d="M50 48l-6-9 3-6M50 48l9-4 6 3M50 48l-2 10 4 6"/><path class="c2" d="M44 39l-9-5-6 2M59 44l10-9M48 58l-9 7M50 48l12 9 5 8M50 48l-15 3"/><path class="c3" d="M29 36l-14-8M69 35l18-7M39 65l-6 9M67 65l10 9M35 51l-24 2"/></svg>`;
// Symbole booster : un mini paquet REF POCKET
const BOOSTER_SVG=`<svg class="bstsvg" viewBox="0 0 60 80" aria-hidden="true">
  <defs><linearGradient id="bpg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd23f"/><stop offset=".33" stop-color="#ff6fbf"/><stop offset=".66" stop-color="#8b7bff"/><stop offset="1" stop-color="#21d4fd"/></linearGradient>
  <linearGradient id="bps" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>
  <path d="M5 9 L8.5 4 L12 9 L15.5 4 L19 9 L22.5 4 L26 9 L29.5 4 L33 9 L36.5 4 L40 9 L43.5 4 L47 9 L50.5 4 L55 9 V71 L51.5 76 L48 71 L44.5 76 L41 71 L37.5 76 L34 71 L30.5 76 L27 71 L23.5 76 L20 71 L16.5 76 L13 71 L9.5 76 L5 71 Z" fill="url(#bpg)" stroke="#fff" stroke-width="1.6" stroke-linejoin="round"/>
  <rect x="5" y="13" width="50" height="2.5" fill="rgba(255,255,255,.6)"/><rect x="5" y="64" width="50" height="2.5" fill="rgba(255,255,255,.6)"/>
  <text x="30" y="37" font-family="Bowlby One, Impact, sans-serif" font-size="13" fill="#1a1030" text-anchor="middle" transform="rotate(-8 30 40)">REF</text>
  <text x="30" y="50" font-family="Bowlby One, Impact, sans-serif" font-size="8.5" fill="#1a1030" text-anchor="middle" transform="rotate(-8 30 40)">POCKET</text>
  <rect x="17" y="54" width="26" height="6" rx="3" fill="#1a1030"/><text x="30" y="58.8" font-family="Arial" font-weight="900" font-size="4.6" fill="#fff" text-anchor="middle">BOOSTER</text>
  <path class="bshine" d="M-20 80 L10 0 H22 L-8 80 Z" fill="url(#bps)"/></svg>`;
