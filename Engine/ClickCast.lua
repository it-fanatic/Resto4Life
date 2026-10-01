--[[
    Resto4Life - Engine/ClickCast.lua
    Verwaltung von Click-Casting (Mausklicks, Mausrad, Tasten 1-6) und Smart Battle Rez
--]]

local _, R4L = ...

R4L.ClickCast = {}
local CC = R4L.ClickCast

-- Erstellt einen sicheren Macrotext unter Berücksichtigung von Smart Battle Rez
function CC:BuildMacroText(unit, actionType, spellName, isLeftClick)
    local cfg = R4L.ProfileManager:GetConfig()
    local smartRez = cfg.smartRez or {}

    -- Falls der Klick für Zielauswahl oder Menü gedacht ist
    if actionType == "target" then
        return "/target [@" .. unit .. "]"
    elseif actionType == "menu" then
        return nil
    end

    -- Wenn kein Zauber angegeben ist
    if not spellName or spellName == "" then
        return nil
    end

    local castLine = ""
    -- Intelligentes Battle-Rez / Normal-Rez bei Linksklick auf tote Gruppenmitglieder
    if smartRez.enabled and isLeftClick then
        local combatRez = smartRez.combatRezSpell
        local normalRez = smartRez.normalRezSpell

        local rezParts = {}
        if combatRez and combatRez ~= "" then
            table.insert(rezParts, "[combat,help,dead,@" .. unit .. "] " .. combatRez)
        end
        if normalRez and normalRez ~= "" then
            table.insert(rezParts, "[nocombat,help,dead,@" .. unit .. "] " .. normalRez)
        end

        if #rezParts > 0 then
            castLine = "/cast " .. table.concat(rezParts, "; ") .. "; [@" .. unit .. "] " .. spellName
        else
            castLine = "/cast [@" .. unit .. "] " .. spellName
        end
    else
        castLine = "/cast [@" .. unit .. "] " .. spellName
    end

    if cfg.general and cfg.general.targetOnCast then
        return "/target [@" .. unit .. "]\n" .. castLine
    else
        return castLine
    end
end


-- Erstellt dedizierte SecureActionButton-Kinder für Mausrad & Tasten 1-6
function CC:SetupChildButtons(frame)
    if frame.wheelUpBtn then return end

    local name = frame:GetName()
    frame.wheelUpBtn = CreateFrame("Button", name .. "_WheelUp", frame, "SecureActionButtonTemplate")
    frame.wheelUpBtn:SetSize(1, 1)
    frame.wheelUpBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.wheelUpBtn:RegisterForClicks("AnyUp", "AnyDown")

    frame.wheelDownBtn = CreateFrame("Button", name .. "_WheelDown", frame, "SecureActionButtonTemplate")
    frame.wheelDownBtn:SetSize(1, 1)
    frame.wheelDownBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.wheelDownBtn:RegisterForClicks("AnyUp", "AnyDown")

    frame.keyBtns = {}
    for i = 1, 6 do
        local kBtn = CreateFrame("Button", name .. "_Key" .. i, frame, "SecureActionButtonTemplate")
        kBtn:SetSize(1, 1)
        kBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        kBtn:RegisterForClicks("AnyUp", "AnyDown")
        frame.keyBtns[i] = kBtn
    end
end

-- Wendet alle konfigurierten Tastenbelegungen auf einen Unit-Frame an
function CC:ApplyBindingsToFrame(frame)
    if not frame or not frame.unit then return end
    if InCombatLockdown() then
        R4L:QueueOutOfCombat(function()
            CC:ApplyBindingsToFrame(frame)
        end)
        return
    end

    self:SetupChildButtons(frame)

    local cfg = R4L.ProfileManager:GetConfig()
    local bindings = cfg.bindings or {}
    local unit = frame.unit

    frame:RegisterForClicks("AnyUp", "AnyDown")

    -- 1. Maustasten 1 bis 5 direkt auf dem Hauptframe
    local mouseButtons = {
        ["1"] = "1",
        ["2"] = "2",
        ["3"] = "3",
        ["4"] = "4",
        ["5"] = "5",
    }

    for bKey, bId in pairs(mouseButtons) do
        local bConfig = bindings[bKey]
        if bConfig then
            if bConfig.action == "target" then
                frame:SetAttribute("*type" .. bId, "target")
                frame:SetAttribute("*unit" .. bId, unit)
                frame:SetAttribute("type" .. bId, "target")
                frame:SetAttribute("unit" .. bId, unit)
            elseif bConfig.action == "menu" then
                frame:SetAttribute("*type" .. bId, "togglemenu")
                frame:SetAttribute("*unit" .. bId, unit)
                frame:SetAttribute("type" .. bId, "togglemenu")
                frame:SetAttribute("unit" .. bId, unit)
            elseif bConfig.action == "spell" and bConfig.spell ~= "" then
                local macro = self:BuildMacroText(unit, "spell", bConfig.spell, (bId == "1"))
                frame:SetAttribute("*type" .. bId, "macro")
                frame:SetAttribute("*macrotext" .. bId, macro)
                frame:SetAttribute("type" .. bId, "macro")
                frame:SetAttribute("macrotext" .. bId, macro)
            else
                frame:SetAttribute("*type" .. bId, nil)
                frame:SetAttribute("*macrotext" .. bId, nil)
                frame:SetAttribute("type" .. bId, nil)
                frame:SetAttribute("macrotext" .. bId, nil)
            end
        end
    end

    -- 2. Mausrad (WheelUp, WheelDown) auf Child-Buttons
    if bindings["WheelUp"] and bindings["WheelUp"].spell ~= "" then
        local macro = self:BuildMacroText(unit, "spell", bindings["WheelUp"].spell, false)
        frame.wheelUpBtn:SetAttribute("*type1", "macro")
        frame.wheelUpBtn:SetAttribute("*macrotext1", macro)
        frame.wheelUpBtn:SetAttribute("type1", "macro")
        frame.wheelUpBtn:SetAttribute("macrotext1", macro)
        frame.wheelUpBtn:SetAttribute("*type", "macro")
        frame.wheelUpBtn:SetAttribute("*macrotext", macro)
        frame.wheelUpBtn:SetAttribute("type", "macro")
        frame.wheelUpBtn:SetAttribute("macrotext", macro)
    else
        frame.wheelUpBtn:SetAttribute("*type1", nil)
        frame.wheelUpBtn:SetAttribute("*macrotext1", nil)
        frame.wheelUpBtn:SetAttribute("type1", nil)
        frame.wheelUpBtn:SetAttribute("macrotext1", nil)
        frame.wheelUpBtn:SetAttribute("*type", nil)
        frame.wheelUpBtn:SetAttribute("*macrotext", nil)
        frame.wheelUpBtn:SetAttribute("type", nil)
        frame.wheelUpBtn:SetAttribute("macrotext", nil)
    end

    if bindings["WheelDown"] and bindings["WheelDown"].spell ~= "" then
        local macro = self:BuildMacroText(unit, "spell", bindings["WheelDown"].spell, false)
        frame.wheelDownBtn:SetAttribute("*type1", "macro")
        frame.wheelDownBtn:SetAttribute("*macrotext1", macro)
        frame.wheelDownBtn:SetAttribute("type1", "macro")
        frame.wheelDownBtn:SetAttribute("macrotext1", macro)
        frame.wheelDownBtn:SetAttribute("*type", "macro")
        frame.wheelDownBtn:SetAttribute("*macrotext", macro)
        frame.wheelDownBtn:SetAttribute("type", "macro")
        frame.wheelDownBtn:SetAttribute("macrotext", macro)
    else
        frame.wheelDownBtn:SetAttribute("*type1", nil)
        frame.wheelDownBtn:SetAttribute("*macrotext1", nil)
        frame.wheelDownBtn:SetAttribute("type1", nil)
        frame.wheelDownBtn:SetAttribute("macrotext1", nil)
        frame.wheelDownBtn:SetAttribute("*type", nil)
        frame.wheelDownBtn:SetAttribute("*macrotext", nil)
        frame.wheelDownBtn:SetAttribute("type", nil)
        frame.wheelDownBtn:SetAttribute("macrotext", nil)
    end

    -- 3. Tasten 1 bis 6 auf Child-Buttons
    for i = 1, 6 do
        local kKey = "KEY_" .. i
        local bConfig = bindings[kKey]
        local kBtn = frame.keyBtns[i]
        if bConfig and bConfig.spell and bConfig.spell ~= "" then
            local macro = self:BuildMacroText(unit, "spell", bConfig.spell, false)
            kBtn:SetAttribute("*type1", "macro")
            kBtn:SetAttribute("*macrotext1", macro)
            kBtn:SetAttribute("type1", "macro")
            kBtn:SetAttribute("macrotext1", macro)
            kBtn:SetAttribute("*type", "macro")
            kBtn:SetAttribute("*macrotext", macro)
            kBtn:SetAttribute("type", "macro")
            kBtn:SetAttribute("macrotext", macro)
        else
            kBtn:SetAttribute("*type1", nil)
            kBtn:SetAttribute("*macrotext1", nil)
            kBtn:SetAttribute("type1", nil)
            kBtn:SetAttribute("macrotext1", nil)
            kBtn:SetAttribute("*type", nil)
            kBtn:SetAttribute("*macrotext", nil)
            kBtn:SetAttribute("type", nil)
            kBtn:SetAttribute("macrotext", nil)
        end
    end

    -- Richte Hover-Bindings ein
    self:SetupSecureHover(frame)
end

-- Richtet die dynamischen Tastatur- und Mausrad-Bindings bei Mausüberfahrung ein
function CC:SetupSecureHover(frame)
    if frame._hoverSetupDone then return end
    frame._hoverSetupDone = true

    -- Hardware-Bindings beim Berühren des Rahmens
    frame:HookScript("OnEnter", function(self)
        if not InCombatLockdown() then
            if self.wheelUpBtn then
                SetOverrideBindingClick(self, true, "MOUSEWHEELUP", self.wheelUpBtn:GetName())
            end
            if self.wheelDownBtn then
                SetOverrideBindingClick(self, true, "MOUSEWHEELDOWN", self.wheelDownBtn:GetName())
            end
            if self.keyBtns then
                for i = 1, 6 do
                    if self.keyBtns[i] then
                        SetOverrideBindingClick(self, true, tostring(i), self.keyBtns[i]:GetName())
                    end
                end
            end
        end
    end)

    frame:HookScript("OnLeave", function(self)
        if not InCombatLockdown() then
            ClearOverrideBindings(self)
        end
    end)
end

function CC:ApplyAllBindings()
    if R4L.GroupHeader and R4L.GroupHeader.frames then
        for _, frame in ipairs(R4L.GroupHeader.frames) do
            self:ApplyBindingsToFrame(frame)
        end
    end
    if R4L.RaidHeader and R4L.RaidHeader.containers then
        for _, container in ipairs(R4L.RaidHeader.containers) do
            if container.frames then
                for _, frame in ipairs(container.frames) do
                    self:ApplyBindingsToFrame(frame)
                end
            end
        end
    end
end

