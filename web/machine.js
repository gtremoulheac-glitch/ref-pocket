/* =========================================================
   MACHINE À SOUS « FORTUNE KHEY »
   Le tirage se fait sur le serveur (slot_spin) : ici, on ne fait que l'animer.
   Symboles = 11 réfs de la semaine (les deux générations) + pièce, appareil photo de Nils, booster.
   ========================================================= */
const SLOT_LINES=[[1,1,1,1,1],[0,0,0,0,0],[2,2,2,2,2],[0,1,2,1,0],[2,1,0,1,2],[0,0,1,2,2],[2,2,1,0,0],[1,0,0,0,1],[1,2,2,2,1],[1,0,1,2,1],
  [1,2,1,0,1],[0,1,0,1,0],[2,1,2,1,2],[0,1,1,1,0],[2,1,1,1,2],[1,1,0,1,1],[1,1,2,1,1],[0,2,0,2,0],[2,0,2,0,2],[0,2,2,2,0]];
const SLOT_W=[25,25,23,23,8,8,7,4,4,2.5,2.3,18,1.1,1.4];      // seulement pour l'aspect des rouleaux qui défilent
const SLOT_PAY={3:[1,1,1,1,2,2,2,4,4,8,10],4:[2,2,2,2,5,5,5,10,10,25,40],5:[4,4,4,4,12,12,12,40,40,100,250]};
const SLOT_JP={101:["MINI",20],102:["MINOR",50],103:["MAJOR",250],104:["GRAND",0]};
const LINE_COL=["#21d4fd","#ff3bd5","#c6ff3d","#ffd23f","#ff8a3d","#8b7bff","#3dffa8","#ff4f6d"];

const Slot={
  info:null, bet:1, busy:false, fast:false, cam:0,
  sym(i){const id=this.info?.symbols?.[i];return id&&BYID[id]||null;},
  alive(){return !!document.getElementById("reels");},
  wait(ms){return new Promise(r=>{if(!this.alive())return r();setTimeout(r,this.fast?ms*.25:ms);});},
  fmtK(n){return `${fmt(Math.round(n))} K`;},

  async load(){
    const r=await sb.rpc("slot_info");
    if(r.error){toast("Machine indisponible : relance schema.sql dans Supabase ("+errMsg(r.error)+")");return;}
    this.info=r.data; this.cam=r.data.cam||0;
    (this.info.symbols||[]).forEach(id=>{const c=BYID[id];if(c&&c.image){const im=new Image();im.src=c.image;}});
    if(tab==="machine"&&!this.busy) render();
  },

  /* ---------- Rendu ---------- */
  tile(sym,coin){
    if(sym===11){const v=coin||[1,2,3,5][Math.floor(Math.random()*4)],jp=SLOT_JP[v];
      return `<div class="tl coin${jp?" jp jp-"+jp[0].toLowerCase():""}"><span class="cn"><b>${jp?jp[0]:this.fmtK(v*this.bet)}</b></span></div>`;}
    if(sym===12) return `<div class="tl camt"><span class="ci">${CAM_SVG}</span></div>`;
    if(sym===13) return `<div class="tl bst"><span class="bi">🎴</span><i>BOOSTER</i></div>`;
    const c=this.sym(sym); if(!c) return `<div class="tl"><span class="em">❔</span></div>`;
    const t=typeOf(c.type);
    return `<div class="tl ref r-${c.r}${sym===10?" wild":""}" style="--tc:${esc(t.color)}" title="${esc(c.name)}">${c.image?`<img src="${esc(c.image)}" alt="" draggable="false">`:`<span class="em">${esc(c.art||"❔")}</span>`}${sym===10?'<i class="wt">JOKER</i>':""}</div>`;
  },
  randSym(r){let w=SLOT_W.slice();if(r===0||r===4)w[10]=0;let t=Math.random()*w.reduce((a,b)=>a+b,0);for(let i=0;i<w.length;i++){t-=w[i];if(t<0)return i;}return 0;},
  camsHTML(n){
    return [0,1,2].map(i=>{const hits=Math.max(0,Math.min(3,n-i*3));return `<div class="cam h${hits}" data-cam="${i}" aria-label="Appareil ${i+1} : ${hits} coup${hits>1?"s":""} sur 3">${CAM_SVG}${CRACK_SVG}</div>`;}).join("");
  },
  view(){
    if(!this._b){this._b=1;if([1,5,10].includes(L.sbet))this.bet=L.sbet;}
    const I=this.info;
    if(!I){this.load();return `<div class="slot"><p class="note" style="text-align:center;margin:auto">Chargement de la machine…</p></div>`;}
    const free=I.free||0, bet=free?I.fbet:this.bet;
    const g0=Array.from({length:15},(_,i)=>this.lastGrid?this.lastGrid[i]:this.randSym(Math.floor(i/3)));
    const reels=[0,1,2,3,4].map(r=>`<div class="reel" data-r="${r}"><div class="strip">${[0,1,2].map(k=>this.tile(g0[r*3+k],this.lastCoins?.[r*3+k])).join("")}</div></div>`).join("");
    const w=(I.wins||[])[0];
    return `<div class="slot${free?" freemode":""}">
      <canvas class="slotfx" id="slotfx" aria-hidden="true"></canvas>
      <div class="jp">
        <div class="jp-grand"><span>GRAND</span><b id="jpg">${this.fmtK(I.pool)}</b></div>
        <div class="jp-row"><div class="j3"><span>MAJOR</span><b>${fmt(250*bet)}</b></div><div class="j2"><span>MINOR</span><b>${fmt(50*bet)}</b></div><div class="j1"><span>MINI</span><b>${fmt(20*bet)}</b></div></div>
      </div>
      <div class="camrow"><div class="cams" id="cams">${this.camsHTML(this.cam)}</div><span class="camlab">Casse les appareils de Nils<br><b>→ Roue</b></span></div>
      <div class="reelbox"><div class="reels" id="reels">${reels}<svg class="plines" id="plines" viewBox="0 0 500 300" preserveAspectRatio="none" aria-hidden="true"></svg>
        <div class="slotbanner" id="sbanner" hidden></div></div></div>
      <div class="slotmsg" id="smsg" role="status">${free?`🎡 ${free} tour${free>1?"s":""} gratuit${free>1?"s":""} à ${bet} K`:w?`🏆 ${esc(pseudoOf(w.user))} : ${esc(w.label)}${w.amount?` · ${fmt(w.amount)} K`:""}`:"Aligne 3 réfs ou plus depuis la gauche"}</div>
      <div class="slotctl">
        <div class="bets" role="radiogroup" aria-label="Mise">${[1,5,10].map(b=>`<button role="radio" data-sbet="${b}" aria-checked="${bet===b}" ${free?"disabled":""}>${b} K</button>`).join("")}</div>
        <button class="spinbtn" id="spin" data-act="slotspin" ${!free&&S.me.kheys<bet?"disabled":""}><span>${free?"GRATUIT":"TOURNER"}</span><small>${free?`${free} restant${free>1?"s":""}`:`mise ${bet} K`}</small></button>
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
    const free=this.info.free||0, bet=free?this.info.fbet:this.bet;
    if(!free&&S.me.kheys<bet){toast("Pas assez de Kheys.");return;}
    Sfx.unlock(); this.busy=true; this.fast=false;
    const btn=document.getElementById("spin"); if(btn) btn.classList.add("going");
    this.msg(free?"Tour gratuit…":"Bonne chance…");
    this.clearLines();
    if(!free){S.me.kheys-=bet;renderTop();}
    // on lance les rouleaux tout de suite, la réponse du serveur arrive pendant qu'ils tournent
    const spinning=this.startReels();
    const r=await sb.rpc("slot_spin",{p_bet:bet});
    if(r.error){this.stopReels(spinning,null);if(!free)S.me.kheys+=bet;renderTop();this.busy=false;btn?.classList.remove("going");toast(errMsg(r.error));return;}
    const o=r.data;
    try{ await this.play(o,spinning); }
    catch(e){ console.error(e); }
    finally{
      S.me.kheys=o.kheys; this.info.free=o.free; this.info.fbet=o.bet; this.info.spins=o.spins; this.info.pool=o.pool; this.cam=o.cam; this.info.cam=o.cam;
      this.lastGrid=o.grid; this.lastCoins=o.coins;
      if(o.prize||o.win>=50*o.bet) this.load();   // tableau des gros gains
      this.busy=false; this.fast=false; renderTop();
      if(tab==="machine"&&this.alive()) this.refreshCtl(o);
      if(o.prize) sync().then(renderTop).catch(()=>{});
    }
  },
  refreshCtl(o){
    const v=$("#view"), keep=document.getElementById("reels");
    // on ne recrée que le bas (mise, bouton, compteurs) pour garder la grille affichée
    const tmp=document.createElement("div"); tmp.innerHTML=this.view();
    for(const sel of [".slotctl",".slotfoot",".jp",".slotmsg"]){const a=v.querySelector(sel),b=tmp.querySelector(sel);if(a&&b)a.replaceWith(b);}
    v.querySelector(".slot")?.classList.toggle("freemode",!!this.info.free);
    if(o&&o.win>0) this.msg(`Gagné : ${this.fmtK(o.win)} !`); else if(o&&!this.info.free) this.msg(o.prize?"🎁 Cadeau !":"Pas cette fois… retente !");
  },
  msg(t){const m=document.getElementById("smsg");if(m)m.textContent=t;},

  startReels(){
    const reels=[...document.querySelectorAll("#reels .reel")];
    Sfx.p("spin");
    return reels.map((el,r)=>{
      const strip=el.querySelector(".strip"), th=el.clientHeight/3;
      // bande qui défile en boucle pendant l'attente du serveur
      const filler=Array.from({length:12},()=>this.tile(this.randSym(r))).join("");
      strip.innerHTML=filler+strip.innerHTML; strip.style.transform=`translateY(${-12*th}px)`;
      el.classList.add("spinning");
      const a=strip.animate([{transform:`translateY(${-12*th}px)`},{transform:`translateY(0px)`}],{duration:380,iterations:Infinity});
      return {el,strip,a,th};
    });
  },
  stopReels(sp,o){sp.forEach(s=>{s.a.cancel();s.el.classList.remove("spinning");s.strip.style.transform="";if(!o)s.strip.innerHTML=s.strip.innerHTML.split('<div class="tl').slice(-3).map(x=>'<div class="tl'+x).join("");});},

  async play(o,sp){
    const g=o.grid, coins=o.coins||{};
    // anticipation : 4 pièces ou plus sur les 3 premiers rouleaux -> les derniers ralentissent
    const coinsUpTo=r=>g.slice(0,(r+1)*3).filter(x=>x===11).length;
    let t=this.fast?150:550;
    for(let r=0;r<5;r++){
      const s=sp[r]; if(!s||!s.el.isConnected) break;
      const tease=r>=3&&coinsUpTo(r-1)>=4;
      if(tease){s.el.classList.add("tease");Sfx.p("tease");await this.wait(900);}
      await this.landReel(s,g.slice(r*3,r*3+3),coins,r,t);
      s.el.classList.remove("tease");
      t=this.fast?80:190;
    }
    if(!this.alive()) return;
    // appareils photo touchés
    if(o.cams>0) await this.camHits(o);
    // lignes gagnantes
    let shown=0;
    if(o.lines&&o.lines.length){shown=await this.showLines(o);}
    // Pluie de Kheys
    if(o.bonus&&typeof o.bonus==="object") shown+=await this.pluie(o);
    // roue de Nils
    if(o.wheel) shown+=await this.wheel(o);
    // boosters / carte offerts
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
    const d=this.fast?120:320;
    const an=s.strip.animate([{transform:`translateY(${-6*th}px)`},{transform:`translateY(${th*.12}px)`,offset:.85},{transform:"translateY(0px)"}],{duration:d,easing:"cubic-bezier(.3,.7,.4,1)"});
    await new Promise(res=>{an.onfinish=res;an.oncancel=res;setTimeout(res,d+60);});
    s.strip.innerHTML=finals; s.strip.style.transform=""; s.el.classList.remove("spinning");
    Sfx.p("stop"); buzz(8);
    if(col.includes(12)){Sfx.p("shutter");s.el.querySelectorAll(".camt").forEach(x=>x.classList.add("flash"));}
    if(col.includes(11)) Sfx.p("coin");
  },
  cell(p){const r=Math.floor(p/3),k=p%3;return document.querySelector(`#reels .reel[data-r="${r}"] .strip`)?.children[k]||null;},

  /* ---------- Appareils photo de Nils ---------- */
  async camHits(o){
    const cams=document.getElementById("cams"); if(!cams) return;
    let n=this.cam; const total=n+o.cams;   // avant le tour (o.cam = après, roue déduite)
    const pos=o.grid.map((x,i)=>x===12?i:-1).filter(i=>i>=0);
    for(const p of pos){
      if(n>=9) break;
      const el=this.cell(p), ci=Math.floor(n/3), cam=cams.querySelector(`[data-cam="${ci}"]`);
      if(el&&cam){await this.flyTo(el,cam,"#ffffff");}
      n++;
      const hits=n-ci*3;
      if(cam){cam.className=`cam h${hits} hit`;void cam.offsetWidth;
        if(hits>=3){cam.classList.add("boom");Sfx.p("smash");buzz([20,30,60]);const rc=cam.getBoundingClientRect();SFx.burst(rc.left+rc.width/2,rc.top+rc.height/2,["#ffffff","#bfefff","#21d4fd","#ff3bd5"],40,{speed:6,g:.18,life:60,conf:true});}
        else{Sfx.p("crack");buzz(15);}}
      await this.wait(260);
    }
    this.cam=Math.min(9,total);
  },
  flyTo(from,to,col){
    return new Promise(res=>{
      const a=from.getBoundingClientRect(), b=to.getBoundingClientRect();
      const d=document.createElement("div"); d.className="flydot"; d.style.background=col;
      d.style.left=(a.left+a.width/2)+"px"; d.style.top=(a.top+a.height/2)+"px"; document.body.appendChild(d);
      const dx=b.left+b.width/2-(a.left+a.width/2), dy=b.top+b.height/2-(a.top+a.height/2);
      const an=d.animate([{transform:"translate(-50%,-50%) scale(1.4)",opacity:1},{transform:`translate(calc(-50% + ${dx}px),calc(-50% + ${dy}px)) scale(.6)`,opacity:.9}],{duration:this.fast?120:420,easing:"cubic-bezier(.5,0,.3,1)"});
      an.onfinish=()=>{d.remove();res();}; setTimeout(()=>{d.remove();res();},700);
    });
  },
  async repairCams(left){
    const cams=document.getElementById("cams"); if(!cams) return;
    cams.innerHTML=this.camsHTML(left); cams.querySelectorAll(".cam").forEach(c=>c.classList.add("repair"));
  },

  /* ---------- Lignes ---------- */
  clearLines(){const sv=document.getElementById("plines");if(sv)sv.innerHTML="";document.querySelectorAll("#reels .tl.win").forEach(x=>x.classList.remove("win"));},
  async showLines(o){
    const sv=document.getElementById("plines"); if(!sv) return 0;
    const all=o.lines; let sum=0;
    const draw=(L,i)=>{const pts=SLOT_LINES[L.l].map((row,r)=>`${50+r*100},${50+row*100}`).join(" ");const c=LINE_COL[i%LINE_COL.length];
      return `<polyline points="${pts}" style="--lc:${c}" class="pl"/>`;};
    // toutes les lignes d'un coup, puis une par une
    sv.innerHTML=all.map(draw).join("");
    for(const L of all) for(let r=0;r<L.n;r++) this.cell(r*3+SLOT_LINES[L.l][r])?.classList.add("win");
    Sfx.p(all.reduce((s,x)=>s+x.w,0)>=5*o.bet?"win":"smallwin");
    for(const L of all) sum+=L.w;
    this.countUp(sum,500);
    await this.wait(all.length>1?650:900);
    if(all.length>1&&!this.fast){
      for(const [i,L] of all.slice(0,6).entries()){
        if(!this.alive()) break;
        document.querySelectorAll("#reels .tl.win").forEach(x=>x.classList.remove("win"));
        sv.innerHTML=draw(L,i);
        for(let r=0;r<L.n;r++) this.cell(r*3+SLOT_LINES[L.l][r])?.classList.add("win");
        const c=this.sym(L.s); this.msg(`${L.n} × ${c?c.name:"réf"} : ${this.fmtK(L.w)}`);
        await this.wait(520);
      }
      sv.innerHTML=all.map(draw).join("");
    }
    return sum;
  },
  countUp(to,ms,from=0){const m=document.getElementById("smsg");if(!m)return;const t0=performance.now();
    const f=now=>{const k=Math.min(1,(now-t0)/(this.fast?ms*.3:ms));m.textContent=`Gagné : ${this.fmtK(from+(to-from)*k)}`;if(k<1&&m.isConnected)requestAnimationFrame(f);};requestAnimationFrame(f);},
  banner(html,cls,ms){
    const b=document.getElementById("sbanner"); if(!b) return Promise.resolve();
    b.className="slotbanner "+(cls||""); b.innerHTML=html; b.hidden=false; void b.offsetWidth; b.classList.add("on");
    return this.wait(ms||1300).then(()=>{b.classList.remove("on");return this.wait(200);}).then(()=>{b.hidden=true;});
  },

  /* ---------- Pluie de Kheys (6 pièces ou plus) ---------- */
  async pluie(o){
    const B=o.bonus, reels=document.getElementById("reels"); if(!reels) return 0;
    reels.classList.add("bonusmode"); Sfx.L(); buzz([40,40,80]);
    const rc=reels.getBoundingClientRect();
    SFx.burst(rc.left+rc.width/2,rc.top,["#ffd23f","#fff1a8","#ff9a3d"],60,{speed:7,g:.2,life:80,conf:true});
    await this.banner(`<b>PLUIE DE KHEYS</b><span>Chaque nouvelle pièce relance le compteur</span>`,"gold",1500);
    const coins={...o.coins};
    const rs=document.createElement("div"); rs.className="respins"; reels.appendChild(rs);
    const setR=n=>{rs.innerHTML=`Relances <b>${"●".repeat(n)}${"○".repeat(3-n)}</b>`;};
    let n=3; setR(n);
    for(const step of B.steps){
      if(!this.alive()) break;
      // les cases vides frémissent
      for(let p=0;p<15;p++) if(!(String(p) in coins)) this.cell(p)?.classList.add("rs");
      Sfx.p("spin"); await this.wait(650);
      for(let p=0;p<15;p++) this.cell(p)?.classList.remove("rs");
      if(step.length){
        for(const c of step){coins[c.p]=c.v;const el=this.cell(c.p);if(el){el.outerHTML=this.tile(11,c.v);const ne=this.cell(c.p);ne?.classList.add("drop","lock");}Sfx.p("coin");buzz(12);await this.wait(170);}
        n=3; setR(n); rs.classList.remove("pulse"); void rs.offsetWidth; rs.classList.add("pulse");
      } else { n--; setR(n); Sfx.p("stop"); }
      await this.wait(300);
    }
    rs.remove();
    // décompte des pièces une par une
    let tot=0; const order=Object.keys(coins).map(Number).sort((a,b)=>a-b);
    for(const p of order){
      if(!this.alive()) break;
      const v=coins[p], el=this.cell(p); el?.classList.add("tally");
      if(v<100) tot+=v*o.bet;
      else if(v<104){tot+=SLOT_JP[v][1]*o.bet; await this.jackpot(SLOT_JP[v][0],SLOT_JP[v][1]*o.bet);}
      this.msg(`Pluie de Kheys : ${this.fmtK(tot)}`); Sfx.p("tick"); await this.wait(order.length>10?110:170);
    }
    const gr=(o.events||[]).find(e=>e.t==="grand");
    if(gr){tot+=gr.v; await this.jackpot("GRAND",gr.v);}
    reels.classList.remove("bonusmode");
    await this.wait(300);
    return tot;
  },
  async jackpot(name,amount){
    Sfx.L(); buzz([60,40,60,40,120]);
    const rc=document.getElementById("reels")?.getBoundingClientRect();
    if(rc) for(let i=0;i<3;i++) setTimeout(()=>SFx.burst(rc.left+rc.width*(0.2+0.3*i),rc.top+rc.height/2,["#ffd23f","#ffffff","#ff3bd5","#21d4fd"],70,{speed:9,g:.12,life:90,conf:true}),i*200);
    await this.banner(`<small>JACKPOT</small><b>${name}</b><span>+ ${this.fmtK(amount)}</span>`,"jackpot jp-"+name.toLowerCase(),name==="GRAND"?3200:1900);
  },

  /* ---------- Roue de Nils ---------- */
  async wheel(o){
    const W=this.info.wheel||[], seg=o.wheel, n=W.length||8, step=360/n;
    Sfx.p("smash"); await this.wait(300);
    const ov=document.createElement("div"); ov.className="wheelov"; ov.setAttribute("role","dialog"); ov.setAttribute("aria-label","Roue de Nils");
    const cols=["#21d4fd","#ff3bd5","#ffd23f","#3dffa8","#8b7bff","#ff8a3d","#ff4f6d","#c6ff3d"];
    const grad=W.map((s,i)=>`${s.t==="w"?cols[i%cols.length]:"#1b1440"} ${i*step}deg ${(i+1)*step}deg`).join(",");
    ov.innerHTML=`<div class="wh-in"><p class="wh-t">Les 3 appareils sont cassés !</p><h2>ROUE DE NILS</h2>
      <div class="wh-box"><div class="wh-ptr"></div><div class="wh" id="wh" style="background:conic-gradient(${grad})">
        ${W.map((s,i)=>`<span class="ws ${s.t}" style="transform:rotate(${i*step+step/2}deg)"><b>${s.t==="w"?`×${s.v}`:`${s.v}<small>TOURS</small>`}</b></span>`).join("")}
        <div class="wh-hub">📷</div></div></div><p class="wh-res" id="whres">&nbsp;</p></div>`;
    document.body.appendChild(ov);
    await this.wait(500);
    const wh=ov.querySelector("#wh"), turns=this.fast?2:5, target=turns*360+(360-(seg.i*step+step/2));
    const dur=this.fast?1200:4600;
    wh.style.transition=`transform ${dur}ms cubic-bezier(.12,.62,.1,1)`; void wh.offsetWidth; wh.style.transform=`rotate(${target}deg)`;
    // tic-tac à chaque case qui passe
    let last=0; const t0=performance.now();
    await new Promise(res=>{const f=()=>{const m=getComputedStyle(wh).transform;let a=0;if(m&&m!=="none"){const v=m.split("(")[1].split(",");a=Math.atan2(+v[1],+v[0])*180/Math.PI;}
      const k=Math.floor(((a%360)+360)%360/step); if(k!==last){last=k;Sfx.p("tick");} if(performance.now()-t0<dur+50&&ov.isConnected)requestAnimationFrame(f);else res();};requestAnimationFrame(f);});
    const res=ov.querySelector("#whres");
    if(seg.t==="w"){res.innerHTML=`<b>×${seg.v}</b> = ${this.fmtK(seg.amount)}`;Sfx.E();}
    else{res.innerHTML=`<b>${seg.v} TOURS GRATUITS</b>`;Sfx.L();}
    res.classList.add("on"); buzz([30,30,90]);
    const r=ov.querySelector(".wh-box").getBoundingClientRect();
    SFx.burst(r.left+r.width/2,r.top+r.height/2,cols,90,{speed:10,g:.15,life:90,conf:true});
    await this.wait(2000);
    ov.classList.add("out"); await this.wait(350); ov.remove();
    this.repairCams(o.cam);
    if(seg.t==="f"){this.info.free=o.free;this.info.fbet=o.bet;}
    return seg.amount||0;
  },

  async prize(o){
    document.querySelectorAll("#reels .bst").forEach(x=>x.classList.add("win"));
    const c=o.prize.t==="card"?BYID[o.prize.card]:null;
    Sfx.E(); buzz([30,30,60]);
    await this.banner(c?`<small>CARTE OFFERTE</small><b>${esc(c.name)}</b><span>Épique · ajoutée à ta collection</span>`
      :`<small>CADEAU</small><b>🎴 ${o.prize.n} BOOSTER${o.prize.n>1?"S":""}</b><span>ajouté${o.prize.n>1?"s":""} à ta réserve</span>`,"gift",1800);
  },

  async bigWin(win,bet,label){
    const x=win/bet, name=label||(x>=100?"MÉGA GAIN":x>=50?"SUPER GAIN":"GROS GAIN");
    const ov=document.createElement("div"); ov.className="bigwin"; ov.innerHTML=`<b>${name}</b><span id="bwv">0 K</span><small>Touche pour continuer</small>`;
    document.body.appendChild(ov); Sfx.L(); buzz([50,30,50,30,150]);
    let stop=false; ov.onclick=()=>{stop=true;};
    const t0=performance.now(), dur=this.fast?600:Math.min(4200,1600+x*18), v=ov.querySelector("#bwv");
    const rain=setInterval(()=>SFx.burst(Math.random()*innerWidth,-10,["#ffd23f","#fff1a8","#ff9a3d","#ffffff"],14,{speed:3,g:.25,life:120,conf:true,size:3.4}),120);
    await new Promise(res=>{const f=now=>{const k=stop?1:Math.min(1,(now-t0)/dur);v.textContent=this.fmtK(win*(1-Math.pow(1-k,3)));if(k<1&&ov.isConnected)requestAnimationFrame(f);else res();};requestAnimationFrame(f);});
    await new Promise(res=>{const tm=setTimeout(res,stop?200:1500);ov.onclick=()=>{clearTimeout(tm);res();};});
    clearInterval(rain); ov.classList.add("out"); setTimeout(()=>ov.remove(),300);
  },

  /* ---------- Règles ---------- */
  paytable(){
    const dlg=$("#dlg"), I=this.info; if(!I) return;
    const row=i=>{const c=this.sym(i);if(!c)return"";return `<div class="ptr">${this.tile(i)}<div class="ptn"><b>${esc(c.name)}</b><span class="note">${i===10?"Joker · remplace toutes les réfs":RARITIES[c.r].name+(c.gen===2?" · Gén. 2":" · Gén. 1")}</span></div><div class="ptp">${[3,4,5].map(k=>`<span>${k}× <b>${SLOT_PAY[k][i]}</b></span>`).join("")}</div></div>`;};
    dlg.innerHTML=`<div class="dlg paytbl"><p class="eyebrow">Fortune Khey</p><h2>Règles et gains</h2>
      <p class="note">Les réfs changent chaque semaine. 20 lignes : aligne au moins 3 réfs identiques depuis la gauche. Les gains sont en multiples de ta mise (1, 5 ou 10 K).</p>
      <div class="ptlist">${[10,9,8,7,6,5,4,3,2,1,0].map(row).join("")}</div>
      <div class="ptx"><div class="ptr">${this.tile(11,3)}<div class="ptn"><b>Khey d'or</b><span class="note">6 pièces ou plus : <b>Pluie de Kheys</b>. Les pièces restent, 3 relances, chaque nouvelle pièce remet les relances à 3. Grille pleine = GRAND.</span></div></div>
      <div class="ptr">${this.tile(12)}<div class="ptn"><b>Appareil photo</b><span class="note">Chaque appareil qui tombe abîme ceux de Nils (3 coups chacun). Les 3 cassés : <b>roue</b> (×8 à ×60 ou 6 à 15 tours gratuits).</span></div></div>
      <div class="ptr">${this.tile(13)}<div class="ptn"><b>Booster</b><span class="note">3 n'importe où : 1 booster · 4 : 3 boosters · 5 : une carte épique.</span></div></div></div>
      <p class="note">Jackpots sur les pièces : MINI 20×, MINOR 50×, MAJOR 250× la mise. <b>GRAND</b> = la cagnotte partagée (3 % de toutes les mises) : en entier à 10 K, la moitié à 5 K, 10 % à 1 K.
      Retour moyen ≈ 92 % : sur la durée, la machine garde environ 8 % des mises. 500 tours payants par jour.</p>
      <div class="row" style="justify-content:flex-end"><button type="button" class="btn ghost" id="ptclose">Fermer</button></div></div>`;
    $("#ptclose").onclick=()=>dlg.close(); dlg.showModal();
  },
};
const SFx=makeFx();
const CAM_SVG=`<svg class="camsvg" viewBox="0 0 64 48" aria-hidden="true"><rect x="3" y="11" width="58" height="34" rx="7" fill="#1f1a33" stroke="currentColor" stroke-width="3"/><path d="M20 11l5-7h14l5 7" fill="#1f1a33" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/><circle cx="32" cy="28" r="11" fill="#0b0820" stroke="currentColor" stroke-width="3"/><circle cx="32" cy="28" r="5" fill="currentColor" opacity=".55"/><circle cx="51" cy="18" r="2.5" fill="#ff3bd5"/></svg>`;
const CRACK_SVG=`<svg class="crack" viewBox="0 0 64 48" aria-hidden="true"><path class="c1" d="M30 18l4 6-5 4 6 7"/><path class="c2" d="M34 24l9-3 6 4M29 28l-10 2-6-4"/><path class="c3" d="M35 35l-2 9M22 30l-8 12M43 21l12-9M24 17l-9-7"/></svg>`;
