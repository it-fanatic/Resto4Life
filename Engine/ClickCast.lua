--[[
    Resto4Life - Engine/ClickCast.lua
    Verwaltung von Click-Casting (Mausklicks, Mausrad, Tasten 1-6) und Smart Battle Rez
--]]

local _, R4L = ...

R4L.ClickCast = {}
local CC = R4L.ClickCast

-- Löst Zaubernamen sicher auf (egal ob Spell-ID oder Name als String übergeben wurde)
local function ResolveSpellName(spell)
    if not spell or spell == "" then return nil end
    if type(spell) == "number" then
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spell)
            if info and info.name then return info.name end
        end
        if GetSpellInfo then
            local name = GetSpellInfo(spell)
            if name then return name end
        end
    end
    return tostring(spell)
end
CC.ResolveSpellName = ResolveSpellName

-- Prüft sicher, ob ein Zauber im Zauberbuch des Spielers bekannt ist
local function IsPlayerSpellKnown(spellId)
    if not spellId then return false end
    if type(spellId) == "number" then
        if IsSpellKnown and IsSpellKnown(spellId) then return true end
        if IsPlayerSpell and IsPlayerSpell(spellId) then return true end
        if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellId) then return true end
    end
    local name = ResolveSpellName(spellId)
    if name and name ~= "" then
        if GetSpellInfo then
            local ok, foundName = pcall(GetSpellInfo, name)
            if ok and foundName and foundName ~= "" then
                return true
            end
        end
    end
    return false
end

local function FirstKnownSpellName(spellIdList)
    if not spellIdList then return nil end
    for _, id in ipairs(spellIdList) do
        if IsPlayerSpellKnown(id) then
            local name = ResolveSpellName(id)
            if name and name ~= "" then return name end
        end
    end
    -- Fallback: Ersten auflösbaren Zaubernamen zurückgeben
    for _, id in ipairs(spellIdList) do
        local name = ResolveSpellName(id)
        if name and name ~= "" then return name end
    end
    return nil
end

-- Ermittelt den passenden Reinigungszauber für die Heiler-Klasse & den aktuellen Debuff-Typ (Classic, Forever, WotLK & Retail)
function CC:GetDispelSpell(dispelType)
    local cfg = R4L.ProfileManager:GetConfig()
    local sd = cfg.smartDispel or {}
    if not sd.enabled then return nil end

    -- Falls ein benutzerdefinierter Zauber eingetragen ist (und im Zauberbuch existiert)
    if sd.dispelSpell and sd.dispelSpell ~= "" then
        local custom = sd.dispelSpell
        local numId = tonumber(custom)
        if numId then
            if IsPlayerSpellKnown(numId) then
                return ResolveSpellName(numId)
            end
        else
            local customStr = tostring(custom)
            -- Ignoriere veraltete Retail-Standardnamen, falls der Zauber in Classic/Forever nicht existiert
            if IsPlayerSpellKnown(customStr) then
                return customStr
            end
        end
    end

    local _, engClass = UnitClass("player")
    local cls = engClass or "DRUID"

    if cls == "DRUID" then
        -- Retail: Heilung der Natur (88423) bannt Magie, Fluch & Gift
        if IsPlayerSpellKnown(88423) then
            return ResolveSpellName(88423)
        end
        if dispelType == "Poison" then
            -- Classic / WotLK / Forever: Vergiftung aufheben (2893) oder Vergiftung heilen (8946)
            return FirstKnownSpellName({ 2893, 8946, 2782 })
        elseif dispelType == "Curse" then
            -- Classic / WotLK / Forever: Fluch aufheben (2782)
            return FirstKnownSpellName({ 2782, 2893, 8946 })
        else
            return FirstKnownSpellName({ 2893, 2782, 8946, 88423 })
        end
    elseif cls == "PRIEST" then
        if dispelType == "Disease" then
            -- Classic / WotLK / Forever: Krankheit aufheben (552) oder Krankheit heilen (528) oder Läutern (527)
            return FirstKnownSpellName({ 552, 528, 527 })
        elseif dispelType == "Magic" then
            -- Magiebannung (527 / 988)
            return FirstKnownSpellName({ 527, 988, 552, 528 })
        else
            return FirstKnownSpellName({ 527, 552, 528 })
        end
    elseif cls == "PALADIN" then
        if dispelType == "Poison" or dispelType == "Disease" then
            return FirstKnownSpellName({ 4987, 1152 })
        else
            return FirstKnownSpellName({ 4987, 1152 })
        end
    elseif cls == "SHAMAN" then
        if IsPlayerSpellKnown(77130) then
            return ResolveSpellName(77130)
        end
        if dispelType == "Curse" then
            return FirstKnownSpellName({ 51886, 77130 })
        elseif dispelType == "Disease" then
            return FirstKnownSpellName({ 51886, 2870, 526 })
        elseif dispelType == "Poison" then
            return FirstKnownSpellName({ 51886, 526, 2870 })
        else
            return FirstKnownSpellName({ 51886, 526, 2870, 77130 })
        end
    elseif cls == "MAGE" then
        return FirstKnownSpellName({ 475 })
    elseif cls == "MONK" then
        return FirstKnownSpellName({ 115450, 218164 })
    elseif cls == "EVOKER" then
        return FirstKnownSpellName({ 360823, 374251 })
    end

    return nil
end

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

    local actualSpell = ResolveSpellName(spellName)
    if not actualSpell or actualSpell == "" then
        return nil
    end

    local castLine = ""
    -- Intelligentes Battle-Rez / Normal-Rez bei Linksklick auf tote Gruppenmitglieder
    if smartRez.enabled and isLeftClick then
        local combatRez = ResolveSpellName(smartRez.combatRezSpell)
        local normalRez = ResolveSpellName(smartRez.normalRezSpell)

        local rezParts = {}
        if combatRez and combatRez ~= "" then
            table.insert(rezParts, "[combat,help,dead,@" .. unit .. "] " .. combatRez)
        end
        if normalRez and normalRez ~= "" then
            table.insert(rezParts, "[nocombat,help,dead,@" .. unit .. "] " .. normalRez)
        end

        if #rezParts > 0 then
            castLine = "/cast " .. table.concat(rezParts, "; ") .. "; [@" .. unit .. "] " .. actualSpell
        else
            castLine = "/cast [@" .. unit .. "] " .. actualSpell
        end
    else
        castLine = "/cast [@" .. unit .. "] " .. actualSpell
    end

    if cfg.general and cfg.general.targetOnCast then
        return "/target [@" .. unit .. "]\n" .. castLine
    else
        return castLine
    end
end

-- Smart-Dispel: Außerhalb des Kampfes bei Klick auf debuffte Einheit Zauber dynamisch anpassen
function CC:ApplySmartDispel(frame, debuffColor, debuff)
    if not frame or not frame.unit then return end
    local cfg = R4L.ProfileManager:GetConfig()
    local sd = cfg.smartDispel or {}

    if not sd.enabled then
        if frame._smartDispelApplied then
            frame._smartDispelApplied = nil
            if not InCombatLockdown() then
                self:ApplyBindingsToFrame(frame)
            end
        end
        return
    end

    if InCombatLockdown() then return end

    local isDead = false
    local okDead, deadVal = pcall(UnitIsDead, frame.unit)
    if okDead and deadVal == true then isDead = true end

    local dispelType = (debuff and debuff.dispelType) or R4L.testDebuff or nil
    local dispelSpell = debuffColor and self:GetDispelSpell(dispelType) or nil
    if debuffColor and dispelSpell and dispelSpell ~= "" and not isDead then
        local targetCmd = (cfg.general and cfg.general.targetOnCast) and ("/target [@" .. frame.unit .. "]\n") or ""
        local macro = targetCmd .. "/cast [@" .. frame.unit .. "] " .. dispelSpell
        if frame._smartDispelApplied ~= dispelSpell or frame:GetAttribute("macrotext1") ~= macro then
            frame._smartDispelApplied = dispelSpell
            frame:SetAttribute("*type1", "macro")
            frame:SetAttribute("*macrotext1", macro)
            frame:SetAttribute("type1", "macro")
            frame:SetAttribute("macrotext1", macro)
            frame:SetAttribute("unit1", nil)
            frame:SetAttribute("*unit1", nil)
        end
    elseif frame._smartDispelApplied then
        frame._smartDispelApplied = nil
        self:ApplyBindingsToFrame(frame)
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

    local function HookChildClick(btn)
        if not btn or btn._clickHooked then return end
        btn._clickHooked = true
        btn:HookScript("PreClick", function(self)
            if self._r4lUnit and self._r4lSpell and R4L.AuraTracker and R4L.AuraTracker.OnPlayerClickCast then
                R4L.AuraTracker:OnPlayerClickCast(self._r4lUnit, self._r4lSpell)
            end
        end)
    end

    for _, modTable in pairs(frame.wheelBtns) do
        modTable.UP:SetSize(1, 1)
        modTable.UP:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        modTable.UP:RegisterForClicks("AnyUp", "AnyDown")
        modTable.UP:SetAttribute("checkselfcast", false)
        modTable.UP:SetAttribute("checkfocuscast", false)
        HookChildClick(modTable.UP)
        modTable.DOWN:SetSize(1, 1)
        modTable.DOWN:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        modTable.DOWN:RegisterForClicks("AnyUp", "AnyDown")
        modTable.DOWN:SetAttribute("checkselfcast", false)
        modTable.DOWN:SetAttribute("checkfocuscast", false)
        HookChildClick(modTable.DOWN)
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
        btnNone:SetAttribute("checkselfcast", false)
        btnNone:SetAttribute("checkfocuscast", false)
        HookChildClick(btnNone)
        frame.keyBtns.NONE[i] = btnNone

        local btnCtrl = CreateFrame("Button", name .. "_Key" .. i .. "_Ctrl", frame, "SecureActionButtonTemplate")
        btnCtrl:SetSize(1, 1)
        btnCtrl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        btnCtrl:RegisterForClicks("AnyUp", "AnyDown")
        btnCtrl:SetAttribute("checkselfcast", false)
        btnCtrl:SetAttribute("checkfocuscast", false)
        HookChildClick(btnCtrl)
        frame.keyBtns.CTRL[i] = btnCtrl

        local btnAlt = CreateFrame("Button", name .. "_Key" .. i .. "_Alt", frame, "SecureActionButtonTemplate")
        btnAlt:SetSize(1, 1)
        btnAlt:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        btnAlt:RegisterForClicks("AnyUp", "AnyDown")
        btnAlt:SetAttribute("checkselfcast", false)
        btnAlt:SetAttribute("checkfocuscast", false)
        HookChildClick(btnAlt)
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

    frame._smartDispelApplied = nil
    self:SetupChildButtons(frame)

    local cfg = R4L.ProfileManager:GetConfig()
    local bindings = cfg.bindings or {}
    local unit = frame.unit

    frame:RegisterForClicks("AnyUp", "AnyDown")
    frame:SetAttribute("checkselfcast", false)
    frame:SetAttribute("checkfocuscast", false)

    -- Hilfsfunktion für Child-Buttons (Mausrad & Tasten 1-6)
    local function ConfigureButton(btn, spell)
        if not btn then return end
        btn._r4lUnit = unit
        btn._r4lSpell = (spell and spell ~= "") and ResolveSpellName(spell) or nil
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

    -- Falls aktuell ein Debuff auf dem Frame aktiv ist, Smart-Dispel sofort wieder anwenden
    if cfg.smartDispel and cfg.smartDispel.enabled then
        local debuffColor = nil
        local activeDebuff = nil
        if R4L.testDebuff then
            debuffColor = R4L.AuraTracker and R4L.AuraTracker.DebuffColors[R4L.testDebuff]
            activeDebuff = { dispelType = R4L.testDebuff }
        elseif cfg.auras and cfg.auras.showDebuffs and R4L.AuraTracker and UnitExists(unit) then
            local debuff, color = R4L.AuraTracker:GetDispellableDebuff(unit)
            if debuff and color then
                debuffColor = color
                activeDebuff = debuff
            end
        end
        if debuffColor then
            self:ApplySmartDispel(frame, debuffColor, activeDebuff)
        end
    end
end

-- Richtet die dynamischen Tastatur- und Mausrad-Bindings bei Mausüberfahrung ein
function CC:SetupSecureHover(frame)
    if frame._hoverSetupDone then return end
    frame._hoverSetupDone = true

    -- PreClick Hook für direktes HoT-/Schild-/Heilungs-Tracking (auch im Kampf bei Secret Values)
    frame:HookScript("PreClick", function(self, button)
        if not self.unit or not R4L.AuraTracker or not R4L.AuraTracker.OnPlayerClickCast then return end
        local bId = nil
        if button == "LeftButton" then bId = "1"
        elseif button == "RightButton" then bId = "2"
        elseif button == "MiddleButton" then bId = "3"
        elseif button == "Button4" then bId = "4"
        elseif button == "Button5" then bId = "5"
        end
        if not bId then return end

        local modPrefix = ""
        if IsControlKeyDown and IsControlKeyDown() then
            modPrefix = "CTRL_"
        elseif IsAltKeyDown and IsAltKeyDown() then
            modPrefix = "ALT_"
        end

        -- Falls Smart-Dispel auf Linksklick aktiv ist, wird ein Reinigungszauber und kein HoT gewirkt
        if bId == "1" and modPrefix == "" and self._smartDispelApplied then
            return
        end

        local cfg = R4L.ProfileManager and R4L.ProfileManager:GetConfig()
        if not cfg or not cfg.bindings then return end
        local bConfig = cfg.bindings[modPrefix .. bId]
        if bConfig and bConfig.action == "spell" and bConfig.spell and bConfig.spell ~= "" then
            local resolved = ResolveSpellName(bConfig.spell)
            if resolved and resolved ~= "" then
                R4L.AuraTracker:OnPlayerClickCast(self.unit, resolved)
            end
        end
    end)

    -- Hardware-Bindings beim Berühren des Rahmens
    frame:HookScript("OnEnter", function(self)
        if R4L.AuraTracker then
            R4L.AuraTracker.hoveredUnit = self.unit
        end
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
        if R4L.AuraTracker and R4L.AuraTracker.hoveredUnit == self.unit then
            R4L.AuraTracker.hoveredUnit = nil
        end
        if not InCombatLockdown() then
            ClearOverrideBindings(self)
        end
    end)
end

-- Verhindert oder erlaubt die Blizzard-Selbstzauber-Interferenz bei ALT
function CC:ApplySelfCastPreference()
    local cfg = R4L.ProfileManager:GetConfig()
    local disable = true
    if cfg and cfg.general and cfg.general.disableSelfCastKey ~= nil then
        disable = cfg.general.disableSelfCastKey
    end

    if disable then
        if SetModifiedClick then pcall(SetModifiedClick, "SELFCAST", "NONE") end
        if SetCVar then pcall(SetCVar, "selfCastKey", "NONE") end
    else
        if SetModifiedClick then pcall(SetModifiedClick, "SELFCAST", "ALT") end
        if SetCVar then pcall(SetCVar, "selfCastKey", "ALT") end
    end

    if SaveBindings and GetCurrentBindingSet then
        pcall(function()
            local bSet = GetCurrentBindingSet()
            if bSet then SaveBindings(bSet) end
        end)
    end
end

function CC:ApplyAllBindings()
    self:ApplySelfCastPreference()
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

-- Selbstzauber-Einstellung bei Login und Zonenwechsel sicherstellen
R4L:RegisterEvent("PLAYER_LOGIN", function()
    CC:ApplySelfCastPreference()
end)

R4L:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    CC:ApplySelfCastPreference()
end)

-- Beim Kampfeintritt sicherstellen, dass alle Smart-Dispel Modifikationen zurückgesetzt sind
R4L:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if R4L.GroupHeader and R4L.GroupHeader.frames then
        for _, frame in ipairs(R4L.GroupHeader.frames) do
            if frame._smartDispelApplied then
                frame._smartDispelApplied = nil
                CC:ApplyBindingsToFrame(frame)
            end
        end
    end
    if R4L.RaidHeader and R4L.RaidHeader.containers then
        for _, container in ipairs(R4L.RaidHeader.containers) do
            if container.frames then
                for _, frame in ipairs(container.frames) do
                    if frame._smartDispelApplied then
                        frame._smartDispelApplied = nil
                        CC:ApplyBindingsToFrame(frame)
                    end
                end
            end
        end
    end
end)

