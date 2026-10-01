--[[
    Resto4Life - UI/UnitFrame.lua
    Sichere Unit-Frame Komponente mit Health-Bar (Normal/Reverse), Mana-Bar,
    Klassen-/Minimalfarben, HoTs und Debuff-Hervorhebung
--]]

local _, R4L = ...

R4L.UnitFrame = {}
local UF = R4L.UnitFrame

-- Klassenfarben-Fallback
local FALLBACK_CLASS_COLORS = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.25, g = 0.78, b = 0.92 },
    ["WARLOCK"]     = { r = 0.53, g = 0.53, b = 0.93 },
    ["MONK"]        = { r = 0.00, g = 1.00, b = 0.59 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
    ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79 },
    ["EVOKER"]      = { r = 0.20, g = 0.58, b = 0.50 },
}

-- Ermittelt Klassenfarben zuverlässig für Retail & Classic
local function GetClassColorRGB(class)
    if not class then return 1.0, 0.49, 0.04 end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local c = C_ClassColor.GetClassColor(class)
        if c then return c.r, c.g, c.b end
    end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    if FALLBACK_CLASS_COLORS[class] then
        local c = FALLBACK_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 1.0, 0.49, 0.04
end

-- Ermittelt Ressourcen-/Power-Farben für alle Klassen
local function GetPowerColorRGB(unit, explicitType)
    local powerType, powerToken = UnitPowerType(unit)
    if explicitType ~= nil then
        powerType = explicitType
        powerToken = (explicitType == 0) and "MANA" or powerToken
    end
    if powerToken and PowerBarColor and PowerBarColor[powerToken] then
        local c = PowerBarColor[powerToken]
        return c.r, c.g, c.b
    end
    if powerType and PowerBarColor and PowerBarColor[powerType] then
        local c = PowerBarColor[powerType]
        return c.r, c.g, c.b
    end
    -- Standardfarben
    if powerType == 0 or powerToken == "MANA" then
        return 0.0, 0.5, 1.0       -- Mana (Blau)
    elseif powerType == 1 or powerToken == "RAGE" then
        return 1.0, 0.2, 0.2       -- Rage (Rot)
    elseif powerType == 2 or powerToken == "FOCUS" then
        return 1.0, 0.5, 0.25      -- Focus (Orange)
    elseif powerType == 3 or powerToken == "ENERGY" then
        return 1.0, 1.0, 0.2       -- Energy (Gelb)
    elseif powerType == 6 or powerToken == "RUNIC_POWER" then
        return 0.0, 0.82, 1.0      -- Runic Power (Cyan)
    elseif powerType == 8 or powerToken == "LUNAR_POWER" or powerToken == "ASTRAL_POWER" then
        return 0.3, 0.52, 0.9      -- Astral Power (Druide Eule)
    elseif powerType == 13 or powerToken == "INSANITY" then
        return 0.4, 0.0, 0.8       -- Insanity (Shadow Priest)
    elseif powerType == 17 or powerToken == "FURY" then
        return 0.79, 0.26, 0.99    -- Fury (Demon Hunter)
    end
    return 0.0, 0.5, 1.0
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

-- Registriert Unit-Events gezielt für die zugewiesene Einheit
function UF:RegisterUnitEvents(frame, unit)
    frame:UnregisterAllEvents()
    if not unit or not UnitExists(unit) then return end

    frame:RegisterUnitEvent("UNIT_HEALTH", unit)
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
    frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    frame:RegisterUnitEvent("UNIT_AURA", unit)
    frame:RegisterUnitEvent("UNIT_CONNECTION", unit)
    frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unit)
    frame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
    frame.border:SetFrameLevel(frame:GetFrameLevel() + 5)

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
    frame.powerBar:SetFrameLevel(frame:GetFrameLevel() + 3)

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
    frame.healthBar:SetStatusBarColor(1.0, 0.49, 0.04, 0.95)
    frame.healthBar:SetMinMaxValues(0, 100)
    frame.healthBar:SetValue(100)
    frame.healthBar:SetFrameLevel(frame:GetFrameLevel() + 2)

    -- Hintergrund hinter der Healthbar (Defizit-Bereich bei erlittenem Schaden)
    frame.healthBar.bg = frame.healthBar:CreateTexture(nil, "BACKGROUND", nil, -5)
    frame.healthBar.bg:SetAllPoints(frame.healthBar)
    frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95)

    -- Spielername Text (mittig auf dem Lebensbalken)
    frame.nameText = frame.healthBar:CreateFontString(nil, "OVERLAY")
    if not frame.nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", cfg.display.nameFontSize or 11, "OUTLINE") then
        frame.nameText:SetFontObject("GameFontHighlightSmall")
    end
    frame.nameText:SetPoint("CENTER", frame.healthBar, "CENTER", 0, -7)
    frame.nameText:SetJustifyH("CENTER")

    -- Status / Lebenspunkte Text
    frame.statusText = frame.healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusText:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT", -4, 4)
    frame.statusText:SetJustifyH("RIGHT")

    -- Rollen-Icon (Tank, Heiler, DD) oben links mit Abstand links und oben
    frame.roleIcon = frame.healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.roleIcon:SetSize(13, 13)
    frame.roleIcon:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", 4, -4)
    frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    frame.roleIcon:SetHorizTile(false)
    frame.roleIcon:SetVertTile(false)
    frame.roleIcon:Hide()

    -- HoT Icons Container (oben rechts)
    frame.hotContainer = CreateFrame("Frame", nil, frame)
    frame.hotContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.hotContainer:SetSize(80, 20)
    frame.hotContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.hotContainer:Show()

    frame.hotIcons = {}
    for i = 1, 4 do
        local hotIcon = CreateFrame("Frame", nil, frame.hotContainer, "BackdropTemplate")
        hotIcon:SetSize(18, 18)
        hotIcon:SetPoint("RIGHT", frame.hotContainer, "RIGHT", -((i - 1) * 20), 0)
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
        if not hotIcon.cdText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE") then
            hotIcon.cdText:SetFontObject("GameFontHighlightSmall")
        end
        hotIcon.cdText:SetPoint("CENTER", hotIcon, "CENTER", 0, 0)
        hotIcon.cdText:SetTextColor(1, 1, 1, 1)

        hotIcon.countText = hotIcon:CreateFontString(nil, "OVERLAY")
        if not hotIcon.countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE") then
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
        frame.healthBar:SetReverseFill(false)
        frame.healthBar:SetMinMaxValues(0, 100)
        frame.healthBar:SetValue(sim.hp)
        frame.healthBar:SetStatusBarColor(r, g, b, 0.95)
        if cfg.display.colorMode == "MINIMAL" then
            frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95)
        else
            frame.healthBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)
        end
    else
        frame.healthBar:SetReverseFill(false)
        frame.healthBar:SetMinMaxValues(0, 100)
        frame.healthBar:SetValue(100 - sim.hp)
        frame.healthBar:SetStatusBarColor(0.85, 0.15, 0.15, 0.95)
        frame.healthBar.bg:SetColorTexture(r * 0.85, g * 0.85, b * 0.85, 0.90)
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

    -- 5. HoT Icons
    if sim.hots and cfg.auras and cfg.auras.showHots ~= false then
        for i = 1, 4 do
            local hot = sim.hots[i]
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
    elseif sim.hasAggro then
        frame.border:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0) -- Roter Aggro-Rahmen
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

    -- 2. Reichweitenprüfung & Alpha-Fading
    if cfg.display.fadeOutOfRange then
        if UnitIsUnit(unit, "player") then
            frame:SetAlpha(1.0)
        else
            local inRange = UnitInRange(unit)
            if inRange == false then
                frame:SetAlpha(cfg.display.outOfRangeAlpha or 0.4)
            else
                frame:SetAlpha(1.0)
            end
        end
    else
        frame:SetAlpha(1.0)
    end

    -- 3. Lebenspunkte & Farbgebung
    local hp = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)
    local isDead = UnitIsDead(unit)
    local isGhost = UnitIsGhost(unit)
    local isConnected = UnitIsConnected(unit)

    local isSecret = (issecretvalue ~= nil) and (issecretvalue(hp) or issecretvalue(hpMax))

    -- Sichere Prozentberechnung (nur wenn kein Secret Value)
    local pct = 1.0
    if not isSecret and hp and hpMax then
        local ok, val = pcall(function()
            if hpMax > 0 then
                return hp / hpMax
            end
            return 1.0
        end)
        if ok and type(val) == "number" then
            pct = math.max(0, math.min(1.0, val))
        end
    end

    -- Klassenfarben vs. Minimal (Klassischer VuhDo Grün-Gelb-Rot Verlauf)
    local _, class = UnitClass(unit)
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
        frame.healthBar:SetReverseFill(false)
        if isSecret then
            frame.healthBar:SetMinMaxValues(0, hpMax)
            frame.healthBar:SetValue(hp)
        else
            frame.healthBar:SetMinMaxValues(0, (hpMax and hpMax > 0) and hpMax or 1)
            frame.healthBar:SetValue(hp or 0)
        end
        frame.healthBar:SetStatusBarColor(r, g, b, 0.95)
        if cfg.display.colorMode == "MINIMAL" then
            frame.healthBar.bg:SetColorTexture(0.55, 0.08, 0.08, 0.95) -- Rot bei Grün/Rot-Einstellung
        else
            frame.healthBar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.95) -- Schwarz bei Klassenfarben
        end
    else
        -- Reverse / Defizit Modus (VuhDo-Stil): Balken füllt sich rot bei erlittenem Schaden
        frame.healthBar:SetReverseFill(false)
        if isSecret then
            local missing = UnitHealthMissing and UnitHealthMissing(unit) or 0
            frame.healthBar:SetMinMaxValues(0, hpMax)
            frame.healthBar:SetValue(missing)
        else
            local okDef, deficit = pcall(function() return hpMax - hp end)
            local defVal = (okDef and type(deficit) == "number") and deficit or 0
            frame.healthBar:SetMinMaxValues(0, (hpMax and hpMax > 0) and hpMax or 1)
            frame.healthBar:SetValue(defVal)
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

    -- 4. Mana / Power Bar
    if cfg.display.showManaBar then
        frame.powerBar:Show()
        frame.powerText:Show()

        -- Bevorzuge Mana (Typ 0) für Druiden und alle Klassen mit Manapool
        local powerType, powerToken = UnitPowerType(unit)
        local curType = 0
        local okMana, manaMax = pcall(UnitPowerMax, unit, 0)
        local isPowerSecret = (issecretvalue ~= nil) and ((okMana and issecretvalue(manaMax)) or false)
        if not isPowerSecret and okMana and type(manaMax) == "number" and manaMax > 0 then
            curType = 0
        else
            curType = (powerType or 0)
        end

        local power = UnitPower(unit, curType)
        local powerMax = UnitPowerMax(unit, curType)
        local isSecretP = (issecretvalue ~= nil) and (issecretvalue(power) or issecretvalue(powerMax))

        if isSecretP then
            frame.powerBar:SetMinMaxValues(0, powerMax)
            frame.powerBar:SetValue(power)
        else
            local pMax = (powerMax and powerMax > 0) and powerMax or 100
            local pCur = power or 0
            frame.powerBar:SetMinMaxValues(0, pMax)
            frame.powerBar:SetValue(pCur)
        end

        local pr, pg, pb = GetPowerColorRGB(unit, curType)
        frame.powerBar:SetStatusBarColor(pr, pg, pb, 0.95)

        local pctText = ""
        local okPct, calcPct = pcall(function()
            if pMax > 0 then
                return math.floor((pCur / pMax) * 100)
            end
            return 100
        end)
        if okPct and type(calcPct) == "number" then
            pctText = math.max(0, math.min(100, calcPct)) .. "%"
        elseif UnitPowerPercent then
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

    -- 5. HoT Tracker (Tickende HoTs anzeigen)
    local showHots = (cfg.auras == nil) or (cfg.auras.showHots ~= false)
    if showHots and R4L.AuraTracker then
        local okHots, hots = pcall(R4L.AuraTracker.GetPlayerHots, R4L.AuraTracker, unit)
        local hotList = (okHots and type(hots) == "table") and hots or {}
        for i = 1, 4 do
            local hotIcon = frame.hotIcons[i]
            local hot = hotList[i]
            if hot and hot.icon then
                hotIcon.tex:SetTexture(hot.icon)
                hotIcon:SetFrameLevel(frame.hotContainer:GetFrameLevel() + 2)

                -- Restzeit anzeigen
                local cdStr = ""
                local okTime, timeLeft = pcall(function()
                    if hot.expirationTime and hot.expirationTime > 0 then
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

                -- Stacks anzeigen
                local okCount, cnt = pcall(function() return hot.count end)
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
    else
        for i = 1, 4 do
            if frame.hotIcons and frame.hotIcons[i] then
                frame.hotIcons[i]:Hide()
            end
        end
    end

    -- 6. Bannbare Flüche / Vergiftung (Debuff-Border) & Aggro-Anzeige
    local debuffColor = nil
    if R4L.testDebuff then
        debuffColor = R4L.AuraTracker and R4L.AuraTracker.DebuffColors[R4L.testDebuff]
    elseif cfg.auras and cfg.auras.showDebuffs and R4L.AuraTracker then
        local debuff, color = R4L.AuraTracker:GetDispellableDebuff(unit)
        if debuff and color then
            debuffColor = color
        end
    end

    if debuffColor then
        -- Priorität 1: Debuff hat IMMER Vorrang vor Aggro!
        frame.border:SetBackdropBorderColor(debuffColor.r, debuffColor.g, debuffColor.b, 1.0)
    else
        -- Priorität 2: Aggro-Anzeige (Rot, nur wenn der Spieler KEIN Tank ist!)
        local isTank = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK")
        local threat = UnitThreatSituation and UnitThreatSituation(unit)
        -- threat in WoW: 2 = hohes Bedrohungsrisiko / Übergang, 3 = hat Aggro (wird angegriffen)
        local hasAggro = (not isTank) and (threat ~= nil and threat >= 2)
        if hasAggro then
            frame.border:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0) -- Rot bei Aggro auf Nicht-Tank
        else
            frame.border:SetBackdropBorderColor(0, 0, 0, 0.9) -- Normaler Rahmen
        end
    end

    -- 7. Rollen-Icon (Tank, Heiler, DD)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if (not role or role == "NONE") then
        if unit == "player" or UnitIsUnit(unit, "player") then
            local spec = GetSpecialization and GetSpecialization()
            if spec then
                role = GetSpecializationRole(spec)
            end
        end
    end
    if (not role or role == "NONE") and UnitExists(unit) then
        if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
            role = "TANK"
        end
    end
    UpdateRoleIcon(frame, role)
end

