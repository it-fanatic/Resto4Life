--[[
    Resto4Life - UI/MinimapButton.lua
    Ruckelfreier, moderner Minimap-Button mit AddonCompartment-Integration für WoW Retail
--]]

local _, R4L = ...
local L = R4L.L

R4L.MinimapButton = {}
local MB = R4L.MinimapButton

local button = nil

-- Dynamische Berechnung des Minimap-Radius (funktioniert bei jeder Minimap-Größe & Edit-Mode)
local function GetMinimapRadius()
    if not Minimap then return 80 end
    local w = Minimap:GetWidth() or 140
    local h = Minimap:GetHeight() or 140
    return (math.max(w, h) / 2) + 10
end

-- Aktualisiert die Position des Buttons basierend auf dem gespeicherten Winkel (in Grad)
function MB:UpdatePosition()
    if not button or not Minimap then return end
    local cfg = R4L.ProfileManager:GetConfig()
    local pos = (cfg.minimap and cfg.minimap.position) or 220
    local rad = math.rad(pos)
    local radius = GetMinimapRadius()
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Sichtbarkeit umschalten
function MB:SetShown(show)
    if not button then return end
    if show then
        button:Show()
        self:UpdatePosition()
    else
        button:Hide()
    end
end

function MB:Initialize()
    if button or not Minimap then return end

    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.minimap then
        cfg.minimap = { show = true, position = 220 }
    end

    button = CreateFrame("Button", "Resto4LifeMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Dunkler runder Hintergrund
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", button, "CENTER", 0, 0)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(0, 0, 0, 0.7)

    -- Icon (Resto4Life Icon)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\Spell_Nature_HealingTouch")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Offizieller runder Blizzard Minimap-Tracking-Border
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight-Effekt beim Überfahren
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(20, 20)
    highlight:SetPoint("CENTER", button, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    -- Ruckelfreies Ziehen entlang des Minimap-Rands (UI-Scale berücksichtigt)
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local uScale = UIParent:GetEffectiveScale()
            if not mx or not my or not cx or not cy or not uScale or uScale == 0 then return end
            cx = cx / uScale
            cy = cy / uScale
            local dx = cx - mx
            local dy = cy - my
            local deg = math.deg(math.atan2(dy, dx))
            if deg < 0 then deg = deg + 360 end
            cfg.minimap.position = deg
            MB:UpdatePosition()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)

    -- Klick-Aktionen
    button:SetScript("OnClick", function(self, btn)
        if self.isDragging then return end
        if btn == "LeftButton" then
            if IsShiftKeyDown() then
                if (IsInRaid() or (R4L.RaidHeader and R4L.RaidHeader.isSimulating)) and R4L.RaidHeader then
                    R4L.RaidHeader:ResetPositions()
                elseif R4L.GroupHeader then
                    R4L.GroupHeader:ResetPosition()
                end
            else
                if R4L.OptionsUI then
                    R4L.OptionsUI:Toggle()
                end
            end
        elseif btn == "RightButton" then
            if (IsInRaid() or (R4L.RaidHeader and R4L.RaidHeader.isSimulating)) and R4L.RaidHeader then
                R4L.RaidHeader:ToggleLock()
            elseif R4L.GroupHeader then
                R4L.GroupHeader:ToggleLock()
            end
        end

    end)

    -- Tooltip mit Anleitung
    button:SetScript("OnEnter", function(self)
        if self.isDragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ff96Resto4Life|r (v" .. R4L.version .. ")", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_LCLICK"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_RCLICK"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_SHIFT"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_DRAG"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    self.button = button
    self:SetShown(cfg.minimap.show)
end

-- Retail Addon Compartment Integration (WoW 10.0+ / 11.0+ / 12.0+)
_G["Resto4Life_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if R4L.OptionsUI then
        R4L.OptionsUI:Toggle()
    end
end

-- Automatische Initialisierung beim Login
R4L:RegisterEvent("PLAYER_LOGIN", function()
    MB:Initialize()
end)
