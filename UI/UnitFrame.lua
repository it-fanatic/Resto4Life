--[[
    Resto4Life - UI/UnitFrame.lua
    Sichere Unit-Frame Komponente mit Health-Bar (Normal/Reverse), Mana-Bar,
    Klassen-/Minimalfarben, HoTs und Debuff-Hervorhebung
--]]

local _, R4L = ...

R4L.UnitFrame = {}
local UF = R4L.UnitFrame

-- Helper zur Erkennung von geheimen Werten in WoW Forever & 12.0
local function IsSecret(val)
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res then return true end
    end
    local okNil, isN = pcall(function() return val == nil end)
    if okNil and isN then return false end
    if R4L.IsSecret then
        local okR, resR = pcall(R4L.IsSecret, val)
        if okR and resR then return true end
    end
    local okTest = pcall(function()
        if val == true or val == false then return true end
        local _ = tostring(val)
        return true
    end)
    if not okTest then return true end
    return false
end

-- Klassenfarben-Fallback (unterstützt englische & deutsche Klassentoken)
local FALLBACK_CLASS_COLORS = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["KRIEGER"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["JÄGER"]       = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["SCHURKE"]     = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["PRIESTER"]    = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["TODESRITTER"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["SCHAMANE"]    = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.25, g = 0.78, b = 0.92 },
    ["MAGIER"]      = { r = 0.25, g = 0.78, b = 0.92 },
    ["WARLOCK"]     = { r = 0.53, g = 0.53, b = 0.93 },
    ["HEXENMEISTER"]= { r = 0.53, g = 0.53, b = 0.93 },
    ["MONK"]        = { r = 0.00, g = 1.00, b = 0.59 },
    ["MÖNCH"]       = { r = 0.00, g = 1.00, b = 0.59 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
    ["DRUIDE"]      = { r = 1.00, g = 0.49, b = 0.04 },
    ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79 },
    ["DÄMONENJÄGER"]= { r = 0.64, g = 0.19, b = 0.79 },
    ["EVOKER"]      = { r = 0.20, g = 0.58, b = 0.50 },
    ["RUFER"]       = { r = 0.20, g = 0.58, b = 0.50 },
}

-- Ermittelt Klassenfarben zuverlässig für Retail & Classic
local function GetClassColorRGB(class)
    if not class then return 0.7, 0.7, 0.7 end
    local upperClass = string.upper(tostring(class))
    if C_ClassColor and C_ClassColor.GetClassColor then
        local ok, c = pcall(C_ClassColor.GetClassColor, upperClass)
        if ok and c and c.r then return c.r, c.g, c.b end
    end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[upperClass] then
        local c = RAID_CLASS_COLORS[upperClass]
        return c.r, c.g, c.b
    end
    if FALLBACK_CLASS_COLORS[upperClass] then
        local c = FALLBACK_CLASS_COLORS[upperClass]
        return c.r, c.g, c.b
    end
    return 0.7, 0.7, 0.7
end

UF._lastKnownPowerType = UF._lastKnownPowerType or {}

-- Erkennt Druiden-Gestalt (Bär = 1 Wut, Katze = 3 Energie) und Ressourcentyp sicher für Spieler & Gruppe
local function DetectUnitPowerType(unit, class)
    local upperClass = class and string.upper(tostring(class)) or ""

    -- 1. Für Druiden: Prüfe aktiv Bärengestalt (Icon 132276 / Spell 5487, 9634) & Katzengestalt (Icon 132115 / Spell 768)
    if upperClass == "DRUID" or upperClass == "DRUIDE" then
        local formPower = nil
        local function CheckDruidAuraTable(a)
            if type(a) ~= "table" then return false end
            local okCheck, matched = pcall(function()
                local ic = (not IsSecret(a.icon) and a.icon) or (not IsSecret(a.iconFileID) and a.iconFileID) or nil
                if ic then
                    if ic == 132276 or (type(ic) == "string" and ic:lower():find("bearform", 1, true)) then
                        formPower = 1
                        return true
                    elseif ic == 132115 or (type(ic) == "string" and ic:lower():find("catform", 1, true)) then
                        formPower = 3
                        return true
                    end
                end
                local sp = not IsSecret(a.spellId) and a.spellId or nil
                if sp and type(sp) == "number" then
                    if sp == 5487 or sp == 9634 then
                        formPower = 1
                        return true
                    elseif sp == 768 then
                        formPower = 3
                        return true
                    end
                end
                local nm = not IsSecret(a.name) and a.name or nil
                if nm and type(nm) == "string" then
                    local lower = nm:lower()
                    if lower:find("bärengestalt", 1, true) or lower:find("bear form", 1, true) then
                        formPower = 1
                        return true
                    elseif lower:find("katzengestalt", 1, true) or lower:find("cat form", 1, true) then
                        formPower = 3
                        return true
                    end
                end
                return false
            end)
            return okCheck and matched == true
        end

        if C_UnitAuras and C_UnitAuras.GetUnitAuras then
            local okA, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL", 40, 0, 0)
            if not okA or not auras or type(auras) ~= "table" then
                okA, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
            end
            if okA and auras and type(auras) == "table" then
                for _, a in pairs(auras) do
                    if CheckDruidAuraTable(a) then
                        break
                    end
                end
            end
        end
        if not formPower and R4L.AuraTracker and R4L.AuraTracker.GetUnitAuraByIndex then
            for i = 1, 40 do
                local a = R4L.AuraTracker:GetUnitAuraByIndex(unit, i, "HELPFUL")
                if not a then break end
                if CheckDruidAuraTable(a) then break end
            end
        end
        if formPower then
            UF._lastKnownPowerType[unit] = formPower
            return formPower
        end
    end

    -- 2. Sichere Auswertung von UnitPowerType (fängt Secret Values in pcall ab)
    if UnitPowerType then
        local okPT, resolved = pcall(function()
            local pType, pToken = UnitPowerType(unit)
            if pType == 1 or pToken == "RAGE" then return 1
            elseif pType == 3 or pToken == "ENERGY" then return 3
            elseif pType == 2 or pToken == "FOCUS" then return 2
            elseif pType == 6 or pToken == "RUNIC_POWER" then return 6
            elseif pType == 8 or pToken == "LUNAR_POWER" or pToken == "ASTRAL_POWER" then return 8
            elseif pType == 13 or pToken == "INSANITY" then return 13
            elseif pType == 17 or pToken == "FURY" then return 17
            elseif pType == 0 or pToken == "MANA" then return 0
            end
            return nil
        end)
        if okPT and type(resolved) == "number" then
            -- Falls Druide im Kampf und zuvor Bärengestalt (1) oder Katzengestalt (3) aktiv war, nicht blind durch Mana-Fallback überschreiben, wenn Auren geheim sind
            if (upperClass == "DRUID" or upperClass == "DRUIDE") and resolved == 0 and InCombatLockdown and InCombatLockdown() and UF._lastKnownPowerType[unit] and UF._lastKnownPowerType[unit] > 0 then
                return UF._lastKnownPowerType[unit]
            end
            UF._lastKnownPowerType[unit] = resolved
            return resolved
        end
    end

    -- 2b. Letzter bekannter PowerType im Kampf (wenn UnitPowerType & Auren Secret Values liefern)
    if UF._lastKnownPowerType[unit] ~= nil then
        return UF._lastKnownPowerType[unit]
    end

    -- 3. Klassen-Fallback falls UnitPowerType einen Secret Value lieferte
    if upperClass == "WARRIOR" or upperClass == "KRIEGER" then
        return 1 -- Wut
    elseif upperClass == "ROGUE" or upperClass == "SCHURKE" then
        return 3 -- Energie
    elseif upperClass == "DEATHKNIGHT" or upperClass == "TODESRITTER" then
        return 6 -- Runenmacht
    end
    return 0 -- Mana
end

-- Ermittelt Ressourcen-/Power-Farben 100% frei von Secret-Value-Indizierungsfehlern
local function GetPowerColorRGB(unit, explicitType)
    local pType = (type(explicitType) == "number" and not IsSecret(explicitType)) and explicitType or 0
    if pType == 1 then
        return 1.0, 0.2, 0.2       -- Rage / Wut (Rot)
    elseif pType == 2 then
        return 1.0, 0.5, 0.25      -- Focus (Orange)
    elseif pType == 3 then
        return 1.0, 1.0, 0.2       -- Energy / Energie (Gelb)
    elseif pType == 6 then
        return 0.0, 0.82, 1.0      -- Runic Power (Cyan)
    elseif pType == 8 then
        return 0.3, 0.52, 0.9      -- Astral Power (Druide Eule)
    elseif pType == 13 then
        return 0.4, 0.0, 0.8       -- Insanity (Shadow Priest)
    elseif pType == 17 then
        return 0.79, 0.26, 0.99    -- Fury (Demon Hunter)
    end
    return 0.0, 0.5, 1.0           -- Mana (Blau)
end

-- Zahl formatieren (z. B. 15.4k oder 2.1M)
local function FormatNumber(val)
    if not val then return "" end
    local ok, formatted = pcall(function()
        if type(val) ~= "number" then return tostring(val) end
        if val >= 1000000 then
            return string.format("%.1fM", val / 1000000)
        elseif val >= 1000 then
            return string.format("%.1fk", val / 1000)
        else
            return tostring(math.floor(val))
        end
    end)
    return ok and formatted or tostring(val)
end

-- Sichere Berechnung des Lebensanzeige-Texts (verhindert Secret-Value Fehler in WoW 12.0)
local function SafeGetHealthText(unit, hp, hpMax, format)
    local ok, def = pcall(function() return hpMax - hp end)
    if ok and type(def) == "number" then
        if format == "DEFICIT" then
            if def > 0 then
                return "|cffff5555-" .. FormatNumber(def) .. "|r"
            else
                return ""
            end
        elseif format == "PERCENT" then
            local okP, pct = pcall(function() return math.floor((hp / (hpMax > 0 and hpMax or 1)) * 100) end)
            if okP and type(pct) == "number" then
                return pct .. "%"
            end
        else
            return FormatNumber(hp)
        end
    end

    -- WoW 12.0 Retail Fallback für geschützte / geheime Combat-Werte
    if UnitHealthPercent then
        local okP, txt = pcall(function()
            local p = UnitHealthPercent(unit)
            if issecretvalue and issecretvalue(p) then
                return ""
            end
            if type(p) == "number" then
                return math.floor(p * 100) .. "%"
            end
            return ""
        end)
        if okP and txt and txt ~= "" then
            return txt
        end
    end

    return ""
end

-- Registriert Unit-Events gezielt für die zugewiesene Einheit (sicher für Retail & Classic)
function UF:RegisterUnitEvents(frame, unit)
    frame:UnregisterAllEvents()
    if not unit or not UnitExists(unit) then return end

    local function SafeRegister(event, u)
        if frame.RegisterUnitEvent then
            local ok = pcall(frame.RegisterUnitEvent, frame, event, u)
            if not ok then
                pcall(frame.RegisterEvent, frame, event)
            end
        else
            pcall(frame.RegisterEvent, frame, event)
        end
    end

    SafeRegister("UNIT_HEALTH", unit)
    SafeRegister("UNIT_MAXHEALTH", unit)
    SafeRegister("UNIT_POWER_UPDATE", unit)
    SafeRegister("UNIT_POWER_FREQUENT", unit)
    SafeRegister("UNIT_MAXPOWER", unit)
    SafeRegister("UNIT_DISPLAYPOWER", unit)
    SafeRegister("UNIT_AURA", unit)
    SafeRegister("UNIT_CONNECTION", unit)
    SafeRegister("UNIT_THREAT_SITUATION_UPDATE", unit)
    SafeRegister("UNIT_THREAT_LIST_UPDATE", unit)
    SafeRegister("UNIT_HEAL_PREDICTION", unit)
    SafeRegister("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    SafeRegister("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit)
    pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
    pcall(frame.RegisterEvent, frame, "PLAYER_ROLES_ASSIGNED")
    pcall(frame.RegisterEvent, frame, "PLAYER_SPECIALIZATION_CHANGED")
    pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
    pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORM")
    pcall(frame.RegisterEvent, frame, "UPDATE_SHAPESHIFT_FORMS")
end

-- Aktualisiert das Rollen-Icon (Tank, Heiler, DD) nach Blizzard-Standard
local function UpdateRoleIcon(frame, role)
    if not frame or not frame.roleIcon then return end
    local cfg = R4L.ProfileManager:GetConfig()
    if cfg.display and cfg.display.showRoleIcons == false then
        frame.roleIcon:Hide()
        return
    end

    if role == "DPS" then role = "DAMAGER" end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        local coords
        if GetTexCoordsForRoleSmallCircle then
            local ok, c1, c2, c3, c4 = pcall(GetTexCoordsForRoleSmallCircle, role)
            if ok and c1 and c2 and c3 and c4 then
                coords = { c1, c2, c3, c4 }
            end
        end

        if coords then
            frame.roleIcon:SetTexCoord(unpack(coords))
        else
            -- Exakte Koordinaten auf 64x64 UI-LFG-ICON-PORTRAITROLES ohne Rand-Überlappung
            if role == "TANK" then
                frame.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
            elseif role == "HEALER" then
                frame.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
            elseif role == "DAMAGER" then
                frame.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
            end
        end
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end
end

-- Sichere Prozentanzeige für Mana
local function SafeGetPowerText(power, powerMax)
    local ok, txt = pcall(function()
        if type(power) ~= "number" or type(powerMax) ~= "number" then return "" end
        if powerMax <= 0 then return "" end
        if power >= powerMax then return "" end
        local pct = math.floor((power / powerMax) * 100)
        return pct .. "%"
    end)
    return ok and txt or ""
end

-- Erstellt einen einzelnen Frame
function UF:CreateUnitFrame(name, parent, unit)
    local frame = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    frame.unit = unit
    frame:SetAttribute("checkselfcast", false)
    frame:SetAttribute("checkfocuscast", false)

    local cfg = R4L.ProfileManager:GetConfig()
    frame:SetSize(cfg.general.frameWidth, cfg.general.frameHeight)

    -- Äußerer Rahmen / Debuff-Border
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetAllPoints(frame)
    frame.border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
    frame.border:SetFrameLevel(frame:GetFrameLevel() + 6)

    -- Dunkler Hintergrund für den gesamten Rahmen
    frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0.04, 0.04, 0.04, 0.95)

    -- Mana / Power Bar (unten)
    frame.powerBar = CreateFrame("StatusBar", nil, frame)
    frame.powerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.powerBar:SetHeight(cfg.general.powerBarHeight or 10)
    frame.powerBar:SetStatusBarTexture("Interface\\AddOns\\Resto4Life\\Media\\statusbar.tga")
    frame.powerBar:SetStatusBarColor(0.0, 0.5, 1.0, 0.95)
    frame.powerBar:SetMinMaxValues(0, 100)
    frame.powerBar:SetValue(100)
    frame.powerBar:SetFrameLevel(frame:GetFrameLevel() + 5)

    frame.powerBar.bg = frame.powerBar:CreateTexture(nil, "BACKGROUND", nil, -5)
    frame.powerBar.bg:SetAllPoints(frame.powerBar)
    frame.powerBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)

    -- Mana / Power Text (Immer sichtbar mit Outline)
    frame.powerText = frame.powerBar:CreateFontString(nil, "OVERLAY")
    if not frame.powerText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE") then
        frame.powerText:SetFontObject("GameFontHighlightSmall")
    end
    frame.powerText:SetPoint("CENTER", frame.powerBar, "CENTER", 0, 0)
    frame.powerText:SetTextColor(1, 1, 1, 1)

    -- Health Bar (oben)
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    local pHeight = cfg.display.showManaBar and ((cfg.general.powerBarHeight or 10) + 2) or 1
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, pHeight)
    frame.healthBar:SetStatusBarTexture("Interface\\AddOns\\Resto4Life\\Media\\statusbar.tga")
    frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 0.95)
    frame.healthBar:SetMinMaxValues(0, 100)
    frame.healthBar:SetValue(100)
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel() + 4)
    pcall(frame.healthBar.SetClipsChildren, frame.healthBar, true)

    -- Hintergrund hinter der Healthbar (Defizit-Bereich bei erlittenem Schaden)
    frame.healthBar.bg = frame.healthBar:CreateTexture(nil, "BACKGROUND", nil, -5)
    frame.healthBar.bg:SetAllPoints(frame.healthBar)
    frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95)

    local healthTex = frame.healthBar:GetStatusBarTexture() or frame.healthBar

    -- Heal Prediction Bar (heftet sich an das rechte Ende des aktuellen Lebensbalkens)
    frame.healPredictBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.healPredictBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
    frame.healPredictBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
    frame.healPredictBar:SetWidth(24)
    frame.healPredictBar:SetStatusBarTexture("Interface\\AddOns\\Resto4Life\\Media\\statusbar.tga")
    frame.healPredictBar:SetStatusBarColor(0.05, 0.92, 0.52, 0.75) -- Frisches Mint-Grün
    frame.healPredictBar:SetMinMaxValues(0, 100)
    frame.healPredictBar:SetValue(100)
    frame.healPredictBar:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.healPredictBar:Hide()

    -- Absorb / Shield Bar (heftet sich an das rechte Ende des aktuellen Lebensbalkens und wandert beim Heilen nach rechts)
    frame.absorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.absorbBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
    frame.absorbBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
    frame.absorbBar:SetWidth(22)
    frame.absorbBar:SetStatusBarTexture("Interface\\AddOns\\Resto4Life\\Media\\statusbar.tga")
    frame.absorbBar:SetStatusBarColor(0.20, 0.78, 1.0, 0.78) -- Schild-Cyan
    frame.absorbBar:SetMinMaxValues(0, 100)
    frame.absorbBar:SetValue(100)
    frame.absorbBar:SetFrameLevel(frame:GetFrameLevel() + 5)
    frame.absorbBar:Hide()

    -- Text- & Icon-Overlay über den StatusBars (Level + 7)
    frame.textOverlay = CreateFrame("Frame", nil, frame)
    frame.textOverlay:SetAllPoints(frame.healthBar)
    frame.textOverlay:SetFrameLevel(frame:GetFrameLevel() + 7)

    -- Schild-Kantenleuchten am rechten Ende des Schild-Balkens
    frame.overAbsorbGlow = frame.absorbBar:CreateTexture(nil, "OVERLAY", nil, 6)
    frame.overAbsorbGlow:SetPoint("TOPRIGHT", frame.absorbBar, "TOPRIGHT", 0, 0)
    frame.overAbsorbGlow:SetPoint("BOTTOMRIGHT", frame.absorbBar, "BOTTOMRIGHT", 0, 0)
    frame.overAbsorbGlow:SetWidth(3)
    frame.overAbsorbGlow:SetColorTexture(0.45, 0.92, 1.0, 0.98)
    frame.overAbsorbGlow:Hide()

    -- Spielername Text (mittig auf dem Lebensbalken)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY")
    if not frame.nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", cfg.display.nameFontSize or 11, "OUTLINE") then
        frame.nameText:SetFontObject("GameFontHighlightSmall")
    end
    frame.nameText:SetPoint("CENTER", frame.healthBar, "CENTER", 0, -7)
    frame.nameText:SetJustifyH("CENTER")

    -- Status / Lebenspunkte Text
    frame.statusText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusText:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", -4, 4)
    frame.statusText:SetJustifyH("RIGHT")

    -- Rollen-Icon (Tank, Heiler, DD) mittig links auf gleicher Höhe wie der Name
    frame.roleIcon = frame.textOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.roleIcon:SetSize(13, 13)
    frame.roleIcon:SetPoint("LEFT", frame.healthBar, "LEFT", 4, -7)
    frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    frame.roleIcon:SetHorizTile(false)
    frame.roleIcon:SetVertTile(false)
    frame.roleIcon:Hide()

    -- Fremde HoT Icons Container (oben links - bündig am oberen Rand)
    frame.otherHotContainer = CreateFrame("Frame", nil, frame)
    frame.otherHotContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.otherHotContainer:SetSize(60, 16)
    frame.otherHotContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.otherHotContainer:Show()

    frame.otherHotIcons = {}
    for i = 1, 3 do
        local hotIcon = CreateFrame("Frame", nil, frame.otherHotContainer, "BackdropTemplate")
        hotIcon:SetSize(16, 16)
        hotIcon:SetPoint("TOPLEFT", frame.otherHotContainer, "TOPLEFT", ((i - 1) * 17), 0)
        hotIcon:SetFrameLevel(frame.otherHotContainer:GetFrameLevel() + 2)
        hotIcon:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        hotIcon:SetBackdropColor(0, 0, 0, 0.6)
        hotIcon:SetBackdropBorderColor(0, 0, 0, 1)

        hotIcon.tex = hotIcon:CreateTexture(nil, "ARTWORK")
        hotIcon.tex:SetPoint("TOPLEFT", hotIcon, "TOPLEFT", 1, -1)
        hotIcon.tex:SetPoint("BOTTOMRIGHT", hotIcon, "BOTTOMRIGHT", -1, 1)
        hotIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        hotIcon.cdText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.cdText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE") then
            hotIcon.cdText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.cdText:SetPoint("CENTER", hotIcon, "CENTER", 0, 0)
        hotIcon.cdText:SetTextColor(1, 1, 1, 1)

        hotIcon.countText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE") then
            hotIcon.countText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.countText:SetPoint("BOTTOMRIGHT", hotIcon, "BOTTOMRIGHT", 1, -1)
        hotIcon.countText:SetTextColor(1, 1, 0, 1)

        hotIcon:Hide()
        frame.otherHotIcons[i] = hotIcon
    end

    -- Eigene HoT Icons Container (oben rechts - bündig am oberen Rand)
    frame.hotContainer = CreateFrame("Frame", nil, frame)
    frame.hotContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.hotContainer:SetSize(76, 16)
    frame.hotContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.hotContainer:Show()

    frame.hotIcons = {}
    for i = 1, 4 do
        local hotIcon = CreateFrame("Frame", nil, frame.hotContainer, "BackdropTemplate")
        hotIcon:SetSize(16, 16)
        hotIcon:SetPoint("TOPRIGHT", frame.hotContainer, "TOPRIGHT", -((i - 1) * 17), 0)
        hotIcon:SetFrameLevel(frame.hotContainer:GetFrameLevel() + 2)
        hotIcon:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        hotIcon:SetBackdropColor(0, 0, 0, 0.8)
        hotIcon:SetBackdropBorderColor(0, 0, 0, 1)

        hotIcon.tex = hotIcon:CreateTexture(nil, "ARTWORK")
        hotIcon.tex:SetPoint("TOPLEFT", hotIcon, "TOPLEFT", 1, -1)
        hotIcon.tex:SetPoint("BOTTOMRIGHT", hotIcon, "BOTTOMRIGHT", -1, 1)
        hotIcon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        hotIcon.cdText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.cdText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE") then
            hotIcon.cdText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.cdText:SetPoint("CENTER", hotIcon, "CENTER", 0, 0)
        hotIcon.cdText:SetTextColor(1, 1, 1, 1)

        hotIcon.countText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE") then
            hotIcon.countText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.countText:SetPoint("BOTTOMRIGHT", hotIcon, "BOTTOMRIGHT", 1, -1)
        hotIcon.countText:SetTextColor(1, 1, 0, 1)

        hotIcon:Hide()
        frame.hotIcons[i] = hotIcon
    end

    -- Initialisiere Child-Buttons für Mausrad & Tastenbelegungen
    R4L.ClickCast:SetupChildButtons(frame)

    -- Event-Handler für verzögerungsfreie Werteaktualisierung
    frame:SetScript("OnEvent", function(self, event, unit)
        UF:UpdateFrame(self)
    end)

    -- Update-Ticker für Auren-Restzeiten und Reichweiten-Prüfung
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
        if self.timeSinceLastUpdate > 0.05 then
            UF:UpdateFrame(self)
            self.timeSinceLastUpdate = 0
        end
    end)

    return frame
end

-- Aktualisiert Aussehen und Werte eines Frames (gesichert vor Lua-Fehlern)
function UF:UpdateFrame(frame)
    if frame.isSimulated then
        local ok, err = pcall(self._UpdateFrameSimulated, self, frame)
        if not ok and err then
            print("|cffff5555[Resto4Life Fehler in UpdateFrameSim]:|r " .. tostring(err))
        end
        return
    end

    local ok, err = pcall(self._UpdateFrameInternal, self, frame)
    if not ok and err then
        if not self._lastErr or self._lastErr ~= err then
            self._lastErr = err
            print("|cffff5555[Resto4Life Fehler in UpdateFrame]:|r " .. tostring(err))
        end
    end
end

function UF:_UpdateFrameSimulated(frame)
    local sim = frame.simData
    if not sim then return end

    local cfg = R4L.ProfileManager:GetConfig()
    frame:SetAlpha(1)

    -- 1. Name
    if cfg.display.showNames then
        frame.nameText:Show()
        frame.nameText:SetText(sim.name)
    else
        frame.nameText:Hide()
    end

    -- 2. Lebensbalken & Farbe
    local r, g, b
    if cfg.display.colorMode == "MINIMAL" then
        if sim.hp > 50 then
            local factor = (sim.hp - 50) / 50
            r = 0.15 + (1 - factor) * 0.80
            g = 0.85
            b = 0.25 * factor
        else
            local factor = sim.hp / 50
            r = 0.95
            g = 0.15 + factor * 0.70
            b = 0.05
        end
    else
        r, g, b = GetClassColorRGB(sim.class)
    end

    local isReverse = (cfg.display.healthOrientation == "REVERSE")
    if not isReverse then
        frame.healthBar:SetMinMaxValues(0, 100)
        frame.healthBar:SetValue(sim.hp)
        frame.healthBar:SetStatusBarColor(r, g, b, 0.95)
        if cfg.display.colorMode == "MINIMAL" then
            frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95)
        else
            frame.healthBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)
        end

        local simHeal = sim.incomingHeal or 0
        local simAbsorb = sim.absorbs or 0
        local barW = frame.healthBar:GetWidth() or 110
        local healthTex = frame.healthBar:GetStatusBarTexture() or frame.healthBar
        local curPx = (sim.hp / 100) * barW
        local offsetX = math.min(0, math.floor(barW - curPx - 6))

        if simHeal > 0 and cfg.display.showHealPrediction ~= false and frame.healPredictBar then
            frame.healPredictBar:ClearAllPoints()
            frame.healPredictBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", offsetX, 0)
            frame.healPredictBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", offsetX, 0)
            frame.healPredictBar:SetWidth(math.max(16, math.floor(barW * 0.24)))
            frame.healPredictBar:SetMinMaxValues(0, 100)
            frame.healPredictBar:SetValue(100)
            frame.healPredictBar:Show()
        elseif frame.healPredictBar then
            frame.healPredictBar:Hide()
        end

        if simAbsorb > 0 and cfg.display.showAbsorbs ~= false and frame.absorbBar then
            frame.absorbBar:ClearAllPoints()
            frame.absorbBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", offsetX, 0)
            frame.absorbBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", offsetX, 0)
            frame.absorbBar:SetWidth(math.max(15, math.floor(barW * 0.22)))
            frame.absorbBar:SetMinMaxValues(0, 100)
            frame.absorbBar:SetValue(100)
            frame.absorbBar:Show()
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Show() end
        else
            if frame.absorbBar then frame.absorbBar:Hide() end
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
        end
    else
        local deficit = 100 - sim.hp
        frame.healthBar:SetMinMaxValues(0, 100)
        frame.healthBar:SetValue(deficit)
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.95)
        frame.healthBar.bg:SetColorTexture(r * 0.85, g * 0.85, b * 0.85, 0.90)

        local simHeal = sim.incomingHeal or 0
        local simAbsorb = sim.absorbs or 0
        local barW = frame.healthBar:GetWidth() or 110
        local healthTex = frame.healthBar:GetStatusBarTexture() or frame.healthBar
        local curPx = (deficit / 100) * barW
        local offsetX = math.min(0, math.floor(barW - curPx - 6))

        if simHeal > 0 and cfg.display.showHealPrediction ~= false and frame.healPredictBar then
            frame.healPredictBar:ClearAllPoints()
            frame.healPredictBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", offsetX, 0)
            frame.healPredictBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", offsetX, 0)
            frame.healPredictBar:SetWidth(math.max(16, math.floor(barW * 0.24)))
            frame.healPredictBar:SetMinMaxValues(0, 100)
            frame.healPredictBar:SetValue(100)
            frame.healPredictBar:Show()
        elseif frame.healPredictBar then
            frame.healPredictBar:Hide()
        end

        if simAbsorb > 0 and cfg.display.showAbsorbs ~= false and frame.absorbBar then
            frame.absorbBar:ClearAllPoints()
            frame.absorbBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", offsetX, 0)
            frame.absorbBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", offsetX, 0)
            frame.absorbBar:SetWidth(math.max(15, math.floor(barW * 0.22)))
            frame.absorbBar:SetMinMaxValues(0, 100)
            frame.absorbBar:SetValue(100)
            frame.absorbBar:Show()
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Show() end
        else
            if frame.absorbBar then frame.absorbBar:Hide() end
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
        end
    end

    -- 3. Statustext
    if sim.hp < 100 then
        frame.statusText:SetText("|cffff5555-" .. (100 - sim.hp) .. "%|r")
    else
        frame.statusText:SetText("")
    end

    -- 4. Manabalken
    if cfg.display.showManaBar then
        frame.powerBar:Show()
        frame.powerText:Show()
        frame.powerBar:SetMinMaxValues(0, 100)
        frame.powerBar:SetValue(sim.power)
        frame.powerBar:SetStatusBarColor(sim.pr or 0.0, sim.pg or 0.5, sim.pb or 1.0, 0.95)
        frame.powerText:SetText(sim.power .. "%")
    else
        frame.powerBar:Hide()
        frame.powerText:Hide()
    end

    -- 5. HoT Icons (Eigene rechts, Fremde links)
    if cfg.auras and cfg.auras.showHots ~= false then
        -- Eigene HoTs (rechts)
        for i = 1, 4 do
            local hot = sim.hots and sim.hots[i]
            local hotIcon = frame.hotIcons[i]
            if hot then
                hotIcon.tex:SetTexture(hot.icon)
                hotIcon.cdText:SetText(hot.cd or "")
                hotIcon.countText:SetText(hot.count or "")
                hotIcon:Show()
            else
                hotIcon:Hide()
            end
        end

        -- Fremde HoTs (links)
        if frame.otherHotIcons then
            for i = 1, 3 do
                local hot = sim.otherHots and sim.otherHots[i]
                local hotIcon = frame.otherHotIcons[i]
                if hot then
                    hotIcon.tex:SetTexture(hot.icon)
                    hotIcon.cdText:SetText(hot.cd or "")
                    hotIcon.countText:SetText(hot.count or "")
                    hotIcon:Show()
                else
                    hotIcon:Hide()
                end
            end
        end
    else
        for i = 1, 4 do
            if frame.hotIcons and frame.hotIcons[i] then frame.hotIcons[i]:Hide() end
        end
        if frame.otherHotIcons then
            for i = 1, 3 do
                frame.otherHotIcons[i]:Hide()
            end
        end
    end

    -- 6. Debuff & Aggro Border (Debuff hat Vorrang vor Aggro)
    if sim.debuffColor then
        frame.border:SetBackdropBorderColor(sim.debuffColor.r, sim.debuffColor.g, sim.debuffColor.b, 1.0)
    elseif cfg.display.showThreat ~= false and (sim.hasAggro or sim.threat) then
        if sim.threat == 3 or sim.hasAggro then
            frame.border:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0) -- Roter Aggro-Rahmen
        elseif sim.threat == 2 then
            frame.border:SetBackdropBorderColor(1.0, 0.5, 0.0, 1.0) -- Orange (Übergang)
        elseif sim.threat == 1 then
            frame.border:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0) -- Gelb-Orange (hohe Bedrohung)
        else
            frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
        end
    else
        frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
    end

    -- 7. Rollen-Icon (Tank, Heiler, DD)
    UpdateRoleIcon(frame, sim.role)
end


function UF:_UpdateFrameInternal(frame)
    local unit = frame.unit
    if not unit or not UnitExists(unit) then
        frame:SetAlpha(0)
        return
    end

    frame:SetAlpha(1)
    local cfg = R4L.ProfileManager:GetConfig()

    -- 1. Name & Sichtbarkeit
    if cfg.display.showNames then
        frame.nameText:Show()
        local name = UnitName(unit) or "Unbekannt"
        frame.nameText:SetText(name)
    else
        frame.nameText:Hide()
    end

    -- 2. Reichweitenprüfung & Alpha-Fading (100% gesichert gegen Secret Values)
    local targetAlpha = 1.0
    local isSelfUnit = (unit == "player")
    if not isSelfUnit and UnitIsUnit then
        local okSelfUnit, resSelf = pcall(function() return UnitIsUnit(unit, "player") == true end)
        if okSelfUnit and resSelf then isSelfUnit = true end
    end
    if cfg.display.fadeOutOfRange and not isSelfUnit then
        local inRange = true
        local okR, rRes = pcall(function()
            if R4L.IsUnitInRange then
                return R4L:IsUnitInRange(unit) == true
            elseif UnitInRange then
                local rVal = UnitInRange(unit)
                if rVal ~= nil then return (rVal == true or rVal == 1) end
            end
            return true
        end)
        if okR and rRes == false then
            inRange = false
        end

        if not inRange then
            targetAlpha = cfg.display.outOfRangeAlpha or 0.4
        end
    end
    frame:SetAlpha(targetAlpha)

    -- 3. Lebenspunkte & Farbgebung
    local hp = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)

    local isDead = false
    if UnitIsDead then
        local okDead, resDead = pcall(function() return UnitIsDead(unit) == true end)
        if okDead and resDead then isDead = true end
    end

    local isGhost = false
    if UnitIsGhost then
        local okGhost, resGhost = pcall(function() return UnitIsGhost(unit) == true end)
        if okGhost and resGhost then isGhost = true end
    end

    local isConnected = true
    if UnitIsConnected then
        local okConn, resDisconn = pcall(function() return UnitIsConnected(unit) == false end)
        if okConn and resDisconn then isConnected = false end
    end

    -- Sichere Prozentberechnung
    local isSecret = false
    if issecretvalue then
        local okS1, s1 = pcall(issecretvalue, hp)
        local okS2, s2 = pcall(issecretvalue, hpMax)
        if (okS1 and s1) or (okS2 and s2) then
            isSecret = true
        end
    end

    local pct = 1.0
    local okArith, calcPct = pcall(function()
        if hpMax and hpMax > 0 and hp then
            return hp / hpMax
        end
        return 1.0
    end)
    if okArith and type(calcPct) == "number" then
        pct = math.max(0, math.min(1.0, calcPct))
    else
        isSecret = true
    end

    -- Klassenfarben vs. Minimal (Klassischer VuhDo Grün-Gelb-Rot Verlauf)
    local localizedClass, englishClass = UnitClass(unit)
    local class = englishClass or localizedClass
    local r, g, b = 0.15, 0.85, 0.25
    if cfg.display.colorMode == "MINIMAL" then
        if not isSecret then
            if pct > 0.5 then
                local factor = (pct - 0.5) * 2
                r = 0.15 + (1 - factor) * 0.80
                g = 0.85
                b = 0.25 * factor
            else
                local factor = pct * 2
                r = 0.95
                g = 0.15 + factor * 0.70
                b = 0.05
            end
        else
            r, g, b = 0.15, 0.85, 0.25
        end
    else
        r, g, b = GetClassColorRGB(class)
    end

    -- Reverse vs. Normal Modus
    local isReverse = (cfg.display.healthOrientation == "REVERSE")

    if not isReverse then
        -- Normaler Modus: Balken füllt sich in gewählter Farbe (Klassenfarbe oder Grün) und leert sich bei Schaden
        local okSet = pcall(function()
            if isSecret then
                frame.healthBar:SetMinMaxValues(0, hpMax)
                frame.healthBar:SetValue(hp)
            else
                local mVal = (hpMax and hpMax > 0) and hpMax or 1
                local cVal = hp or 0
                frame.healthBar:SetMinMaxValues(0, mVal)
                frame.healthBar:SetValue(cVal)
            end
        end)
        if not okSet then
            pcall(frame.healthBar.SetMinMaxValues, frame.healthBar, 0, 100)
            pcall(frame.healthBar.SetValue, frame.healthBar, 100)
        end
        frame.healthBar:SetStatusBarColor(r, g, b, 0.95)
        if cfg.display.colorMode == "MINIMAL" then
            frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95) -- Rot bei Grün/Rot-Einstellung
        else
            frame.healthBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95) -- Schwarz bei Klassenfarben
        end
    else
        -- Reverse / Defizit Modus (VuhDo-Stil): Balken füllt sich rot bei erlittenem Schaden
        local okSet = pcall(function()
            if isSecret then
                frame.healthBar:SetMinMaxValues(0, hpMax)
                frame.healthBar:SetValue(0)
            else
                local mVal = (hpMax and hpMax > 0) and hpMax or 1
                local defVal = math.max(0, mVal - (hp or 0))
                frame.healthBar:SetMinMaxValues(0, mVal)
                frame.healthBar:SetValue(defVal)
            end
        end)
        if not okSet then
            pcall(frame.healthBar.SetMinMaxValues, frame.healthBar, 0, 100)
            pcall(frame.healthBar.SetValue, frame.healthBar, 0)
        end
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.95) -- Rot bei Schaden
        frame.healthBar.bg:SetColorTexture(r * 0.85, g * 0.85, b * 0.85, 0.90) -- Gewählte Farbe als Basis dahinter
    end

    -- Statustext (Tot, Geist, Offline oder HP/Defizit)
    if not isConnected then
        frame.statusText:SetText("|cff888888[OFF]|r")
    elseif isGhost then
        frame.statusText:SetText("|cffaaaaaa[GEIST]|r")
    elseif isDead then
        frame.statusText:SetText("|cffff0000[TOT]|r")
    else
        frame.statusText:SetText(SafeGetHealthText(unit, hp, hpMax, cfg.display.healthTextFormat))
    end

    -- 4. Mana / Power Bar (mit sicherer Bären-/Katzengestalt-Erkennung für Spieler & Gruppe)
    local curType = DetectUnitPowerType(unit, class)
    if cfg.display.showManaBar then
        frame.powerBar:Show()
        frame.powerText:Show()

        local power = UnitPower(unit, curType)
        local powerMax = UnitPowerMax(unit, curType)

        local isSecretP = false
        if issecretvalue then
            local okS1, s1 = pcall(issecretvalue, power)
            local okS2, s2 = pcall(issecretvalue, powerMax)
            if (okS1 and s1) or (okS2 and s2) then
                isSecretP = true
            end
        end

        local pr, pg, pb = GetPowerColorRGB(unit, curType)
        frame.powerBar:SetStatusBarColor(pr, pg, pb, 0.95)
        if curType == 1 or curType == 3 or curType == 6 then
            -- Bei Wut (Rot), Energie (Gelb), Runenmacht (Cyan) Hintergrund leicht einfärben, damit Bär auch bei 0 Wut sofort rot erkennbar ist
            frame.powerBar.bg:SetColorTexture(pr * 0.38, pg * 0.12, pb * 0.12, 0.95)
        else
            frame.powerBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)
        end

        local okSetP = pcall(function()
            if isSecretP then
                frame.powerBar:SetMinMaxValues(0, powerMax)
                frame.powerBar:SetValue(power)
            else
                local pM = (powerMax and powerMax > 0) and powerMax or 100
                local pC = power or 0
                frame.powerBar:SetMinMaxValues(0, pM)
                frame.powerBar:SetValue(pC)
            end
        end)
        if not okSetP then
            pcall(frame.powerBar.SetMinMaxValues, frame.powerBar, 0, 100)
            pcall(frame.powerBar.SetValue, frame.powerBar, 100)
        end

        local pctText = ""
        local okCalc, calcPct = pcall(function()
            if power and powerMax and powerMax > 0 then
                if curType == 1 or curType == 3 or curType == 6 then
                    if power > 0 then
                        return tostring(math.floor(power))
                    else
                        return ""
                    end
                else
                    if power >= powerMax then return "" end
                    return math.floor((power / powerMax) * 100) .. "%"
                end
            end
            return ""
        end)
        if okCalc and type(calcPct) == "string" then
            pctText = calcPct
        end

        if pctText == "" and UnitPowerPercent then
            local okP, txt = pcall(function()
                local p = UnitPowerPercent(unit, curType, false, CurveConstants and CurveConstants.ScaleTo100)
                if issecretvalue and issecretvalue(p) then return "" end
                if type(p) == "number" then
                    return math.floor(p) .. "%"
                end
                return ""
            end)
            if okP and txt and txt ~= "" then
                pctText = txt
            end
        end

        frame.powerText:SetText(pctText)
    else
        frame.powerBar:Hide()
        frame.powerText:Hide()
        frame.powerText:SetText("")
    end

    -- 5. HoT Tracker (Eigene HoTs RECHTS oben, Fremde HoTs LINKS oben)
    local showHots = (cfg.auras == nil) or (cfg.auras.showHots ~= false)
    local hasShieldFromHots = false
    if R4L.AuraTracker then
        local okHots, ownHots, otherHots = pcall(R4L.AuraTracker.GetPlayerHots, R4L.AuraTracker, unit)
        local ownList = (okHots and type(ownHots) == "table") and ownHots or {}
        local otherList = (okHots and type(otherHots) == "table") and otherHots or {}

        for _, h in ipairs(ownList) do
            if h.isShield or h.icon == 135940 or h.icon == 136089 or h.icon == 538745 then
                hasShieldFromHots = true
            end
        end
        for _, h in ipairs(otherList) do
            if h.isShield or h.icon == 135940 or h.icon == 136089 or h.icon == 538745 then
                hasShieldFromHots = true
            end
        end

        if showHots then
            -- 1. Eigene HoTs (oben rechts, max 4)
            for i = 1, 4 do
                local hotIcon = frame.hotIcons[i]
                local hot = ownList[i]
                if hot and (hot.icon or hot.rawIcon ~= nil) then
                    local okTex = false
                    if hot.rawIcon ~= nil then
                        okTex = pcall(hotIcon.tex.SetTexture, hotIcon.tex, hot.rawIcon)
                    end
                    if not okTex and hot.icon then
                        pcall(hotIcon.tex.SetTexture, hotIcon.tex, hot.icon)
                    end
                    hotIcon:SetFrameLevel(frame.hotContainer:GetFrameLevel() + 2)

                    local cdStr = ""
                    local okTime, timeLeft = pcall(function()
                        if not IsSecret(hot.expirationTime) and type(hot.expirationTime) == "number" and hot.expirationTime > 0 then
                            return hot.expirationTime - GetTime()
                        end
                        return nil
                    end)
                    if okTime and type(timeLeft) == "number" and timeLeft > 0 then
                        if timeLeft < 10 then
                            cdStr = string.format("%.0f", timeLeft)
                        else
                            cdStr = string.format("%d", timeLeft)
                        end
                    end
                    hotIcon.cdText:SetText(cdStr)

                    local okCount, cnt = pcall(function()
                        if not IsSecret(hot.count) and type(hot.count) == "number" then
                            return hot.count
                        end
                        return 0
                    end)
                    if okCount and type(cnt) == "number" and cnt > 1 then
                        hotIcon.countText:SetText(tostring(cnt))
                    else
                        hotIcon.countText:SetText("")
                    end

                    hotIcon:Show()
                else
                    hotIcon:Hide()
                end
            end

            -- 2. Fremde HoTs (oben links, max 3)
            if frame.otherHotIcons then
                for i = 1, 3 do
                    local hotIcon = frame.otherHotIcons[i]
                    local hot = otherList[i]
                    if hot and (hot.icon or hot.rawIcon ~= nil) then
                        local okTex = false
                        if hot.rawIcon ~= nil then
                            okTex = pcall(hotIcon.tex.SetTexture, hotIcon.tex, hot.rawIcon)
                        end
                        if not okTex and hot.icon then
                            pcall(hotIcon.tex.SetTexture, hotIcon.tex, hot.icon)
                        end
                        hotIcon:SetFrameLevel(frame.otherHotContainer:GetFrameLevel() + 2)

                        local cdStr = ""
                        local okTime, timeLeft = pcall(function()
                            if not IsSecret(hot.expirationTime) and type(hot.expirationTime) == "number" and hot.expirationTime > 0 then
                                return hot.expirationTime - GetTime()
                            end
                            return nil
                        end)
                        if okTime and type(timeLeft) == "number" and timeLeft > 0 then
                            if timeLeft < 10 then
                                cdStr = string.format("%.0f", timeLeft)
                            else
                                cdStr = string.format("%d", timeLeft)
                            end
                        end
                        hotIcon.cdText:SetText(cdStr)

                        local okCount, cnt = pcall(function()
                            if not IsSecret(hot.count) and type(hot.count) == "number" then
                                return hot.count
                            end
                            return 0
                        end)
                        if okCount and type(cnt) == "number" and cnt > 1 then
                            hotIcon.countText:SetText(tostring(cnt))
                        else
                            hotIcon.countText:SetText("")
                        end

                        hotIcon:Show()
                    else
                        hotIcon:Hide()
                    end
                end
            end
        else
            for i = 1, 4 do
                if frame.hotIcons and frame.hotIcons[i] then frame.hotIcons[i]:Hide() end
            end
            if frame.otherHotIcons then
                for i = 1, 3 do
                    frame.otherHotIcons[i]:Hide()
                end
            end
        end
    end

    -- 5b. Eingehende Heilung (Heal Prediction) & Schilde (Absorbs) - Am rechten Ende des aktuellen Lebensbalkens verankert
    if isDead or isGhost or not isConnected then
        if frame.healPredictBar then frame.healPredictBar:Hide() end
        if frame.absorbBar then frame.absorbBar:Hide() end
        if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
    else
        local barW = frame.healthBar:GetWidth() or 110
        local healthTex = frame.healthBar:GetStatusBarTexture() or frame.healthBar
        local curPx = (not isSecret and pct) and (pct * barW) or nil
        local baseOffset = curPx and math.min(0, math.floor(barW - curPx - 6)) or -4

        -- Prüfe eingehende Heilung (API + Cast-Tracker)
        local hasIncomingHeal = false
        local healAmount = nil
        if cfg.display.showHealPrediction ~= false then
            if R4L.AuraTracker and R4L.AuraTracker.HasIncomingHeal and R4L.AuraTracker:HasIncomingHeal(unit) then
                hasIncomingHeal = true
            end
            if UnitGetIncomingHeals then
                local okHeal, hVal = pcall(UnitGetIncomingHeals, unit)
                if okHeal and hVal ~= nil then
                    local okPos, isPos = pcall(function() return type(hVal) == "number" and hVal > 0 end)
                    if okPos and isPos then
                        hasIncomingHeal = true
                        healAmount = hVal
                    end
                end
            end
        end

        local healW = math.max(16, math.floor(barW * 0.24))
        if healAmount and not isSecret and hpMax and hpMax > 0 then
            healW = math.max(14, math.min(math.floor(barW * 0.45), math.floor((healAmount / hpMax) * barW)))
        end

        if hasIncomingHeal and frame.healPredictBar then
            frame.healPredictBar:ClearAllPoints()
            frame.healPredictBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", baseOffset, 0)
            frame.healPredictBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", baseOffset, 0)
            frame.healPredictBar:SetWidth(healW)
            frame.healPredictBar:SetMinMaxValues(0, 100)
            frame.healPredictBar:SetValue(100)
            frame.healPredictBar:Show()
        elseif frame.healPredictBar then
            frame.healPredictBar:Hide()
        end

        -- Prüfe aktive Schilde / Absorbs (API + Schild-Aura-Erkennung z. B. Machtwort: Schild)
        local hasAbsorbShield = false
        local absorbAmount = nil
        if cfg.display.showAbsorbs ~= false then
            if hasShieldFromHots then
                hasAbsorbShield = true
            elseif R4L.AuraTracker and R4L.AuraTracker.HasActiveShield and R4L.AuraTracker:HasActiveShield(unit) then
                hasAbsorbShield = true
            end
            if UnitGetTotalAbsorbs then
                local okAbs, aVal = pcall(UnitGetTotalAbsorbs, unit)
                if okAbs and aVal ~= nil then
                    local okPos, isPos = pcall(function() return type(aVal) == "number" and aVal > 0 end)
                    if okPos and isPos then
                        hasAbsorbShield = true
                        absorbAmount = aVal
                    end
                end
            end
        end

        local shieldW = math.max(15, math.floor(barW * 0.22))
        if absorbAmount and not isSecret and hpMax and hpMax > 0 then
            shieldW = math.max(14, math.min(math.floor(barW * 0.40), math.floor((absorbAmount / hpMax) * barW)))
        end

        if hasAbsorbShield and frame.absorbBar then
            frame.absorbBar:ClearAllPoints()
            frame.absorbBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", baseOffset, 0)
            frame.absorbBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", baseOffset, 0)
            frame.absorbBar:SetWidth(shieldW)
            frame.absorbBar:SetMinMaxValues(0, 100)
            frame.absorbBar:SetValue(100)
            frame.absorbBar:Show()
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Show() end
        else
            if frame.absorbBar then frame.absorbBar:Hide() end
            if frame.overAbsorbGlow then frame.overAbsorbGlow:Hide() end
        end
    end

    -- 6. Bannbare Flüche / Vergiftung (Debuff-Border) & Aggro-Anzeige
    local debuffColor = nil
    local activeDebuff = nil
    if R4L.testDebuff then
        debuffColor = R4L.AuraTracker and R4L.AuraTracker.DebuffColors[R4L.testDebuff]
        activeDebuff = { dispelType = R4L.testDebuff }
    elseif cfg.auras and cfg.auras.showDebuffs and R4L.AuraTracker then
        local debuff, color = R4L.AuraTracker:GetDispellableDebuff(unit)
        if debuff and color then
            debuffColor = color
            activeDebuff = debuff
        end
    end

    if debuffColor then
        -- Priorität 1: Debuff hat IMMER Vorrang vor Aggro!
        frame.border:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b, 1.0)
    elseif cfg.display.showThreat ~= false then
        -- Priorität 2: Aggro- & Bedrohungs-Anzeige (gesichert gegen Secret Values & mit Mob-Target-Prüfung)
        local isTank = false
        local okRole, assignedRole = pcall(function()
            return UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        end)
        if okRole and assignedRole == "TANK" then
            isTank = true
        end
        if not isTank and GetPartyAssignment then
            local okMT, isMT = pcall(function() return GetPartyAssignment("MAINTANK", unit) == true end)
            if okMT and isMT then isTank = true end
        end
        -- Druide in Bärengestalt (Wut = 1) ist Tank
        local upperClass = class and string.upper(tostring(class)) or ""
        if not isTank and (upperClass == "DRUID" or upperClass == "DRUIDE") and curType == 1 then
            isTank = true
        end
        if not isTank and R4L.Sorting and R4L.Sorting:GetUnitRole(unit) == "TANK" then
            isTank = true
        end

        local inCombat = false
        if InCombatLockdown and InCombatLockdown() then
            inCombat = true
        end
        if not inCombat and UnitAffectingCombat then
            local okC1, c1 = pcall(function() return UnitAffectingCombat(unit) == true end)
            local okC2, c2 = pcall(function() return UnitAffectingCombat("player") == true end)
            if (okC1 and c1) or (okC2 and c2) then
                inCombat = true
            end
        end

        local threat = nil
        if UnitThreatSituation then
            local okThreat, tVal = pcall(function()
                local t = UnitThreatSituation(unit)
                if t == nil and UnitExists("target") and UnitCanAttack("player", "target") then
                    t = UnitThreatSituation(unit, "target")
                end
                if type(t) == "number" then
                    if t == 3 then return 3
                    elseif t == 2 then return 2
                    elseif t == 1 then return 1
                    elseif t == 0 then return 0
                    end
                end
                return nil
            end)
            if okThreat and type(tVal) == "number" then
                threat = tVal
            end
        end

        -- Direkter Mob-Target-Check (erkennt 100% zuverlässig, wenn ein Mob einen DD/Heiler angreift, selbst wenn UnitThreatSituation geheim ist!)
        if inCombat and threat ~= 3 then
            local mobUnits = {
                "target", "focus",
                "party1target", "party2target", "party3target", "party4target",
                "nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5", "nameplate6",
            }
            local mobTargetingThisUnit = false
            local mobTargetingOtherMember = false
            for _, mob in ipairs(mobUnits) do
                local okMob, isHostile = pcall(function()
                    return UnitExists(mob) and UnitCanAttack("player", mob) and not UnitIsDead(mob)
                end)
                if okMob and isHostile then
                    local mobTarget = mob .. "target"
                    local okTgt, isTgt = pcall(function()
                        return UnitExists(mobTarget) and UnitIsUnit(mobTarget, unit) == true
                    end)
                    if okTgt and isTgt then
                        mobTargetingThisUnit = true
                        break
                    end
                    local okOther, isOther = pcall(function()
                        return UnitExists(mobTarget) and (UnitIsUnit(mobTarget, "player") == true or UnitInParty(mobTarget) == true or UnitInRaid(mobTarget) == true)
                    end)
                    if okOther and isOther then
                        mobTargetingOtherMember = true
                    end
                end
            end
            if mobTargetingThisUnit then
                threat = 3
            elseif isTank and mobTargetingOtherMember and threat == nil then
                threat = 2
            end
        end

        if inCombat and threat then
            if threat == 3 then
                if isTank then
                    frame.border:SetBackdropBorderColor(0, 0, 0, 0.9) -- Tank hält regulär Aggro
                else
                    frame.border:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0) -- Roter Rahmen bei Aggro auf DD/Heiler!
                end
            elseif threat == 2 then
                frame.border:SetBackdropBorderColor(1.0, 0.5, 0.0, 1.0) -- Orange (Aggro-Wechsel / Tank verliert Aggro)
            elseif threat == 1 then
                frame.border:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0) -- Gelb-Orange (hohe Bedrohung)
            elseif isTank and threat < 3 then
                frame.border:SetBackdropBorderColor(1.0, 0.6, 0.1, 1.0) -- Warnung: Tank verliert Aggro!
            else
                frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
            end
        else
            frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
        end
    else
        frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
    end

    -- 6b. Smart-Dispel (Außerhalb des Kampfes Linksklick automatisch auf den passenden Reinigungszauber setzen)
    if R4L.ClickCast and R4L.ClickCast.ApplySmartDispel then
        R4L.ClickCast:ApplySmartDispel(frame, debuffColor, activeDebuff)
    end

    -- 7. Rollen-Icon (Tank, Heiler, DD)
    local role = nil
    local okR, rAssigned = pcall(function()
        return UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    end)
    if okR and rAssigned and rAssigned ~= "NONE" then
        role = rAssigned
    end
    if not role or role == "NONE" then
        if isSelfUnit then
            local spec = GetSpecialization and GetSpecialization()
            if spec and GetSpecializationRole then
                role = GetSpecializationRole(spec)
            end
        end
    end
    if (not role or role == "NONE") and UnitExists(unit) then
        if GetPartyAssignment then
            local okMT, isMT = pcall(function() return GetPartyAssignment("MAINTANK", unit) == true end)
            if okMT and isMT then
                role = "TANK"
            end
        end
    end
    UpdateRoleIcon(frame, role)
end

