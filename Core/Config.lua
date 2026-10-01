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
        hotIconSize = 14,
        maxHots = 4,
        showDebuffs = true,
        highlightDispellableOnly = true,
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
    bindings = {
        -- Maustasten (1 = Links, 2 = Rechts, 3 = Mitte, 4 = Maus4, 5 = Maus5)
        ["1"] = { action = "target", spell = "" },
        ["2"] = { action = "menu", spell = "" },
        ["3"] = { action = "spell", spell = "" },
        -- Mausrad
        ["WheelUp"] = { action = "spell", spell = "" },
        ["WheelDown"] = { action = "spell", spell = "" },
        -- Tasten 1 - 6 (beim Überfahren des Rahmens)
        ["KEY_1"] = { action = "spell", spell = "" },
        ["KEY_2"] = { action = "spell", spell = "" },
        ["KEY_3"] = { action = "spell", spell = "" },
        ["KEY_4"] = { action = "spell", spell = "" },
        ["KEY_5"] = { action = "spell", spell = "" },
        ["KEY_6"] = { action = "spell", spell = "" },
    }
}

-- Intelligente Standard-Voreinstellungen je nach Heiler-Klasse (per Spell-ID sprachunabhängig)
R4L.Config.ClassDefaults = {
    ["DRUID"] = {
        smartRez = {
            combatRezSpell = 20484, -- Rebirth / Wiedergeburt
            normalRezSpell = 50769, -- Revive / Wiederbeleben
        },
        bindings = {
            ["1"] = { action = "spell", spell = 774 },   -- Rejuvenation / Verjüngung
            ["2"] = { action = "spell", spell = 8936 },  -- Regrowth / Nachwachsen
            ["3"] = { action = "spell", spell = 18562 }, -- Swiftmend / Rasche Heilung
            ["WheelUp"] = { action = "spell", spell = 33763 }, -- Lifebloom / Blühendes Leben
            ["WheelDown"] = { action = "spell", spell = 48438 }, -- Wild Growth / Wildwuchs
            ["KEY_1"] = { action = "spell", spell = 50464 }, -- Nourish / Pflege
            ["KEY_2"] = { action = "spell", spell = 88423 }, -- Nature's Cure / Heilung der Natur
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
        bindings = {
            ["1"] = { action = "spell", spell = 2061 },  -- Flash Heal / Blitzheilung
            ["2"] = { action = "spell", spell = 17 },    -- Power Word: Shield / Machtwort: Schild
            ["3"] = { action = "spell", spell = 139 },   -- Renew / Erneuerung
            ["WheelUp"] = { action = "spell", spell = 33076 }, -- Prayer of Mending / Gebet der Besserung
            ["WheelDown"] = { action = "spell", spell = 34861 }, -- Circle of Healing / Kreis der Heilung
            ["KEY_1"] = { action = "spell", spell = 2060 }, -- Heal / Große Heilung
            ["KEY_2"] = { action = "spell", spell = 527 },  -- Purify / Läutern
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
        bindings = {
            ["1"] = { action = "spell", spell = 20473 }, -- Holy Shock / Heiliger Schock
            ["2"] = { action = "spell", spell = 19750 }, -- Flash of Light / Lichtblitz
            ["3"] = { action = "spell", spell = 85673 }, -- Word of Glory / Wort der Herrlichkeit
            ["WheelUp"] = { action = "spell", spell = 85222 }, -- Light of Dawn / Licht der Morgendämmerung
            ["WheelDown"] = { action = "spell", spell = 82326 }, -- Holy Light / Heiliges Licht
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
            normalRezSpell = 2008, -- Ancestral Spirit / Geistläuterung
        },
        bindings = {
            ["1"] = { action = "spell", spell = 77472 }, -- Healing Wave / Welle der Heilung
            ["2"] = { action = "spell", spell = 8004 },  -- Healing Surge / Heilende Woge
            ["3"] = { action = "spell", spell = 61295 }, -- Riptide / Springflut
            ["WheelUp"] = { action = "spell", spell = 974 }, -- Earth Shield / Erdschild
            ["WheelDown"] = { action = "spell", spell = 1064 }, -- Chain Heal / Kettenheilung
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
