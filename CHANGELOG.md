# Resto4Life Changelog

All notable changes to **Resto4Life** are documented in this file.

---

## [v0.3.2-beta] - 2026-11-11

### 🇩🇪 Deutsch

#### ✨ Neue Funktionen
* **Zusätzlicher Modifikator `SHIFT +`:**
  * Im Konfigurationsmenü unter **„Tastenbelegung“** gibt es nun neben `[Standard]`, `[STRG +]` und `[ALT +]` auch den neuen Umschalter **`[SHIFT +]`**.
  * Vollständig unabhängig belegbar für alle Maustasten 1 bis 5 (Linksklick, Rechtsklick, Mitteltaste, Daumentasten 4 & 5), das Mausrad (Hoch & Runter) sowie die Schnelltasten 1 bis 6.
  * Voll integriert in die Click-Cast-Engine inklusive Hover-Overrides (`SHIFT-MOUSEWHEELUP`, `SHIFT-1`..`6`).
* **Blizzard-Frames ausblenden (Reiter „Frames“):**
  * Der frühere Reiter „Raid“ wurde in **„Frames“** umbenannt.
  * Neue Einstellung zum Ausblenden der Standard-Spieler- und Gruppenanzeigen von Blizzard (`CompactRaidFrameContainer`, `CompactPartyFrame`, `PartyFrame`, `PartyMemberFrame1..4`).
  * **Seitenmenü bleibt erhalten:** Das ausklappbare Blizzard-Schlachtzugsmenü (`CompactRaidFrameManager` auf der linken Bildschirmseite mit Bereitschaftscheck, Rollenabfrage, Ziel- und Weltmarkierungen) bleibt vollständig erhalten und nutzbar.
  * **Sofortige Wiederherstellung:** Beim Entfernen des Hakens werden die Blizzard-Frames sofort ohne `/reload` wieder live angezeigt.

#### 🔧 Fehlerbehebungen & Verbesserungen
* **Buff-Bar Reichweiten-Priorisierung:**
  * Das Klick-Makro der Buff-Bar wählt nun **garantiert nur Einheiten aus, die sich tatsächlich in Zauberreichweite befinden** (`inRangeMissing[1]`).
  * Einheiten an anderen Orten oder außerhalb der Reichweite (selbst mit höherer Rollenpriorität wie ein entfernter Tank) blockieren nicht mehr das Buffen naher Gruppenmitglieder.
  * Direkte Reichweitenprüfung pro Buff mit dem echten lokalisierten Zaubernamen (`IsSpellInRange(castSpell, unit)`).
  * Der Tooltip jedes Buff-Buttons zeigt nun bei allen fehlenden Spielern übersichtlich an, ob sie `(in Reichweite)` oder `(außer Reichweite)` sind, sowie das genaue nächste Klickziel.
* **Allgemeine Reichweitenprüfung (`Core/Init.lua`):**
  * Der Fallback nutzt nun die tatsächlichen Zaubernamen der Klassen, wodurch `IsSpellInRange` auf WotLK / WoW Forever nicht mehr fehlschlägt. Bei nicht bestätigter Reichweite meldet das System nun verlässlich `false`.

---

### 🇬🇧 English

#### ✨ New Features
* **Additional Modifier Key `SHIFT +`:**
  * Added a dedicated **`[SHIFT +]`** toggle button under the **"Key Bindings"** options tab alongside `[Standard]`, `[CTRL +]`, and `[ALT +]`.
  * Fully independently configurable for Mouse Buttons 1–5, Mouse Wheel Up/Down, and Hover Keys 1–6.
  * Fully registered in the secure click-cast engine with hover key overrides.
* **Hide Default Blizzard Player Frames (Tab "Frames"):**
  * Renamed the "Raid" options tab to **"Frames"**.
  * Added option to hide default Blizzard unit & party frames (`CompactRaidFrameContainer`, `CompactPartyFrame`, `PartyFrame`, `PartyMemberFrame1..4`).
  * **Sidebar Menu Preserved:** The slide-out manager bar (`CompactRaidFrameManager` with Ready Check, Role Check, and Ground/Target Markers) remains fully visible and usable.
  * **Instant Restoration:** Unchecking the option immediately restores Blizzard frames without requiring a `/reload`.

#### 🔧 Fixes & Improvements
* **Buff-Bar In-Range Targeting Priority:**
  * Buff-Bar click-to-cast macros now **strictly target units that are within spell range** (`inRangeMissing[1]`). Out-of-range players (e.g. at another location) will no longer block you from buffing nearby party members.
  * Direct range checking per buff spell using localized spell names (`IsSpellInRange(castSpell, unit)`).
  * Button tooltips now show whether each missing party member is `(in range)` or `(out of range)` as well as the active click target.
* **Core Range Check (`Core/Init.lua`):**
  * Fixed spellbook string resolution for WotLK / WoW Forever clients so friendly spell checks evaluate correctly and unconfirmed units return `false`.

---

## [v0.3.1-beta] - 2026-11-11

### 🇩🇪 Deutsch
* **Begleiter-Frames (Pets) für 5er-Gruppe und Solo-Modus:**
  * Der Begleiter-Container kann nun flexibel auch in 5-Spieler-Gruppen und beim Solo-Spiel aktiviert und angezeigt werden.
  * Einheitliche Skalierungs-, Drag- und Mover-Logik.

### 🇬🇧 English
* **Pet Frame Support in 5-Man Party & Solo:**
  * Pet frames can now be enabled and positioned during 5-man dungeon groups and solo play.

---

## [v0.3.0-beta] - 2026-10-13

### 🇩🇪 Deutsch
* **Native C++ `AuraContainer` für eigene HoTs & Schilde im Kampf:**
  * Nutzt Blizzards natives `CustomAuraContainerTemplate` zur fehlerfreien HoT- und Schild-Darstellung im Kampf unter WoW Forever (Interface 16001).
  * Entfernung der fehleranfälligen Fremd-HoT-Schätzung.
* **Native C++ Heal Prediction & Absorbs:**
  * Anbindung von `CreateUnitHealPredictionCalculator` an `StatusBar`-Widgets ohne Lua-Taint oder Secret-Value-Abstürze.
* **Freie Dispel-Mausbelegung:**
  * Starres "Smart-Dispel" entfernt; Reinigungs- und Bannzauber können nun völlig frei auf beliebige Tasten und Mausklicks gelegt werden.

### 🇬🇧 English
* **Native C++ `AuraContainer` & Heal Prediction:**
  * Secure in-combat HoT and absorb tracking using Blizzard's forbidden table C++ engine for WoW Forever (`Interface: 16001`).
  * Replaced rigid Smart-Dispel with standard, fully customizable key/mouse bindings.
