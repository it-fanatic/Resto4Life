--[[
    Resto4Life - Core/Init.lua
    Hauptinitialisierung, Event-Handling und Namespace-Setup
--]]

local addonName, R4L = ...
_G["Resto4Life"] = R4L

R4L.addonName = addonName
R4L.version = "0.1.6a_beta"
R4L.inCombat = false
R4L.combatQueue = {}

-- Event Management
local eventFrame = CreateFrame("Frame")
local eventCallbacks = {}

function R4L:RegisterEvent(event, callback)
    if not eventCallbacks[event] then
        eventCallbacks[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventCallbacks[event], callback)
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
        -- Verarbeite Aktionen, die während des Kampfes verzögert wurden
        if #R4L.combatQueue > 0 then
            local queue = R4L.combatQueue
            R4L.combatQueue = {}
            for _, action in ipairs(queue) do
                pcall(action)
            end
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

function R4L:Print(msg, ...)
    local formatted = string.format(msg, ...)
    print("|cff00ff96[Resto4Life]|r " .. formatted)
end

-- Slash Commands
SLASH_RESTO4LIFE1 = "/r4l"
SLASH_RESTO4LIFE2 = "/resto4life"

SlashCmdList["RESTO4LIFE"] = function(msg)
    local cmd = string.lower(string.trim(msg or ""))
    if cmd == "unlock" or cmd == "move" then
        if R4L.GroupHeader then
            R4L.GroupHeader:ToggleLock(false)
        end
    elseif cmd == "lock" then
        if R4L.GroupHeader then
            R4L.GroupHeader:ToggleLock(true)
        end
    elseif cmd == "reset" or cmd == "center" then
        if R4L.GroupHeader then
            R4L.GroupHeader:ResetPosition()
        end
    elseif cmd == "resetall" then
        if R4L.ProfileManager then
            R4L.ProfileManager:ResetToDefaults()
        end
    else
        if R4L.OptionsUI then
            R4L.OptionsUI:Toggle()
        else
            R4L:Print("Konfigurationsmenü wird geladen...")
        end
    end
end
