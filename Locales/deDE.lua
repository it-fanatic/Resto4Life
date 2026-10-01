--[[
    Resto4Life - Locales/deDE.lua
    Deutsche Lokalisierung
--]]

local _, R4L = ...
local L = R4L.Locales.deDE

-- Mover & Drag
L["MOVER_TITLE"] = "Resto4Life"
L["MOVER_DRAG"] = "Ziehen: Verschieben"
L["MOVER_SCALE_HINT"] = "Mausrad / Ziehecke:"
L["MOVER_SCALE_FMT"] = "Skalieren (%d%%)"
L["RESIZER_TOOLTIP_TITLE"] = "Skalieren"
L["RESIZER_TOOLTIP_DESC"] = "Ziehen, um die Fenstergröße stufenlos zu skalieren."

-- Chat Messages
L["CHAT_FRAME_LOCKED"] = "Rahmen gesperrt."
L["CHAT_FRAME_UNLOCKED"] = "Rahmen entsperrt: Verschieben mit Links-Klick, Skalieren mit Mausrad oder Ziehecke."
L["CHAT_SCALE_FMT"] = "Skalierung: |cff00ff00%d%%|r"
L["CHAT_SCALE_SAVED_FMT"] = "Skalierung gespeichert: |cff00ff00%d%%|r"
L["CHAT_POS_RESET"] = "Position und Skalierung (100%) in die |cff00ff00Bildschirm-Mitte|r zurückgesetzt."
L["CHAT_SIM_STARTED"] = "5er-Gruppe |cff00ff00simuliert|r (Test-Modus aktiv)."
L["CHAT_SIM_STOPPED"] = "Simulation |cffff5555beendet|r. Echte Gruppe wird wieder angezeigt."
L["CHAT_REVERSE_ACTIVE"] = "Reverse Health Modus: |cff00ff00Aktiviert (Defizit)|r"
L["CHAT_REVERSE_INACTIVE"] = "Reverse Health Modus: |cffff5555Deaktiviert (Normal)|r"
L["CHAT_COLOR_CLASS"] = "Farbmodus gewählt: |cffff7c0aKlassenfarben|r"
L["CHAT_COLOR_MINIMAL"] = "Farbmodus gewählt: |cff00ff00Grün / Rot (Heiler)|r"
L["CHAT_LAYOUT_COL"] = "Anordnung gewählt: |cff00ff00Spalte (Vertikal)|r"
L["CHAT_LAYOUT_ROW"] = "Anordnung gewählt: |cff00ff00Zeile (Horizontal)|r"
L["CHAT_TEST_DEBUFF_STOP"] = "Test-Debuff |cffff5555deaktiviert|r."
L["CHAT_DEFAULTS_RESET"] = "Einstellungen auf Standard zurückgesetzt."
L["LOADED_MSG_FMT"] = "v%s geladen. Tippe /r4l für Optionen."

-- Options Window: Header & Tabs
L["CONFIG_TITLE_FMT"] = "|cff00ff96Resto4Life|r - Konfiguration (v%s)"
L["TAB_GENERAL"] = "Allgemein"
L["TAB_BINDINGS"] = "Tastenbelegung"
L["TAB_HOTS"] = "HoTs & Debuffs"
L["TAB_RAID"] = "Raid"
L["TAB_PROFILES"] = "Profil / Im-Export"

-- Tab 1: Allgemein
L["UNLOCK_FRAME"] = "5er-Frame entsperren"
L["POS_RESET"] = "5er-Pos. Reset"
L["SHOW_NAMES"] = "Spielernamen anzeigen"
L["SHOW_ROLE_ICONS"] = "Rollen-Icons (Tank, Heal, DD) anzeigen"

L["SHOW_MANA"] = "Mana- / Ressourcenbalken anzeigen"
L["REVERSE_HEALTH"] = "Reverse Health (VuhDo-Defizit)"
L["COLOR_MODE"] = "Farbmodus:"
L["CLASS_COLORS"] = "Klassenfarben"
L["GREEN_RED_HEALER"] = "Grün / Rot (Heiler)"
L["LAYOUT"] = "Anordnung:"
L["COL_VERTICAL"] = "Spalte (Vertikal)"
L["ROW_HORIZONTAL"] = "Zeile (Horizontal)"
L["SIM_GROUP_BTN"] = "5er-Gruppe simulieren (Test-Modus)"
L["SIM_ACTIVE_BTN"] = "Simulation AKTIV (Klick zum Beenden)"
L["AUTO_SORT"] = "Auto-Sortierung (Tank, DD, Heal)"
L["FADE_OUT_OF_RANGE"] = "Außer Reichweite verblassen"
L["TARGET_ON_CAST"] = "Ziel bei Zauber automatisch anvisieren"
L["CHAT_TARGET_ON_CAST_ON"] = "Zielwechsel beim Zaubern: |cff00ff00Aktiviert|r"
L["CHAT_TARGET_ON_CAST_OFF"] = "Zielwechsel beim Zaubern: |cffff5555Deaktiviert|r"
L["SCALE_LABEL"] = "Größe / Skalierung:"
L["SCALE_DEFAULT"] = "Standard 100%"
L["SHOW_MINIMAP_CB"] = "Minimap-Button anzeigen"
L["MINIMAP_TOOLTIP_LCLICK"] = "|cff00ff96Linksklick:|r Optionen öffnen / schließen"
L["MINIMAP_TOOLTIP_RCLICK"] = "|cff00ff96Rechtsklick:|r Rahmen entsperren / sperren"
L["MINIMAP_TOOLTIP_SHIFT"] = "|cff00ff96Shift + Linksklick:|r Position in Bildschirmmitte zurücksetzen"
L["MINIMAP_TOOLTIP_DRAG"] = "|cff888888Ziehen mit linker Maustaste zum Verschieben|r"

-- Tab 2: Tastenbelegung
L["BINDINGS_HEADER"] = "|cffffff00Mausklicks & Tastenbelegungen (beim Überfahren des Rahmens):|r"
L["LEFT_CLICK"] = "Linksklick Zauber:"
L["RIGHT_CLICK"] = "Rechtsklick Zauber:"
L["MID_CLICK"] = "Mittlere Maustaste:"
L["WHEEL_UP"] = "Mausrad Hoch:"
L["WHEEL_DOWN"] = "Mausrad Runter:"
L["KEY_N_FMT"] = "Taste %d:"
L["SMART_REZ_HEADER"] = "|cffffff00Smart Battle Rez (Automatisches Wiederbeleben):|r"
L["SMART_REZ_ENABLE"] = "Smart Battle-Rez aktivieren (Linksklick auf tote Spieler)"
L["COMBAT_REZ_SPELL"] = "Kampf-Wiederbelebung (In-Combat):"
L["NORMAL_REZ_SPELL"] = "Normale Wiederbelebung (Out-of-Combat):"

-- Tab 3: HoTs & Debuffs
L["SHOW_HOTS_CB"] = "Tickende HoTs auf Gruppenmitgliedern anzeigen (Icons & Restzeit)"
L["COLOR_DEBUFFS_CB"] = "Bannbare Debuffs am Rahmen hervorheben (Farblicher Rand)"
L["DISP_ONLY_CB"] = "Nur hervorheben, wenn meine Klasse den Debuff bannen kann"
L["HIGHLIGHT_CURSE"] = "|cff9900ffFlüche|r hervorheben"
L["HIGHLIGHT_POISON"] = "|cff00bb00Vergiftungen|r hervorheben"
L["HIGHLIGHT_DISEASE"] = "|cff996600Krankheiten|r hervorheben"
L["HIGHLIGHT_MAGIC"] = "|cff3399ffMagie|r hervorheben"
L["DEBUFF_TEST_HEADER"] = "|cffffff00Test-Modus (Debuff-Rahmen simulieren):|r"
L["POISON_TEST_BTN"] = "|cff00dd00Gift (Grün)|r"
L["CURSE_TEST_BTN"] = "|cffaa00ffFluch (Lila)|r"
L["MAGIC_TEST_BTN"] = "|cff00aaffMagie (Blau)|r"
L["TEST_OFF_BTN"] = "Test Aus"
L["TEST_POISON_CHAT"] = "Test-Debuff aktiviert: |cff00ff00Vergiftung (Grüner Rahmen)|r"
L["TEST_CURSE_CHAT"] = "Test-Debuff aktiviert: |cffaa00ffFluch (Lila Rahmen)|r"
L["TEST_MAGIC_CHAT"] = "Test-Debuff aktiviert: |cff00aaffMagie (Blauer Rahmen)|r"
L["CHAT_TEST_DEBUFF_STOP"] = "Test-Debuff |cffff5555deaktiviert|r."

-- Tab 4: Profiles
L["PROFILES_DESC"] = "Profile werden |cff00ff96automatisch pro Charakter|r gespeichert.\nNutze den String unten zum Teilen oder Wiederherstellen von Einstellungen."
L["EXPORT_BTN"] = "Profil Exportieren"
L["IMPORT_BTN"] = "Profil Importieren"
L["RESET_DEFAULTS_BTN"] = "Auf Standard zurücksetzen"
L["STRING_GENERATED_COPY"] = "|cff00ff00String generiert! Strg+C zum Kopieren.|r"
L["PROFILE_RESET_SUCCESS"] = "|cffffff00Profil auf Standardwerte zurückgesetzt.|r"

-- Tab 5: Raid-Optionen
L["RAID_ENABLE"] = "Raid-Frames aktivieren (automatisch im Schlachtzug)"
L["RAID_SHOW_TANKS"] = "Markierte Tanks in separatem Frame anzeigen"
L["RAID_SHOW_MYGROUP"] = "Eigene Gruppe in separatem Frame anzeigen"
L["RAID_SHOW_REMAINING"] = "Restlichen Raid anzeigen"
L["RAID_SHOW_PETS"] = "Begleiter-Frames anzeigen (Jäger-/Hexer-Pets)"
L["RAID_MOVERS_HEADER"] = "|cffffff00Raid-Frames verschieben & positionieren:|r"
L["RAID_UNLOCK_ALL"] = "Raid-Frames entsperren"
L["RAID_LOCK_ALL"] = "Raid-Frames sperren"
L["RAID_RESET_POS"] = "Raid-Positionen zurücksetzen"
L["RAID_SIM_HEADER"] = "|cffffff00Raid-Simulationen (Test-Modus):|r"
L["RAID_SIM_10"] = "10er-Raid simulieren"
L["RAID_SIM_25"] = "25er-Raid simulieren"
L["RAID_SIM_40"] = "40er-Raid simulieren"
L["RAID_SIM_STOP"] = "Raid-Simulation beenden"
L["MOVER_TANK_TITLE"] = "Resto4Life\nTanks"
L["MOVER_MYGROUP_TITLE"] = "Resto4Life\nEigene Gruppe"
L["MOVER_RAID_TITLE"] = "Resto4Life\nRaid"
L["MOVER_PET_TITLE"] = "Resto4Life\nBegleiter"
L["ORIENTATION_LABEL"] = "Anordnung:"
L["ORIENTATION_VERTICAL"] = "Spalte"
L["ORIENTATION_HORIZONTAL"] = "Zeile"
L["ORIENTATION_RAID_VERTICAL"] = "Spalten (8x5)"
L["ORIENTATION_RAID_HORIZONTAL"] = "Zeilen (5x8)"

-- Entwickler-Sprachumschaltung
L["DEV_LANG_CHANGED"] = "Sprache auf |cff00ff00%s|r geändert. UI wird neu geladen..."
L["DEV_LANG_RESET"] = "Sprache auf Client-Standard (|cff00ff00%s|r) zurückgesetzt. UI wird neu geladen..."
L["DEV_LANG_CURRENT"] = "Aktuelle Sprache: |cff00ff00%s|r (Gespeichert: %s). Nutzung: /r4l lang de | en | auto"

-- Initiales Anwenden der aktiven Sprache
R4L:ApplyLocale()


