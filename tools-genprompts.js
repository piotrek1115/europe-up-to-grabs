const fs=require("fs");
const h=fs.readFileSync("/Users/piotrkujko/barbarzyncy/KARTY-ART.html","utf8");

// ---- wspólne DNA stylu (identyczne dla KAŻDEJ karty = spójność serii) ----
/* ===== DNA STYLU =====
   Wersja 2, po teście na Gemini: pierwsza wersja dawała 4 różne "ręce" na 4 kartach.
   Przyczyny: alternatywy w opisie techniki (woodcut/engraving), sprzeczność (flat + painterly),
   brak sztywnej reguły tła i kadru. Teraz: JEDNA technika, JEDEN sposób cieniowania, zero "lekko". */
const STYLE=[
 "ONE SINGLE ILLUSTRATION STYLE, as if every card in this deck was drawn by the SAME artist in the same week",
 "TECHNIQUE: flat folk woodblock-poster illustration — drawn as clean vector-like shapes, NOT a painting, NOT a sketch, NOT 3D, NOT photorealistic",
 "LINework: every shape has a black ink outline of CONSTANT medium thickness; no thin-to-thick tapering, no sketchy or doubled lines",
 "COLOUR: strictly FLAT fills — exactly two tones per colour (base + one darker shade). NO gradients, NO airbrush, NO blending, NO cross-hatching, NO engraving lines, NO texture inside shapes",
 "PALETTE: use ONLY these — parchment #efe4cf, rust #8f2d22, burnt-orange #c07a1a, ochre-gold #b8860b, deep-brown #5a4a35, muted-green #2f6f3a, dark-violet #3a2a55, charcoal #2b2117; warm earthy tones dominate, at most 6 colours per image",
 "FACES: stylized comic faces — large nose, small round eyes, one clear exaggerated expression; never realistic portraiture",
 "TONE: dramatic-but-comedic historical parody (NOT historically accurate)",
 "FULL BLEED: the illustration fills the entire canvas edge to edge and is cropped by the canvas itself — treat any border, frame, mount or paper margin as part of the artwork that must be painted over",
 "high readability at small size"
].join(" — ");
// Tło rozstrzygnięte SZTYWNO, bo to była największa oś rozjazdu (pergamin vs pełna sceneria).
const BG_FIGURE="BACKGROUND: one single flat parchment tone #efe4cf with faint paper grain and nothing else — no scenery, no landscape, no horizon line, no props behind the subject";
const BG_SCENE="BACKGROUND: simple flat landscape built from large plain colour shapes — at most three depth layers, no fine detail, no clutter";
// Dwie reguły wymuszone po teście na Gemini: model wypisywał opis jako napis i brał metafory dosłownie.
const NOTEXT="ABSOLUTELY NO TEXT ANYWHERE IN THE IMAGE: no title, no caption, no lettering, no letters, numbers, runes or symbols-as-writing — and no inscriptions, signage or engraved words on buildings, gates, banners, shields or scrolls; leave those surfaces blank. All typography is added later in InDesign";
const BRIEF="the Polish sentence above is a SCENE BRIEF telling you what to draw — never render it as words, and never depict a figure of speech literally";

const ACC={
  rome:"imperial-Rome accent: rust-red & gold, laurels and eagles, sun-bleached marble, purple-edged togas",
  goths:"Gothic accent: iron-grey & muted green, furs and horsehair, windswept motion, rough wooden shields",
  vandals:"Vandal accent: burnt-orange & looted gold, sea and sails, glittering plunder, sun-scorched skin",
  gauls:"Gaulish accent: dark-violet & bronze, torcs and drooping moustaches, deep forest, war-horns",
  rulers:"regal accent: crown, throne and heavier gold, commanding presence",
  events:"event accent: ominous deep-crimson mood, portentous sky, a wide dramatic moment",
  provinces:"PROVINCE PLATE: landscape vignette; leave the TOP-RIGHT corner clear for a banner and the WHOLE BOTTOM HALF clear for an army token",
  components:"game-component design asset, clean flat graphic, print-ready, minimal"
};

// Kadr podany liczbowo — "portret" bez rozmiaru dawał raz popiersie, raz całą postać w pełnym planie.
const TYPE={
  "POSTAĆ":"FRAMING: exactly ONE full-length standing character, whole body visible including feet, centered, filling about 85% of the frame height",
  "POSTAĆ (Dowódca)":"FRAMING: exactly ONE full-length standing commander, whole body visible including feet, centered, filling about 85% of the frame height, mid-command gesture",
  "WŁADCA":"FRAMING: exactly ONE full-length ruler on a throne, whole figure visible, centered, filling about 85% of the frame height, crown and regalia prominent",
  "WZMOCNIENIE":"FRAMING: ONE single iconic object centered, filling about 60% of the frame, no character",
  "TAKTYKA":"FRAMING: one or two full-length figures caught mid-action, whole bodies visible, centered, filling about 85% of the frame height",
  "REAKCJA":"FRAMING: one or two full-length figures in a sudden reaction beat, whole bodies visible, centered, filling about 85% of the frame height",
  "KARTA SPECJALNA":"FRAMING: ONE bold symbolic subject centered, filling about 65% of the frame",
  "WYDARZENIE":"FRAMING: wide establishing shot with a sense of scale, one clear focal point in the centre",
  "KOMPONENT":"FRAMING: flat symmetrical graphic asset, centered, print-ready"
};
// karty trzymane w ręce = zawsze pergamin (spójna talia); świat = scena
const SCENIC=new Set(["WYDARZENIE"]);

const AR={ province:"--ar 3:4", component:"--ar 1:1", card:"--ar 63:88" };

// ---- parser: sekcje h2 -> frakcja, potem karty ----
const secRe=/<h2[^>]*>([\s\S]*?)<\/h2>/g;
// zbuduj listę [indexStart, faction]
let secs=[], m;
while((m=secRe.exec(h))){
  const t=m[1].replace(/<[^>]+>/g,"").trim();
  let f=null;
  if(/RZYM/.test(t))f="rome"; else if(/GOCI/.test(t))f="goths";
  else if(/WANDAL/.test(t))f="vandals"; else if(/GAL/.test(t))f="gauls";
  else if(/WŁADC/.test(t))f="rulers"; else if(/WYDARZ/.test(t))f="events";
  else if(/PROWINCJ/.test(t))f="provinces"; else if(/KOMPONENT/.test(t))f="components";
  if(f) secs.push({at:m.index, f, title:t});
}
function facAt(i){ let cur=secs[0]; for(const s of secs){ if(s.at<=i) cur=s; else break; } return cur; }

// ---- karty ----
const cardRe=/<div class="card"><div class="chead"><span class="badge"[^>]*>([^<]*)<\/span><h4>([^<]*)<\/h4>[\s\S]*?<div class="art"><b>Ilustracja:<\/b>([\s\S]*?)<\/div>/g;
const out={}; secs.forEach(s=>out[s.f]=[]);
let c, N=0;
while((c=cardRe.exec(h))){
  const badge=c[1].trim();
  const name=c[2].trim();
  const art=c[3].replace(/<[^>]+>/g,"").trim();
  const sec=facAt(c.index);
  const f=sec.f;
  const acc=ACC[f]||"";
  const isBoard=/PLANSZA REGIONU/.test(name);
  const comp=isBoard
    ? "REGION BOARD: a play-mat that four province cards are laid onto — atmosphere lives at the EDGES, the centre stays calm and light; four EMPTY BLANK card slots in a 2x2 grid, each slot a tall rectangle of 3:4 proportion, the whole grid filling about 65% of the board; plus one blank horizontal banner shape at the top left completely empty"
    : (TYPE[badge]|| (f==="provinces"?"":TYPE["KARTA SPECJALNA"]));
  const ar = isBoard?"--ar 3:4" : f==="provinces"?AR.province : f==="components"?AR.component : AR.card;
  // subject = polski opis ilustracji (autorska treść) + akcent + kompozycja + styl
  const subjPersona = (f==="provinces")
    ? `Prowincja „${name}" — ${art}`
    : (f==="components")
    ? `${name} — ${art}`
    : `„${name}": ${art}`;
  const scenic = isBoard || f==="provinces" || SCENIC.has(badge);
  const bg = scenic ? BG_SCENE : BG_FIGURE;
  const prompt=[subjPersona, BRIEF, comp, acc, STYLE, bg, NOTEXT, ar].filter(Boolean).join(" — ");
  out[f].push({name,badge,art,prompt}); N++;
}

// ---- render HTML ----
const secMeta={
  rome:["RZYM — Zachodnie Cesarstwo","#7a1f1f"], goths:["GOCI","#4a5a3a"],
  vandals:["WANDALOWIE","#c07a1a"], gauls:["GALOWIE","#3a2a55"],
  rulers:["WŁADCY","#b8860b"], events:["WYDARZENIA","#8f2d22"],
  provinces:["PROWINCJE","#2f6f3a"], components:["POZOSTAŁE KOMPONENTY","#5a4a35"]
};
const order=["rome","goths","vandals","gauls","rulers","events","provinces","components"];
const esc=s=>s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");

let body="";
for(const f of order){
  const [title,col]=secMeta[f]; const cards=out[f]||[];
  body+=`<section><h2 style="border-color:${col}"><span class="dot" style="background:${col}"></span>${title} <span class="cnt">(${cards.length})</span></h2><div class="grid">`;
  for(const cd of cards){
    body+=`<div class="card"><div class="chead"><span class="badge">${esc(cd.badge)}</span><h4>${esc(cd.name)}</h4></div>`
      +`<div class="art"><b>Ilustracja (PL):</b> ${esc(cd.art)}</div>`
      +`<div class="prompt" onclick="cp(this)" title="kliknij, aby skopiować">${esc(cd.prompt)}</div></div>`;
  }
  body+=`</div></section>`;
}

const html=`<!doctype html><html lang="pl"><head><meta charset="utf-8"><title>Europe: Up To Grabs! — prompty graficzne</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#f5f3ee;color:#2b2117;font-family:-apple-system,Segoe UI,Roboto,sans-serif;line-height:1.45}
header{background:#2b2117;color:#f2e2c0;padding:26px 30px}
header h1{margin:0 0 6px;font-size:27px}
header p{margin:4px 0;opacity:.85;font-size:14px;max-width:960px}
main{padding:22px 30px 60px;max-width:1500px;margin:0 auto}
.note{background:#fff;border:1px solid #ddd6c6;border-radius:10px;padding:16px 20px;margin:20px 0 26px;font-size:14px}
.note b{color:#8f2d22}
.note code{background:#efe4cf;padding:1px 5px;border-radius:4px;font-size:12.5px}
section{margin:30px 0}
h2{font-size:22px;border-left:7px solid;padding-left:12px;margin:0 0 12px;display:flex;align-items:center;gap:10px}
.dot{width:14px;height:14px;border-radius:3px;display:inline-block}
.cnt{color:#9a8f78;font-weight:normal;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:14px}
.card{background:#fff;border:1px solid #ddd6c6;border-radius:9px;padding:12px 14px;break-inside:avoid}
.chead{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:7px}
.badge{background:#5a4a35;color:#fff;font-size:9.5px;letter-spacing:.6px;padding:3px 7px;border-radius:4px;font-weight:700}
.card h4{margin:0;font-size:14.5px}
.art{font-size:12.5px;color:#6b5a3d;margin:4px 0 8px}
.prompt{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11.5px;line-height:1.5;background:#2b2117;color:#f0e6cf;padding:10px 12px;border-radius:6px;cursor:pointer;white-space:pre-wrap;position:relative;transition:background .15s}
.prompt:hover{background:#3a2f22}
.prompt.copied::after{content:"skopiowano ✓";position:absolute;top:6px;right:8px;font-size:10px;background:#2f6f3a;color:#fff;padding:2px 6px;border-radius:4px;font-family:sans-serif}
@media print{.prompt{white-space:pre-wrap;background:#f3ecd8;color:#2b2117;border:1px solid #ccc}}
</style></head><body>
<header>
<h1>Europe: Up To Grabs! — prompty do generatora grafik</h1>
<p>Po jednym gotowym prompcie na każdą kartę (${N} łącznie). Każdy = polski opis sceny + akcent frakcji + kompozycja typu karty + <b>wspólne „DNA stylu"</b> (identyczne wszędzie → spójna seria) + proporcja karty. Kliknij dowolny prompt, aby skopiować.</p>
<p style="opacity:.7">Działa w Nano Banana Pro / Midjourney / Freepik. Sceny po polsku (silniki radzą sobie z PL), dyrektywy stylu po angielsku dla pewności.</p>
</header>
<main>
<div class="note">
<b>Jak używać:</b> wklej cały prompt do generatora. <code>--ar 63:88</code> to proporcja klasycznej karty (prowincje <code>3:4</code>, komponenty <code>1:1</code>) — jeśli Twój silnik nie zna <code>--ar</code>, usuń go i ustaw format w UI.
</div>
<div class="note" style="border-color:#8f2d22">
<b style="color:#8f2d22">Spójność serii — najważniejsze:</b> sam prompt NIE wystarczy. Test na Gemini pokazał, że te same reguły dają cztery różne „ręce”. Żeby cała talia wyglądała jak od jednego rysownika:
<ol style="margin:8px 0 0;padding-left:20px">
<li><b>Wygeneruj jeden obrazek wzorcowy</b> (master) i wybieraj tak długo, aż będzie dokładnie tym, czego chcesz.</li>
<li><b>Do każdej kolejnej karty podepnij go jako referencję stylu</b> — na Freepiku „Style reference”, w Midjourney <code>--sref &lt;url&gt;</code>. To robi 80% roboty.</li>
<li><b>Nie zmieniaj modelu w trakcie serii</b> — inny model = inny rysownik, nawet przy tym samym prompcie.</li>
<li>Generuj partiami po ok. 10 i porównuj z masterem, zanim pójdziesz dalej.</li>
</ol>
</div>
${body}
</main>
<script>
function cp(el){navigator.clipboard.writeText(el.textContent).then(()=>{document.querySelectorAll(".prompt.copied").forEach(x=>x.classList.remove("copied"));el.classList.add("copied");setTimeout(()=>el.classList.remove("copied"),1400);});}
</script>
</body></html>`;

fs.writeFileSync("/Users/piotrkujko/barbarzyncy/PROMPTY-KART.html",html);
console.log("Zapisano PROMPTY-KART.html — kart:",N);
for(const f of order)console.log("  ",f,(out[f]||[]).length);
