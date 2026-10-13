--[[
    Resto4Life - Core/Config.lua
    Standard-Konfiguration und Datenstrukturen
--]]

local _, R4L = ...

R4L.Config = {}

R4L.Config.Defaults = {
    version = 1,
    general = {
        locked = true,
        targetOnCast = false,
        disableSelfCastKey = true,
        frameWidth = 140,
        frameHeight = 52,
        powerBarHeight = 10,
        spacing = 0,
        scale = 1.0,
        growthDirection = "DOWN", -- "DOWN", "UP", "RIGHT", "LEFT"
        posX = 300,
        posY = -300,
    },
    minimap = {
        show = true,
        position = 220,
    },
    display = {
        showNames = true,
        showRoleIcons = true,
        nameFontSize = 12,
        showHealthText = true,
        healthTextFormat = "DEFICIT", -- "DEFICIT", "PERCENT", "CURRENT_MAX"
        healthOrientation = "NORMAL", -- "NORMAL", "REVERSE" (Defizit füllt sich)
        colorMode = "CLASS",          -- "CLASS", "MINIMAL" (Grün/Rot)
        showManaBar = true,
        fadeOutOfRange = true,
        outOfRangeAlpha = 0.4,
        showThreat = true,            -- Aggro- & Bedrohungsanzeige
        showHealPrediction = true,    -- Eingehende Heilung visualisieren
        showAbsorbs = true,           -- Schilde & Absorbs visualisieren
    },
    raid = {
        enabled = true,
        showTanks = true,
        showMyGroup = true,
        showRaid = true,
        showPets = false,
        tankWidth = 120,
        tankHeight = 44,
        raidWidth = 90,
        raidHeight = 40,
        petWidth = 80,
        petHeight = 32,
        tankOrientation = "VERTICAL",    -- "VERTICAL" (Spalte) oder "HORIZONTAL" (Zeile)
        myGroupOrientation = "VERTICAL", -- "VERTICAL" (Spalte) oder "HORIZONTAL" (Zeile)
        raidOrientation = "VERTICAL",    -- "VERTICAL" (Spalten: 8x5) oder "HORIZONTAL" (Zeilen: 5x8)
        petOrientation = "VERTICAL",     -- "VERTICAL" (Spalten) oder "HORIZONTAL" (Zeilen)
        tankPos = { x = 120, y = -260, scale = 1.0 },
        myGroupPos = { x = 260, y = -260, scale = 1.0 },
        raidPos = { x = 400, y = -260, scale = 1.0 },
        petPos = { x = 400, y = -500, scale = 1.0 },
    },

    sorting = {
        enabled = true,
        order = { "TANK", "MELEE", "DAMAGER", "HEALER" },
    },
    auras = {
        showHots = true,
        onlyMyHots = true, -- Nur eigene HoTs auf Gruppenmitgliedern (auf eigenem Frame immer alle)
        hotIconSize = 14,
        maxHots = 4,
        showDebuffs = true,
        highlightDispellableOnly = true,
        includeGroupDispels = false, -- Auch hervorheben, wenn ein Gruppenmitglied den Debuff bannen kann
        showCurse = true,
        showPoison = true,
        showDisease = true,
        showMagic = true,
    },
    smartRez = {
        enabled = true,
        autoDetectSpell = true,
        combatRezSpell = "",  -- e.g. "Rebirth" (Druid), "Soulstone" (Warlock), "Intercession" (Paladin), "Raise Ally" (Death Knight)
        normalRezSpell = "",  -- e.g. "Revive" (Druid), "Redemption" (Paladin), "Resurrection" (Priest), "Ancestral Spirit" (Shaman)
    },
    smartDispel = {
        enabled = true,       -- Standardmäßig aktiv (in den Optionen jederzeit deaktivierbar)
        autoDetectSpell = true,
        dispelSpell = "",     -- Eigener Zaubername oder Spell-ID (leer = automatische Erkennung nach Klasse & Debuff-Typ)
    },
    buffBar = {
        enabled = true,
        scale = 1.0,
        iconSize = 22,
        spacing = 4,
        posX = 300,
        posY = -230,
        locked = true,
        targets = {
            -- Speichert benutzerdefinierte Zieleinstellungen pro Zauber: z.B. ["Dornen"] = "TANK"
        },
    },
    bindings = {
        -- Standard: Maustasten (1 = Links, 2 = Rechts, 3 = Mitte, 4 = Daumen hinten, 5 = Daumen vorne)
        ["1"] = { action = "target", spell = "" },
        ["2"] = { action = "menu", spell = "" },
        ["3"] = { action = "spell", spell = "" },
        ["4"] = { action = "spell", spell = "" },
        ["5"] = { action = "spell", spell = "" },
        -- STRG + Maustasten
        ["CTRL_1"] = { action = "spell", spell = "" },
        ["CTRL_2"] = { action = "spell", spell = "" },
        ["CTRL_3"] = { action = "spell", spell = "" },
        ["CTRL_4"] = { action = "spell", spell = "" },
        ["CTRL_5"] = { action = "spell", spell = "" },
        -- ALT + Maustasten
        ["ALT_1"] = { action = "spell", spell = "" },
        ["ALT_2"] = { action = "spell", spell = "" },
        ["ALT_3"] = { action = "spell", spell = "" },
        ["ALT_4"] = { action = "spell", spell = "" },
        ["ALT_5"] = { action = "spell", spell = "" },
        -- Mausrad (Standard, STRG, ALT)
        ["WheelUp"] = { action = "spell", spell = "" },
        ["WheelDown"] = { action = "spell", spell = "" },
        ["CTRL_WheelUp"] = { action = "spell", spell = "" },
        ["CTRL_WheelDown"] = { action = "spell", spell = "" },
        ["ALT_WheelUp"] = { action = "spell", spell = "" },
        ["ALT_WheelDown"] = { action = "spell", spell = "" },
        -- Tasten 1 - 6 (Standard, STRG, ALT)
        ["KEY_1"] = { action = "spell", spell = "" },
        ["KEY_2"] = { action = "spell", spell = "" },
        ["KEY_3"] = { action = "spell", spell = "" },
        ["KEY_4"] = { action = "spell", spell = "" },
        ["KEY_5"] = { action = "spell", spell = "" },
        ["KEY_6"] = { action = "spell", spell = "" },
        ["CTRL_KEY_1"] = { action = "spell", spell = "" },
        ["CTRL_KEY_2"] = { action = "spell", spell = "" },
        ["CTRL_KEY_3"] = { action = "spell", spell = "" },
        ["CTRL_KEY_4"] = { action = "spell", spell = "" },
        ["CTRL_KEY_5"] = { action = "spell", spell = "" },
        ["CTRL_KEY_6"] = { action = "spell", spell = "" },
        ["ALT_KEY_1"] = { action = "spell", spell = "" },
        ["ALT_KEY_2"] = { action = "spell", spell = "" },
        ["ALT_KEY_3"] = { action = "spell", spell = "" },
        ["ALT_KEY_4"] = { action = "spell", spell = "" },
        ["ALT_KEY_5"] = { action = "spell", spell = "" },
        ["ALT_KEY_6"] = { action = "spell", spell = "" },
    }
}

-- Intelligente Standard-Voreinstellungen je nach Heiler-Klasse (per Spell-ID sprachunabhängig)
R4L.Config.ClassDefaults = {
    ["DRUID"] = {
        smartRez = {
            combatRezSpell = 20484, -- Rebirth / Wiedergeburt
            normalRezSpell = 50769, -- Revive / Wiederbeleben
        },
        smartDispel = {
            dispelSpell = "",       -- Automatische Erkennung (Vergiftung aufheben / Fluch aufheben / Heilung der Natur)
        },
        bindings = {
            ["1"] = { action = "spell", spell = 774 },   -- Rejuvenation / Verjüngung
            ["2"] = { action = "spell", spell = 8936 },  -- Regrowth / Nachwachsen
            ["3"] = { action = "spell", spell = 18562 }, -- Swiftmend / Rasche Heilung
            ["WheelUp"] = { action = "spell", spell = 33763 }, -- Lifebloom / Blühendes Leben
            ["WheelDown"] = { action = "spell", spell = 48438 }, -- Wild Growth / Wildwuchs
            ["CTRL_1"] = { action = "spell", spell = 2782 }, -- Fluch aufheben / Remove Curse
            ["CTRL_2"] = { action = "spell", spell = 2893 }, -- Vergiftung aufheben / Abolish Poison
            ["KEY_1"] = { action = "spell", spell = 50464 }, -- Nourish / Pflege
            ["KEY_2"] = { action = "spell", spell = 2782 },  -- Fluch aufheben / Verderbnis entfernen
        },
        trackedHots = {
            774,    -- Verjüngung (Rejuvenation)
            8936,   -- Nachwachsen (Regrowth)
            33763,  -- Blühendes Leben (Lifebloom)
            48438,  -- Wildwuchs (Wild Growth)
            102351, -- Cenarischer Zauberschutz (Cenarion Ward)
        }
    },
    ["PRIEST"] = {
        smartRez = {
            combatRezSpell = "",
            normalRezSpell = 2006, -- Resurrection / Auferstehung
        },
        smartDispel = {
            dispelSpell = "",      -- Automatische Erkennung (Magiebannung / Krankheit aufheben / Läutern)
        },
        bindings = {
            ["1"] = { action = "spell", spell = 2061 },  -- Flash Heal / Blitzheilung
            ["2"] = { action = "spell", spell = 17 },    -- Power Word: Shield / Machtwort: Schild
            ["3"] = { action = "spell", spell = 139 },   -- Renew / Erneuerung
            ["WheelUp"] = { action = "spell", spell = 33076 }, -- Prayer of Mending / Gebet der Besserung
            ["WheelDown"] = { action = "spell", spell = 34861 }, -- Circle of Healing / Kreis der Heilung
            ["CTRL_1"] = { action = "spell", spell = 527 },  -- Magiebannung / Dispel Magic
            ["CTRL_2"] = { action = "spell", spell = 552 },  -- Krankheit aufheben / Abolish Disease
            ["KEY_1"] = { action = "spell", spell = 2060 }, -- Heal / Große Heilung
            ["KEY_2"] = { action = "spell", spell = 527 },  -- Purify / Magiebannung
        },
        trackedHots = {
            139,    -- Erneuerung (Renew)
            17,     -- Machtwort: Schild (PW: Shield)
            41635,  -- Gebet der Besserung (Prayer of Mending)
            194384, -- Abbitte (Atonement)
        }
    },
    ["PALADIN"] = {
        smartRez = {
            combatRezSpell = 391054, -- Intercession / Fürbitte
            normalRezSpell = 7328,   -- Redemption / Erlösung
        },
        smartDispel = {
            dispelSpell = "",        -- Automatische Erkennung (Reinigung des Glaubens / Läutern)
        },
        bindings = {
            ["1"] = { action = "spell", spell = 20473 }, -- Holy Shock / Heiliger Schock
            ["2"] = { action = "spell", spell = 19750 }, -- Flash of Light / Lichtblitz
            ["3"] = { action = "spell", spell = 85673 }, -- Word of Glory / Wort der Herrlichkeit
            ["WheelUp"] = { action = "spell", spell = 85222 }, -- Light of Dawn / Licht der Morgendämmerung
            ["WheelDown"] = { action = "spell", spell = 82326 }, -- Holy Light / Heiliges Licht
            ["CTRL_1"] = { action = "spell", spell = 4987 },  -- Cleanse / Reinigung des Glaubens
            ["KEY_1"] = { action = "spell", spell = 53563 }, -- Beacon of Light / Flamme des Glaubens
            ["KEY_2"] = { action = "spell", spell = 4987 },  -- Cleanse / Reinigung des Glaubens
        },
        trackedHots = {
            53563,  -- Flamme des Glaubens (Beacon of Light)
            156910, -- Flamme der Zuversicht (Beacon of Faith)
            223306, -- Bestow Faith
        }
    },
    ["SHAMAN"] = {
        smartRez = {
            combatRezSpell = "",
            normalRezSpell = 2008, -- Ancestral Spirit / Geist der Ahnen
        },
        smartDispel = {
            dispelSpell = "",      -- Automatische Erkennung (Geistreinigung / Vergiftung heilen / Krankheit heilen)
        },
        bindings = {
            ["1"] = { action = "spell", spell = 77472 }, -- Healing Wave / Welle der Heilung
            ["2"] = { action = "spell", spell = 8004 },  -- Healing Surge / Heilende Woge
            ["3"] = { action = "spell", spell = 61295 }, -- Riptide / Springflut
            ["WheelUp"] = { action = "spell", spell = 974 }, -- Earth Shield / Erdschild
            ["WheelDown"] = { action = "spell", spell = 1064 }, -- Chain Heal / Kettenheilung
            ["CTRL_1"] = { action = "spell", spell = 526 },   -- Vergiftung heilen / Cure Poison
            ["CTRL_2"] = { action = "spell", spell = 2870 },  -- Krankheit heilen / Cure Disease
            ["KEY_1"] = { action = "spell", spell = 52127 }, -- Water Shield / Wasserschild
            ["KEY_2"] = { action = "spell", spell = 77130 }, -- Purify Spirit / Geistläuterung
        },
        trackedHots = {
            61295,  -- Springflut (Riptide)
            974,    -- Erdschild (Earth Shield)
        }
    },
    ["MONK"] = {
        smartRez = {
            combatRezSpell = "",
            normalRezSpell = 115178, -- Resuscitate / Wiedererwecken
        },
        smartDispel = {
            dispelSpell = 115450,    -- Detox / Entgiftung
        },
        bindings = {
            ["1"] = { action = "spell", spell = 115175 }, -- Soothing Mist / Beruhigender Nebel
            ["2"] = { action = "spell", spell = 124682 }, -- Enveloping Mist / Einhüllender Nebel
            ["3"] = { action = "spell", spell = 116670 }, -- Vivify / Beleben
            ["WheelUp"] = { action = "spell", spell = 119611 }, -- Renewing Mist / Erneuernder Nebel
            ["WheelDown"] = { action = "spell", spell = 191837 }, -- Essence Font / Essenzborn
            ["KEY_1"] = { action = "spell", spell = 115450 }, -- Detox / Entgiftung
        },
        trackedHots = {
            119611, -- Erneuernder Nebel (Renewing Mist)
            124682, -- Einhüllender Nebel (Enveloping Mist)
            115175, -- Beruhigender Nebel (Soothing Mist)
        }
    },
    ["EVOKER"] = {
        smartRez = {
            combatRezSpell = "",
            normalRezSpell = 361227, -- Return / Rückkehr
        },
        smartDispel = {
            dispelSpell = 360823,    -- Naturalize / Natürliche Säuberung
        },
        bindings = {
            ["1"] = { action = "spell", spell = 366155 }, -- Reversion / Rückverwandlung
            ["2"] = { action = "spell", spell = 361469 }, -- Living Flame / Lebende Flamme
            ["3"] = { action = "spell", spell = 364343 }, -- Echo
            ["WheelUp"] = { action = "spell", spell = 355936 }, -- Dream Breath / Traumatem
            ["WheelDown"] = { action = "spell", spell = 355913 }, -- Emerald Blossom / Smaragdblüte
            ["KEY_1"] = { action = "spell", spell = 360823 }, -- Naturalize / Natürliche Säuberung
        },
        trackedHots = {
            364343, -- Echo
            366155, -- Reversion (Rückverwandlung)
            376788, -- Dream Breath (Traumatem)
        }
    }
}
