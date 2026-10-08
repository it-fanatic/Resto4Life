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


-- Erstellt dedizierte SecureActionButton-Kinder für Mausrad & Tasten 1-6 (Standard, STRG, ALT)
function CC:SetupChildButtons(frame)
    if frame._childButtonsDone then return end
    frame._childButtonsDone = true

    local name = frame:GetName()
    frame.wheelBtns = {
        NONE = {
            UP = CreateFrame("Button", name .. "_WheelUp", frame, "SecureActionButtonTemplate"),
            DOWN = CreateFrame("Button", name .. "_WheelDown", frame, "SecureActionButtonTemplate"),
        },
        CTRL = {
            UP = CreateFrame("Button", name .. "_WheelUp_Ctrl", frame, "SecureActionButtonTemplate"),
            DOWN = CreateFrame("Button", name .. "_WheelDown_Ctrl", frame, "SecureActionButtonTemplate"),
        },
        ALT = {
            UP = CreateFrame("Button", name .. "_WheelUp_Alt", frame, "SecureActionButtonTemplate"),
            DOWN = CreateFrame("Button", name .. "_WheelDown_Alt", frame, "SecureActionButtonTemplate"),
        },
    }

    for _, modTable in pairs(frame.wheelBtns) do
        modTable.UP:SetSize(1, 1)
        modTable.UP:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        modTable.UP:RegisterForClicks("AnyUp", "AnyDown")
        modTable.DOWN:SetSize(1, 1)
        modTable.DOWN:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        modTable.DOWN:RegisterForClicks("AnyUp", "AnyDown")
    end

    frame.wheelUpBtn = frame.wheelBtns.NONE.UP
    frame.wheelDownBtn = frame.wheelBtns.NONE.DOWN

    frame.keyBtns = {
        NONE = {},
        CTRL = {},
        ALT = {},
    }

    for i = 1, 6 do
        local btnNone = CreateFrame("Button", name .. "_Key" .. i, frame, "SecureActionButtonTemplate")
        btnNone:SetSize(1, 1)
        btnNone:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        btnNone:RegisterForClicks("AnyUp", "AnyDown")
        frame.keyBtns.NONE[i] = btnNone

        local btnCtrl = CreateFrame("Button", name .. "_Key" .. i .. "_Ctrl", frame, "SecureActionButtonTemplate")
        btnCtrl:SetSize(1, 1)
        btnCtrl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        btnCtrl:RegisterForClicks("AnyUp", "AnyDown")
        frame.keyBtns.CTRL[i] = btnCtrl

        local btnAlt = CreateFrame("Button", name .. "_Key" .. i .. "_Alt", frame, "SecureActionButtonTemplate")
        btnAlt:SetSize(1, 1)
        btnAlt:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        btnAlt:RegisterForClicks("AnyUp", "AnyDown")
        frame.keyBtns.ALT[i] = btnAlt
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

    -- Hilfsfunktion für Child-Buttons (Mausrad & Tasten 1-6)
    local function ConfigureButton(btn, spell)
        if not btn then return end
        if spell and spell ~= "" then
            local macro = self:BuildMacroText(unit, "spell", spell, false)
            btn:SetAttribute("*type1", "macro")
            btn:SetAttribute("*macrotext1", macro)
            btn:SetAttribute("type1", "macro")
            btn:SetAttribute("macrotext1", macro)
            btn:SetAttribute("*type", "macro")
            btn:SetAttribute("*macrotext", macro)
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", macro)
        else
            btn:SetAttribute("*type1", nil)
            btn:SetAttribute("*macrotext1", nil)
            btn:SetAttribute("type1", nil)
            btn:SetAttribute("macrotext1", nil)
            btn:SetAttribute("*type", nil)
            btn:SetAttribute("*macrotext", nil)
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
        end
    end

    -- 1. Maustasten 1 bis 5 (Standard, STRG, ALT) direkt auf dem Hauptframe
    local mouseButtons = { "1", "2", "3", "4", "5" }
    local modifiers = {
        { prefix = "",      cfgPrefix = "",     isMod = false },
        { prefix = "ctrl-", cfgPrefix = "CTRL_", isMod = true },
        { prefix = "alt-",  cfgPrefix = "ALT_",  isMod = true },
    }

    for _, bId in ipairs(mouseButtons) do
        for _, mod in ipairs(modifiers) do
            local cfgKey = mod.cfgPrefix .. bId
            local bConfig = bindings[cfgKey]
            local attrType = mod.prefix .. "type" .. bId
            local attrMacro = mod.prefix .. "macrotext" .. bId
            local attrUnit = mod.prefix .. "unit" .. bId

            if bConfig then
                if bConfig.action == "target" then
                    frame:SetAttribute(attrType, "target")
                    frame:SetAttribute(attrUnit, unit)
                    frame:SetAttribute(attrMacro, nil)
                elseif bConfig.action == "menu" then
                    frame:SetAttribute(attrType, "togglemenu")
                    frame:SetAttribute(attrUnit, unit)
                    frame:SetAttribute(attrMacro, nil)
                elseif bConfig.action == "spell" and bConfig.spell and bConfig.spell ~= "" then
                    local isSmartRez = (bId == "1" and not mod.isMod)
                    local macro = self:BuildMacroText(unit, "spell", bConfig.spell, isSmartRez)
                    frame:SetAttribute(attrType, "macro")
                    frame:SetAttribute(attrMacro, macro)
                    frame:SetAttribute(attrUnit, nil)
                else
                    frame:SetAttribute(attrType, nil)
                    frame:SetAttribute(attrMacro, nil)
                    frame:SetAttribute(attrUnit, nil)
                end
            else
                frame:SetAttribute(attrType, nil)
                frame:SetAttribute(attrMacro, nil)
                frame:SetAttribute(attrUnit, nil)
            end
        end

        -- Für Standard ohne Modifikator auch Wildcard *type als sicheren Fallback setzen
        local stdConfig = bindings[bId]
        if stdConfig then
            if stdConfig.action == "target" then
                frame:SetAttribute("*type" .. bId, "target")
                frame:SetAttribute("*unit" .. bId, unit)
                frame:SetAttribute("*macrotext" .. bId, nil)
            elseif stdConfig.action == "menu" then
                frame:SetAttribute("*type" .. bId, "togglemenu")
                frame:SetAttribute("*unit" .. bId, unit)
                frame:SetAttribute("*macrotext" .. bId, nil)
            elseif stdConfig.action == "spell" and stdConfig.spell and stdConfig.spell ~= "" then
                local macro = self:BuildMacroText(unit, "spell", stdConfig.spell, (bId == "1"))
                frame:SetAttribute("*type" .. bId, "macro")
                frame:SetAttribute("*macrotext" .. bId, macro)
                frame:SetAttribute("*unit" .. bId, nil)
            else
                frame:SetAttribute("*type" .. bId, nil)
                frame:SetAttribute("*macrotext" .. bId, nil)
                frame:SetAttribute("*unit" .. bId, nil)
            end
        else
            frame:SetAttribute("*type" .. bId, nil)
            frame:SetAttribute("*macrotext" .. bId, nil)
            frame:SetAttribute("*unit" .. bId, nil)
        end
    end

    -- 2. Mausrad (WheelUp, WheelDown) auf Child-Buttons (Standard, STRG, ALT)
    if frame.wheelBtns then
        ConfigureButton(frame.wheelBtns.NONE.UP, bindings["WheelUp"] and bindings["WheelUp"].spell)
        ConfigureButton(frame.wheelBtns.NONE.DOWN, bindings["WheelDown"] and bindings["WheelDown"].spell)

        ConfigureButton(frame.wheelBtns.CTRL.UP, bindings["CTRL_WheelUp"] and bindings["CTRL_WheelUp"].spell)
        ConfigureButton(frame.wheelBtns.CTRL.DOWN, bindings["CTRL_WheelDown"] and bindings["CTRL_WheelDown"].spell)

        ConfigureButton(frame.wheelBtns.ALT.UP, bindings["ALT_WheelUp"] and bindings["ALT_WheelUp"].spell)
        ConfigureButton(frame.wheelBtns.ALT.DOWN, bindings["ALT_WheelDown"] and bindings["ALT_WheelDown"].spell)
    end

    -- 3. Tasten 1 bis 6 auf Child-Buttons (Standard, STRG, ALT)
    if frame.keyBtns then
        for i = 1, 6 do
            ConfigureButton(frame.keyBtns.NONE[i], bindings["KEY_" .. i] and bindings["KEY_" .. i].spell)
            ConfigureButton(frame.keyBtns.CTRL[i], bindings["CTRL_KEY_" .. i] and bindings["CTRL_KEY_" .. i].spell)
            ConfigureButton(frame.keyBtns.ALT[i], bindings["ALT_KEY_" .. i] and bindings["ALT_KEY_" .. i].spell)
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
            -- Mausrad (Standard, STRG, ALT)
            if self.wheelBtns then
                SetOverrideBindingClick(self, true, "MOUSEWHEELUP", self.wheelBtns.NONE.UP:GetName())
                SetOverrideBindingClick(self, true, "MOUSEWHEELDOWN", self.wheelBtns.NONE.DOWN:GetName())

                SetOverrideBindingClick(self, true, "CTRL-MOUSEWHEELUP", self.wheelBtns.CTRL.UP:GetName())
                SetOverrideBindingClick(self, true, "CTRL-MOUSEWHEELDOWN", self.wheelBtns.CTRL.DOWN:GetName())

                SetOverrideBindingClick(self, true, "ALT-MOUSEWHEELUP", self.wheelBtns.ALT.UP:GetName())
                SetOverrideBindingClick(self, true, "ALT-MOUSEWHEELDOWN", self.wheelBtns.ALT.DOWN:GetName())
            end

            -- Tasten 1 bis 6 (Standard, STRG, ALT)
            if self.keyBtns then
                for i = 1, 6 do
                    if self.keyBtns.NONE[i] then
                        SetOverrideBindingClick(self, true, tostring(i), self.keyBtns.NONE[i]:GetName())
                    end
                    if self.keyBtns.CTRL[i] then
                        SetOverrideBindingClick(self, true, "CTRL-" .. i, self.keyBtns.CTRL[i]:GetName())
                    end
                    if self.keyBtns.ALT[i] then
                        SetOverrideBindingClick(self, true, "ALT-" .. i, self.keyBtns.ALT[i]:GetName())
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

