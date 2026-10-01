# Resto4Life - World of Warcraft Heiler-Addon (v0.1.6a_beta)

**Resto4Life** ist ein modernes, leichtgewichtiges und hochgradig anpassbares Heiler- und Gruppenframe-Addon für **WoW Retail** (The War Within 11.x / Midnight 12.x) und **WoW Forever**.

Eine vollständige Liste aller Funktionen und Details findest du in der [FEATURES.md](file:///f:/Documents/Projekte/Resto4Life/FEATURES.md).

---

## 🌟 Hauptfunktionen

* **Kompakter 5-Spieler-Gruppenframe (v1):**
  * Entwickelt für 5er-Dungeons / Mythisch+ und Gruppen-Content.
  * Zukunftsfähig für Raid-Frames vorbereitet (Priorisierung und Kennzeichnung der eigenen Gruppe).
* **Minimap-Button & Addon Compartment:**
  * Ruckelfreier, frei positionierbarer Minimap-Button mit Standard-Tracking-Border.
  * Linksklick öffnet Optionen, Rechtsklick entsperrt Frames, Shift-Linksklick zentriert die Position.
  * Automatische Integration in das moderne Blizzard Addon Compartment Menü.
* **Gesundheitsbalken (Health Bar):**

  * **Normaler Modus:** Lebensbalken leert sich bei erlittenem Schaden.
  * **Reverse-Modus (VuhDo-Stil):** Lebensbalken füllt sich rot auf, je mehr Leben verloren geht (Defizitanzeige).
  * **Farbmodi:** Dynamische **Klassenfarben** oder **Minimaler Farbverlauf** (Grün $\rightarrow$ Gelb $\rightarrow$ Rot je nach HP-Stand).
  * **Spielernamen:** Jederzeit ein- oder ausblendbar.
* **Mana- & Ressourcenbalken:**
  * Integrierte Ressourcenanzeige für Heiler und Gruppenmitglieder (Mana, Wut, Energie, etc.).
* **Automatische Rollensortierung:**
  * Sortiert Gruppenmitglieder automatisch in der Reihenfolge: **Tank $\rightarrow$ Nahkämpfer (Melee) $\rightarrow$ Fernkämpfer (Range) $\rightarrow$ Heiler**.
* **Smart Battle Rez (Automatisches Wiederbeleben):**
  * Ist ein Gruppenmitglied tot, löst ein Klick auf den Frame im Kampf automatisch die **Wiedergeburt / Battle-Rez** deiner Klasse aus.
  * Außerhalb des Kampfes wird die normale Wiederbelebung gewirkt.
* **HoT- & Aura-Tracker:**
  * Verfolgt aktive eigene HoTs (Verjüngung, Nachwachsen, Erneuerung, Springflut etc.) mit Icon, Restzeitanzeige und Stacks.
* **Bannbare Flüche, Vergiftungen, Krankheiten & Magie:**
  * Der äußere Rahmen leuchtet in der jeweiligen Debuff-Farbe auf (Lila für Fluch, Grün für Gift, Braun für Krankheit, Blau für Magie), sobald ein Effekt gebannt werden kann.
* **Konfigurierbares Click-Casting (Mouse-Over):**
  * **Linksklick** (Button 1)
  * **Rechtsklick** (Button 2)
  * **Mittlere Maustaste** (Button 3)
  * **Mausrad Hoch** (MouseWheelUp)
  * **Mausrad Runter** (MouseWheelDown)
  * **Schnelltasten 1 bis 6** beim Überfahren des Gruppenmitglieds
* **Profile & Datenverwaltung:**
  * Alle Einstellungen werden **pro Charakter separat gespeichert** (`Resto4LifeCharDB`).
  * **Import- und Exportfunktion:** Einstellungen können als kompakte Zeichenkette exportiert und mit Freunden oder Twinks geteilt werden.

---

## 🚀 Installation

1. Kopiere den gesamten Ordner `Resto4Life` in dein WoW-Addons-Verzeichnis:
   * **Retail:** `World of Warcraft\_retail_\Interface\AddOns\Resto4Life`
   * **WoW Forever:** `World of Warcraft\<Forever-Verzeichnis>\Interface\AddOns\Resto4Life`
2. Starte World of Warcraft neu oder gib im Spiel `/reload` ein.

---

## ⚙️ Befehle & Bedienung

* `/r4l` oder `/resto4life` – Öffnet das grafische Konfigurationsmenü.
* `/r4l unlock` – Entsperrt das Gruppenframe, sodass es mit der Maus an jede beliebige Bildschirmposition gezogen werden kann.
* `/r4l lock` – Sperrt die Position wieder.
* `/r4l reset` – Setzt die Einstellungen auf die Klassenvorlagen zurück.
