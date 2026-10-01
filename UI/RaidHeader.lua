--[[
    Resto4Life - UI/RaidHeader.lua
    Modulares Raid-Heiler-System für 10er, 25er und 40er Raids
    Unterstützt separate Container für:
      1. Markierte Tanks (Main Tanks)
      2. Eigene Gruppe (Subgruppe des Spielers)
      3. Restlicher Raid (oder Gesamtraid bei Deaktivierung von 1 & 2)
      4. Begleiter (Pets)
    Jeder Container besitzt einen eigenen verschiebbaren & skalierbaren Mover.
--]]

local _, R4L = ...
local L = R4L.L

R4L.RaidHeader = {}
local RH = R4L.RaidHeader

RH.isSimulating = false
RH.simMode = nil -- "10", "25", "40"
RH.containers = {}
RH.isLocked = true

-- Hilfsfunktion: Mover für einen Container erstellen
local function CreateContainerMover(container, titleKey, posKey, onScale)
    local mover = CreateFrame("Frame", container:GetName() .. "Mover", container, "BackdropTemplate")
    mover:SetAllPoints(container)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0, 0.6, 0.8, 0.45)
    mover:SetBackdropBorderColor(0, 0.9, 1.0, 1)
    mover:EnableMouse(true)
    mover:EnableMouseWheel(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetFrameLevel(container:GetFrameLevel() + 25)

    local moverText = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moverText:SetPoint("CENTER")
    mover.text = moverText

    mover:SetScript("OnDragStart", function(self)
        container:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        container:StopMovingOrSizing()
        local cfg = R4L.ProfileManager:GetConfig()
        local left = container:GetLeft()
        local top = container:GetTop()
        local uTop = UIParent:GetTop() or 768
        local cScale = container:GetEffectiveScale()
        local uScale = UIParent:GetEffectiveScale()
        if left and top and cScale and uScale and cScale > 0 then
            local screenLeft = left * cScale
            local screenTop = top * cScale
            local parentTop = uTop * uScale
            if not cfg.raid[posKey] then cfg.raid[posKey] = {} end
            cfg.raid[posKey].x = math.floor(screenLeft / cScale)
            cfg.raid[posKey].y = math.floor((screenTop - parentTop) / cScale)
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.raid[posKey].x, cfg.raid[posKey].y)
        end
    end)

    mover:SetScript("OnMouseWheel", function(self, delta)
        local cfg = R4L.ProfileManager:GetConfig()
        if not cfg.raid[posKey] then cfg.raid[posKey] = {} end
        local scale = cfg.raid[posKey].scale or 1.0
        if delta > 0 then
            scale = math.min(2.0, scale + 0.05)
        else
            scale = math.max(0.5, scale - 0.05)
        end
        scale = math.floor(scale * 100 + 0.5) / 100
        cfg.raid[posKey].scale = scale
        container:SetScale(scale)
        if onScale then onScale(scale) end
        mover:UpdateText()
    end)

    -- Resize Handle (Ziehecke unten rechts)
    local resizer = CreateFrame("Button", container:GetName() .. "Resizer", mover, "BackdropTemplate")
    resizer:SetSize(14, 14)
    resizer:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", -1, 1)
    resizer:EnableMouse(true)
    resizer:SetFrameLevel(mover:GetFrameLevel() + 5)
    resizer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resizer:SetBackdropColor(0, 0.8, 1.0, 0.7)
    resizer:SetBackdropBorderColor(1, 1, 1, 0.9)

    resizer:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0, 1.0, 1.0, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_TITLE"], 0, 0.8, 1.0)
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_DESC"], 1, 1, 1)
        GameTooltip:Show()
    end)
    resizer:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0.8, 1.0, 0.7)
        GameTooltip:Hide()
    end)

    resizer:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isScaling = true
            local curX, curY = GetCursorPosition()
            local uScale = UIParent:GetEffectiveScale()
            self.startX = curX / uScale
            self.startY = curY / uScale
            local cfg = R4L.ProfileManager:GetConfig()
            self.startScale = (cfg.raid[posKey] and cfg.raid[posKey].scale) or 1.0
        end
    end)

    resizer:SetScript("OnUpdate", function(self)
        if self.isScaling then
            local curX, curY = GetCursorPosition()
            local uScale = UIParent:GetEffectiveScale()
            local cX = curX / uScale
            local cY = curY / uScale
            local dx = cX - self.startX
            local dy = self.startY - cY
            local delta = (dx + dy) / 2
            local newScale = self.startScale + (delta / 160)
            newScale = math.max(0.5, math.min(2.0, newScale))
            newScale = math.floor(newScale * 100 + 0.5) / 100
            local cfg = R4L.ProfileManager:GetConfig()
            if not cfg.raid[posKey] then cfg.raid[posKey] = {} end
            if newScale ~= cfg.raid[posKey].scale then
                cfg.raid[posKey].scale = newScale
                container:SetScale(newScale)
                if onScale then onScale(newScale) end
                mover:UpdateText()
            end
        end
    end)

    resizer:SetScript("OnMouseUp", function(self)
        self.isScaling = false
    end)

    function mover:UpdateText()
        local cfg = R4L.ProfileManager:GetConfig()
        local s = (cfg.raid[posKey] and cfg.raid[posKey].scale) or 1.0
        local pct = math.floor(s * 100 + 0.5)
        moverText:SetText(string.format("%s\n%s\n(%d%%)", L[titleKey] or titleKey, L["MOVER_DRAG"], pct))
    end

    mover:UpdateText()
    mover:Hide()
    container.mover = mover
    return mover
end

-- Erstellt einen Sub-Header-Container
local function CreateSubContainer(name, count, titleKey, posKey, defaultWidth, defaultHeight, cols, rows)
    local container = CreateFrame("Frame", name, UIParent)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:EnableMouse(false)

    local cfg = R4L.ProfileManager:GetConfig()
    local posData = (cfg.raid and cfg.raid[posKey]) or { x = 200, y = -200, scale = 1.0 }
    container:SetScale(posData.scale or 1.0)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", posData.x or 200, posData.y or -200)

    container.frames = {}
    container.maxFrames = count

    for i = 1, count do
        local frameName = name .. "Unit" .. i
        local frame = R4L.UnitFrame:CreateUnitFrame(frameName, container, nil)
        frame:Hide()
        container.frames[i] = frame
    end

    CreateContainerMover(container, titleKey, posKey)

    -- Ordnet die Frames im Container bündig (0px spacing) an (Spalte / Zeile)
    function container:LayoutFrames(w, h, unitsPerGroup, orientation)
        local upg = unitsPerGroup or 5
        local isHorizontal = (orientation == "HORIZONTAL")

        for i = 1, self.maxFrames do
            local f = self.frames[i]
            f:SetSize(w, h)
            f.healthBar:ClearAllPoints()
            f.healthBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
            if cfg.display.showManaBar then
                f.powerBar:Show()
                f.healthBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, (cfg.general.powerBarHeight or 10) + 2)
            else
                f.powerBar:Hide()
                f.healthBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
            end

            f:ClearAllPoints()
            if isHorizontal then
                -- Zeile (Horizontal): Einheiten laufen nebeneinander, Gruppen untereinander
                local row = math.floor((i - 1) / upg)
                local col = (i - 1) % upg
                f:SetPoint("TOPLEFT", self, "TOPLEFT", col * w, -(row * h))
            else
                -- Spalte (Vertikal): Einheiten laufen untereinander, Gruppen nebeneinander
                local col = math.floor((i - 1) / upg)
                local row = (i - 1) % upg
                f:SetPoint("TOPLEFT", self, "TOPLEFT", col * w, -(row * h))
            end
        end

        if isHorizontal then
            local totalRows = math.ceil(self.maxFrames / upg)
            self:SetSize(upg * w, totalRows * h)
        else
            local totalCols = math.ceil(self.maxFrames / upg)
            self:SetSize(totalCols * w, upg * h)
        end
    end

    container:Hide()
    return container
end

function RH:Initialize()
    if self.initialized then return end
    self.initialized = true

    local cfg = R4L.ProfileManager:GetConfig()
    local rCfg = cfg.raid

    -- 1. Tank-Container (bis zu 4 Tanks)
    self.tankContainer = CreateSubContainer(
        "Resto4LifeTankHeader",
        4,
        "MOVER_TANK_TITLE",
        "tankPos",
        rCfg.tankWidth or 120,
        rCfg.tankHeight or 44,
        1,
        4
    )

    -- 2. Eigene Gruppe Container (5 Spieler)
    self.myGroupContainer = CreateSubContainer(
        "Resto4LifeMyGroupHeader",
        5,
        "MOVER_MYGROUP_TITLE",
        "myGroupPos",
        rCfg.raidWidth or 90,
        rCfg.raidHeight or 40,
        1,
        5
    )

    -- 3. Restlicher Raid Container (bis zu 40 Spieler)
    self.raidContainer = CreateSubContainer(
        "Resto4LifeRaidHeader",
        40,
        "MOVER_RAID_TITLE",
        "raidPos",
        rCfg.raidWidth or 90,
        rCfg.raidHeight or 40,
        8,
        5
    )

    -- 4. Pet Container (bis zu 10 Begleiter)
    self.petContainer = CreateSubContainer(
        "Resto4LifePetHeader",
        10,
        "MOVER_PET_TITLE",
        "petPos",
        rCfg.petWidth or 80,
        rCfg.petHeight or 32,
        2,
        5
    )

    self:UpdateLayout()

    self.containers = {
        self.tankContainer,
        self.myGroupContainer,
        self.raidContainer,
        self.petContainer,
    }

    -- Events für Roster-Updates
    R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        RH:UpdateRoster()
    end)
    R4L:RegisterEvent("PLAYER_ROLES_ASSIGNED", function()
        RH:UpdateRoster()
    end)
    R4L:RegisterEvent("UNIT_PET", function()
        if cfg.raid and cfg.raid.showPets then
            RH:UpdateRoster()
        end
    end)

    self:UpdateLayout()
    self:UpdateRoster()
end

-- Sperren / Entsperren aller Raid-Frames
function RH:ToggleLock(locked)
    local cfg = R4L.ProfileManager:GetConfig()
    if locked == nil then
        self.isLocked = not self.isLocked
    else
        self.isLocked = locked
    end

    local inRaid = IsInRaid()

    for _, c in ipairs(self.containers) do
        if c.mover then
            if not self.isLocked then
                local shouldShow = cfg.raid and cfg.raid.enabled
                if c == self.tankContainer and not cfg.raid.showTanks then shouldShow = false end
                if c == self.myGroupContainer and not cfg.raid.showMyGroup then shouldShow = false end
                if c == self.raidContainer and not cfg.raid.showRaid then shouldShow = false end
                if c == self.petContainer and not cfg.raid.showPets then shouldShow = false end

                if shouldShow then
                    c:Show()
                    c.mover:UpdateText()
                    c.mover:Show()
                else
                    c.mover:Hide()
                end
            else
                c.mover:Hide()
                if not inRaid and not self.isSimulating then
                    c:Hide()
                end
            end
        end
    end
end

-- Positionen aller Raid-Frames in Standard-Anordnung zurücksetzen
function RH:ResetPositions()
    local cfg = R4L.ProfileManager:GetConfig()
    cfg.raid.tankPos = { x = 120, y = -260, scale = 1.0 }
    cfg.raid.myGroupPos = { x = 260, y = -260, scale = 1.0 }
    cfg.raid.raidPos = { x = 380, y = -260, scale = 1.0 }
    cfg.raid.petPos = { x = 380, y = -500, scale = 1.0 }

    local defaults = {
        { container = self.tankContainer, pos = cfg.raid.tankPos },
        { container = self.myGroupContainer, pos = cfg.raid.myGroupPos },
        { container = self.raidContainer, pos = cfg.raid.raidPos },
        { container = self.petContainer, pos = cfg.raid.petPos },
    }

    for _, d in ipairs(defaults) do
        if d.container then
            d.container:SetScale(1.0)
            d.container:ClearAllPoints()
            d.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", d.pos.x, d.pos.y)
            if d.container.mover then d.container.mover:UpdateText() end
        end
    end

    R4L:Print(L["RAID_RESET_POS"] .. ": Standard-Layout wiederhergestellt.")
end

-- Aktualisiert Größen, Abstände & Orientierung (Spalte / Zeile)
function RH:UpdateLayout()
    local cfg = R4L.ProfileManager:GetConfig()
    local r = cfg.raid

    if self.tankContainer then
        self.tankContainer:LayoutFrames(r.tankWidth or 120, r.tankHeight or 44, 4, r.tankOrientation or "VERTICAL")
    end
    if self.myGroupContainer then
        self.myGroupContainer:LayoutFrames(r.raidWidth or 90, r.raidHeight or 40, 5, r.myGroupOrientation or "VERTICAL")
    end
    if self.raidContainer then
        self.raidContainer:LayoutFrames(r.raidWidth or 90, r.raidHeight or 40, 5, r.raidOrientation or "VERTICAL")
    end
    if self.petContainer then
        self.petContainer:LayoutFrames(r.petWidth or 80, r.petHeight or 32, 5, r.petOrientation or "VERTICAL")
    end
end

-- Hauptfunktion: Weist Einheiten den passenden Containern zu (inkl. Deduplizierung)
function RH:UpdateRoster()
    if not self.initialized then return end

    if self.isSimulating then
        self:ApplySimulation()
        return
    end

    local inRaid = IsInRaid()
    local cfg = R4L.ProfileManager:GetConfig()

    -- Wenn wir nicht im Raid sind (und keine Simulation aktiv ist):
    if not inRaid then
        for _, c in ipairs(self.containers) do
            c:Hide()
        end
        if R4L.GroupHeader and R4L.GroupHeader.container then
            R4L.GroupHeader.container:Show()
            R4L.GroupHeader:UpdateRoster()
        end
        return
    end

    -- Wir sind im Raid: 5er-Gruppenframe ausblenden
    if R4L.GroupHeader and R4L.GroupHeader.container then
        R4L.GroupHeader.container:Hide()
    end

    local numMembers = GetNumGroupMembers()
    local assignedUnits = {}

    -- 1. Eigene Subgruppe ermitteln
    local mySubgroup = 1
    for i = 1, numMembers do
        local unit = "raid" .. i
        if UnitIsUnit(unit, "player") then
            local _, _, subgroup = GetRaidRosterInfo(i)
            mySubgroup = subgroup or 1
            break
        end
    end

    -- 2. Markierte Tanks zuweisen
    local tankUnits = {}
    if cfg.raid.showTanks then
        for i = 1, numMembers do
            local unit = "raid" .. i
            local isTank = (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK")
            local isMainTank = (GetPartyAssignment and GetPartyAssignment("MAINTANK", unit))
            if isTank or isMainTank then
                table.insert(tankUnits, unit)
                assignedUnits[unit] = true
                if #tankUnits >= self.tankContainer.maxFrames then break end
            end
        end
    end

    for i = 1, self.tankContainer.maxFrames do
        local frame = self.tankContainer.frames[i]
        local unit = tankUnits[i]
        if unit and UnitExists(unit) then
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            R4L.UnitFrame:RegisterUnitEvents(frame, unit)
            R4L.ClickCast:ApplyBindingsToFrame(frame)
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        else
            frame.unit = nil
            frame:SetAttribute("unit", nil)
            frame:Hide()
        end
    end
    self.tankContainer:SetShown(cfg.raid.showTanks and #tankUnits > 0)

    -- 3. Eigene Gruppe zuweisen (ohne bereits im Tankframe befindliche)
    local myGroupUnits = {}
    if cfg.raid.showMyGroup then
        for i = 1, numMembers do
            local unit = "raid" .. i
            local _, _, subgroup = GetRaidRosterInfo(i)
            if subgroup == mySubgroup and not assignedUnits[unit] then
                table.insert(myGroupUnits, unit)
                assignedUnits[unit] = true
                if #myGroupUnits >= self.myGroupContainer.maxFrames then break end
            end
        end
    end

    for i = 1, self.myGroupContainer.maxFrames do
        local frame = self.myGroupContainer.frames[i]
        local unit = myGroupUnits[i]
        if unit and UnitExists(unit) then
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            R4L.UnitFrame:RegisterUnitEvents(frame, unit)
            R4L.ClickCast:ApplyBindingsToFrame(frame)
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        else
            frame.unit = nil
            frame:SetAttribute("unit", nil)
            frame:Hide()
        end
    end
    self.myGroupContainer:SetShown(cfg.raid.showMyGroup and #myGroupUnits > 0)

    -- 4. Restlicher Raid (oder gesamter Raid falls Tanks/Eigene Gruppe aus sind)
    local remainingUnits = {}
    for i = 1, numMembers do
        local unit = "raid" .. i
        if not assignedUnits[unit] then
            table.insert(remainingUnits, unit)
        end
    end

    for i = 1, self.raidContainer.maxFrames do
        local frame = self.raidContainer.frames[i]
        local unit = remainingUnits[i]
        if unit and UnitExists(unit) and cfg.raid.showRaid then
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            R4L.UnitFrame:RegisterUnitEvents(frame, unit)
            R4L.ClickCast:ApplyBindingsToFrame(frame)
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        else
            frame.unit = nil
            frame:SetAttribute("unit", nil)
            frame:Hide()
        end
    end
    self.raidContainer:SetShown(cfg.raid.showRaid and #remainingUnits > 0)

    -- 5. Begleiter (Pets)
    local petUnits = {}
    if cfg.raid.showPets then
        for i = 1, numMembers do
            local petUnit = "raidpet" .. i
            if UnitExists(petUnit) then
                table.insert(petUnits, petUnit)
                if #petUnits >= self.petContainer.maxFrames then break end
            end
        end
    end

    for i = 1, self.petContainer.maxFrames do
        local frame = self.petContainer.frames[i]
        local unit = petUnits[i]
        if unit and UnitExists(unit) and cfg.raid.showPets then
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            R4L.UnitFrame:RegisterUnitEvents(frame, unit)
            R4L.ClickCast:ApplyBindingsToFrame(frame)
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        else
            frame.unit = nil
            frame:SetAttribute("unit", nil)
            frame:Hide()
        end
    end
    self.petContainer:SetShown(cfg.raid.showPets and #petUnits > 0)
end

function RH:UpdateAllFrames()
    if self.isSimulating then
        self:ApplySimulation()
        return
    end

    for _, c in ipairs(self.containers) do
        for _, f in ipairs(c.frames) do
            if f:IsShown() and f.unit then
                R4L.UnitFrame:UpdateFrame(f)
            end
        end
    end
end

-- =========================================================================
-- SIMULATIONEN (10er, 25er, 40er, Tanks, Eigene Gruppe, Pets)
-- =========================================================================

function RH:ToggleSimulation(mode)
    if self.simMode == mode or not mode then
        self.isSimulating = false
        self.simMode = nil
        for _, c in ipairs(self.containers) do
            for _, f in ipairs(c.frames) do
                f.isSimulated = false
                f.simData = nil
                f:Hide()
            end
            c:Hide()
        end
        R4L:Print(L["RAID_SIM_STOP"])
        self:UpdateRoster()
    else
        self.isSimulating = true
        self.simMode = mode
        if R4L.GroupHeader and R4L.GroupHeader.container then
            R4L.GroupHeader.container:Hide()
        end
        self:ApplySimulation()
        R4L:Print("Raid-Simulation aktiv: |cff00ff00" .. mode .. "er-Raid|r")
    end
end

function RH:ApplySimulation()
    local mode = self.simMode or "25"
    local cfg = R4L.ProfileManager:GetConfig()

    -- 1. Simulierte Tanks (2 Tanks)
    local simTanks = {
        { name = "Gorgar", class = "WARRIOR", role = "TANK", hp = 95, power = 60, pr = 1.0, pg = 0.2, pb = 0.2 },
        { name = "Brann", class = "PALADIN", role = "TANK", hp = 88, power = 80, pr = 0.0, pg = 0.5, pb = 1.0, hots = { { icon = 136081, cd = "12", count = "" } } },
    }

    -- 2. Eigene Gruppe (5 Spieler inkl. Spieler)
    local pName = UnitName("player") or "Mirulas"
    local simMyGroup = {
        { name = "Gorgar", class = "WARRIOR", role = "TANK", hp = 95, power = 60, pr = 1.0, pg = 0.2, pb = 0.2 },
        { name = "Shadowfang", class = "ROGUE", role = "DAMAGER", hp = 74, power = 100, pr = 1.0, pg = 0.9, pb = 0.1, hasAggro = true },
        { name = "Elysia", class = "MAGE", role = "DAMAGER", hp = 62, power = 85, pr = 0.0, pg = 0.5, pb = 1.0, debuffColor = { r = 0.6, g = 0.0, b = 1.0 } },
        { name = "Valen", class = "PRIEST", role = "HEALER", hp = 45, power = 40, pr = 0.0, pg = 0.5, pb = 1.0, hots = { { icon = 136081, cd = "4", count = "" } } },
        { name = pName, class = "DRUID", role = "HEALER", hp = 100, power = 90, pr = 0.0, pg = 0.5, pb = 1.0, hots = { { icon = 136081, cd = "14", count = "" } } },
    }

    -- 3. Restlicher Raid Pool
    local raidNames = {
        "Aethelgard", "Valkyrie", "Ironhide", "Sylvanas", "Khadgar", "Jaina", "Thrall", "Malfurion",
        "Illidan", "Tyrande", "Baine", "Anduin", "Turalyon", "Alleria", "Lor'themar", "Liadrin",
        "Genn", "Muradin", "Falstad", "Kurdran", "Moira", "Velen", "Nobundo", "Maraad",
        "Yrel", "Akama", "Chen", "Li Li", "Taran Zhu", "Vol'jin", "Rokhan", "Bwonsamdi",
        "Rexxar", "Misha", "Garona", "Shaw", "Tess", "Vanessa", "Lilian", "Calia"
    }
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "DEATHKNIGHT", "EVOKER" }
    local roles = { "DAMAGER", "DAMAGER", "HEALER", "DAMAGER", "DAMAGER" }

    local targetCount = (mode == "10" and 10) or (mode == "25" and 25) or 40

    -- Container anzeigen/verbergen nach Konfiguration
    local showTanks = cfg.raid.showTanks
    local showMyGroup = cfg.raid.showMyGroup
    local showRaid = cfg.raid.showRaid
    local showPets = cfg.raid.showPets

    -- 1. Tanks füllen
    for i = 1, self.tankContainer.maxFrames do
        local f = self.tankContainer.frames[i]
        local s = simTanks[i]
        if s and showTanks then
            f.isSimulated = true
            f.simData = s
            f:Show()
            R4L.UnitFrame:UpdateFrame(f)
        else
            f.isSimulated = false
            f:Hide()
        end
    end
    self.tankContainer:SetShown(showTanks)

    -- 2. Eigene Gruppe füllen
    for i = 1, self.myGroupContainer.maxFrames do
        local f = self.myGroupContainer.frames[i]
        local s = simMyGroup[i]
        if s and showMyGroup then
            f.isSimulated = true
            f.simData = s
            f:Show()
            R4L.UnitFrame:UpdateFrame(f)
        else
            f.isSimulated = false
            f:Hide()
        end
    end
    self.myGroupContainer:SetShown(showMyGroup)

    -- 3. Restlicher Raid füllen
    local startIndex = 1
    local remainingCount = targetCount
    if showTanks then remainingCount = remainingCount - 2 end
    if showMyGroup then remainingCount = remainingCount - 5 end
    remainingCount = math.max(0, remainingCount)

    for i = 1, self.raidContainer.maxFrames do
        local f = self.raidContainer.frames[i]
        if i <= remainingCount and showRaid then
            local cName = raidNames[i] or ("Raid" .. i)
            local cClass = classes[((i - 1) % #classes) + 1]
            local cRole = roles[((i - 1) % #roles) + 1]
            local hp = math.max(30, 100 - ((i * 7) % 65))
            local simData = {
                name = cName,
                class = cClass,
                role = cRole,
                hp = hp,
                power = 75,
                pr = 0.0, pg = 0.5, pb = 1.0,
            }
            if (i % 4) == 0 then
                simData.hots = { { icon = 136081, cd = tostring(8 + (i % 6)), count = "" } }
            end
            if i == 3 then
                simData.hasAggro = true
            elseif i == 6 then
                simData.debuffColor = { r = 0.0, g = 0.8, b = 0.0 } -- Gift
            end

            f.isSimulated = true
            f.simData = simData
            f:Show()
            R4L.UnitFrame:UpdateFrame(f)
        else
            f.isSimulated = false
            f:Hide()
        end
    end
    self.raidContainer:SetShown(showRaid and remainingCount > 0)

    -- 4. Pets füllen
    local simPets = {
        { name = "Hati (Pet)", class = "HUNTER", role = "DAMAGER", hp = 82, power = 100, pr = 1.0, pg = 0.6, pb = 0.0 },
        { name = "Wichtel (Pet)", class = "WARLOCK", role = "DAMAGER", hp = 90, power = 100, pr = 0.0, pg = 0.5, pb = 1.0 },
        { name = "Katze (Pet)", class = "HUNTER", role = "DAMAGER", hp = 55, power = 80, pr = 1.0, pg = 0.6, pb = 0.0 },
        { name = "Leerwandler", class = "WARLOCK", role = "TANK", hp = 70, power = 100, pr = 0.0, pg = 0.5, pb = 1.0 },
    }
    for i = 1, self.petContainer.maxFrames do
        local f = self.petContainer.frames[i]
        local s = simPets[i]
        if s and showPets then
            f.isSimulated = true
            f.simData = s
            f:Show()
            R4L.UnitFrame:UpdateFrame(f)
        else
            f.isSimulated = false
            f:Hide()
        end
    end
    self.petContainer:SetShown(showPets)
end

-- Automatische Initialisierung
R4L:RegisterEvent("PLAYER_LOGIN", function()
    RH:Initialize()
end)
