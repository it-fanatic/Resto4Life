# Resto4Life - Feature-Übersicht (v0.1.6a_beta)

Diese Dokumentation listet alle aktuellen Funktionen, Mechaniken und Einstellmöglichkeiten von **Resto4Life** auf.

---

## 📋 Inhaltsverzeichnis
1. [Unit Frames & Layout](#1-unit-frames--layout)
2. [Gesundheits- & Farbmodi](#2-gesundheits--farbmodi)
3. [Aggro- & Bedrohungsanzeige](#3-aggro--bedrohungsanzeige)
4. [HoTs & Bannbare Debuffs](#4-hots--bannbare-debuffs)
5. [Reichweitenprüfung & Fading](#5-reichweitenprüfung--fading)
6. [Mover, Skalierung & Positionierung](#6-mover-skalierung--positionierung)
7. [Test- & Simulationsmodus](#7-test--simulationsmodus)
8. [Click-Casting & Tastenbelegungen](#8-click-casting--tastenbelegungen)
9. [Befehle (Slash Commands)](#9-befehle-slash-commands)
10. [Lokalisierung & Mehrsprachigkeit](#10-lokalisierung--mehrsprachigkeit)
11. [Minimap-Button & Addon Compartment](#11-minimap-button--addon-compartment)
12. [Raid-Heiler System](#12-raid-heiler-system)

---

## 1. Unit Frames & Layout
* **5-Spieler-Gruppenframe:** Perfekt abgestimmt für Dungeons, Mythisch+ und Arena.
* **Nahtloses Design (0 px):** Alle Frames schließen immer bündig und lückenlos aneinander an.
* **Ausrichtung wählbar:**
  * **Spalte (Vertikal):** Frames wachsen nach unten.
  * **Zeile (Horizontal):** Frames wachsen nach rechts.
* **Automatische Rollensortierung:**
  * Sortiert Gruppenmitglieder stets in der optimalen Reihenfolge:  
    `Tank ➔ Nahkämpfer (Melee) ➔ Fernkämpfer (Range) ➔ Heiler`.
* **Spielernamen:** Mittig auf dem Lebensbalken zentriert mit sauberem Abstand zu den HoT-Symbolen.
* **Ressourcen-/Manabalken:**
  * Zeigt Mana, Wut, Energie etc. inklusive prozentualer Restanzeige.
  * Kann im Menü ein- oder ausgeblendet werden.

---

## 2. Gesundheits- & Farbmodi
* **Normaler Modus:**
  * Lebensbalken nimmt bei Schaden ab.
* **Reverse Health (Defizitanzeige / VuhDo-Stil):**
  * Balken füllt sich bei erlittenem Schaden rot auf, sodass Heiler sofort sehen, wie viel Heilung fehlt.
* **Farbmodi:**
  1. **Klassenfarben:**
     * Lebensbalken erstrahlt in der offiziellen Klassenfarbe (z. B. Orange für Druide, Braun für Krieger).
     * Hintergrund/Defizitbereich ist dezent schwarz gehalten.
  2. **Grün / Rot (Klassischer Heiler-Farbverlauf):**
     * Balken ist grün bei vollem Leben und verfärbt sich zu gelb und rot bei niedrigem Leben.
     * Hintergrund/Defizitbereich hinter der Füllung ist rot.
* **Sichere Werteverarbeitung:** Volle Kompatibilität mit geschützten Werten (*Secret Values*) aus WoW 11.x/12.x.

---

## 3. Aggro- & Bedrohungsanzeige
* **Aggro-Warnung auf Nicht-Tanks:**
  * Zieht ein Schadensausteiler (DPS) oder Heiler Bedrohung von Gegnern, leuchtet der äußere Rahmen des Spielers **leuchtend rot** auf.
  * Tanks erhalten keinen roten Rahmen, da sie regulär Aggro halten sollen.
* **Klare Prioritätsregel:**
  * **Bannbare Debuffs haben immer Vorrang vor Aggro!**
  * Hat ein Spieler gleichzeitig Aggro und einen bannbaren Fluch/Gift, wird die Debuff-Farbe angezeigt, damit die lebenswichtige Reinigung nicht übersehen wird.

---

## 4. HoTs & Bannbare Debuffs
* **HoT-Tracker:**
  * Bis zu 4 HoT-Icons oben rechts im Frame.
  * Zeigt das Zauber-Icon, die verbleibende Restzeit in Sekunden sowie die Stapelanzahl (z. B. bei Blühendes Leben) an.
* **Debuff-Rahmen:**
  * Äußerer 3-Pixel-Rand färbt sich je nach Art des bannbaren Effekts:
    * 🟣 **Fluch (Curse):** Lila
    * 🟢 **Gift (Poison):** Grün
    * 🔵 **Magie (Magic):** Blau
    * 🟤 **Krankheit (Disease):** Braun
* **Interaktive Debuff-Test-Buttons:**
  * Im Einstellungsmenü können Gift-, Fluch- und Magieränder per Klick getestet werden.

---

## 5. Reichweitenprüfung & Fading
* **Wie funktioniert das?**
  * Verwendet Blizzards native Engine-Funktion `UnitInRange(unit)`.
  * Prüft kontinuierlich alle Gruppenmitglieder auf eine Distanz von ca. **40 Metern** (Reichweite von Heilzaubern).
* **Automatisches Verblassen:**
  * Ist ein Gruppenmitglied außer Reichweite, blendet der Frame sanft auf **40 % Deckkraft (Alpha)** ab.
  * Sobald der Spieler wieder in Reichweite kommt, wird der Frame wieder zu 100 % sichtbar.
  * Im Menü an- und abwählbar.

---

## 6. Mover, Skalierung & Positionierung
* **Verschiebemodus:**
  * Über `/r4l` ➔ *„Rahmen entsperren“* wird der grüne Mover eingeblendet.
  * Mit gehaltener linker Maustaste an jede beliebige Stelle ziehbar.
* **Stufenloses Skalieren (50 % bis 200 %):**
  * **Per Mausrad:** Einfach mit der Maus über das entsperrte Fenster fahren und am Mausrad drehen.
  * **Per Ziehecke:** Die Ecke unten rechts anklicken und ziehen.
  * **Per Menü:** Präzise `[-]`, `[+]` und `[Standard 100%]` Knöpfe.
  * **Pixelgenaue Fixierung:** Die Position der linken oberen Ecke bleibt beim Skalieren millimetergenau erhalten.
* **Bildschirm-Klammerung (`SetClampedToScreen`):**
  * Physisch im Spiel verankert – der Frame kann niemals versehentlich außerhalb des Monitors geschoben werden.
* **Positions-Reset:**
  * Ein Klick auf den Button **`[ Pos. Reset ]`** (oder Chat-Befehl `/r4l reset`) zentriert den Rahmen sofort wieder in der Mitte des Bildschirms auf 100 % Skalierung.

---

## 7. Test- & Simulationsmodus
* **5er-Gruppe simulieren:**
  * Knopf im Menü: `[ 5er-Gruppe simulieren (Test-Modus) ]`.
  * Simuliert solo eine realistische Gruppe mit:
    * **Thorvald (Krieger-Tank):** 92 % Leben, Wutbalken, Verjüngung.
    * **Shadowfang (Schurken-DD):** 78 % Leben, Energiebalken, **hat Aggro (roter Rahmen)**.
    * **Elysia (Magier-DD):** 64 % Leben, Manabalken, 2 HoTs, **Fluch-Debuff (lila Rahmen)**.
    * **Valen (Priester):** 45 % Leben, Manabalken, Blühendes Leben (2 Stacks).
    * **Eigener Charakter (Druide):** 100 % Leben, Manabalken, Verjüngung.
  * Ermöglicht das Testen aller Layouts, Farben und Optionen ohne Gruppe.

---

## 8. Click-Casting & Tastenbelegungen
* **Zauber direkt per Klick auf die Frames wirken (Mouse-Over):**
  * **Linksklick** (Button 1)
  * **Rechtsklick** (Button 2)
  * **Mittlere Maustaste** (Button 3)
  * **Maustaste 4** (Hintere Daumentaste)
  * **Maustaste 5** (Vordere Daumentaste)
  * **Mausrad Hoch & Runter**
  * **Tasten 1 bis 6** beim Überfahren des Frames (Hover-Cast)
* **Multiplikator-Tasten (STRG & ALT Modifikatoren):**
  * Im Konfigurationsmenü (`/r4l`) kann über drei Umschalter (`[Standard]`, `[STRG +]`, `[ALT +]`) jede Maustaste, jedes Scrollen und jede Taste 1–6 mit einer separaten Fähigkeit belegt werden.
  * Unterstützt Blizzards native `SecureActionButtonTemplate`-Modifikatoren für sofortige Ausführung im Kampf ohne Latenz.
* **Smart Battle-Rez:**
  * Auf tote Ziele wirkt ein Klick automatisch die klassenspezifische Wiederbelebung (im Kampf: Rebirth / Seelenstein, außerhalb: normale Wiederbelebung).
* **Automatischer Zielwechsel (Target on Cast):**
  * Kann im Menü unter *Allgemein* aktiviert werden (*„Ziel bei Zauber automatisch anvisieren“*).
  * Wird ein Zauber per Klick oder Taste auf einen Gruppenrahmen gewirkt, wird das Ziel sofort aktiv ins Target genommen.


---

## 9. Befehle (Slash Commands)
* `/r4l` oder `/resto4life` – Öffnet das Einstellungsfenster.
* `/r4l unlock` – Entsperrt den Rahmen zum Verschieben und Skalieren.
* `/r4l lock` – Sperrt den Rahmen wieder.
* `/r4l reset` oder `/r4l center` – Setzt Position und Größe sofort in die Bildschirmmitte zurück.
* `/r4l resetall` – Setzt alle Addon-Einstellungen auf Werkseinstellungen zurück.

---

## 10. Lokalisierung & Mehrsprachigkeit
* **Integriertes Lokalisierungssystem (DE / EN):**
  * Erkennt automatisch die Sprache des WoW-Clients (`GetLocale()`).
  * Unterstützt **Deutsch (deDE)** und **Englisch (enUS/enGB)**.
  * Automatische Zauberauflösung über Spell-IDs für alle Client-Sprachen.
  * Saubere Fallback-Architektur (Metatable) für nahtlose Erweiterbarkeit auf weitere Sprachen (frFR, esES, etc.).

---

## 11. Minimap-Button & Addon Compartment
* **Ruckelfreier, runder Minimap-Button:**
  * Saubere Winkelberechnung mit automatischer Erkennung des Minimap-Radius und der UI-Skalierung (kein Hakeln oder Springen).
  * **Linksklick:** Öffnet oder schließt das Konfigurationsmenü (`/r4l`).
  * **Rechtsklick:** Entsperrt oder sperrt die Gruppenrahmen zum Verschieben (`/r4l unlock`).
  * **Shift + Linksklick:** Setzt die Position und Größe direkt in die Bildschirmmitte zurück (`/r4l reset`).
  * **Ziehen (Linke Maustaste):** Verschiebt den Button ruckelfrei am Rand der Minimap entlang.
  * **Ein-/Ausblendbar:** Über die Checkbox *„Minimap-Button anzeigen“* im Menü unter *Allgemein*.
* **Offizielle Blizzard Addon-Compartment-Unterstützung:**
  * Direkter Eintrag im modernen Menü des Addon-Fachs von WoW Retail.

---

## 12. Raid-Heiler System
* **Automatische Erkennung & Umschaltung:**
  * Schaltet im Schlachtzug automatisch auf die optimierten Raid-Frames um und blendet das 5er-Gruppenframe aus.
* **Modulare Multi-Container Architektur:**
  1. **Markierte Tanks (Main Tanks):** Eigener separater Frame für bis zu 4 zugewiesene Tanks.
  2. **Eigene Gruppe:** Zeigt die 5 Spieler der eigenen Subgruppe separat an.
  3. **Restlicher Raid:** Zeigt alle übrigen Raid-Mitglieder mit automatischer Deduplizierung (keine doppelten Spieler).
  4. **Große Raidanzeige (Fallback):** Sind Tank- und Eigene-Gruppe-Frames deaktiviert, schaltet Resto4Life automatisch in ein großes, zusammenhängendes 10er/25er/40er Gesamtraster um.
  5. **Begleiter (Pet-Frames):** Optional aktivierbar für Jäger- und Hexenmeister-Begleiter.
* **Offizielle Blizzard Rollen-Icons:**
  * Zeigt oben links auf jedem UnitFrame das offizielle Blizzard-Icon für **Tank (Schild)**, **Heiler (Grünes Kreuz)** oder **Schadensausteiler (Schwert)** an.
  * In den Einstellungen unter *Allgemein* jederzeit ein- und ausschaltbar.
* **Individuelle Mover & Skalierung:**
  * Jeder aktive Container (Tanks, Eigene Gruppe, Rest-Raid, Pets) besitzt beim Entsperren einen eigenen Mover und kann unabhängig platziert und per Mausrad oder Ziehecke skaliert werden.
  * Korrekte Initialisierung des Entsperr-Status (beim Reload immer gesperrt, sofortiges Entsperren mit einem Klick).
* **Freie Anordnung pro Raid-Frame (Spalte / Zeile):**
  * Für jeden modularen Frame (**Tanks**, **Eigene Gruppe**, **Restlicher Raid**, **Begleiter**) kann im Menü unabhängig gewählt werden zwischen:
    * **Spalte (Vertikal):** Einheiten wachsen von oben nach unten (z.B. klassische 5er-Spalte oder 8 Spalten à 5 Spieler).
    * **Zeile (Horizontal):** Einheiten wachsen von links nach rechts (z.B. waagerechte Leiste oder 8 Zeilen à 5 Spieler).
* **Umfassende Raid-Simulationen:**
  * Dedizierte Test-Buttons im Menü-Reiter *Raid*:
    * **10er-Raid simulieren**
    * **25er-Raid simulieren**
    * **40er-Raid simulieren**
    * Inklusive realistischer Rollenverteilung, HP-Defiziten, HoTs, Aggro und Debuffs.



