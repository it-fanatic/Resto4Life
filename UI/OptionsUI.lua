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
    frame:SetSize(580, 530)
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

    -- Schließen Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Tab-Leiste
    local tabs = { L["TAB_GENERAL"], L["TAB_BINDINGS"], L["TAB_HOTS"], L["TAB_PROFILES"] }
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
        btn:SetSize(125, 24)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + (i - 1) * 132, -42)
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
    end)

    -- In Bildschirm-Mitte zentrieren Button (kleiner Button)
    local btnCenter = CreateFrame("Button", nil, p1, "UIPanelButtonTemplate")
    btnCenter:SetSize(85, 22)
    btnCenter:SetPoint("LEFT", cbLock.text, "RIGHT", 15, 0)
    btnCenter:SetText(L["POS_RESET"])
    btnCenter:SetScript("OnClick", function()
        R4L.GroupHeader:ResetPosition()
    end)

    -- Spielernamen anzeigen
    local cbNames = CreateCheckbox(p1, L["SHOW_NAMES"], 20, -55, function(val)
        cfg.display.showNames = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Manabalken anzeigen
    local cbMana = CreateCheckbox(p1, L["SHOW_MANA"], 20, -90, function(val)
        cfg.display.showManaBar = val
        R4L.GroupHeader:UpdateLayout()
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Reverse Health Bar (Defizitanzeige)
    local cbReverse = CreateCheckbox(p1, L["REVERSE_HEALTH"], 20, -125, function(val)
        cfg.display.healthOrientation = val and "REVERSE" or "NORMAL"
        R4L:Print(val and L["CHAT_REVERSE_ACTIVE"] or L["CHAT_REVERSE_INACTIVE"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Farbmodus Label & Buttons
    local colorLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -162)
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
    end)

    btnMinimalColor:SetScript("OnClick", function()
        cfg.display.colorMode = "MINIMAL"
        UpdateColorButtons()
        R4L:Print(L["CHAT_COLOR_MINIMAL"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Ausrichtung / Anordnung (Spalte vs Zeile)
    local layoutLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    layoutLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -198)
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
    btnSim:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -236)

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

    -- Automatische Sortierung
    local cbSort = CreateCheckbox(p1, L["AUTO_SORT"], 20, -270, function(val)
        cfg.sorting.enabled = val
        R4L.GroupHeader:UpdateRoster()
    end)

    -- Reichweiten-Verblassen
    local cbRange = CreateCheckbox(p1, L["FADE_OUT_OF_RANGE"], 20, -300, function(val)
        cfg.display.fadeOutOfRange = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Ziel bei Zauber ins Target nehmen
    local cbTargetOnCast = CreateCheckbox(p1, L["TARGET_ON_CAST"], 20, -330, function(val)
        cfg.general.targetOnCast = val
        R4L:Print(val and L["CHAT_TARGET_ON_CAST_ON"] or L["CHAT_TARGET_ON_CAST_OFF"])
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Minimap-Button anzeigen
    local cbMinimap = CreateCheckbox(p1, L["SHOW_MINIMAP_CB"], 20, -365, function(val)
        if not cfg.minimap then cfg.minimap = {} end
        cfg.minimap.show = val
        if R4L.MinimapButton then
            R4L.MinimapButton:SetShown(val)
        end
    end)

    -- Skalierung (Größe)
    local scaleLabel = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleLabel:SetPoint("TOPLEFT", p1, "TOPLEFT", 20, -404)
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
    -- TAB 2: TASTENBELEGUNG (CLICK-CASTING)
    -- =========================================================================
    local p2 = frame.tabPanels[2]

    local p2Desc = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p2Desc:SetPoint("TOPLEFT", p2, "TOPLEFT", 20, -15)
    p2Desc:SetText(L["BINDINGS_HEADER"])

    -- Linksklick
    local ebLeft = CreateEditBox(p2, L["LEFT_CLICK"], 20, -40, 180, function(val)
        cfg.bindings["1"].action = "spell"
        cfg.bindings["1"].spell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Rechtsklick
    local ebRight = CreateEditBox(p2, L["RIGHT_CLICK"], 220, -40, 180, function(val)
        cfg.bindings["2"].action = "spell"
        cfg.bindings["2"].spell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Mittlere Maustaste
    local ebMid = CreateEditBox(p2, L["MID_CLICK"], 20, -85, 180, function(val)
        cfg.bindings["3"].action = "spell"
        cfg.bindings["3"].spell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Mausrad Hoch
    local ebWheelUp = CreateEditBox(p2, L["WHEEL_UP"], 220, -85, 180, function(val)
        cfg.bindings["WheelUp"].action = "spell"
        cfg.bindings["WheelUp"].spell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Mausrad Runter
    local ebWheelDown = CreateEditBox(p2, L["WHEEL_DOWN"], 20, -130, 180, function(val)
        cfg.bindings["WheelDown"].action = "spell"
        cfg.bindings["WheelDown"].spell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    -- Tasten 1 bis 6
    local ebKeys = {}
    for i = 1, 6 do
        local col = (i <= 3) and 1 or 2
        local row = (i <= 3) and i or (i - 3)
        local posX = (col == 1) and 20 or 220
        local posY = -175 - (row - 1) * 45

        local eb = CreateEditBox(p2, string.format(L["KEY_N_FMT"], i), posX, posY, 180, function(val)
            local k = "KEY_" .. i
            cfg.bindings[k].action = "spell"
            cfg.bindings[k].spell = val
            R4L.ClickCast:ApplyAllBindings()
        end)
        ebKeys[i] = eb
    end

    -- Smart Battle Rez Sektion (unten)
    local cbSmartRez = CreateCheckbox(p2, L["SMART_REZ_ENABLE"], 20, -320, function(val)
        cfg.smartRez.enabled = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    local ebBattleRez = CreateEditBox(p2, L["COMBAT_REZ_SPELL"], 20, -355, 180, function(val)
        cfg.smartRez.combatRezSpell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    local ebNormalRez = CreateEditBox(p2, L["NORMAL_REZ_SPELL"], 220, -355, 180, function(val)
        cfg.smartRez.normalRezSpell = val
        R4L.ClickCast:ApplyAllBindings()
    end)

    p2:SetScript("OnShow", function()
        ebLeft:SetText(cfg.bindings["1"] and cfg.bindings["1"].spell or "")
        ebRight:SetText(cfg.bindings["2"] and cfg.bindings["2"].spell or "")
        ebMid:SetText(cfg.bindings["3"] and cfg.bindings["3"].spell or "")
        ebWheelUp:SetText(cfg.bindings["WheelUp"] and cfg.bindings["WheelUp"].spell or "")
        ebWheelDown:SetText(cfg.bindings["WheelDown"] and cfg.bindings["WheelDown"].spell or "")
        for i = 1, 6 do
            local k = "KEY_" .. i
            ebKeys[i]:SetText(cfg.bindings[k] and cfg.bindings[k].spell or "")
        end
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
    end)

    local cbDebuffs = CreateCheckbox(p3, L["COLOR_DEBUFFS_CB"], 20, -60, function(val)
        cfg.auras.showDebuffs = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    local cbDispOnly = CreateCheckbox(p3, L["DISP_ONLY_CB"], 40, -95, function(val)
        cfg.auras.highlightDispellableOnly = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    local cbCurse = CreateCheckbox(p3, L["HIGHLIGHT_CURSE"], 40, -135, function(val)
        cfg.auras.showCurse = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    local cbPoison = CreateCheckbox(p3, L["HIGHLIGHT_POISON"], 40, -170, function(val)
        cfg.auras.showPoison = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    local cbDisease = CreateCheckbox(p3, L["HIGHLIGHT_DISEASE"], 40, -205, function(val)
        cfg.auras.showDisease = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    local cbMagic = CreateCheckbox(p3, L["HIGHLIGHT_MAGIC"], 40, -240, function(val)
        cfg.auras.showMagic = val
        R4L.GroupHeader:UpdateAllFrames()
    end)

    -- Test-Modus für Debuffs
    local testHeader = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    testHeader:SetPoint("TOPLEFT", p3, "TOPLEFT", 20, -280)
    testHeader:SetText(L["DEBUFF_TEST_HEADER"])

    local btnTestPoison = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestPoison:SetSize(110, 24)
    btnTestPoison:SetPoint("TOPLEFT", testHeader, "BOTTOMLEFT", 0, -8)
    btnTestPoison:SetText(L["POISON_TEST_BTN"])

    local btnTestCurse = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestCurse:SetSize(110, 24)
    btnTestCurse:SetPoint("LEFT", btnTestPoison, "RIGHT", 8, 0)
    btnTestCurse:SetText(L["CURSE_TEST_BTN"])

    local btnTestMagic = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestMagic:SetSize(110, 24)
    btnTestMagic:SetPoint("LEFT", btnTestCurse, "RIGHT", 8, 0)
    btnTestMagic:SetText(L["MAGIC_TEST_BTN"])

    local btnTestOff = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    btnTestOff:SetSize(90, 24)
    btnTestOff:SetPoint("LEFT", btnTestMagic, "RIGHT", 8, 0)
    btnTestOff:SetText(L["TEST_OFF_BTN"])

    btnTestPoison:SetScript("OnClick", function()
        R4L.testDebuff = "Poison"
        R4L:Print(L["TEST_POISON_CHAT"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    btnTestCurse:SetScript("OnClick", function()
        R4L.testDebuff = "Curse"
        R4L:Print(L["TEST_CURSE_CHAT"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    btnTestMagic:SetScript("OnClick", function()
        R4L.testDebuff = "Magic"
        R4L:Print(L["TEST_MAGIC_CHAT"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    btnTestOff:SetScript("OnClick", function()
        R4L.testDebuff = nil
        R4L:Print(L["CHAT_TEST_DEBUFF_STOP"])
        R4L.GroupHeader:UpdateAllFrames()
    end)

    p3:SetScript("OnShow", function()
        cbHots:SetChecked(cfg.auras.showHots)
        cbDebuffs:SetChecked(cfg.auras.showDebuffs)
        cbDispOnly:SetChecked(cfg.auras.highlightDispellableOnly)
        cbCurse:SetChecked(cfg.auras.showCurse)
        cbPoison:SetChecked(cfg.auras.showPoison)
        cbDisease:SetChecked(cfg.auras.showDisease)
        cbMagic:SetChecked(cfg.auras.showMagic)
    end)

    -- =========================================================================
    -- TAB 4: PROFIL / IM- UND EXPORT
    -- =========================================================================
    local p4 = frame.tabPanels[4]

    local p4Desc = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p4Desc:SetPoint("TOPLEFT", p4, "TOPLEFT", 20, -15)
    p4Desc:SetText(L["PROFILES_DESC"])

    -- ScrollFrame für Im- / Export String
    local scrollFrame = CreateFrame("ScrollFrame", nil, p4, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", p4, "TOPLEFT", 20, -60)
    scrollFrame:SetSize(490, 160)

    local exportBox = CreateFrame("EditBox", nil, scrollFrame)
    exportBox:SetMultiLine(true)
    exportBox:SetSize(470, 160)
    exportBox:SetFontObject("GameFontHighlightSmall")
    exportBox:SetAutoFocus(false)
    scrollFrame:SetScrollChild(exportBox)

    local statusMsg = p4:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusMsg:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -15)
    statusMsg:SetText("")

    -- Export Button
    local btnExport = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
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
    local btnImport = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
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
    local btnReset = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
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
