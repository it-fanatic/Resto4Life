--[[
    Resto4Life - Locales/Locales.lua
    Zentrales Lokalisierungssystem (Fallback auf englische Basiswerte)
--]]

local _, R4L = ...

local L = setmetatable({}, {
    __index = function(t, key)
        -- Fallback: Liefert den Schlüssel selbst zurück, falls keine Übersetzung existiert
        rawset(t, key, key)
        return key
    end
})

R4L.L = L
