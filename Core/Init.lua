--[[
    Resto4Life - Core/Init.lua
    Hauptinitialisierung, Event-Handling und Namespace-Setup
--]]

local addonName, R4L = ...
_G["Resto4Life"] = R4L

R4L.addonName = addonName
R4L.version = "0.2.7-beta"
R4L.inCombat = false
R4L.combatQueue = {}

-- Event Management
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
local eventCallbacks = {}

function R4L:RegisterEvent(event, callback)
    if not eventCallbacks[event] then
        eventCallbacks[event] = {}
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            eventCallbacks[event] = nil
            return false
        end
    end
    table.insert(eventCallbacks[event], callback)
    return true
end

function R4L:UnregisterEvent(event, callback)
    if eventCallbacks[event] then
        for i, cb in ipairs(eventCallbacks[event]) do
            if cb == callback then
                table.remove(eventCallbacks[event], i)
                break
            end
        end
        if #eventCallbacks[event] == 0 then
            eventCallbacks[event] = nil
            eventFrame:UnregisterEvent(event)
        end
    end
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        R4L.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        R4L.inCombat = false
        -- Verarbeite Aktionen, die während des Kampfes verzögert wurden (z.B. neue Gruppenmitglieder)
        if #R4L.combatQueue > 0 then
            local queue = R4L.combatQueue
            R4L.combatQueue = {}
            for _, action in ipairs(queue) do
                pcall(action)
            end
        end
        -- Nach Kampfende Roster immer abgleichen
        if R4L.GroupHeader and R4L.GroupHeader.UpdateRoster then
            pcall(R4L.GroupHeader.UpdateRoster, R4L.GroupHeader)
        end
        if R4L.RaidHeader and R4L.RaidHeader.UpdateRoster then
            pcall(R4L.RaidHeader.UpdateRoster, R4L.RaidHeader)
        end
    end

    if eventCallbacks[event] then
        for _, cb in ipairs(eventCallbacks[event]) do
            local success, err = pcall(cb, event, ...)
            if not success and err then
                print("|cffff0000[Resto4Life Fehler]|r " .. tostring(err))
            end
        end
    end
end)

function R4L:QueueOutOfCombat(action)
    if self.inCombat or InCombatLockdown() then
        table.insert(self.combatQueue, action)
    else
        action()
    end
end

-- =========================================================================
-- Universelle Zauber-Abfrage (kompatibel mit Retail 11.0+, 12.0, Classic & WotLK 3.3.5)
-- =========================================================================
function R4L:GetSpellName(spellId)
    if not spellId then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
        if ok and info and info.name then return info.name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and name then return name end
    end
    return nil
end

function R4L:GetSpellTexture(spellId)
    if not spellId then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and tex then return tex end
    end
    if GetSpellTexture then
        local ok, tex = pcall(GetSpellTexture, spellId)
        if ok and tex then return tex end
    end
    if GetSpellInfo then
        local ok, _, _, sIcon = pcall(GetSpellInfo, spellId)
        if ok and sIcon then return sIcon end
    end
    return nil
end

-- =========================================================================
-- Zuverlässige 40-Meter Reichweitenprüfung (Retail & Classic / Forever)
-- =========================================================================
local FRIENDLY_RANGE_SPELLS = {
    ["PRIEST"]      = { 2061, 139, 17 },        -- Blitzheilung, Erneuerung, Machtwort: Schild
    ["DRUID"]       = { 774, 8936, 33763 },     -- Verjüngung, Nachwachsen, Blühendes Leben
    ["PALADIN"]     = { 19750, 82326 },         -- Lichtblitz, Heiliges Licht
    ["SHAMAN"]      = { 8004, 77472, 61295 },   -- Heilende Woge, Welle der Heilung, Springflut
    ["MONK"]        = { 116670, 115175 },       -- Vivat / Beleben, Beruhigender Nebel
    ["EVOKER"]      = { 361469, 366155 },       -- Lebende Flamme, Zurückspulen
    ["MAGE"]        = { 475 },                  -- Fluch aufheben
    ["WARLOCK"]     = { 5697 },                 -- Unendlicher Atem
}

function R4L:GetRangeCheckSpell()
    if self.rangeCheckSpell ~= nil then return self.rangeCheckSpell end
    local _, englishClass = UnitClass("player")
    local candidates = englishClass and FRIENDLY_RANGE_SPELLS[englishClass]
    if candidates then
        for _, id in ipairs(candidates) do
            local exists = false
            if C_Spell and C_Spell.DoesSpellExist then
                local ok, ex = pcall(C_Spell.DoesSpellExist, id)
                if ok and ex then exists = true end
            elseif GetSpellInfo then
                local ok, name = pcall(GetSpellInfo, id)
                if ok and name then exists = true end
            end
            if exists then
                self.rangeCheckSpell = id
                return id
            end
        end
    end
    self.rangeCheckSpell = false
    return false
end

function R4L:IsUnitInRange(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end

    -- 1. Offline oder nicht in 3D-Sichtweite (> 100 Meter)
    if UnitIsConnected then
        local okConn, isConn = pcall(UnitIsConnected, unit)
        if okConn and isConn == false then return false end
    end
    if UnitIsVisible then
        local okVis, isVis = pcall(UnitIsVisible, unit)
        if okVis and isVis == false then return false end
    end

    -- 2. Primäre 40-Meter Prüfung über Zauber (100% verlässlich auf jedem Client)
    local spell = self:GetRangeCheckSpell()
    if spell then
        if C_Spell and C_Spell.IsSpellInRange then
            local okSpell, inSpell = pcall(C_Spell.IsSpellInRange, spell, unit)
            if okSpell and inSpell ~= nil then
                return (inSpell == true or inSpell == 1)
            end
        elseif IsSpellInRange then
            local okSpell, inSpell = pcall(IsSpellInRange, spell, unit)
            if okSpell and inSpell ~= nil then
                return (inSpell == 1 or inSpell == true)
            end
        end
    end

    -- 3. UnitInRange Fallback
    if UnitInRange then
        local okRange, inRange, checked = pcall(UnitInRange, unit)
        if okRange and inRange ~= nil then
            if checked == true or checked == 1 then
                return (inRange == true or inRange == 1)
            elseif inRange == false or inRange == 0 then
                return false
            elseif inRange == true or inRange == 1 then
                return true
            end
        end
    end

    -- 4. CheckInteractDistance(unit, 4) = ca. 28 Meter
    if CheckInteractDistance then
        local okDist, inDist = pcall(CheckInteractDistance, unit, 4)
        if okDist and inDist == true then
            return true
        end
    end

    return true
end

function R4L:Print(msg, ...)
    local formatted = string.format(msg, ...)
    print("|cff00ff96[Resto4Life]|r " .. formatted)
end

function R4L:SetDevLanguage(targetLocale)
    if not Resto4LifeDB then Resto4LifeDB = {} end
    local L = self.L
    if targetLocale == "auto" then
        Resto4LifeDB.devLocale = nil
        self:Print(L["DEV_LANG_RESET"] or "Sprache auf Client-Standard (%s) zurückgesetzt. UI wird neu geladen...", GetLocale())
    else
        Resto4LifeDB.devLocale = targetLocale
        self:Print(L["DEV_LANG_CHANGED"] or "Sprache auf %s geändert. UI wird neu geladen...", targetLocale)
    end
    if C_UI and C_UI.Reload then
        C_UI.Reload()
    else
        ReloadUI()
    end
end

-- Slash Commands
SLASH_RESTO4LIFE1 = "/r4l"
SLASH_RESTO4LIFE2 = "/resto4life"
SLASH_RESTO4LIFE3 = "/resto"

SlashCmdList["RESTO4LIFE"] = function(msg)
    local cmd = string.lower(string.trim(msg or ""))
    if cmd:match("^lang") or cmd:match("^devlang") then
        local sub = string.trim(cmd:gsub("^devlang", ""):gsub("^lang", ""))
        if sub == "de" or sub == "dede" then
            R4L:SetDevLanguage("deDE")
        elseif sub == "en" or sub == "enus" then
            R4L:SetDevLanguage("enUS")
        elseif sub == "auto" or sub == "reset" then
            R4L:SetDevLanguage("auto")
        else
            local saved = (Resto4LifeDB and Resto4LifeDB.devLocale) or "Client-Standard"
            local cur = R4L.currentLocale or GetLocale()
            R4L:Print(R4L.L["DEV_LANG_CURRENT"] or "Aktuelle Sprache: |cff00ff00%s|r (Gespeichert: %s). Nutzung: /r4l lang de | en | auto", cur, saved)
        end
    elseif cmd == "unlock" or cmd == "move" then
        if (IsInRaid() or (R4L.RaidHeader and R4L.RaidHeader.isSimulating)) and R4L.RaidHeader then
            R4L.RaidHeader:ToggleLock(false)
        elseif R4L.GroupHeader then
            R4L.GroupHeader:ToggleLock(false)
        end
        if R4L.BuffBar then
            R4L.BuffBar:ToggleLock(false)
        end
    elseif cmd == "lock" then
        if R4L.RaidHeader then
            R4L.RaidHeader:ToggleLock(true)
        end
        if R4L.GroupHeader then
            R4L.GroupHeader:ToggleLock(true)
        end
        if R4L.BuffBar then
            R4L.BuffBar:ToggleLock(true)
        end
    elseif cmd == "reset" or cmd == "center" then
        if (IsInRaid() or (R4L.RaidHeader and R4L.RaidHeader.isSimulating)) and R4L.RaidHeader then
            R4L.RaidHeader:ResetPositions()
        elseif R4L.GroupHeader then
            R4L.GroupHeader:ResetPosition()
        end
        if R4L.BuffBar then
            R4L.BuffBar:ResetPosition()
        end

    elseif cmd == "resetall" then
        if R4L.ProfileManager then
            R4L.ProfileManager:ResetToDefaults()
        end
    elseif cmd == "bufftest" or cmd == "testbuff" then
        if R4L.BuffBar and R4L.BuffBar.RunDiagnostic then
            R4L.BuffBar:RunDiagnostic()
        else
            R4L:Print("BuffBar-Modul nicht aktiv.")
        end
    elseif cmd == "debufftest" or cmd == "testdebuff" then
        if R4L.AuraTracker and R4L.AuraTracker.RunDiagnostic then
            R4L.AuraTracker:RunDiagnostic()
        else
            R4L:Print("AuraTracker-Modul nicht aktiv.")
        end
    elseif cmd:match("^test%s+debuff") or cmd:match("^test%s+border") or cmd:match("^debuff%s+test") then
        local sub = cmd:gsub("^test%s+debuff%s*", ""):gsub("^test%s+border%s*", ""):gsub("^debuff%s+test%s*", "")
        sub = string.lower(string.trim(sub))
        if sub == "poison" or sub == "gift" then
            R4L.testDebuff = "Poison"
            R4L:Print("Test-Debuff: |cff00ff00Gift (Grüner Rahmen)|r")
        elseif sub == "curse" or sub == "fluch" then
            R4L.testDebuff = "Curse"
            R4L:Print("Test-Debuff: |cffaa00ffFluch (Lila Rahmen)|r")
        elseif sub == "disease" or sub == "krankheit" then
            R4L.testDebuff = "Disease"
            R4L:Print("Test-Debuff: |cff996600Krankheit (Brauner Rahmen)|r")
        elseif sub == "magic" or sub == "magie" then
            R4L.testDebuff = "Magic"
            R4L:Print("Test-Debuff: |cff00aaffMagie (Blauer Rahmen)|r")
        elseif sub == "off" or sub == "aus" or sub == "stop" then
            R4L.testDebuff = nil
            R4L:Print("Test-Debuff deaktiviert.")
        else
            R4L:Print("Nutzung: /r4l test debuff poison | curse | disease | magic | off")
        end
        if R4L.GroupHeader and R4L.GroupHeader.UpdateAllFrames then R4L.GroupHeader:UpdateAllFrames() end
        if R4L.RaidHeader and R4L.RaidHeader.UpdateAllFrames then R4L.RaidHeader:UpdateAllFrames() end
    else
        if R4L.OptionsUI then
            R4L.OptionsUI:Toggle()
        else
            R4L:Print("Konfigurationsmenü wird geladen...")
        end
    end
end
