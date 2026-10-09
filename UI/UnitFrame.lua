--[[
    Resto4Life - UI/UnitFrame.lua
    Sichere Unit-Frame Komponente mit Health-Bar (Normal/Reverse), Mana-Bar,
    Klassen-/Minimalfarben, HoTs und Debuff-Hervorhebung
--]]

local _, R4L = ...

R4L.UnitFrame = {}
local UF = R4L.UnitFrame

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
    pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
    pcall(frame.RegisterEvent, frame, "PLAYER_ROLES_ASSIGNED")
    pcall(frame.RegisterEvent, frame, "PLAYER_SPECIALIZATION_CHANGED")
    pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
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
    frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 0.95)
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

    -- Rollen-Icon (Tank, Heiler, DD) mittig links auf gleicher Höhe wie der Name
    frame.roleIcon = frame.healthBar:CreateTexture(nil, "OVERLAY", nil, 7)
    frame.roleIcon:SetSize(13, 13)
    frame.roleIcon:SetPoint("LEFT", frame.healthBar, "LEFT", 4, -7)
    frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    frame.roleIcon:SetHorizTile(false)
    frame.roleIcon:SetVertTile(false)
    frame.roleIcon:Hide()

    -- Fremde HoT Icons Container (oben links)
    frame.otherHotContainer = CreateFrame("Frame", nil, frame)
    frame.otherHotContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.otherHotContainer:SetSize(60, 20)
    frame.otherHotContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.otherHotContainer:Show()

    frame.otherHotIcons = {}
    for i = 1, 3 do
        local hotIcon = CreateFrame("Frame", nil, frame.otherHotContainer, "BackdropTemplate")
        hotIcon:SetSize(16, 16)
        hotIcon:SetPoint("LEFT", frame.otherHotContainer, "LEFT", ((i - 1) * 18), 0)
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

    -- Eigene HoT Icons Container (oben rechts)
    frame.hotContainer = CreateFrame("Frame", nil, frame)
    frame.hotContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.hotContainer:SetSize(76, 20)
    frame.hotContainer:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.hotContainer:Show()

    frame.hotIcons = {}
    for i = 1, 4 do
        local hotIcon = CreateFrame("Frame", nil, frame.hotContainer, "BackdropTemplate")
        hotIcon:SetSize(16, 16)
        hotIcon:SetPoint("RIGHT", frame.hotContainer, "RIGHT", -((i - 1) * 18), 0)
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
    else
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
    local targetAlpha = 1.0
    if cfg.display.fadeOutOfRange and not UnitIsUnit(unit, "player") then
        local inRange = true
        if R4L.IsUnitInRange then
            inRange = R4L:IsUnitInRange(unit)
        else
            local okRange, rVal = pcall(UnitInRange, unit)
            if okRange and rVal ~= nil then inRange = (rVal == true or rVal == 1) end
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
    local okDead, deadVal = pcall(UnitIsDead, unit)
    if okDead and deadVal ~= nil then
        local okTest, res = pcall(function() return deadVal == true end)
        if okTest and res then isDead = true end
    end

    local isGhost = false
    local okGhost, ghostVal = pcall(UnitIsGhost, unit)
    if okGhost and ghostVal ~= nil then
        local okTest, res = pcall(function() return ghostVal == true end)
        if okTest and res then isGhost = true end
    end

    local isConnected = true
    local okConn, connVal = pcall(UnitIsConnected, unit)
    if okConn and connVal ~= nil then
        local okTest, res = pcall(function() return connVal == false end)
        if okTest and res then isConnected = false end
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

    -- 4. Mana / Power Bar
    if cfg.display.showManaBar then
        frame.powerBar:Show()
        frame.powerText:Show()

        local powerType = 0
        local okType, pType = pcall(UnitPowerType, unit)
        if okType and type(pType) == "number" then
            powerType = pType
        end

        -- Bevorzuge Mana (Typ 0) falls Einheit Manapool besitzt
        local curType = 0
        local okMana, manaMax = pcall(UnitPowerMax, unit, 0)
        local hasManaPool = false
        if okMana and manaMax ~= nil then
            local okCheck, res = pcall(function() return manaMax > 0 end)
            if okCheck and res then
                hasManaPool = true
            end
        end

        if hasManaPool then
            curType = 0
        else
            curType = powerType
        end

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
            pcall(frame.powerBar.SetMinMaxValues, frame.powerBar, 0, powerMax or 100)
            pcall(frame.powerBar.SetValue, frame.powerBar, power or 0)
        end

        local pr, pg, pb = GetPowerColorRGB(unit, curType)
        frame.powerBar:SetStatusBarColor(pr, pg, pb, 0.95)

        local pctText = ""
        local okCalc, calcPct = pcall(function()
            if power and powerMax and powerMax > 0 then
                if power >= powerMax then return "" end
                return math.floor((power / powerMax) * 100) .. "%"
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
    if showHots and R4L.AuraTracker then
        local okHots, ownHots, otherHots = pcall(R4L.AuraTracker.GetPlayerHots, R4L.AuraTracker, unit)
        local ownList = (okHots and type(ownHots) == "table") and ownHots or {}
        local otherList = (okHots and type(otherHots) == "table") and otherHots or {}

        -- 1. Eigene HoTs (oben rechts, max 4)
        for i = 1, 4 do
            local hotIcon = frame.hotIcons[i]
            local hot = ownList[i]
            if hot and hot.icon then
                hotIcon.tex:SetTexture(hot.icon)
                hotIcon:SetFrameLevel(frame.hotContainer:GetFrameLevel() + 2)

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

        -- 2. Fremde HoTs (oben links, max 3)
        if frame.otherHotIcons then
            for i = 1, 3 do
                local hotIcon = frame.otherHotIcons[i]
                local hot = otherList[i]
                if hot and hot.icon then
                    hotIcon.tex:SetTexture(hot.icon)
                    hotIcon:SetFrameLevel(frame.otherHotContainer:GetFrameLevel() + 2)

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
        end
    else
        for i = 1, 4 do
            if frame.hotIcons and frame.hotIcons[i] then
                frame.hotIcons[i]:Hide()
            end
        end
        if frame.otherHotIcons then
            for i = 1, 3 do
                frame.otherHotIcons[i]:Hide()
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
        local isTank = false
        if UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
            isTank = true
        elseif R4L.Sorting and R4L.Sorting:GetUnitRole(unit) == "TANK" then
            isTank = true
        end

        local inCombat = false
        local okCombat, cVal = pcall(UnitAffectingCombat, unit)
        if okCombat and cVal == true then
            inCombat = true
        end

        local threat = nil
        if UnitThreatSituation then
            local okThreat, tVal = pcall(UnitThreatSituation, unit)
            if okThreat and type(tVal) == "number" then
                threat = tVal
            end
        end

        -- threat in WoW:
        -- nil = kein Kampf / nicht auf Bedrohungsliste
        -- 0 = unter 100% Bedrohung (keine Aggro)
        -- 1 = hohe Bedrohung, aber Mob greift noch jemand anderen an
        -- 2 = Übergang / verliert/gewinnt gerade Aggro
        -- 3 = hat direkte Aggro (wird geschlagen)
        local hasAggro = (not isTank) and inCombat and (threat ~= nil and threat >= 2)
        if hasAggro then
            frame.border:SetBackdropBorderColor(1.0, 0.1, 0.1, 1.0) -- Rot bei Aggro auf Nicht-Tank
        else
            frame.border:SetBackdropBorderColor(0, 0, 0, 0.9) -- Normaler schwarzer Rahmen
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

