--[[
    Resto4Life - Locales/Locales.lua
    Zentrales Lokalisierungssystem (Unterstützt enUS, deDE und Entwickler-Override)
--]]

local _, R4L = ...

R4L.Locales = {
    enUS = {},
    deDE = {},
}

local activeLocale = {}
local L = setmetatable(activeLocale, {
    __index = function(t, key)
        -- Fallback: Liefert den Schlüssel selbst zurück, falls keine Übersetzung existiert
        rawset(t, key, key)
        return key
    end
})

R4L.L = L

function R4L:ApplyLocale(targetLocale)
    local loc = targetLocale
    if not loc or loc == "auto" then
        if Resto4LifeDB and Resto4LifeDB.devLocale then
            loc = Resto4LifeDB.devLocale
        else
            loc = GetLocale()
        end
    end

    -- Bestehende Einträge zurücksetzen
    for k in pairs(activeLocale) do
        activeLocale[k] = nil
    end

    -- 1. Immer englische Basiswerte als Fallback laden
    if R4L.Locales.enUS then
        for k, v in pairs(R4L.Locales.enUS) do
            activeLocale[k] = v
        end
    end

    -- 2. Wenn deDE aktiv ist, deutsche Übersetzungen darüberlegen
    if (loc == "deDE" or loc == "de") and R4L.Locales.deDE then
        for k, v in pairs(R4L.Locales.deDE) do
            activeLocale[k] = v
        end
    end

    R4L.currentLocale = loc
end
