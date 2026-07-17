# Europe: Up To Grabs!

Humorystyczna gra strategiczno-karciana o Wędrówce Ludów i upadku Rzymu (tytuł roboczy PL: *Barbarzyńcy u Bram*). Prototyp w **jednym pliku HTML**, LLM-first — trzy frakcje przeciwników prowadzi Claude (gadają, negocjują, blefują i zdradzają po polsku).

## Jak uruchomić

Gra to jeden plik: **`index.html`**. Dwie opcje:

1. **Przez lokalny serwer (zalecane — API działa bez problemów z CORS):**
   ```
   python3 -m http.server 4599 --directory .
   ```
   i otwórz **http://localhost:4599** w przeglądarce.
2. Otwarcie `index.html` bezpośrednio (`file://`) też działa, ale wywołania API bywają blokowane przez CORS.

**Klucz API Anthropic** (opcjonalny): wklej na ekranie startowym, żeby przeciwnicy „myśleli" przez LLM. Zapisuje się w localStorage przeglądarki (wpisujesz raz). Bez klucza działa awaryjny bot (pasuje). Model domyślny: `claude-sonnet-5`.

> **Ważny gotcha (naprawiony):** Sonnet 5 przy dużych promptach zwraca najpierw blok `thinking`, a tekst dopiero w kolejnym bloku — `callLLM` parsuje blok `type:"text"`, nie `content[0]`. Bez tego AI zawsze milczy.

## Architektura

- **1 plik**, vanilla JS + CSS, zero zależności/buildu. Cały stan w obiekcie `S`.
- Karty: obiekty w `CARDS` z typami i efektami (`eff` / `cb` / `rb` / `onConq` / `ruleEff`) — treść realnie wpływa na grę, nie jest tylko napisem.
- Talie frakcyjne: `FULL_DECK.{rome,goths,vandals,gauls}` (po 36 kart), Wydarzenia (`EVENTS`) wtasowane w każdą talię i odpalane przy dobraniu.
- AI: `aiTurn → callLLM (Anthropic API z przeglądarki) → parseJSON → execAIAction`.

## Co jest zrobione

- **Mapa 16 prowincji / 4 regiony** (Zachód, Środek, Wschód, Południe) w układzie rombu; neutralne ≠ puste (własna Obrona 2–6).
- **Faza SETUP** — przed grą przeciągasz prowincje i talię jak chcesz, potem „ROZPOCZNIJ GRĘ" rozdaje ręce i stawia armie.
- **Przygotowana Armia** — atak bramkowany Obroną (≤3 dowolna, 4–5 wymaga Dowódcy/Wzmocnienia, ≥6 Dowódcy albo 2 Wzmocnień).
- **Dochód** (+1 Złoto/prowincję, +1 Chwały/pełny region), **3 akcje/turę**, dobór karty na starcie tury.
- **System Władcy / Bezkrólewie** — Postać jako Dowódca albo Władca; Władca w Armii ryzykuje śmiercią (k6); Bezkrólewie kończy k6=6 albo mianowanie.
- **Bitwa z blefem** — zakryte karty, negocjacja, okup (ransom), pułapka; karta przepada po odkryciu (też blef).
- **4 pełne talie 36-kartowe** o różnych stylach (Rzym defensywa/dobór, Goci mobilność/atak, Wandalowie łup/Złoto, Galowie konfederacja wodzów).
- **Karty realne i widoczne** — żeton armii pokazuje żywą Siłę ⚔/🛡 z rozbiciem (tooltip); zyski zasobów wyskakują „+N 💰/✦".
- **Animacje** kart wrzucanych na stół (gracz i AI) + błysk „zadziałało".
- Panel wrogów (zwijane chipy), przycisk pomocy „?", Kronika stołu.

## Do zrobienia dalej

- **Attyla-najemnik → pełna licytacja** (event z przekupstwem, kto go skieruje).
- **Balans** czterech talii na żywych partiach.
- **Edytowalne sąsiedztwo** — obecnie przesuwanie prowincji zmienia tylko wygląd; graf `ADJ` (kto z kim graniczy) jest stały.
- **Pole aktywnych Postaci** (wykładanie bohaterów przed sobą, max 2).
- Zrównanie opisów kart z mechaniką jest zrobione; parę „ruchowych" gockich efektów jest uproszczonych (płaskie), nie kłamią.

## Sterowanie (diegetyczne, bez dashboardu)

Klik Armii → klik prowincji (marsz/atak). Klik karty w ręce → klik Armii (Dowódca/Wzmocnienie) albo cel (intryga/specjalna). Dwuklik własnej ziemi = Rekrutacja. Klik maty AI = dyplomacja. Klik Totemu = zdrada. Klik własnej maty = Dwór (Władca). Pieczęć = Zakończ turę.
