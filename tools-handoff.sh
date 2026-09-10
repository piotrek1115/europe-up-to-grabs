#!/bin/bash
# Buduje pakiet przekazania projektu (EUTG-handoff.zip).
# Użycie:  bash tools-handoff.sh [katalog-docelowy]     (domyślnie ~/Desktop)
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/Desktop}"
WORK="$(mktemp -d)"
PKG="$WORK/EUTG-handoff"
mkdir -p "$PKG/gra" "$PKG/materialy" "$PKG/grafiki"

cp "$SRC/index.html" "$SRC/README.md" "$PKG/gra/"
cp "$SRC/KARTY-ART.html" "$SRC/PROMPTY-KART.html" "$SRC/tools-genprompts.js" "$PKG/materialy/"
cp "$SRC/DOKUMENTACJA.html" "$PKG/materialy/DOKUMENTACJA-nieaktualna.html"

cat > "$PKG/00-START-TUTAJ.md" <<'EOF'
# Europe: Up To Grabs! — pakiet przekazania

> Czytasz to jako model/asystent przejmujący projekt. Ten plik daje ci pełny kontekst.
> Kolejność czytania: ten plik → `gra/index.html` (kod) → `materialy/PROMPTY-KART.html` (grafika).
> Stan kodu: wrzesień 2026. Prace nad grafiką: sierpień 2026.

---

## 1. Co to jest

Humorystyczna gra strategiczno-karciana dla 2–4 graczy o Wędrówce Ludów i upadku Rzymu
(V wiek n.e.). Tytuł PL: *Barbarzyńcy u Bram*.

Dwie rzeczy naraz:
1. **Grywalny prototyp cyfrowy** — jeden plik HTML, vanilla JS, zero zależności i buildu.
   Gracz prowadzi jedną frakcję, trzy pozostałe prowadzi Claude przez API (gadają,
   negocjują, blefują i zdradzają po polsku).
2. **Projekt gry planszowej** — prototyp jest narzędziem do testowania mechaniki, która
   docelowo ma wyjść jako fizyczna gra karciana. Stąd biblia kart i prompty graficzne.

Repozytorium: `github.com/piotrek1115/europe-up-to-grabs` (publiczne), katalog `~/barbarzyncy`.

**Właściciel projektu mówi po polsku — cała komunikacja, UI gry i teksty kart są po polsku.**

---

## 2. Jak uruchomić

    python3 -m http.server 4599 --directory .

i otwórz `http://localhost:4599`. Otwarcie przez `file://` też działa, ale API bywa
blokowane przez CORS.

Klucz API Anthropic wkleja się na ekranie startowym (zapisuje się w localStorage).
Bez klucza działa awaryjny bot — gra się toczy, ale frakcje nic nie mówią.
Model domyślny: `claude-sonnet-5`.

---

## 3. Stan: co działa

- Mapa 16 prowincji w 4 blokach regionów, neutralne prowincje mają własną Obronę 2–6.
- Faza układania stołu + **sąsiedztwo wynikające z układu** (patrz §4).
- Przygotowana Armia, bramkowanie ataku Obroną, dochód, 3 akcje/turę.
- System Władcy i Bezkrólewia, śmierć Władcy w Armii (k6).
- Bitwa z blefem, negocjacją, okupem i pułapką.
- 4 pełne talie po 36 kart + 9 Wydarzeń wtasowanych w każdą talię.
- Animacje kart, żeton armii z żywą Siłą, panel wrogów, Kronika stołu.
- **Zweryfikowane symulacją:** pełna partia 8 rund przechodzi bez błędów, graf sąsiedztwa
  pozostaje spójny i nienaruszony do końca.

## Czego NIE ma

- Licytacji o Attylę (event istnieje, ale bez przekupstwa).
- Pola aktywnych Postaci (wykładanie bohaterów przed sobą, max 2).
- Zbalansowania talii na żywych partiach — to największa niewiadoma.
- Grafik na kartach (patrz §6 i §7).

---

## 4. Architektura — niezmienniki, których nie wolno złamać

Cały stan gry siedzi w globalnym obiekcie `S`. Karty to obiekty w `CARDS` z funkcjami
efektów (`eff`, `cb`, `rb`, `onConq`, `ruleEff`) — treść karty realnie wpływa na grę,
nie jest tylko napisem.

### 4a. Mapa to 4 przesuwane BLOKI regionów

To najświeższa i najłatwiejsza do zepsucia część.

**Pozycje prowincji nie są nigdzie zapisane.** `S.prov[p].px/py` wylicza `syncProvPos()`
z `S.regPos[region]` plus offsetu slotu. Kolejność w `REGIONS[r].provs` = kolejność slotów:
`[lewy-górny, prawy-górny, lewy-dolny, prawy-dolny]`. `PROV` **nie ma** pól `x`/`y` —
dodanie ich z powrotem rozjedzie mapę.

**Sąsiedztwo** (`deriveAdj()`), trzy kroki:
1. Wewnątrz regionu — zawsze wszyscy ze wszystkimi (region jest spójny z definicji).
2. Między regionami — karty leżące naprzeciw siebie; próg **ortogonalny w jednostkach
   slotu** (`sdx()`/`sdy()`), NIE w surowych procentach, bo % w osi X i Y mają inną skalę px.
3. Pętla po `components()` dokleja rozłączne kawałki — mapa zawsze jest przejezdna.

Graf zamraża się w `beginPlay()` do `S.adj` i od tej chwili rządzi ruchem i atakami.
`adjOf(p)` zwraca zamrożony graf albo fallback `ADJ`. **Cała logika gry musi używać
`adjOf(...)`, nigdy `ADJ[...]` bezpośrednio.**

**Warstwy z-index** (łatwo zepsuć, objaw jest mylący):
`.regionbox` = 1 → `#links` = 2 → `.prov` = 3.
Linie granic muszą być NAD blokami, inaczej bloki je zasłaniają i widać tylko strzępki.
Rysujemy wyłącznie krawędzie **międzyregionalne** — te wewnątrz bloku i tak są pod
kartami i robią wizualny szum.

W setupie `.prov` ma `pointer-events:none`, żeby kliknięcie w kartę ciągnęło cały blok.

### 4b. Pipeline AI

`aiTurn → callLLM → parseJSON → execAIAction`.

**Gotcha, który kosztował dużo czasu:** Sonnet 5 przy dużych promptach zwraca najpierw
blok `type:"thinking"`, a tekst dopiero w kolejnym bloku. `callLLM` musi filtrować bloki
`type:"text"`, a nie czytać `content[0].text` — inaczej AI zawsze milczy i odpowiada „...".
`max_tokens` = 1200, bo thinking zjada budżet.

---

## 5. Odrzucone pomysły — NIE wracać do nich

| Pomysł | Dlaczego odrzucony |
|---|---|
| Swobodne przeciąganie pojedynczych prowincji | 16 kart nie da się sensownie ułożyć geograficznie w rzędy — dysproporcja. Zastąpione blokami regionów. |
| Domyślny układ „romb" | Dawał 4 rozłączne wyspy przy sąsiedztwie z odległości. |
| Siatka 4×4, kolumna = region | Czytelna, ale kłamała: Brytania „graniczyła" z Belgicą tylko dlatego, że była wyżej w kolumnie. |
| Wikingowie jako frakcja/region | Zły wiek — Wikingowie to VIII w., gra dzieje się w V. Mroźny klimat dostał Wschód (Scytia, Sarmacja). |

---

## 6. Materiały graficzne

### `materialy/KARTY-ART.html`
Biblia kart: nazwa, **realna mechanika 1:1 z kodu** i opis ilustracji do narysowania,
plus pusty slot na szkic. 187 pozycji: 144 karty frakcyjne (4 talie × 36), 4 Władców,
9 Wydarzeń, 16 Prowincji, 14 komponentów (w tym 4 plansze regionów).

### `materialy/PROMPTY-KART.html`
Po jednym gotowym prompcie na każdą pozycję, klik = kopiuj do schowka.
Każdy prompt = opis sceny po polsku + akcent frakcji + kadr wg typu karty +
wspólne DNA stylu + reguła tła + zakaz tekstu.

### `materialy/tools-genprompts.js`
Generator, który buduje `PROMPTY-KART.html` z `KARTY-ART.html`.
**Zmieniasz styl tutaj, nie w wygenerowanym HTML-u.** Uruchomienie: `node tools-genprompts.js`.

### DNA stylu — czego się nauczyliśmy (WAŻNE)

Pierwsza wersja promptów dawała **cztery różne style na czterech kartach**. Przyczyny
i poprawki (wszystkie już wprowadzone w generatorze):

| Błąd | Poprawka |
|---|---|
| `woodcut/engraving` — dwie techniki naraz, model losował | jedna technika: płaski drzeworytowy plakat, „NOT a painting, NOT a sketch" |
| `flat slightly painterly` — sprzeczność sama w sobie | dokładnie 2 tony na kolor, zero gradientów i kreskowania |
| brak reguły tła | sztywno: postacie zawsze na czystym pergaminie, świat zawsze płaski pejzaż |
| „portret" bez rozmiaru | kadr podany liczbowo: cała postać, ~85% wysokości kadru |
| `NO frame` (negacja) | „full bleed" — **negacje w promptach obrazowych prawie nie działają** |
| „title bar" na planszy regionu | model wpisywał w niego nazwę regionu („WEST") mimo zakazu tekstu → „pusty banner" |
| metafora w opisie („serce, o które biją się wszyscy") | model narysował anatomiczne serce → opisy muszą być dosłowne, plus klauzula SCENE BRIEF |
| opisy wymagające napisu (worek „RZYM") | przepisane tak, żeby gag działał bez liter |

**Najważniejszy wniosek: sam prompt NIE wystarcza.** Żeby seria wyglądała jak od jednego
rysownika:
1. Wygeneruj jeden obrazek **wzorcowy** i dopieszczaj go, aż będzie dokładnie taki, jak chcesz.
2. Do każdej kolejnej karty **podepnij go jako referencję stylu** (Freepik: „Style reference",
   Midjourney: `--sref`). To robi 80% roboty.
3. **Nie zmieniaj modelu w trakcie serii** — inny model to inny rysownik przy tym samym prompcie.
4. Generuj partiami po ~10 i porównuj z wzorcem.

Grafika ma być **bez tekstu** — cała typografia dokładana później w InDesignie.

---

## 7. Stan generacji grafik

Wygenerowano **21 grafik** przez Freepik/Magnific, modelem **Gemini 2.5 Flash Image**
(slug `imagen-nano-banana`), wszystkie z referencją stylu do wzorca „Alaryk":
1 wzorzec + 4 plansze regionów + 16 prowincji. Szczegóły w `grafiki/GDZIE-SA-GRAFIKI.md`.

**Plików graficznych nie ma w tej paczce** — linki CDN Freepika wygasają po kilku dniach.
Grafiki żyją na koncie Magnific właściciela, w projekcie **„Europe: Up To Grabs! — karty"**.

**Koszty (stan na 6.08.2026):** 50 kredytów za grafikę, zostało wtedy ~4 024 kredytów
(~80 grafik). Do zrobienia 163 pozycje = ~8 150 kredytów, czyli na wszystko nie starczało.
Uwaga: „lite"/„flash" z serii Nano Banana 2 są **droższe** (60 i 75), nie tańsze.

Znane niedoskonałości wygenerowanych grafik:
- Model uparcie ryje „ROMA" na bramie Italii mimo zakazu tekstu.
- Rezerwa dolnej połowy pod żeton armii działa nierówno: Germania wzorowo, Brytania zapchana.
- Barbarzyńcy pod Rzymem wyszli „goblinowato" — komicznie, ale bardziej fantasy niż V wiek.

---

## 8. Co dalej — backlog

1. **Balans czterech talii na żywych partiach** — największa niewiadoma projektu.
2. **Licytacja o Attylę** — event z przekupstwem, kto go skieruje na przeciwnika.
3. **Pole aktywnych Postaci** — wykładanie bohaterów przed sobą, max 2.
4. **Dokończyć grafiki** — kolejne w kolejce: 4 Władców + 9 Wydarzeń (najczęściej widoczne),
   potem talie frakcyjne.
5. `materialy/DOKUMENTACJA-nieaktualna.html` — dokument dla wspólniczki, opisuje **starą**
   mapę sprzed bloków regionów. Do przegenerowania przed wysłaniem komukolwiek.

---

## 9. Zasady pracy z właścicielem projektu

- Odpowiadaj po polsku.
- Prototyp jest **testbedem** — zmiany rób w sposób ogólny, silnikowo, nie jako łatki
  pod pojedynczy przypadek.
- Przed wydaniem jego kredytów Magnifica (generacje obrazów) powiedz, ile to kosztuje.
- Grafiki i UI mają mówić po ludzku: bez żargonu technicznego w tekstach widocznych dla gracza.

---

## 10. Jak odtworzyć tę paczkę

W katalogu projektu:

    bash tools-handoff.sh [katalog-docelowy]

Domyślnie ląduje na Pulpicie jako `EUTG-handoff.zip`.
EOF

cat > "$PKG/grafiki/GDZIE-SA-GRAFIKI.md" <<'EOF'
# Wygenerowane grafiki — spis i skąd je wziąć

**Plików nie ma w tej paczce.** Linki CDN Freepika wygasają po kilku dniach.
Grafiki żyją na koncie Magnific właściciela projektu, w projekcie
**„Europe: Up To Grabs! — karty"** (magnific.com → Projects).

Żeby mieć je lokalnie: otwórz projekt na koncie i pobierz hurtem.

## Co jest gotowe (21 szt.)

Wszystkie wygenerowane modelem **Gemini 2.5 Flash Image** (`imagen-nano-banana`),
proporcja 3:4, każda z referencją stylu do wzorca „Alaryk".

### Wzorzec stylu (1)
| Nazwa | Uwagi |
|---|---|
| Alaryk (dowódca Gotów) | **WZORZEC** — podpinamy go jako referencję stylu do wszystkich kolejnych generacji |

### Plansze regionów (4)
| Region | Klimat |
|---|---|
| ZACHÓD | mgła, klify, deszcz, ruiny przegrywające z pogodą |
| ŚRODEK | puszcza, zielono-brunatna gama, dym z ukrytych osad |
| POŁUDNIE | rozgrzany antyk, marmur, kolumnada, słońce, morze |
| WSCHÓD | lodowaty step, szron, jeźdźcy, kości, porzucone wozy |

Każda ma 4 puste sloty na karty prowincji (2×2) i pusty banner u góry na nazwę.

### Prowincje (16)
| Region | Prowincje |
|---|---|
| Zachód | Brytania, Belgica, Galia, Hispania |
| Środek | Germania, Panonia, Dacja, Iliria |
| Południe | Italia (Rzym), Sycylia, Grecja, Bałkany |
| Wschód | Scytia, Sarmacja, Mezja, Tracja |

Założenie kompozycyjne: wolny prawy górny róg na sztandar właściciela i wolna dolna
połowa na żeton Armii. **Model trzyma się tego nierówno** — Germania wzorowo, Brytania
zapchała cały kadr. Przy dokładaniu kolejnych warto weryfikować sztuka po sztuce.

## Do wyrzucenia

W tym samym projekcie leży ~14 odrzutów z dochodzenia do stylu: warianty sprzed
ujednolicenia DNA (każdy w innym stylu), plansza Zachód z wypalonym napisem „WEST"
oraz Italia, na której model narysował anatomiczne serce (dosłownie wzięta metafora
„serce, o które biją się wszyscy"). Nie używać — historia błędów w `00-START-TUTAJ.md` §6.

## Czego jeszcze nie ma (163 pozycje)

4 Władców, 9 Wydarzeń, 144 karty frakcyjne, 6 pozostałych komponentów
(rewersy talii, żetony, totem sojuszu, maty graczy, znacznik rundy).

Prompty na wszystko czekają gotowe w `materialy/PROMPTY-KART.html`.
EOF

mkdir -p "$DEST"
rm -f "$DEST/EUTG-handoff.zip"
( cd "$WORK" && zip -qr "$DEST/EUTG-handoff.zip" EUTG-handoff )
rm -rf "$WORK"
echo "Gotowe: $DEST/EUTG-handoff.zip"
