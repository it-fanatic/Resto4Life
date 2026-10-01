--[[
    Resto4Life - UI/GroupHeader.lua
    Gruppen- und Frame-Verwaltung (5-Spieler-Gruppe, Vorbereitung für Raid-Frames,
    Verschiebbarkeit und Sortierungsanwendung)
--]]

local _, R4L = ...
local L = R4L.L

R4L.GroupHeader = {}
local GH = R4L.GroupHeader

GH.frames = {}
GH.maxMembers = 5 -- Erste Version: 5-Spieler-Gruppe
GH.isSimulating = false

function GH:Initialize()
    local cfg = R4L.ProfileManager:GetConfig()
    cfg.general.spacing = 0
    cfg.general.locked = true -- Nach Login / Reload immer gesperrt starten
    if not cfg.general.scale then
        cfg.general.scale = 1.0
    end

    -- Haupt-Container
    local container = CreateFrame("Frame", "Resto4LifeHeader", UIParent)
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.general.posX, cfg.general.posY)
    container:SetSize(cfg.general.frameWidth, cfg.general.frameHeight * self.maxMembers)
    container:SetScale(cfg.general.scale)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:EnableMouse(false)
    self.container = container

    -- Mover / Drag Handle (für entsperrten Zustand)
    local mover = CreateFrame("Frame", "Resto4LifeMover", container, "BackdropTemplate")
    mover:SetAllPoints(container)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0, 0.7, 0.4, 0.4)
    mover:SetBackdropBorderColor(0, 1, 0.6, 1)
    mover:EnableMouse(true)
    mover:EnableMouseWheel(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetFrameLevel(container:GetFrameLevel() + 20)

    local moverText = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moverText:SetPoint("CENTER")
    self.moverText = moverText

    mover:SetScript("OnDragStart", function(self)
        container:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        container:StopMovingOrSizing()
        local left = container:GetLeft()
        local top = container:GetTop()
        local uTop = UIParent:GetTop() or 768
        local cScale = container:GetEffectiveScale()
        local uScale = UIParent:GetEffectiveScale()
        if left and top and cScale and uScale and cScale > 0 then
            local screenLeft = left * cScale
            local screenTop = top * cScale
            local parentTop = uTop * uScale
            cfg.general.posX = math.floor(screenLeft / cScale)
            cfg.general.posY = math.floor((screenTop - parentTop) / cScale)
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.general.posX, cfg.general.posY)
        end
    end)

    mover:SetScript("OnMouseWheel", function(self, delta)
        local scale = cfg.general.scale or 1.0
        if delta > 0 then
            scale = math.min(2.0, scale + 0.05)
        else
            scale = math.max(0.5, scale - 0.05)
        end
        scale = math.floor(scale * 100 + 0.5) / 100
        GH:SetScale(scale)
    end)

    -- Rechtsklick: Wechsel zwischen Spalte und Zeile
    mover:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            local curDir = cfg.general.growthDirection or "DOWN"
            local isHorizontal = (curDir == "RIGHT" or curDir == "LEFT")
            if isHorizontal then
                cfg.general.growthDirection = "DOWN"
            else
                cfg.general.growthDirection = "RIGHT"
            end

            GH:UpdateLayout()
            GH:UpdateMoverText()

            local oText = (cfg.general.growthDirection == "RIGHT") and L["ORIENTATION_HORIZONTAL"] or L["ORIENTATION_VERTICAL"]
            R4L:Print(L["CHAT_ORIENTATION_CHANGED"] or "%s: Anordnung geändert auf |cff00ff00%s|r.", L["MOVER_TITLE"] or "Resto4Life", oText)
        end
    end)

    mover:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0, 0.8, 0.5, 0.55)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["MOVER_TITLE"] or "Resto4Life", 0, 1, 0.6)
        GameTooltip:AddLine(L["MOVER_DRAG"], 1, 1, 1)
        GameTooltip:AddLine(L["MOVER_RCLICK_ORIENTATION"] or "Rechts-Klick: Spalte / Zeile wechseln", 0.4, 0.9, 1)
        GameTooltip:AddLine(L["MOVER_SCALE_HINT"] .. " Skalieren", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    mover:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0.7, 0.4, 0.4)
        GameTooltip:Hide()
    end)

    -- Skalierungs-Ecke (Resize Handle) unten rechts am Mover
    local resizer = CreateFrame("Button", "Resto4LifeResizer", mover, "BackdropTemplate")
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", -1, 1)
    resizer:EnableMouse(true)
    resizer:SetFrameLevel(mover:GetFrameLevel() + 5)
    resizer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resizer:SetBackdropColor(0, 1, 0.6, 0.7)
    resizer:SetBackdropBorderColor(1, 1, 1, 0.9)

    resizer:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0, 1, 0.8, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_TITLE"], 0, 1, 0.6)
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_DESC"], 1, 1, 1)
        GameTooltip:Show()
    end)
    resizer:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 1, 0.6, 0.7)
        GameTooltip:Hide()
    end)

    resizer:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isScaling = true
            local curX, curY = GetCursorPosition()
            local uScale = UIParent:GetEffectiveScale()
            self.startX = curX / uScale
            self.startY = curY / uScale
            self.startScale = cfg.general.scale or 1.0
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

            local newScale = self.startScale + (delta / 180)
            newScale = math.max(0.5, math.min(2.0, newScale))
            newScale = math.floor(newScale * 100 + 0.5) / 100

            if newScale ~= cfg.general.scale then
                GH:SetScale(newScale, true)
            end
        end
    end)

    resizer:SetScript("OnMouseUp", function(self)
        if self.isScaling then
            self.isScaling = false
            R4L:Print(L["CHAT_SCALE_SAVED_FMT"], math.floor((cfg.general.scale or 1.0) * 100))
        end
    end)

    mover:Hide()
    self.mover = mover

    -- Erstelle die 5 Gruppen-Frames
    for i = 1, self.maxMembers do
        local frameName = "Resto4LifeUnitFrame" .. i
        local frame = R4L.UnitFrame:CreateUnitFrame(frameName, container, nil)
        frame:ClearAllPoints()
        if i == 1 then
            frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        else
            frame:SetPoint("TOPLEFT", self.frames[i - 1], "BOTTOMLEFT", 0, 0)
        end
        self.frames[i] = frame
    end

    -- Event-Registrierungen
    R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        GH:UpdateRoster()
    end)
    R4L:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        GH:UpdateRoster()
    end)

    self:UpdateLayout()
    self:UpdateRoster()
end

-- Skalierung setzen & anwenden (Position bleibt pixelgenau an Ort und Stelle)
function GH:SetScale(newScale, silent)
    local cfg = R4L.ProfileManager:GetConfig()
    newScale = math.max(0.5, math.min(2.0, newScale))
    cfg.general.scale = newScale

    if self.container then
        local cScale = self.container:GetEffectiveScale()
        local uScale = UIParent:GetEffectiveScale()
        local left = self.container:GetLeft()
        local top = self.container:GetTop()
        local uTop = UIParent:GetTop() or 768

        self.container:SetScale(newScale)

        if left and top and cScale and uScale and cScale > 0 then
            local screenLeft = left * cScale
            local screenTop = top * cScale
            local newCScale = uScale * newScale
            local parentTop = uTop * uScale

            cfg.general.posX = math.floor(screenLeft / newCScale)
            cfg.general.posY = math.floor((screenTop - parentTop) / newCScale)
        end

        self.container:ClearAllPoints()
        self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.general.posX, cfg.general.posY)
    end

    self:UpdateMoverText()

    if R4L.OptionsUI and R4L.OptionsUI.UpdateScaleDisplay then
        R4L.OptionsUI:UpdateScaleDisplay()
    end

    if not silent then
        R4L:Print(L["CHAT_SCALE_FMT"], math.floor(newScale * 100))
    end
end

-- Position und Skalierung in Bildschirm-Mitte zurücksetzen
function GH:ResetPosition()
    local cfg = R4L.ProfileManager:GetConfig()
    cfg.general.scale = 1.0

    if self.container then
        self.container:SetScale(1.0)
        self.container:ClearAllPoints()
        self.container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

        local left = self.container:GetLeft()
        local top = self.container:GetTop()
        local uTop = UIParent:GetTop() or 768
        if left and top then
            cfg.general.posX = math.floor(left)
            cfg.general.posY = math.floor(top - uTop)
            self.container:ClearAllPoints()
            self.container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.general.posX, cfg.general.posY)
        end
    end

    self:UpdateMoverText()

    if R4L.OptionsUI and R4L.OptionsUI.UpdateScaleDisplay then
        R4L.OptionsUI:UpdateScaleDisplay()
    end

    R4L:Print(L["CHAT_POS_RESET"])
end

function GH:UpdateMoverText()
    if not self.moverText then return end
    local cfg = R4L.ProfileManager:GetConfig()
    local pct = math.floor((cfg.general.scale or 1.0) * 100)
    self.moverText:SetText(string.format("%s\n%s\n%s\n" .. L["MOVER_SCALE_FMT"], L["MOVER_TITLE"], L["MOVER_DRAG"], L["MOVER_SCALE_HINT"], pct))
end

-- Sperren / Entsperren des Rahmens
function GH:ToggleLock(locked)
    local cfg = R4L.ProfileManager:GetConfig()
    if locked == nil then
        cfg.general.locked = not cfg.general.locked
    else
        cfg.general.locked = locked
    end

    if cfg.general.locked then
        self.mover:Hide()
        R4L:Print(L["CHAT_FRAME_LOCKED"])
    else
        self:UpdateMoverText()
        self.mover:Show()
        R4L:Print(L["CHAT_FRAME_UNLOCKED"])
    end
end

-- Layout-Aktualisierung (Breite, Höhe, immer nahtlos 0px)
function GH:UpdateLayout()
    local cfg = R4L.ProfileManager:GetConfig()
    cfg.general.spacing = 0
    if not cfg.general.scale then
        cfg.general.scale = 1.0
    end
    self.container:SetScale(cfg.general.scale)
    local isHorizontal = (cfg.general.growthDirection == "RIGHT" or cfg.general.growthDirection == "LEFT")

    if isHorizontal then
        self.container:SetSize(cfg.general.frameWidth * self.maxMembers, cfg.general.frameHeight)
    else
        self.container:SetSize(cfg.general.frameWidth, cfg.general.frameHeight * self.maxMembers)
    end

    for i, frame in ipairs(self.frames) do
        frame:SetSize(cfg.general.frameWidth, cfg.general.frameHeight)
        frame.powerBar:SetHeight(cfg.general.powerBarHeight)
        frame.healthBar:ClearAllPoints()
        frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        if cfg.display.showManaBar then
            frame.powerBar:Show()
            frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, cfg.general.powerBarHeight + 2)
        else
            frame.powerBar:Hide()
            frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        end

        frame:ClearAllPoints()
        if i == 1 then
            frame:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, 0)
        else
            if cfg.general.growthDirection == "UP" then
                frame:SetPoint("BOTTOMLEFT", self.frames[i - 1], "TOPLEFT", 0, 0)
            elseif cfg.general.growthDirection == "RIGHT" then
                frame:SetPoint("TOPLEFT", self.frames[i - 1], "TOPRIGHT", 0, 0)
            elseif cfg.general.growthDirection == "LEFT" then
                frame:SetPoint("TOPRIGHT", self.frames[i - 1], "TOPLEFT", 0, 0)
            else -- DOWN
                frame:SetPoint("TOPLEFT", self.frames[i - 1], "BOTTOMLEFT", 0, 0)
            end
        end
    end
end

-- Roster aktualisieren (Sortierung Tank -> Melee -> Range -> Heal)
function GH:UpdateRoster()
    if self.isSimulating then
        self:ApplySimulation()
        return
    end

    if InCombatLockdown() then
        R4L:QueueOutOfCombat(function()
            GH:UpdateRoster()
        end)
        return
    end

    local rawUnits = {}

    -- Prüfe Gruppen-Status
    if IsInRaid() then
        -- Zukunft: Raid-Unterstützung mit Kennzeichnung der eigenen Gruppe
        local mySubgroup = 1
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                mySubgroup = subgroup
                break
            end
        end

        -- Für die ersten 5 Frames: Priorisiere Spieler der eigenen Raidgruppe!
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local _, _, subgroup = GetRaidRosterInfo(i)
            if subgroup == mySubgroup and UnitExists(unit) then
                table.insert(rawUnits, unit)
            end
        end
        -- Falls weniger als 5 in der eigenen Gruppe, fülle mit restlichem Raid auf
        if #rawUnits < self.maxMembers then
            for i = 1, GetNumGroupMembers() do
                local unit = "raid" .. i
                if UnitExists(unit) and not tContains(rawUnits, unit) then
                    table.insert(rawUnits, unit)
                    if #rawUnits >= self.maxMembers then break end
                end
            end
        end
    elseif IsInGroup() then
        -- 5-Mann Gruppe
        table.insert(rawUnits, "player")
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                table.insert(rawUnits, unit)
            end
        end
    else
        -- Solo: Nur der Spieler
        table.insert(rawUnits, "player")
    end

    -- Wende Sortierung an: Tank -> Melee -> Range -> Heal
    local sortedUnits = R4L.Sorting:SortUnits(rawUnits)

    for i = 1, self.maxMembers do
        local frame = self.frames[i]
        local unit = sortedUnits[i]

        frame.isSimulated = false
        frame.simData = nil

        if unit and UnitExists(unit) then
            frame.unit = unit
            frame:SetAttribute("unit", unit)
            R4L.ClickCast:ApplyBindingsToFrame(frame)
            R4L.UnitFrame:RegisterUnitEvents(frame, unit)
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        else
            frame.unit = nil
            frame:SetAttribute("unit", nil)
            R4L.UnitFrame:RegisterUnitEvents(frame, nil)
            frame:Hide()
        end
    end
end

function GH:UpdateAllFrames()
    if self.isSimulating then
        self:ApplySimulation()
        return
    end

    for _, frame in ipairs(self.frames) do
        if frame:IsShown() and frame.unit then
            R4L.UnitFrame:UpdateFrame(frame)
        end
    end
end

-- 5-Spieler-Gruppe Test-Modus / Simulation
function GH:ToggleSimulation(enable)
    if enable == nil then
        self.isSimulating = not self.isSimulating
    else
        self.isSimulating = enable
    end

    if self.isSimulating then
        self:ApplySimulation()
        R4L:Print(L["CHAT_SIM_STARTED"])
    else
        for i = 1, self.maxMembers do
            local frame = self.frames[i]
            frame.isSimulated = false
            frame.simData = nil
        end
        self:UpdateRoster()
        R4L:Print(L["CHAT_SIM_STOPPED"])
    end
end

function GH:ApplySimulation()
    local playerName = UnitName("player") or "Mirulas"
    local simRoster = {
        {
            name = "Thorvald",
            class = "WARRIOR",
            role = "TANK",
            hp = 92,
            power = 45,
            pr = 0.9, pg = 0.2, pb = 0.2,
            hots = {
                { icon = 136081, cd = "11", count = "" }, -- Verjüngung
            },
        },
        {
            name = "Shadowfang",
            class = "ROGUE",
            role = "DAMAGER",
            hp = 78,
            power = 100,
            pr = 1.0, pg = 0.9, pb = 0.1,
            hasAggro = true, -- Simuliert: DD hat Aggro gezogen -> Roter Rahmen!
            hots = nil,
        },
        {
            name = "Elysia",
            class = "MAGE",
            role = "DAMAGER",
            hp = 64,
            power = 85,
            pr = 0.0, pg = 0.5, pb = 1.0,
            hasAggro = true, -- Hat Aggro, ABER auch Fluch -> Fluch (Lila) hat Vorrang vor Aggro!
            hots = {
                { icon = 136081, cd = "6", count = "" },
                { icon = 136085, cd = "9", count = "" }, -- Nachwachsen
            },
            debuffColor = { r = 0.6, g = 0.0, b = 1.0 }, -- Fluch (Lila Border)
        },
        {
            name = "Valen",
            class = "PRIEST",
            role = "HEALER",
            hp = 45,
            power = 40,
            pr = 0.0, pg = 0.5, pb = 1.0,
            hots = {
                { icon = 136081, cd = "3", count = "" },
                { icon = 136048, cd = "8", count = "2" }, -- Blühendes Leben (2 Stacks)
            },
        },
        {
            name = playerName,
            class = "DRUID",
            role = "HEALER",
            hp = 100,
            power = 72,
            pr = 0.0, pg = 0.5, pb = 1.0,
            hots = {
                { icon = 136081, cd = "14", count = "" },
            },
        },
    }


    for i = 1, self.maxMembers do
        local frame = self.frames[i]
        local sim = simRoster[i]
        if sim then
            frame.isSimulated = true
            frame.simData = sim
            frame:Show()
            R4L.UnitFrame:UpdateFrame(frame)
        end
    end
end

R4L:RegisterEvent("PLAYER_LOGIN", function()
    GH:Initialize()
end)
