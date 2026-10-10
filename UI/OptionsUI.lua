--[[
    Resto4Life - UI/OptionsUI.lua
    Vollständiges Ingame-Konfigurationsmenü mit Tabs für Allgemein,
    Tastenbelegung (Click-Cast / Mausrad / 1-6), HoTs/Debuffs und Im-/Export
--]]

local _, R4L = ...
local L = R4L.L

R4L.OptionsUI = {}
local OUI = R4L.OptionsUI

local frame = nil
local currentTab = 1

-- Hilfsfunktion: Checkbox erstellen
local function CreateCheckbox(parent, label, x, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontHighlight")
    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
    end)
    return cb
end

-- Hilfsfunktion: Eingabefeld (EditBox) erstellen
local function CreateEditBox(parent, label, x, y, width, onEnterPressed)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(label)

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -4)
    eb:SetSize(width or 160, 22)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnterPressed then onEnterPressed(self:GetText()) end
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        if onEnterPressed then onEnterPressed(self:GetText()) end
    end)

    return eb, title
end

function OUI:Initialize()
    if frame then return end

    local cfg = R4L.ProfileManager:GetConfig()

    -- Hauptfenster
    frame = CreateFrame("Frame", "Resto4LifeOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 580)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })

    -- Titelzeile
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText(string.format(L["CONFIG_TITLE_FMT"], R4L.version))

    -- Versteckter Entwickler-Klick (Strg + Rechtsklick auf den Titel schaltet Sprache DE <-> EN um)
    local devLangBtn = CreateFrame("Button", nil, frame)
    devLangBtn:SetPoint("TOPLEFT", title, "TOPLEFT", -15, 6)
    devLangBtn:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 15, -6)
    devLangBtn:RegisterForClicks("RightButtonUp")
    devLangBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" and IsControlKeyDown() then
            local current = (Resto4LifeDB and Resto4LifeDB.devLocale) or GetLocale()
            local nextLang = (current == "deDE" or current == "de") and "enUS" or "deDE"
            R4L:SetDevLanguage(nextLang)
        end
    end)

    -- Schließen Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Tab-Leiste (6 Tabs inkl. Buff-Bar und Raid)
    local tabs = { L["TAB_GENERAL"], L["TAB_BINDINGS"], L["TAB_HOTS"], L["TAB_BUFFBAR"] or "Buff-Bar", L["TAB_RAID"], L["TAB_PROFILES"] }
    frame.tabButtons = {}
    frame.tabPanels = {}

    local tabContentArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabContentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -70)
    tabContentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    tabContentArea:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    tabContentArea:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
    tabContentArea:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

    for i, tabName in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(108, 24)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + (i - 1) * 114, -42)
        btn:SetText(tabName)
        btn:SetScript("OnClick", function()
            OUI:SelectTab(i)
        end)
        frame.tabButtons[i] = btn

        local panel = CreateFrame("Frame", nil, tabContentArea)
        panel:SetAllPoints(tabContentArea)
        panel:Hide()
        frame.tabPanels[i] = panel
    end


    -- =========================================================================
    -- TAB 1: ALLGEMEIN
    -- =========================================================================
    local p1 = frame.tabPanels[1]

    -- Rahmen entsperren
    local cbLock = CreateCheckbox(p1, L["UNLOCK_FRAME"], 20, -20, function(val)
        R4L.GroupHeader:ToggleLock(not val)
        if R4L.BuffBar then R4L.BuffBar:ToggleLock(not val) end
    end)

    -- In Bildschirm-Mitte zentrieren Button (Rechte Spalte)
    local btnCenter = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnCenter:SetSize(110, 22)
    btnCenter:SetPoint("TOPLEFT", p1, "TOPLEFT", 360, -20)
    btnCenter:SetText(L["POS_RESET"])
    btnCenter:SetScript("OnClick", function()
        R4L.GroupHeader:ResetPosition()
    end)

    -- Spielernamen anzeigen
    local cbNames = CreateCheckbox(p1, L["SHOW_NAMES"], 20, -55, function(val)
        cfg.display.showNames = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Rollen-Icons anzeigen
    local cbRole = CreateCheckbox(p1, L["SHOW_ROLE_ICONS"], 20, -90, function(val)
        cfg.display.showRoleIcons = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Manabalken anzeigen
    local cbMana = CreateCheckbox(p1, L["SHOW_MANA"], 20, -125, function(val)
        cfg.display.showManaBar = val
        R4L.GroupHeader:UpdateLayout()
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Reverse Health Bar (Defizitanzeige)
    local cbReverse = CreateCheckbox(p1, L["REVERSE_HEALTH"], 20, -160, function(val)
        cfg.display.healthOrientation = val and "REVERSE" or "NORMAL"
        R4L:Print(val and L["CHAT_REVERSE_ACTIVE"] or L["CHAT_REVERSE_INACTIVE"])
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Rechte Spalte Checkboxen (ab x = 360)
    -- Automatische Sortierung
    local cbSort = CreateCheckbox(p1, L["AUTO_SORT"], 360, -55, function(val)
        cfg.sorting.enabled = val
        R4L.GroupHeader:UpdateRoster()
    end)

    -- Reichweiten-Verblassen
    local cbRange = CreateCheckbox(p1, L["FADE_OUT_OF_RANGE"], 360, -90, function(val)
        cfg.display.fadeOutOfRange = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Ziel bei Zauber ins Target nehmen
    local cbTargetOnCast = CreateCheckbox(p1, L["TARGET_ON_CAST"], 360, -125, function(val)
        cfg.general.targetOnCast = val
        R4L:Print(val and L["CHAT_TARGET_ON_CAST_ON"] or L["CHAT_TARGET_ON_CAST_OFF"])
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Minimap-Button anzeigen
    local cbMinimap = CreateCheckbox(p1, L["SHOW_MINIMAP_CB"], 360, -160, function(val)
        if not cfg.minimap then cfg.minimap = {} end
        cfg.minimap.show = val
        if R4L.MinimapButton then
            R4L.MinimapButton:SetShown(val)
        end
    end)

    -- Farbmodus Label & Buttons
    local colorLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -202)
    colorLabel:SetText(L["COLOR_MODE"])

    local btnClassColor = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnClassColor:SetSize(130, 24)
    btnClassColor:SetPoint("LEFT", colorLabel, "RIGHT", 15, 0)
    btnClassColor:SetText(L["CLASS_COLORS"])

    local btnMinimalColor = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnMinimalColor:SetSize(150, 24)
    btnMinimalColor:SetPoint("LEFT", btnClassColor, "RIGHT", 10, 0)
    btnMinimalColor:SetText(L["GREEN_RED_HEALER"])

    local function UpdateColorButtons()
        if cfg.display.colorMode == "MINIMAL" then
            btnMinimalColor:SetText("[" .. L["GREEN_RED_HEALER"] .. "]")
            btnClassColor:SetText(L["CLASS_COLORS"])
        else
            btnClassColor:SetText("[" .. L["CLASS_COLORS"] .. "]")
            btnMinimalColor:SetText(L["GREEN_RED_HEALER"])
        end
    end

    btnClassColor:SetScript("OnClick", function()
        cfg.display.colorMode = "CLASS"
        UpdateColorButtons()
        R4L:Print(L["CHAT_COLOR_CLASS"])
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    btnMinimalColor:SetScript("OnClick", function()
        cfg.display.colorMode = "MINIMAL"
        UpdateColorButtons()
        R4L:Print(L["CHAT_COLOR_MINIMAL"])
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Ausrichtung / Anordnung (Spalte vs Zeile)
    local layoutLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    layoutLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -238)
    layoutLabel:SetText(L["LAYOUT"])

    local btnColLayout = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnColLayout:SetSize(130, 24)
    btnColLayout:SetPoint("LEFT", layoutLabel, "RIGHT", 15, 0)
    btnColLayout:SetText(L["COL_VERTICAL"])

    local btnRowLayout = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnRowLayout:SetSize(150, 24)
    btnRowLayout:SetPoint("LEFT", btnColLayout, "RIGHT", 10, 0)
    btnRowLayout:SetText(L["ROW_HORIZONTAL"])

    local function UpdateLayoutButtons()
        if cfg.general.growthDirection == "RIGHT" or cfg.general.growthDirection == "LEFT" then
            btnRowLayout:SetText("[" .. L["ROW_HORIZONTAL"] .. "]")
            btnColLayout:SetText(L["COL_VERTICAL"])
        else
            btnColLayout:SetText("[" .. L["COL_VERTICAL"] .. "]")
            btnRowLayout:SetText(L["ROW_HORIZONTAL"])
        end
    end

    btnColLayout:SetScript("OnClick", function()
        cfg.general.growthDirection = "DOWN"
        UpdateLayoutButtons()
        R4L:Print(L["CHAT_LAYOUT_COL"])
        R4L.GroupHeader:UpdateLayout()
    end)

    btnRowLayout:SetScript("OnClick", function()
        cfg.general.growthDirection = "RIGHT"
        UpdateLayoutButtons()
        R4L:Print(L["CHAT_LAYOUT_ROW"])
        R4L.GroupHeader:UpdateLayout()
    end)

    -- 5er-Gruppe Simulation / Test-Modus Button
    local btnSim = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnSim:SetSize(295, 26)
    btnSim:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -276)

    local function UpdateSimButton()
        if R4L.GroupHeader and R4L.GroupHeader.isSimulating then
            btnSim:SetText("[" .. L["SIM_ACTIVE_BTN"] .. "]")
        else
            btnSim:SetText(L["SIM_GROUP_BTN"])
        end
    end

    btnSim:SetScript("OnClick", function()
        if R4L.GroupHeader then
            R4L.GroupHeader:ToggleSimulation()
            UpdateSimButton()
        end
    end)

    -- Skalierung (Größe)
    local scaleLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -316)
    scaleLabel:SetText(L["SCALE_LABEL"])

    local btnScaleMinus = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnScaleMinus:SetSize(32, 24)
    btnScaleMinus:SetPoint("LEFT", scaleLabel, "RIGHT", 15, 0)
    btnScaleMinus:SetText("-")

    local scaleDisplay = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleDisplay:SetPoint("LEFT", btnScaleMinus, "RIGHT", 8, 0)
    scaleDisplay:SetWidth(48)
    scaleDisplay:SetJustifyH("CENTER")

    local btnScalePlus = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnScalePlus:SetSize(32, 24)
    btnScalePlus:SetPoint("LEFT", scaleDisplay, "RIGHT", 8, 0)
    btnScalePlus:SetText("+")

    local btnScaleReset = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnScaleReset:SetSize(110, 24)
    btnScaleReset:SetPoint("LEFT", btnScalePlus, "RIGHT", 10, 0)
    btnScaleReset:SetText(L["SCALE_DEFAULT"])

    function OUI:UpdateScaleDisplay()
        local s = cfg.general.scale or 1.0
        if scaleDisplay then
            scaleDisplay:SetText(math.floor(s * 100 + 0.5) .. "%")
        end
    end

    btnScaleMinus:SetScript("OnClick", function()
        local s = (cfg.general.scale or 1.0) - 0.05
        s = math.max(0.5, math.floor(s * 100 + 0.5) / 100)
        R4L.GroupHeader:SetScale(s)
    end)

    btnScalePlus:SetScript("OnClick", function()
        local s = (cfg.general.scale or 1.0) + 0.05
        s = math.min(2.0, math.floor(s * 100 + 0.5) / 100)
        R4L.GroupHeader:SetScale(s)
    end)

    btnScaleReset:SetScript("OnClick", function()
        R4L.GroupHeader:SetScale(1.0)
    end)

    p1:SetScript("OnShow", function()
        cbLock:SetChecked(not cfg.general.locked)
        cbNames:SetChecked(cfg.display.showNames)
        cbRole:SetChecked(cfg.display.showRoleIcons ~= false)
        cbMana:SetChecked(cfg.display.showManaBar)
        cbReverse:SetChecked(cfg.display.healthOrientation == "REVERSE")
        UpdateColorButtons()
        UpdateLayoutButtons()
        UpdateSimButton()
        cbSort:SetChecked(cfg.sorting.enabled)
        cbRange:SetChecked(cfg.display.fadeOutOfRange)
        cbTargetOnCast:SetChecked(cfg.general.targetOnCast or false)
        cbMinimap:SetChecked(cfg.minimap and cfg.minimap.show ~= false)
        OUI:UpdateScaleDisplay()
    end)




    -- =========================================================================
    -- TAB 2: TASTENBELEGUNG (CLICK-CASTING MIT MODIFIKATOREN STRG & ALT)
    -- =========================================================================
    local p2 = frame.tabPanels[2]

    local p2Desc = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p2Desc:SetPoint("TOPLEFT", p2, "TOPLEFT", 20, -12)
    p2Desc:SetText(L["BINDINGS_HEADER"])

    local currentMod = "NONE" -- "NONE", "CTRL", "ALT"

    -- 3 Modifikator-Umschalt-Buttons
    local btnModNone = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    btnModNone:SetSize(140, 24)
    btnModNone:SetPoint("TOPLEFT", p2, "TOPLEFT", 20, -32)
    btnModNone:SetText(L["MOD_NONE"] or "Standard")

    local btnModCtrl = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    btnModCtrl:SetSize(140, 24)
    btnModCtrl:SetPoint("LEFT", btnModNone, "RIGHT", 10, 0)
    btnModCtrl:SetText(L["MOD_CTRL"] or "STRG +")

    local btnModAlt = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    btnModAlt:SetSize(140, 24)
    btnModAlt:SetPoint("LEFT", btnModCtrl, "RIGHT", 10, 0)
    btnModAlt:SetText(L["MOD_ALT"] or "ALT +")

    local function GetBindingKey(baseKey)
        if currentMod == "NONE" then
            return baseKey
        else
            return currentMod .. "_" .. baseKey
        end
    end

    local function SaveSpell(baseKey, val)
        local key = GetBindingKey(baseKey)
        if not cfg.bindings[key] then
            cfg.bindings[key] = { action = "spell", spell = "" }
        end
        if baseKey == "1" and currentMod == "NONE" and val == "" then
            cfg.bindings[key].action = "target"
            cfg.bindings[key].spell = ""
        elseif baseKey == "2" and currentMod == "NONE" and val == "" then
            cfg.bindings[key].action = "menu"
            cfg.bindings[key].spell = ""
        else
            cfg.bindings[key].action = "spell"
            cfg.bindings[key].spell = val
        end
        R4L.ClickCast:ApplyAllBindings()
    end

    local function GetSpell(baseKey)
        local key = GetBindingKey(baseKey)
        return (cfg.bindings[key] and cfg.bindings[key].spell) or ""
    end

    -- Linke Spalte (Mausaktionen): Linksklick, Rechtsklick, Mittlere Maustaste, Maus 4, Maus 5, Mausrad Hoch, Mausrad Runter
    local ebLeft, titleLeft = CreateEditBox(p2, L["LEFT_CLICK"], 20, -64, 250, function(val)
        SaveSpell("1", val)
    end)

    local ebRight, titleRight = CreateEditBox(p2, L["RIGHT_CLICK"], 20, -104, 250, function(val)
        SaveSpell("2", val)
    end)

    local ebMid, titleMid = CreateEditBox(p2, L["MID_CLICK"], 20, -144, 250, function(val)
        SaveSpell("3", val)
    end)

    local ebMouse4, titleMouse4 = CreateEditBox(p2, L["MOUSE_BTN4"] or "Maustaste 4 (Daumen):", 20, -184, 250, function(val)
        SaveSpell("4", val)
    end)

    local ebMouse5, titleMouse5 = CreateEditBox(p2, L["MOUSE_BTN5"] or "Maustaste 5 (Daumen):", 20, -224, 250, function(val)
        SaveSpell("5", val)
    end)

    local ebWheelUp, titleWheelUp = CreateEditBox(p2, L["WHEEL_UP"], 20, -264, 250, function(val)
        SaveSpell("WheelUp", val)
    end)

    local ebWheelDown, titleWheelDown = CreateEditBox(p2, L["WHEEL_DOWN"], 20, -304, 250, function(val)
        SaveSpell("WheelDown", val)
    end)

    -- Rechte Spalte: Tasten 1 bis 6
    local ebKeys = {}
    local titleKeys = {}
    for i = 1, 6 do
        local posY = -64 - (i - 1) * 40
        local eb, title = CreateEditBox(p2, string.format(L["KEY_N_FMT"], i), 350, posY, 250, function(val)
            SaveSpell("KEY_" .. i, val)
        end)
        ebKeys[i] = eb
        titleKeys[i] = title
    end

    -- Hinweistext unten rechts
    local hintText = p2:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("TOPLEFT", p2, "TOPLEFT", 350, -308)
    hintText:SetWidth(280)
    hintText:SetJustifyH("LEFT")
    hintText:SetText("|cff00ccffTipp:|r Wähle oben |cff00ff00[Standard]|r, |cff00ff00[STRG +]|r oder |cff00ff00[ALT +]|r, um Tastenkombinationen zu belegen.")

    local function UpdateBindingsTab()
        -- Button-Zustände optisch hervorheben
        if currentMod == "NONE" then
            btnModNone:SetText("|cff00ff00[ " .. (L["MOD_NONE"] or "Standard") .. " ]|r")
            btnModCtrl:SetText(L["MOD_CTRL"] or "STRG +")
            btnModAlt:SetText(L["MOD_ALT"] or "ALT +")
        elseif currentMod == "CTRL" then
            btnModNone:SetText(L["MOD_NONE"] or "Standard")
            btnModCtrl:SetText("|cff00ff00[ " .. (L["MOD_CTRL"] or "STRG +") .. " ]|r")
            btnModAlt:SetText(L["MOD_ALT"] or "ALT +")
        elseif currentMod == "ALT" then
            btnModNone:SetText(L["MOD_NONE"] or "Standard")
            btnModCtrl:SetText(L["MOD_CTRL"] or "STRG +")
            btnModAlt:SetText("|cff00ff00[ " .. (L["MOD_ALT"] or "ALT +") .. " ]|r")
        end

        local pfx = ""
        if currentMod == "CTRL" then
            pfx = "STRG + "
        elseif currentMod == "ALT" then
            pfx = "ALT + "
        end

        -- Beschriftungen anpassen
        titleLeft:SetText(pfx .. L["LEFT_CLICK"])
        titleRight:SetText(pfx .. L["RIGHT_CLICK"])
        titleMid:SetText(pfx .. L["MID_CLICK"])
        titleMouse4:SetText(pfx .. (L["MOUSE_BTN4"] or "Maustaste 4 (Daumen):"))
        titleMouse5:SetText(pfx .. (L["MOUSE_BTN5"] or "Maustaste 5 (Daumen):"))
        titleWheelUp:SetText(pfx .. L["WHEEL_UP"])
        titleWheelDown:SetText(pfx .. L["WHEEL_DOWN"])
        for i = 1, 6 do
            titleKeys[i]:SetText(pfx .. string.format(L["KEY_N_FMT"], i))
        end

        -- Werte in EditBoxen laden
        ebLeft:SetText(GetSpell("1"))
        ebRight:SetText(GetSpell("2"))
        ebMid:SetText(GetSpell("3"))
        ebMouse4:SetText(GetSpell("4"))
        ebMouse5:SetText(GetSpell("5"))
        ebWheelUp:SetText(GetSpell("WheelUp"))
        ebWheelDown:SetText(GetSpell("WheelDown"))
        for i = 1, 6 do
            ebKeys[i]:SetText(GetSpell("KEY_" .. i))
        end
    end

    btnModNone:SetScript("OnClick", function()
        currentMod = "NONE"
        UpdateBindingsTab()
    end)
    btnModCtrl:SetScript("OnClick", function()
        currentMod = "CTRL"
        UpdateBindingsTab()
    end)
    btnModAlt:SetScript("OnClick", function()
        currentMod = "ALT"
        UpdateBindingsTab()
    end)

    -- Smart Battle Rez Sektion (unten mit farbiger Überschrift)
    local rezHeader = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rezHeader:SetPoint("TOPLEFT", p2, "TOPLEFT", 20, -355)
    rezHeader:SetText(L["SMART_REZ_HEADER"])

    local cbSmartRez = CreateCheckbox(p2, L["SMART_REZ_ENABLE"], 20, -375, function(val)
        cfg.smartRez.enabled = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    local ebBattleRez = CreateEditBox(p2, L["COMBAT_REZ_SPELL"], 20, -410, 250, function(val)
        cfg.smartRez.combatRezSpell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    local ebNormalRez = CreateEditBox(p2, L["NORMAL_REZ_SPELL"], 350, -410, 250, function(val)
        cfg.smartRez.normalRezSpell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    p2:SetScript("OnShow", function()
        UpdateBindingsTab()
        cbSmartRez:SetChecked(cfg.smartRez.enabled)
        ebBattleRez:SetText(cfg.smartRez.combatRezSpell or "")
        ebNormalRez:SetText(cfg.smartRez.normalRezSpell or "")
    end)

    -- =========================================================================
    -- TAB 3: HOTS & DEBUFFS
    -- =========================================================================
    local p3 = frame.tabPanels[3]

    local cbHots = CreateCheckbox(p3, L["SHOW_HOTS_CB"], 20, -20, function(val)
        cfg.auras.showHots = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbOnlyMyHots = CreateCheckbox(p3, L["ONLY_MY_HOTS_CB"], 40, -50, function(val)
        cfg.auras.onlyMyHots = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbDebuffs = CreateCheckbox(p3, L["COLOR_DEBUFFS_CB"], 20, -90, function(val)
        cfg.auras.showDebuffs = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbDispOnly = CreateCheckbox(p3, L["DISP_ONLY_CB"], 40, -125, function(val)
        cfg.auras.highlightDispellableOnly = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbCurse = CreateCheckbox(p3, L["HIGHLIGHT_CURSE"], 40, -160, function(val)
        cfg.auras.showCurse = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbPoison = CreateCheckbox(p3, L["HIGHLIGHT_POISON"], 40, -195, function(val)
        cfg.auras.showPoison = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbDisease = CreateCheckbox(p3, L["HIGHLIGHT_DISEASE"], 40, -230, function(val)
        cfg.auras.showDisease = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    local cbMagic = CreateCheckbox(p3, L["HIGHLIGHT_MAGIC"], 40, -265, function(val)
        cfg.auras.showMagic = val
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    -- Test-Modus für Debuffs (Klick aktiviert, erneuter Klick deaktiviert)
    local testHeader = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    testHeader:SetPoint("TOPLEFT", p3, "TOPLEFT", 20, -305)
    testHeader:SetText(L["DEBUFF_TEST_HEADER"])

    local btnTestPoison = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestPoison:SetSize(130, 24)
    btnTestPoison:SetPoint("TOPLEFT", testHeader, "BOTTOMLEFT", 0, -8)
    btnTestPoison:SetText(L["POISON_TEST_BTN"])

    local btnTestCurse = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestCurse:SetSize(130, 24)
    btnTestCurse:SetPoint("LEFT", btnTestPoison, "RIGHT", 12, 0)
    btnTestCurse:SetText(L["CURSE_TEST_BTN"])

    local btnTestMagic = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestMagic:SetSize(130, 24)
    btnTestMagic:SetPoint("LEFT", btnTestCurse, "RIGHT", 12, 0)
    btnTestMagic:SetText(L["MAGIC_TEST_BTN"])

    local function UpdateDebuffTestButtons()
        if R4L.testDebuff == "Poison" then
            btnTestPoison:SetText("[" .. L["POISON_TEST_BTN"] .. "]")
        else
            btnTestPoison:SetText(L["POISON_TEST_BTN"])
        end

        if R4L.testDebuff == "Curse" then
            btnTestCurse:SetText("[" .. L["CURSE_TEST_BTN"] .. "]")
        else
            btnTestCurse:SetText(L["CURSE_TEST_BTN"])
        end

        if R4L.testDebuff == "Magic" then
            btnTestMagic:SetText("[" .. L["MAGIC_TEST_BTN"] .. "]")
        else
            btnTestMagic:SetText(L["MAGIC_TEST_BTN"])
        end
    end

    btnTestPoison:SetScript("OnClick", function()
        if R4L.testDebuff == "Poison" then
            R4L.testDebuff = nil
            R4L:Print(L["CHAT_TEST_DEBUFF_STOP"])
        else
            R4L.testDebuff = "Poison"
            R4L:Print(L["TEST_POISON_CHAT"])
        end
        UpdateDebuffTestButtons()
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    btnTestCurse:SetScript("OnClick", function()
        if R4L.testDebuff == "Curse" then
            R4L.testDebuff = nil
            R4L:Print(L["CHAT_TEST_DEBUFF_STOP"])
        else
            R4L.testDebuff = "Curse"
            R4L:Print(L["TEST_CURSE_CHAT"])
        end
        UpdateDebuffTestButtons()
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    btnTestMagic:SetScript("OnClick", function()
        if R4L.testDebuff == "Magic" then
            R4L.testDebuff = nil
            R4L:Print(L["CHAT_TEST_DEBUFF_STOP"])
        else
            R4L.testDebuff = "Magic"
            R4L:Print(L["TEST_MAGIC_CHAT"])
        end
        UpdateDebuffTestButtons()
        R4L.GroupHeader:UpdateAllFrames()
        if R4L.RaidHeader then R4L.RaidHeader:UpdateAllFrames() end
    end)

    p3:SetScript("OnShow", function()
        cbHots:SetChecked(cfg.auras.showHots)
        cbOnlyMyHots:SetChecked(cfg.auras.onlyMyHots ~= false)
        cbDebuffs:SetChecked(cfg.auras.showDebuffs)
        cbDispOnly:SetChecked(cfg.auras.highlightDispellableOnly)
        cbCurse:SetChecked(cfg.auras.showCurse)
        cbPoison:SetChecked(cfg.auras.showPoison)
        cbDisease:SetChecked(cfg.auras.showDisease)
        cbMagic:SetChecked(cfg.auras.showMagic)
        UpdateDebuffTestButtons()
    end)

    -- =========================================================================
    -- TAB 4: BUFF-BAR
    -- =========================================================================
    local p4 = frame.tabPanels[4]

    local bbDesc = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bbDesc:SetPoint("TOPLEFT", p4, "TOPLEFT", 20, -15)
    bbDesc:SetWidth(650)
    bbDesc:SetJustifyH("LEFT")
    bbDesc:SetText(L["BUFF_BAR_DESC"] or "Die Buff-Bar überwacht permanente Klassen-Buffs in deiner Gruppe oder deinem Raid.\nFehlende Buffs werden mit einem roten Rahmen und der Anzahl fehlender Ziele markiert.\nPer Linksklick zauberst du den Buff direkt auf das nächste fehlende Gruppenmitglied (Tank > Heiler > DD).")

    -- Buff-Bar aktivieren Checkbox
    local cbBuffBar = CreateCheckbox(p4, L["BUFF_BAR_ENABLE"] or "Buff-Bar aktivieren", 20, -65, function(val)
        if not cfg.buffBar then cfg.buffBar = {} end
        cfg.buffBar.enabled = val
        if R4L.BuffBar then R4L.BuffBar:Update() end
    end)

    -- Buff-Bar Position Reset Button
    local btnBuffReset = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
    btnBuffReset:SetSize(220, 24)
    btnBuffReset:SetPoint("TOPLEFT", p4, "TOPLEFT", 300, -65)
    btnBuffReset:SetText(L["BUFF_BAR_RESET"] or "Buff-Bar Position zurücksetzen")
    btnBuffReset:SetScript("OnClick", function()
        if R4L.BuffBar then R4L.BuffBar:ResetPosition() end
    end)

    -- Überschrift Zielgruppen-Filter
    local buffTargetHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    buffTargetHeader:SetPoint("TOPLEFT", p4, "TOPLEFT", 20, -112)
    buffTargetHeader:SetText("|cffffff00" .. (L["BUFF_TARGET_HEADER"] or "Zielgruppen-Filter für Klassen-Buffs:") .. "|r")

    local buffTargetSub = p4:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    buffTargetSub:SetPoint("TOPLEFT", buffTargetHeader, "BOTTOMLEFT", 0, -4)
    buffTargetSub:SetText(L["BUFF_TARGET_SUB"] or "Klicke auf den Button rechts neben einem Zauber, um festzulegen, wer den Zauber erhalten soll.")

    local TARGET_NAMES = {
        ALL = L["BUFF_TARGET_ALL"] or "Alle",
        TANK = L["BUFF_TARGET_TANK"] or "Nur Tank",
        SELF = L["BUFF_TARGET_SELF"] or "Nur Selbst",
        MANA = L["BUFF_TARGET_MANA"] or "Mana",
        MELEE = L["BUFF_TARGET_MELEE"] or "Melee",
        OFF = L["BUFF_TARGET_OFF"] or "Aus",
    }

    local TARGET_COLORS = {
        ALL = "|cff00ff00",
        TANK = "|cff3399ff",
        SELF = "|cffffff00",
        MANA = "|cff00ccff",
        MELEE = "|cffff8800",
        OFF = "|cffff4444",
    }

    local _, pClass = UnitClass("player")
    local CLASS_BUFF_DEFS = {
        DRUID = {
            { name = "Mal der Wildnis", modes = { "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Nature_Regeneration", desc = "Stärkt Attribute und Rüstung aller Gruppenmitglieder" },
            { name = "Dornen", modes = { "TANK", "ALL", "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Nature_Thorns", desc = "Verleiht Dornen (Standard: Nur Tanks erhalten Dornen)" },
            { name = "Omen der Klarsicht", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Nature_CrystalBall", desc = "Nahkampfangriffe gewähren Chance auf Freizaubern (Nur Selbst)" },
        },
        PRIEST = {
            { name = "Machtwort: Seelenstärke", modes = { "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_WordFortitude", desc = "Erhöht Ausdauer der Gruppe" },
            { name = "Göttlicher Wille", modes = { "MANA", "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_DivineSpirit", desc = "Erhöht Willenskraft von Mana-Klassen" },
            { name = "Inneres Feuer", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_InnerFire", desc = "Erhöht eigene Rüstung und Zaubermacht (Nur Selbst)" },
            { name = "Schattenschutz", modes = { "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Shadow_AntiShadow", desc = "Erhöht Schattenwiderstand der Gruppe" },
        },
        MAGE = {
            { name = "Arkane Intelligenz", modes = { "ALL", "MANA", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", desc = "Erhöht Intelligenz von Gruppenmitgliedern" },
            { name = "Eisrüstung", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Frost_FrostArmor02", desc = "Erhöht eigene Rüstung und Frostwiderstand (Nur Selbst)" },
        },
        PALADIN = {
            { name = "Segen der Macht", modes = { "MELEE", "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", desc = "Erhöht Nahkampf-Angriffskraft (Standard: Nur Melees)" },
            { name = "Segen der Weisheit", modes = { "MANA", "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", desc = "Regeneriert Mana für Mana-Klassen" },
            { name = "Segen der Könige", modes = { "ALL", "OFF" }, icon = "Interface\\Icons\\Spell_Magic_MageArmor", desc = "Erhöht alle Attribute um 10%" },
            { name = "Zorn der Gerechtigkeit", modes = { "TANK", "OFF" }, icon = "Interface\\Icons\\Spell_Holy_SealOfFury", desc = "Erhöht Heilig-Bedrohung (Standard: Nur als Tank)" },
        },
        SHAMAN = {
            { name = "Wasserschild", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Ability_Shaman_WaterShield", desc = "Regeneriert Mana bei Treffern (Nur Selbst)" },
        },
        WARLOCK = {
            { name = "Dämonenrüstung", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Shadow_RagingScream", desc = "Erhöht Rüstung und erhaltene Heilung (Nur Selbst)" },
            { name = "Seelenverbindung", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Spell_Shadow_SoulLeech_3", desc = "Überträgt Schaden auf deinen Dämon (Nur Selbst)" },
        },
        WARRIOR = {
            { name = "Schlachtruf", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Ability_Warrior_BattleShout", desc = "Erhöht Nahkampf-Angriffskraft (Nur Selbst zaubern)" },
            { name = "Befehlsruf", modes = { "SELF", "OFF" }, icon = "Interface\\Icons\\Ability_Warrior_RallyingCry", desc = "Erhöht maximale Gesundheit (Nur Selbst zaubern)" },
        },
    }

    local myBuffs = CLASS_BUFF_DEFS[pClass] or {}
    local buffControls = {}

    if #myBuffs == 0 then
        local noBuffsText = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noBuffsText:SetPoint("TOPLEFT", buffTargetSub, "BOTTOMLEFT", 0, -25)
        noBuffsText:SetText(L["BUFF_NO_CLASS_BUFFS"] or "Für deine Klasse sind derzeit keine automatischen Klassen-Buffs konfiguriert.")
        noBuffsText:SetTextColor(0.6, 0.6, 0.6, 1)
    else
        local bY = -155
        for idx, bDef in ipairs(myBuffs) do
            local rowFrame = CreateFrame("Frame", nil, p4, "BackdropTemplate")
            rowFrame:SetSize(640, 42)
            rowFrame:SetPoint("TOPLEFT", p4, "TOPLEFT", 20, bY)
            rowFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            rowFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.5)
            rowFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)

            -- Zauber-Icon
            local iconTex = rowFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(30, 30)
            iconTex:SetPoint("LEFT", rowFrame, "LEFT", 6, 0)
            iconTex:SetTexture(bDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Zauber-Name
            local bLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            bLabel:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 44, -5)
            bLabel:SetText(bDef.name)

            -- Beschreibung
            local bDesc = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bDesc:SetPoint("TOPLEFT", bLabel, "BOTTOMLEFT", 0, -2)
            bDesc:SetText(bDef.desc or "")

            -- Cycle-Button
            local btnCycle = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
            btnCycle:SetSize(130, 24)
            btnCycle:SetPoint("RIGHT", rowFrame, "RIGHT", -8, 0)

            local function RefreshCycleButton()
                if not cfg.buffBar then cfg.buffBar = {} end
                if not cfg.buffBar.targets then cfg.buffBar.targets = {} end
                local cur = cfg.buffBar.targets[bDef.name] or bDef.modes[1]
                local col = TARGET_COLORS[cur] or "|cffffffff"
                local label = TARGET_NAMES[cur] or cur
                btnCycle:SetText(col .. "[ " .. label .. " ]|r")
            end

            btnCycle:SetScript("OnClick", function()
                if not cfg.buffBar then cfg.buffBar = {} end
                if not cfg.buffBar.targets then cfg.buffBar.targets = {} end
                local cur = cfg.buffBar.targets[bDef.name] or bDef.modes[1]
                local nextIdx = 1
                for mIdx, mVal in ipairs(bDef.modes) do
                    if mVal == cur then
                        nextIdx = (mIdx % #bDef.modes) + 1
                        break
                    end
                end
                cfg.buffBar.targets[bDef.name] = bDef.modes[nextIdx]
                RefreshCycleButton()
                if R4L.BuffBar then R4L.BuffBar:Update() end
            end)

            RefreshCycleButton()
            table.insert(buffControls, RefreshCycleButton)
            bY = bY - 48
        end
    end

    p4:SetScript("OnShow", function()
        if cfg.buffBar then
            cbBuffBar:SetChecked(cfg.buffBar.enabled ~= false)
        else
            cbBuffBar:SetChecked(true)
        end
        for _, refreshFn in ipairs(buffControls) do
            refreshFn()
        end
    end)

    -- =========================================================================
    -- TAB 5: RAID-OPTIONEN
    -- =========================================================================
    local p5 = frame.tabPanels[5]

    local cbRaidEnable = CreateCheckbox(p5, L["RAID_ENABLE"], 20, -15, function(val)
        cfg.raid.enabled = val
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateRoster()
            R4L.RaidHeader:UpdateMovers()
        end
    end)

    -- Tanks
    local cbTanks = CreateCheckbox(p5, L["RAID_SHOW_TANKS"], 20, -50, function(val)
        cfg.raid.showTanks = val
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateRoster()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    local btnTankCol = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnTankCol:SetSize(75, 22)
    btnTankCol:SetPoint("TOPLEFT", p5, "TOPLEFT", 440, -52)
    local btnTankRow = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnTankRow:SetSize(75, 22)
    btnTankRow:SetPoint("LEFT", btnTankCol, "RIGHT", 10, 0)

    -- Eigene Gruppe
    local cbMyGroup = CreateCheckbox(p5, L["RAID_SHOW_MYGROUP"], 20, -85, function(val)
        cfg.raid.showMyGroup = val
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateRoster()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    local btnGroupCol = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnGroupCol:SetSize(75, 22)
    btnGroupCol:SetPoint("TOPLEFT", p5, "TOPLEFT", 440, -87)
    local btnGroupRow = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnGroupRow:SetSize(75, 22)
    btnGroupRow:SetPoint("LEFT", btnGroupCol, "RIGHT", 10, 0)

    -- Restlicher Raid
    local cbRaidRem = CreateCheckbox(p5, L["RAID_SHOW_REMAINING"], 20, -120, function(val)
        cfg.raid.showRaid = val
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateRoster()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    local btnRaidCol = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnRaidCol:SetSize(105, 22)
    btnRaidCol:SetPoint("TOPLEFT", p5, "TOPLEFT", 440, -122)
    local btnRaidRow = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnRaidRow:SetSize(105, 22)
    btnRaidRow:SetPoint("LEFT", btnRaidCol, "RIGHT", 10, 0)

    -- Begleiter (Pets)
    local cbPets = CreateCheckbox(p5, L["RAID_SHOW_PETS"], 20, -155, function(val)
        cfg.raid.showPets = val
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateRoster()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    local btnPetCol = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnPetCol:SetSize(75, 22)
    btnPetCol:SetPoint("TOPLEFT", p5, "TOPLEFT", 440, -157)
    local btnPetRow = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnPetRow:SetSize(75, 22)
    btnPetRow:SetPoint("LEFT", btnPetCol, "RIGHT", 10, 0)

    -- Aktualisierung der Orientierungs-Buttons
    local function UpdateOrientationButtons()
        local r = cfg.raid
        if not r then return end

        if r.tankOrientation == "HORIZONTAL" then
            btnTankRow:SetText("|cffffd100[" .. L["ORIENTATION_HORIZONTAL"] .. "]|r")
            btnTankCol:SetText(L["ORIENTATION_VERTICAL"])
        else
            btnTankCol:SetText("|cffffd100[" .. L["ORIENTATION_VERTICAL"] .. "]|r")
            btnTankRow:SetText(L["ORIENTATION_HORIZONTAL"])
        end

        if r.myGroupOrientation == "HORIZONTAL" then
            btnGroupRow:SetText("|cffffd100[" .. L["ORIENTATION_HORIZONTAL"] .. "]|r")
            btnGroupCol:SetText(L["ORIENTATION_VERTICAL"])
        else
            btnGroupCol:SetText("|cffffd100[" .. L["ORIENTATION_VERTICAL"] .. "]|r")
            btnGroupRow:SetText(L["ORIENTATION_HORIZONTAL"])
        end

        if r.raidOrientation == "HORIZONTAL" then
            btnRaidRow:SetText("|cffffd100[" .. L["ORIENTATION_RAID_HORIZONTAL"] .. "]|r")
            btnRaidCol:SetText(L["ORIENTATION_RAID_VERTICAL"])
        else
            btnRaidCol:SetText("|cffffd100[" .. L["ORIENTATION_RAID_VERTICAL"] .. "]|r")
            btnRaidRow:SetText(L["ORIENTATION_RAID_HORIZONTAL"])
        end

        if r.petOrientation == "HORIZONTAL" then
            btnPetRow:SetText("|cffffd100[" .. L["ORIENTATION_HORIZONTAL"] .. "]|r")
            btnPetCol:SetText(L["ORIENTATION_VERTICAL"])
        else
            btnPetCol:SetText("|cffffd100[" .. L["ORIENTATION_VERTICAL"] .. "]|r")
            btnPetRow:SetText(L["ORIENTATION_HORIZONTAL"])
        end
    end
    OUI.UpdateOrientationButtons = UpdateOrientationButtons

    btnTankCol:SetScript("OnClick", function()
        cfg.raid.tankOrientation = "VERTICAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    btnTankRow:SetScript("OnClick", function()
        cfg.raid.tankOrientation = "HORIZONTAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)

    btnGroupCol:SetScript("OnClick", function()
        cfg.raid.myGroupOrientation = "VERTICAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    btnGroupRow:SetScript("OnClick", function()
        cfg.raid.myGroupOrientation = "HORIZONTAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)

    btnRaidCol:SetScript("OnClick", function()
        cfg.raid.raidOrientation = "VERTICAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    btnRaidRow:SetScript("OnClick", function()
        cfg.raid.raidOrientation = "HORIZONTAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)

    btnPetCol:SetScript("OnClick", function()
        cfg.raid.petOrientation = "VERTICAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)
    btnPetRow:SetScript("OnClick", function()
        cfg.raid.petOrientation = "HORIZONTAL"
        UpdateOrientationButtons()
        if R4L.RaidHeader then
            R4L.RaidHeader:UpdateLayout()
            R4L.RaidHeader:UpdateMovers()
        end
    end)

    -- Mover Sektion
    local moverHeader = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    moverHeader:SetPoint("TOPLEFT", p5, "TOPLEFT", 20, -195)
    moverHeader:SetText(L["RAID_MOVERS_HEADER"])

    local btnUnlockRaid = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnUnlockRaid:SetSize(180, 24)
    btnUnlockRaid:SetPoint("TOPLEFT", moverHeader, "BOTTOMLEFT", 0, -8)
    btnUnlockRaid:SetText(L["RAID_UNLOCK_ALL"])

    local function UpdateRaidLockBtn()
        if R4L.RaidHeader and not R4L.RaidHeader.isLocked then
            btnUnlockRaid:SetText(L["RAID_LOCK_ALL"])
        else
            btnUnlockRaid:SetText(L["RAID_UNLOCK_ALL"])
        end
    end

    btnUnlockRaid:SetScript("OnClick", function()
        if R4L.RaidHeader then
            R4L.RaidHeader:ToggleLock()
            UpdateRaidLockBtn()
        end
    end)

    local btnResetRaid = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnResetRaid:SetSize(210, 24)
    btnResetRaid:SetPoint("LEFT", btnUnlockRaid, "RIGHT", 15, 0)
    btnResetRaid:SetText(L["RAID_RESET_POS"])
    btnResetRaid:SetScript("OnClick", function()
        if R4L.RaidHeader then
            R4L.RaidHeader:ResetPositions()
        end
    end)

    -- Simulations Sektion (Umschaltung per Klick / erneuter Klick beendet)
    local simHeader = p5:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    simHeader:SetPoint("TOPLEFT", p5, "TOPLEFT", 20, -260)
    simHeader:SetText(L["RAID_SIM_HEADER"])

    local btnSim10 = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnSim10:SetSize(190, 24)
    btnSim10:SetPoint("TOPLEFT", simHeader, "BOTTOMLEFT", 0, -8)
    btnSim10:SetText(L["RAID_SIM_10"])

    local btnSim25 = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnSim25:SetSize(190, 24)
    btnSim25:SetPoint("LEFT", btnSim10, "RIGHT", 20, 0)
    btnSim25:SetText(L["RAID_SIM_25"])

    local btnSim40 = CreateFrame("Button", nil, p5, "UIPanelButtonTemplate")
    btnSim40:SetSize(190, 24)
    btnSim40:SetPoint("LEFT", btnSim25, "RIGHT", 20, 0)
    btnSim40:SetText(L["RAID_SIM_40"])

    local function UpdateSimButtons()
        local isSim = R4L.RaidHeader and R4L.RaidHeader.isSimulating
        local mode = isSim and R4L.RaidHeader.simMode or nil

        if mode == "10" then
            btnSim10:SetText("|cffffd100[" .. L["RAID_SIM_10"] .. "]|r")
        else
            btnSim10:SetText(L["RAID_SIM_10"])
        end

        if mode == "25" then
            btnSim25:SetText("|cffffd100[" .. L["RAID_SIM_25"] .. "]|r")
        else
            btnSim25:SetText(L["RAID_SIM_25"])
        end

        if mode == "40" then
            btnSim40:SetText("|cffffd100[" .. L["RAID_SIM_40"] .. "]|r")
        else
            btnSim40:SetText(L["RAID_SIM_40"])
        end
    end

    btnSim10:SetScript("OnClick", function()
        if R4L.RaidHeader then
            if R4L.RaidHeader.isSimulating and R4L.RaidHeader.simMode == "10" then
                R4L.RaidHeader:ToggleSimulation(nil)
            else
                R4L.RaidHeader:ToggleSimulation("10")
            end
            UpdateSimButtons()
        end
    end)

    btnSim25:SetScript("OnClick", function()
        if R4L.RaidHeader then
            if R4L.RaidHeader.isSimulating and R4L.RaidHeader.simMode == "25" then
                R4L.RaidHeader:ToggleSimulation(nil)
            else
                R4L.RaidHeader:ToggleSimulation("25")
            end
            UpdateSimButtons()
        end
    end)

    btnSim40:SetScript("OnClick", function()
        if R4L.RaidHeader then
            if R4L.RaidHeader.isSimulating and R4L.RaidHeader.simMode == "40" then
                R4L.RaidHeader:ToggleSimulation(nil)
            else
                R4L.RaidHeader:ToggleSimulation("40")
            end
            UpdateSimButtons()
        end
    end)

    p5:SetScript("OnShow", function()
        cbRaidEnable:SetChecked(cfg.raid.enabled)
        cbTanks:SetChecked(cfg.raid.showTanks)
        cbMyGroup:SetChecked(cfg.raid.showMyGroup)
        cbRaidRem:SetChecked(cfg.raid.showRaid)
        cbPets:SetChecked(cfg.raid.showPets)
        UpdateRaidLockBtn()
        UpdateOrientationButtons()
        UpdateSimButtons()
    end)

    -- =========================================================================
    -- TAB 6: PROFIL / IM- UND EXPORT
    -- =========================================================================
    local p6 = frame.tabPanels[6]

    local p6Desc = p6:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p6Desc:SetPoint("TOPLEFT", p6, "TOPLEFT", 20, -15)
    p6Desc:SetText(L["PROFILES_DESC"])

    -- ScrollFrame für Im- / Export String
    local scrollFrame = CreateFrame("ScrollFrame", nil, p6, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", p6, "TOPLEFT", 20, -60)
    scrollFrame:SetSize(620, 160)

    local exportBox = CreateFrame("EditBox", nil, scrollFrame)
    exportBox:SetMultiLine(true)
    exportBox:SetSize(600, 160)
    exportBox:SetFontObject("GameFontHighlightSmall")
    exportBox:SetAutoFocus(false)
    scrollFrame:SetScrollChild(exportBox)

    local statusMsg = p6:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusMsg:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -15)
    statusMsg:SetText("")

    -- Export Button
    local btnExport = CreateFrame("Button", nil, p6, "UIPanelButtonTemplate")
    btnExport:SetSize(130, 26)
    btnExport:SetPoint("TOPLEFT", statusMsg, "BOTTOMLEFT", 0, -15)
    btnExport:SetText(L["EXPORT_BTN"])
    btnExport:SetScript("OnClick", function()
        local str = R4L.ProfileManager:ExportProfileString()
        exportBox:SetText(str)
        exportBox:HighlightText()
        exportBox:SetFocus()
        statusMsg:SetText(L["STRING_GENERATED_COPY"])
    end)

    -- Import Button
    local btnImport = CreateFrame("Button", nil, p6, "UIPanelButtonTemplate")
    btnImport:SetSize(130, 26)
    btnImport:SetPoint("LEFT", btnExport, "RIGHT", 15, 0)
    btnImport:SetText(L["IMPORT_BTN"])
    btnImport:SetScript("OnClick", function()
        local text = exportBox:GetText()
        local success, msg = R4L.ProfileManager:ImportProfileString(text)
        if success then
            statusMsg:SetText("|cff00ff00" .. msg .. "|r")
        else
            statusMsg:SetText("|cffff0000" .. msg .. "|r")
        end
    end)

    -- Reset Button
    local btnReset = CreateFrame("Button", nil, p6, "UIPanelButtonTemplate")
    btnReset:SetSize(150, 26)
    btnReset:SetPoint("LEFT", btnImport, "RIGHT", 15, 0)
    btnReset:SetText(L["RESET_DEFAULTS_BTN"])
    btnReset:SetScript("OnClick", function()
        R4L.ProfileManager:ResetToDefaults()
        statusMsg:SetText(L["PROFILE_RESET_SUCCESS"])
    end)


    OUI:SelectTab(1)
    frame:Hide()
end

function OUI:SelectTab(tabIndex)
    currentTab = tabIndex
    for i, btn in ipairs(frame.tabButtons) do
        if i == tabIndex then
            btn:SetNormalFontObject("GameFontHighlight")
            frame.tabPanels[i]:Show()
        else
            btn:SetNormalFontObject("GameFontNormal")
            frame.tabPanels[i]:Hide()
        end
    end
end

function OUI:Toggle()
    if not frame then
        self:Initialize()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
