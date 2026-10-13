--[[
    Resto4Life - UI/UnitFrame.lua
    Sichere Unit-Frame Komponente mit Health-Bar (Normal/Reverse), Mana-Bar,
    Klassen-/Minimalfarben, nativen WoW Forever AuraContainern (Eigene HoTs & Dispel-Glow)
    und nativer Heal- & Schild-Prediction (CreateUnitHealPredictionCalculator).
--]]

local _, R4L = ...

R4L.UnitFrame = {}
local UF = R4L.UnitFrame
UF.allFrames = UF.allFrames or {}

-- Helper zur Erkennung von geheimen Werten in WoW Forever & 12.0
local function IsSecret(val)
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res then return true end
    end
    if issecrettable then
        local ok, res = pcall(issecrettable, val)
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
    if not class or IsSecret(class) then return 0.7, 0.7, 0.7 end
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
    local upperClass = (class and not IsSecret(class)) and string.upper(tostring(class)) or ""

    -- 1. Primär: UnitPowerType direkt auswerten (getrennt für pToken und pType gegen Secret Values)
    if UnitPowerType then
        local pType, pToken = UnitPowerType(unit)
        if not IsSecret(pToken) and type(pToken) == "string" then
            if pToken == "RAGE" then
                UF._lastKnownPowerType[unit] = 1
                return 1
            elseif pToken == "ENERGY" then
                UF._lastKnownPowerType[unit] = 3
                return 3
            elseif pToken == "FOCUS" then
                UF._lastKnownPowerType[unit] = 2
                return 2
            elseif pToken == "RUNIC_POWER" then
                UF._lastKnownPowerType[unit] = 6
                return 6
            elseif pToken == "LUNAR_POWER" or pToken == "ASTRAL_POWER" then
                UF._lastKnownPowerType[unit] = 8
                return 8
            elseif pToken == "INSANITY" then
                UF._lastKnownPowerType[unit] = 13
                return 13
            elseif pToken == "FURY" then
                UF._lastKnownPowerType[unit] = 17
                return 17
            elseif pToken == "MANA" then
                UF._lastKnownPowerType[unit] = 0
                return 0
            end
        end
        if not IsSecret(pType) and type(pType) == "number" then
            UF._lastKnownPowerType[unit] = pType
            return pType
        end
    end

    -- 2. Letzter bekannter PowerType im Kampf
    if UF._lastKnownPowerType[unit] ~= nil then
        return UF._lastKnownPowerType[unit]
    end

    -- 3. Klassen-Fallback
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
    if not val or IsSecret(val) then return "" end
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
    return ok and formatted or ""
end

-- Sichere Berechnung des Lebensanzeige-Texts (verhindert Secret-Value Fehler in WoW Forever & 12.0)
local function SafeGetHealthText(unit, hp, hpMax, format)
    if not IsSecret(hp) and not IsSecret(hpMax) then
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
    end
    return ""
end

-- =========================================================================
-- Native WoW Forever (16001) Heal- & Shield-Prediction Calculator
-- Übergibt Secret Values direkt an StatusBars ohne Lua-Vergleiche!
-- =========================================================================
local healCalc, rawCalc
local function CreatePredictionCalc(healMode)
    local calc = CreateUnitHealPredictionCalculator and CreateUnitHealPredictionCalculator() or false
    if calc and Enum.UnitIncomingHealClampMode then
        pcall(calc.SetIncomingHealClampMode, calc, healMode)
        pcall(calc.SetDamageAbsorbClampMode, calc, Enum.UnitDamageAbsorbClampMode.MissingHealth)
    end
    return calc
end

local function GetUnitHealAndShieldPrediction(unit)
    if healCalc == nil then
        healCalc = CreatePredictionCalc(Enum.UnitIncomingHealClampMode and Enum.UnitIncomingHealClampMode.MissingHealth)
        rawCalc = CreatePredictionCalc(Enum.UnitIncomingHealClampMode and Enum.UnitIncomingHealClampMode.MaximumHealth)
    end
    if healCalc and rawCalc and UnitGetDetailedHealPrediction then
        local ok = pcall(function()
            healCalc:ResetPredictedValues()
            UnitGetDetailedHealPrediction(unit, "player", healCalc)
        end)
        if ok then
            local incoming, _, _, overheal = healCalc:GetIncomingHeals()
            local shield = healCalc:GetTotalDamageAbsorbs()
            local _, overflow = healCalc:GetDamageAbsorbs()
            return incoming, shield, overflow, overheal
        end
    end
    local inc = UnitGetIncomingHeals and UnitGetIncomingHeals(unit)
    local abs = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)
    if not IsSecret(inc) and inc == nil then inc = 0 end
    if not IsSecret(abs) and abs == nil then abs = 0 end
    local overflow = false
    if not IsSecret(abs) and type(abs) == "number" and abs > 0 then
        local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
        if not IsSecret(hp) and not IsSecret(hpMax) and type(hp) == "number" and type(hpMax) == "number" then
            overflow = (hp + abs) >= hpMax
        end
    end
    return inc, abs, overflow, false
end

local function SetBarSafe(bar, maxVal, curVal)
    if not bar then return end
    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(curVal)
end

local function SetGlowFromBool(region, flag, alphaOn)
    if not region then return end
    alphaOn = alphaOn or 0.85
    if IsSecret(flag) then
        if region.SetAlphaFromBoolean then
            pcall(region.SetAlphaFromBoolean, region, flag, alphaOn, 0)
        end
    else
        region:SetAlpha(flag and alphaOn or 0)
    end
end

-- =========================================================================
-- Native WoW Forever (16001) AuraContainer für eigene HoTs & Dispel-Hervorhebung
-- =========================================================================
local FlowDir = AnchorUtil and AnchorUtil.FlowDirection
local INNER_GLOW_TEX = "Interface\\AddOns\\Resto4Life\\Media\\InnerGlow"
local INNER_SLICE = 16

local function StyleInnerGlow(tex, healthBar)
    tex:SetTexture(INNER_GLOW_TEX)
    if tex.SetTextureSliceMargins then
        tex:SetTextureSliceMargins(INNER_SLICE, INNER_SLICE, INNER_SLICE, INNER_SLICE)
        if tex.SetTextureSliceMode and Enum.UITextureSliceMode then
            tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end
    tex:SetBlendMode("BLEND")
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
    tex:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
end

local function InitAuraButton(btn)
    btn:SetIcon(btn.Icon)
    btn:SetDurationCooldown(btn.Cooldown)
    local cfg = R4L.ProfileManager and R4L.ProfileManager:GetConfig()
    local s = (cfg and cfg.auras and cfg.auras.hotIconSize) or 15
    btn:SetSize(s, s)
    btn:EnableMouse(false)
end

local function InitDispelButton(btn, frame)
    btn:SetIcon(btn.Icon)
    btn:SetDurationCooldown(btn.Cooldown)
    local style = Enum.CustomAuraButtonDispelTypeTextureStyle
    pcall(btn.AddDispelTypeTexture, btn, btn.DispelBorder, { style = style and style.Border })
    if btn.DispelGlow and frame and frame.healthBar then
        StyleInnerGlow(btn.DispelGlow, frame.healthBar)
        pcall(btn.AddDispelTypeTexture, btn, btn.DispelGlow, { style = style and style.PreserveAsset })
        btn.DispelGlow:SetAlpha(0.90)
    end
    btn:SetSize(15, 15)
    btn:EnableMouse(false)
end

local function GetHotCandidateFilters()
    local _, pClass = UnitClass("player")
    -- Schamanen (Erdschild 10m) & Paladine (Flamme des Glaubens 5m) nutzen 600s,
    -- Priester & Druiden nutzen 60s, damit Seelenstärke / MdW / Dornen ausgefiltert werden.
    local maxDur = (pClass == "SHAMAN" or pClass == "PALADIN") and 600 or 60
    return { maxDuration = maxDur }
end

local function MakeAuraContainer(parent, point, x, y, filter, maxCount, hDir, vDir, candidates, template, initFn)
    if not FlowDir then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not c then return nil end
    local configured = pcall(function()
        c:SetPoint(point, parent, point, x, y)
        c:SetFlowLayoutAnchorPoint(point)
        c:SetFlowLayoutGrowthDirection(hDir, vDir)
        c:EnableMouse(false)
        if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
        c:AddAuraGroup("main", filter, {
            maxFrameCount = maxCount,
            templateNames = { template or "Resto4LifeAuraIconTemplate" },
            initializeFrame = initFn or InitAuraButton,
            candidateFilters = candidates,
            layout = { elementSpacing = 1 },
        })
    end)
    if not configured then
        c:Hide()
        return nil
    end
    c:SetUnit("none")
    c:Hide()
    return c
end

function UF:CreateAuraContainers(frame, overlayParent)
    if not FlowDir then return end
    frame.buffBox = MakeAuraContainer(
        overlayParent,
        "TOPRIGHT", -1, -1,
        "HELPFUL|PLAYER", 4,
        FlowDir.Left, FlowDir.Down,
        GetHotCandidateFilters(),
        "Resto4LifeAuraIconTemplate",
        InitAuraButton
    )
    -- "HARMFUL|RAID" in WoW Forever = Debuffs, die der eigene Charakter bannen kann!
    frame.dispelBox = MakeAuraContainer(
        overlayParent,
        "BOTTOMLEFT", 2, 2,
        "HARMFUL|RAID", 1,
        FlowDir.Right, FlowDir.Up,
        nil,
        "Resto4LifeDispelIconTemplate",
        function(btn) InitDispelButton(btn, frame) end
    )
    frame.auraBoxes = {}
    for _, box in ipairs({ frame.buffBox, frame.dispelBox }) do
        if box then
            frame.auraBoxes[#frame.auraBoxes + 1] = box
            pcall(box.SetFrameStrata, box, overlayParent:GetFrameStrata())
            pcall(box.SetFrameLevel, box, overlayParent:GetFrameLevel() + 4)
        end
    end
end

local function SetAuraContainersActive(frame, active, showHots, showDebuffs)
    if not frame.auraBoxes or #frame.auraBoxes == 0 then return false end
    for _, box in ipairs(frame.auraBoxes) do
        local wanted = false
        if active and frame.unit then
            if box == frame.buffBox then
                wanted = (showHots ~= false)
            elseif box == frame.dispelBox then
                wanted = (showDebuffs ~= false)
            end
        end
        if wanted then
            local okU, curU = pcall(box.GetUnit, box)
            if not okU or curU ~= frame.unit then
                pcall(box.SetUnit, box, frame.unit)
            end
            box:Show()
        else
            box:Hide()
        end
    end
    return true
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
    SafeRegister("UNIT_HEAL_PREDICTION", unit)
    SafeRegister("UNIT_ABSORB_AMOUNT_CHANGED", unit)
    SafeRegister("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", unit)
    pcall(frame.RegisterEvent, frame, "UNIT_THREAT_LIST_UPDATE")
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

    if IsSecret(role) then
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

-- Erstellt einen einzelnen Frame
function UF:CreateUnitFrame(name, parent, unit)
    local frame = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    frame.unit = unit
    frame:SetAttribute("checkselfcast", false)
    frame:SetAttribute("checkfocuscast", false)

    local cfg = R4L.ProfileManager:GetConfig()
    frame:SetSize(cfg.general.frameWidth, cfg.general.frameHeight)

    -- Äußerer Rahmen / Debuff- & Aggro-Border
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

    -- Mana / Power Text
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

    local healthTex = frame.healthBar:GetStatusBarTexture()

    -- Heal Prediction Bar: startet exakt dort, wo der aktuelle Lebensbalken endet!
    frame.healPredictBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.healPredictBar:SetPoint("TOPLEFT", healthTex, "TOPRIGHT", 0, 0)
    frame.healPredictBar:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMRIGHT", 0, 0)
    frame.healPredictBar:SetWidth(cfg.general.frameWidth - 2)
    frame.healPredictBar:SetStatusBarTexture("Interface\\AddOns\\Resto4Life\\Media\\statusbar.tga")
    frame.healPredictBar:SetStatusBarColor(0.15, 0.95, 0.45, 0.65)
    frame.healPredictBar:SetMinMaxValues(0, 100)
    frame.healPredictBar:SetValue(0)
    frame.healPredictBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)

    local incTex = frame.healPredictBar:GetStatusBarTexture()

    -- Absorb / Shield Bar: startet exakt am rechten Ende des Lebensbalkens (bzw. nach eingehender Heilung)
    -- und verschiebt sich beim Heilen/Regenerieren automatisch nach rechts!
    frame.absorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    frame.absorbBar:SetPoint("TOPLEFT", incTex, "TOPRIGHT", 0, 0)
    frame.absorbBar:SetPoint("BOTTOMLEFT", incTex, "BOTTOMRIGHT", 0, 0)
    frame.absorbBar:SetWidth(cfg.general.frameWidth - 2)
    frame.absorbBar:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    frame.absorbBar:SetStatusBarColor(0.30, 0.85, 1.0, 0.90)
    frame.absorbBar:SetMinMaxValues(0, 100)
    frame.absorbBar:SetValue(0)
    frame.absorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)

    local shieldStripes = frame.absorbBar:CreateTexture(nil, "ARTWORK", nil, 1)
    shieldStripes:SetAllPoints(frame.absorbBar:GetStatusBarTexture())
    shieldStripes:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
    shieldStripes:SetHorizTile(true)
    shieldStripes:SetVertTile(true)
    frame.absorbBar.stripes = shieldStripes

    local barsTop = frame.absorbBar:GetFrameLevel() + 1

    -- Overshield-Leuchten am rechten Rand (wenn ein Schild über 100% Leben hinausragt, über SetAlphaFromBoolean gesteuert)
    frame.glowGate = CreateFrame("Frame", nil, frame.healthBar)
    frame.glowGate:SetAllPoints(frame.healthBar)
    frame.glowGate:SetFrameLevel(barsTop)
    frame.glowGate:SetAlpha(0)

    frame.glowSwitch = CreateFrame("StatusBar", nil, frame.glowGate)
    frame.glowSwitch:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0)
    frame.glowSwitch:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0)
    frame.glowSwitch:SetWidth(16)
    frame.glowSwitch:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Overshield")
    frame.glowSwitch:GetStatusBarTexture():SetBlendMode("ADD")
    frame.glowSwitch:SetMinMaxValues(0, 1)
    frame.glowSwitch:SetValue(0)

    -- Text- & Icon-Overlay innerhalb der HealthBar über den StatusBars
    frame.textOverlay = CreateFrame("Frame", nil, frame.healthBar)
    frame.textOverlay:SetAllPoints(frame.healthBar)
    frame.textOverlay:SetFrameLevel(barsTop + 2)

    -- Spielername Text (mittig auf dem Lebensbalken)
    frame.nameText = frame.textOverlay:CreateFontString(nil, "OVERLAY")
    if not frame.nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", cfg.display.nameFontSize or 11, "OUTLINE") then
        frame.nameText:SetFontObject("GameFontHighlightSmall")
    end
    frame.nameText:SetPoint("CENTER", frame.healthBar, "CENTER", 0, -5)
    frame.nameText:SetJustifyH("CENTER")

    -- Status / Lebenspunkte Text
    frame.statusText = frame.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusText:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", -4, 2)
    frame.statusText:SetJustifyH("RIGHT")

    -- Rollen-Icon (Tank, Heiler, DD) mittig links auf gleicher Höhe wie der Name
    frame.roleIcon = frame.textOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.roleIcon:SetSize(13, 13)
    frame.roleIcon:SetPoint("LEFT", frame.healthBar, "LEFT", 4, -5)
    frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    frame.roleIcon:SetHorizTile(false)
    frame.roleIcon:SetVertTile(false)
    frame.roleIcon:Hide()

    -- Eigene HoT Icons Fallback-Container (oben rechts - für Simulation & ältere Clients ohne AuraContainer)
    frame.hotContainer = CreateFrame("Frame", nil, frame.textOverlay)
    frame.hotContainer:SetPoint("TOPRIGHT", frame.textOverlay, "TOPRIGHT", -1, -1)
    frame.hotContainer:SetSize(76, 16)
    frame.hotContainer:SetFrameLevel(frame.textOverlay:GetFrameLevel() + 3)
    frame.hotContainer:Show()

    frame.hotIcons = {}
    for i = 1, 4 do
        local hotIcon = CreateFrame("Frame", nil, frame.hotContainer, "BackdropTemplate")
        hotIcon:SetSize(15, 15)
        hotIcon:SetPoint("TOPRIGHT", frame.hotContainer, "TOPRIGHT", -((i - 1) * 16), 0)
        hotIcon:SetFrameLevel(frame.hotContainer:GetFrameLevel() + 1)
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
        if not hotIcon.cdText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE") then
            hotIcon.cdText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.cdText:SetPoint("CENTER", hotIcon, "CENTER", 0, 0)
        hotIcon.cdText:SetTextColor(1, 1, 1, 1)

        hotIcon.countText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE") then
            hotIcon.countText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.countText:SetPoint("BOTTOMRIGHT", hotIcon, "BOTTOMRIGHT", 1, -1)
        hotIcon.countText:SetTextColor(1, 1, 0, 1)

        hotIcon:Hide()
        frame.hotIcons[i] = hotIcon
    end

    -- Native WoW Forever AuraContainer erstellen (für Kampf-HoTs & Kampf-Dispel-Erkennung)
    self:CreateAuraContainers(frame, frame.textOverlay)

    -- Initialisiere Child-Buttons für Mausrad & Tastenbelegungen
    R4L.ClickCast:SetupChildButtons(frame)

    -- Event-Handler für verzögerungsfreie Werteaktualisierung
    frame:SetScript("OnEvent", function(self, event, unitArg)
        UF:UpdateFrame(self)
    end)

    -- Update-Ticker für Echtzeit-Balken und Reichweiten-Prüfung
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.timeSinceLastUpdate = (self.timeSinceLastUpdate or 0) + elapsed
        if self.timeSinceLastUpdate > 0.08 then
            UF:UpdateFrame(self)
            self.timeSinceLastUpdate = 0
        end
    end)

    table.insert(self.allFrames, frame)
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
    SetAuraContainersActive(frame, false, false, false)

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

    local barW = math.max(10, (frame.healthBar:GetWidth() or (cfg.general.frameWidth - 2)))
    frame.healPredictBar:SetWidth(barW)
    frame.absorbBar:SetWidth(barW)

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
    else
        local deficit = 100 - sim.hp
        frame.healthBar:SetMinMaxValues(0, 100)
        frame.healthBar:SetValue(deficit)
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.95)
        frame.healthBar.bg:SetColorTexture(r * 0.85, g * 0.85, b * 0.85, 0.90)
    end

    local simHeal = (cfg.display.showHealPrediction ~= false) and (sim.incomingHeal or 0) or 0
    local simAbsorb = (cfg.display.showAbsorbs ~= false) and (sim.absorbs or 0) or 0
    frame.healPredictBar:Show()
    SetBarSafe(frame.healPredictBar, 100, simHeal)
    frame.absorbBar:Show()
    SetBarSafe(frame.absorbBar, 100, simAbsorb)
    frame.glowSwitch:SetValue(simAbsorb > 0 and 1 or 0)
    SetGlowFromBool(frame.glowGate, simAbsorb > 0 and (sim.hp + simAbsorb >= 100), 0.85)

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

    -- 5. Eigene HoT Icons (rechts oben)
    if cfg.auras and cfg.auras.showHots ~= false then
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
    else
        for i = 1, 4 do
            if frame.hotIcons and frame.hotIcons[i] then frame.hotIcons[i]:Hide() end
        end
    end

    -- 6. Debuff & Aggro Border (Debuff hat Vorrang vor Aggro)
    if sim.debuffColor then
        frame.border:SetBackdropBorderColor(sim.debuffColor.r, sim.debuffColor.g, sim.debuffColor.b, 1.0)
    elseif cfg.display.showThreat ~= false and (sim.hasAggro or sim.threat) then
        if sim.threat == 3 or sim.hasAggro then
            frame.border:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0)
        elseif sim.threat == 2 then
            frame.border:SetBackdropBorderColor(1.0, 0.5, 0.0, 1.0)
        elseif sim.threat == 1 then
            frame.border:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0)
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

    local cfg = R4L.ProfileManager:GetConfig()

    -- 1. Name & Sichtbarkeit (Secret-Value sicher)
    if cfg.display.showNames then
        frame.nameText:Show()
        local name = UnitName(unit)
        pcall(frame.nameText.SetText, frame.nameText, name or "Unbekannt")
    else
        frame.nameText:Hide()
    end

    -- 2. Verbindungs- & Todesstatus
    local isDead = false
    if UnitIsDead then
        local okDead, resDead = pcall(function()
            local d = UnitIsDead(unit)
            return not IsSecret(d) and d == true
        end)
        if okDead and resDead then isDead = true end
    end

    local isGhost = false
    if UnitIsGhost then
        local okGhost, resGhost = pcall(function()
            local g = UnitIsGhost(unit)
            return not IsSecret(g) and g == true
        end)
        if okGhost and resGhost then isGhost = true end
    end

    local isConnected = true
    if UnitIsConnected then
        local okConn, resDisconn = pcall(function()
            local c = UnitIsConnected(unit)
            return not IsSecret(c) and c == false
        end)
        if okConn and resDisconn then isConnected = false end
    end

    -- 3. Reichweitenprüfung & Alpha-Fading (nutzt in WoW Forever SetAlphaFromBoolean bei Secret Booleans!)
    local outAlpha = cfg.display.outOfRangeAlpha or 0.4
    local isSelfUnit = (unit == "player")
    if not isSelfUnit and UnitIsUnit then
        local okSelfUnit, resSelf = pcall(function()
            local u = UnitIsUnit(unit, "player")
            return not IsSecret(u) and u == true
        end)
        if okSelfUnit and resSelf then isSelfUnit = true end
    end

    if cfg.display.fadeOutOfRange and not isSelfUnit then
        if not isConnected then
            frame:SetAlpha(outAlpha)
        elseif UnitInRange then
            local inRange, checked = UnitInRange(unit)
            if IsSecret(inRange) or IsSecret(checked) then
                if frame.SetAlphaFromBoolean then
                    pcall(frame.SetAlphaFromBoolean, frame, inRange, 1.0, outAlpha)
                else
                    frame:SetAlpha(1.0)
                end
            else
                local okR, rRes = pcall(function()
                    if R4L.IsUnitInRange then
                        return R4L:IsUnitInRange(unit) == true
                    end
                    if checked then return inRange == true or inRange == 1 end
                    return true
                end)
                if okR and rRes == false then
                    frame:SetAlpha(outAlpha)
                else
                    frame:SetAlpha(1.0)
                end
            end
        else
            frame:SetAlpha(1.0)
        end
    else
        frame:SetAlpha(1.0)
    end

    -- 4. Lebenspunkte & Farbgebung (Secret Values gehen direkt in SetMinMaxValues / SetValue!)
    local hp = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)
    local isSecretHP = IsSecret(hp) or IsSecret(hpMax)

    local pct = 1.0
    if not isSecretHP then
        local okArith, calcPct = pcall(function()
            if hpMax and hpMax > 0 and hp then
                return hp / hpMax
            end
            return 1.0
        end)
        if okArith and type(calcPct) == "number" then
            pct = math.max(0, math.min(1.0, calcPct))
        else
            isSecretHP = true
        end
    end

    local localizedClass, englishClass = UnitClass(unit)
    local class = (not IsSecret(englishClass) and englishClass) or (not IsSecret(localizedClass) and localizedClass) or nil
    local r, g, b = 0.15, 0.85, 0.25
    if cfg.display.colorMode == "MINIMAL" then
        if not isSecretHP then
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

    local isReverse = (cfg.display.healthOrientation == "REVERSE")
    if not isReverse then
        pcall(SetBarSafe, frame.healthBar, hpMax, hp)
        frame.healthBar:SetStatusBarColor(r, g, b, 0.95)
        if cfg.display.colorMode == "MINIMAL" then
            frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95)
        else
            frame.healthBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)
        end
    else
        if isSecretHP then
            pcall(SetBarSafe, frame.healthBar, hpMax, hp)
        else
            local mVal = (hpMax and hpMax > 0) and hpMax or 1
            local defVal = math.max(0, mVal - (hp or 0))
            pcall(SetBarSafe, frame.healthBar, mVal, defVal)
        end
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.95)
        frame.healthBar.bg:SetColorTexture(r * 0.85, g * 0.85, b * 0.85, 0.90)
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

    -- 5. Mana / Power Bar (nutzt UnitPower(unit) ohne erzwungenen Index 0, damit Bärengestalt-Wut für alle sichtbar ist!)
    local curType = DetectUnitPowerType(unit, class)
    if cfg.display.showManaBar then
        frame.powerBar:Show()
        frame.powerText:Show()

        local power = UnitPower(unit)
        local powerMax = UnitPowerMax(unit)

        local pr, pg, pb = GetPowerColorRGB(unit, curType)
        frame.powerBar:SetStatusBarColor(pr, pg, pb, 0.95)
        if curType == 1 or curType == 3 or curType == 6 then
            frame.powerBar.bg:SetColorTexture(pr * 0.38, pg * 0.12, pb * 0.12, 0.95)
        else
            frame.powerBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)
        end

        pcall(SetBarSafe, frame.powerBar, powerMax, power)

        local pctText = ""
        if not IsSecret(power) and not IsSecret(powerMax) then
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
        end
        frame.powerText:SetText(pctText)
    else
        frame.powerBar:Hide()
        frame.powerText:Hide()
        frame.powerText:SetText("")
    end

    -- 6. Native Eingehende Heilung (Heal Prediction) & Schilde (Absorbs)
    -- Übergibt die Werte aus CreateUnitHealPredictionCalculator direkt an die StatusBars!
    local barW = math.max(10, (frame.healthBar:GetWidth() or (cfg.general.frameWidth - 2)))
    frame.healPredictBar:SetWidth(barW)
    frame.absorbBar:SetWidth(barW)

    if isDead or isGhost or not isConnected then
        SetBarSafe(frame.healPredictBar, 1, 0)
        SetBarSafe(frame.absorbBar, 1, 0)
        frame.glowSwitch:SetValue(0)
        frame.glowGate:SetAlpha(0)
    else
        local incoming, shield, overflow = GetUnitHealAndShieldPrediction(unit)

        if cfg.display.showHealPrediction ~= false then
            frame.healPredictBar:Show()
            pcall(SetBarSafe, frame.healPredictBar, hpMax, incoming)
        else
            SetBarSafe(frame.healPredictBar, 1, 0)
        end

        if cfg.display.showAbsorbs ~= false then
            frame.absorbBar:Show()
            pcall(SetBarSafe, frame.absorbBar, hpMax, shield)
            pcall(frame.glowSwitch.SetValue, frame.glowSwitch, shield)
            SetGlowFromBool(frame.glowGate, overflow, 0.85)
        else
            SetBarSafe(frame.absorbBar, 1, 0)
            frame.glowSwitch:SetValue(0)
            frame.glowGate:SetAlpha(0)
        end
    end

    -- 7. Eigene HoTs & Dispel-Container (Nativ über Blizzard AuraContainer in WoW Forever, Fallback für ältere Clients)
    local showHots = (cfg.auras == nil) or (cfg.auras.showHots ~= false)
    local showDebuffs = (cfg.auras == nil) or (cfg.auras.showDebuffs ~= false)
    local usingNativeContainers = SetAuraContainersActive(frame, true, showHots, showDebuffs)

    if usingNativeContainers then
        for i = 1, 4 do
            if frame.hotIcons and frame.hotIcons[i] then
                frame.hotIcons[i]:Hide()
            end
        end
    else
        -- Fallback für Clients ohne CustomAuraContainerTemplate
        if showHots and R4L.AuraTracker then
            local okHots, ownHots = pcall(R4L.AuraTracker.GetPlayerHots, R4L.AuraTracker, unit)
            local ownList = (okHots and type(ownHots) == "table") and ownHots or {}
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
                    local cdStr = ""
                    if not IsSecret(hot.expirationTime) and type(hot.expirationTime) == "number" and hot.expirationTime > 0 then
                        local timeLeft = hot.expirationTime - GetTime()
                        if timeLeft > 0 then
                            cdStr = string.format("%d", timeLeft)
                        end
                    end
                    hotIcon.cdText:SetText(cdStr)
                    if not IsSecret(hot.count) and type(hot.count) == "number" and hot.count > 1 then
                        hotIcon.countText:SetText(tostring(hot.count))
                    else
                        hotIcon.countText:SetText("")
                    end
                    hotIcon:Show()
                else
                    hotIcon:Hide()
                end
            end
        else
            for i = 1, 4 do
                if frame.hotIcons and frame.hotIcons[i] then frame.hotIcons[i]:Hide() end
            end
        end
    end

    -- 8. Äußerer Rahmen: Debuff-Farbe (außerhalb des Kampfes & Test-Modus) + Aggro-Anzeige (im Kampf)
    -- Hinweis: Im Kampf färbt zusätzlich frame.dispelBox (InnerGlow + DispelIcon) über C++ die HealthBar ein!
    local debuffColor = nil
    local activeDebuff = nil
    if R4L.testDebuff then
        debuffColor = R4L.AuraTracker and R4L.AuraTracker.DebuffColors[R4L.testDebuff]
        activeDebuff = { dispelType = R4L.testDebuff }
    elseif showDebuffs and R4L.AuraTracker then
        local debuff, color = R4L.AuraTracker:GetDispellableDebuff(unit)
        if debuff and color then
            debuffColor = color
            activeDebuff = debuff
        end
    end

    if debuffColor then
        frame.border:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b, 1.0)
    elseif cfg.display.showThreat ~= false then
        local threat = UnitThreatSituation and UnitThreatSituation(unit) or nil
        if not IsSecret(threat) and type(threat) == "number" and threat >= 1 then
            local isTank = false
            local okRole, assignedRole = pcall(function()
                local rRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
                return not IsSecret(rRole) and rRole or nil
            end)
            if okRole and assignedRole == "TANK" then
                isTank = true
            end
            if not isTank and GetPartyAssignment then
                local okMT, isMT = pcall(function() return GetPartyAssignment("MAINTANK", unit) == true end)
                if okMT and isMT then isTank = true end
            end
            local upperClass = class and string.upper(tostring(class)) or ""
            if not isTank and (upperClass == "DRUID" or upperClass == "DRUIDE") and curType == 1 then
                isTank = true
            end

            if threat == 3 then
                if isTank then
                    frame.border:SetBackdropBorderColor(0, 0, 0, 0.9) -- Tank hält regulär Aggro
                else
                    frame.border:SetBackdropBorderColor(1.0, 0.0, 0.0, 1.0) -- Roter Rahmen: DD/Heiler hat Aggro!
                end
            elseif threat == 2 then
                frame.border:SetBackdropBorderColor(1.0, 0.5, 0.0, 1.0) -- Orange: Aggro-Wechsel / Tank verliert Aggro!
            elseif threat == 1 then
                frame.border:SetBackdropBorderColor(1.0, 0.8, 0.0, 1.0) -- Gelb-Orange: Hohe Bedrohung
            else
                frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
            end
        else
            frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
        end
    else
        frame.border:SetBackdropBorderColor(0, 0, 0, 0.9)
    end

    -- 9. Rollen-Icon (Tank, Heiler, DD)
    local role = nil
    local okR, rAssigned = pcall(function()
        local rRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
        return not IsSecret(rRole) and rRole or nil
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
