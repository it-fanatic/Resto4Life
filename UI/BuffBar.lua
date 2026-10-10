--[[
    Resto4Life - UI/BuffBar.lua
    Kompakte, durchgehend sichtbare Buff-Bar mit Click-to-Cast,
    rotem Rahmen bei fehlendem Buff und intelligenter Ziel-Priorisierung.
--]]

local _, R4L = ...
local L = R4L.L

R4L.BuffBar = {}
local BB = R4L.BuffBar

local container = nil
local mover = nil
local buttons = {}
local isLocked = true

-- Datenbank aller relevanten Klassen-Buffs mit fixen Icon-Pfaden (100% kompatibel mit allen Clients)
local CLASS_BUFFS = {
    DRUID = {
        {
            id = 1126,
            name = "Mal der Wildnis",
            altNames = { "Mal der Wildnis", "Gabe der Wildnis", "Mark of the Wild", "Gift of the Wild" },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Nature_Regeneration",
        },
        {
            id = 467,
            name = "Dornen",
            altNames = { "Dornen", "Thorns" },
            defaultTarget = "TANK",
            iconPath = "Interface\\Icons\\Spell_Nature_Thorns",
        },
        {
            id = 16864,
            name = "Omen der Klarsicht",
            altNames = { "Omen der Klarsicht", "Omen of Clarity" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Nature_CrystalBall",
        },
    },
    PRIEST = {
        {
            id = 1243,
            name = "Machtwort: Seelenstärke",
            altNames = { "Machtwort: Seelenstärke", "Gebet der Seelenstärke", "Power Word: Fortitude", "Prayer of Fortitude" },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Holy_WordFortitude",
        },
        {
            id = 14752,
            name = "Göttlicher Wille",
            altNames = { "Göttlicher Wille", "Gebet der Willenskraft", "Divine Spirit", "Prayer of Spirit" },
            defaultTarget = "MANA",
            iconPath = "Interface\\Icons\\Spell_Holy_DivineSpirit",
        },
        {
            id = 588,
            name = "Inneres Feuer",
            altNames = { "Inneres Feuer", "Inner Fire" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Holy_InnerFire",
        },
        {
            id = 976,
            name = "Schattenschutz",
            altNames = { "Schattenschutz", "Gebet des Schattenschutzes", "Shadow Protection", "Prayer of Shadow Protection" },
            defaultTarget = "OFF",
            iconPath = "Interface\\Icons\\Spell_Shadow_AntiShadow",
        },
    },
    MAGE = {
        {
            id = 1459,
            name = "Arkane Intelligenz",
            altNames = { "Arkane Intelligenz", "Arkane Brillanz", "Arcane Intellect", "Arcane Brilliance" },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        },
        {
            id = 7302,
            name = "Eisrüstung",
            altNames = { "Eisrüstung", "Frostrüstung", "Magische Rüstung", "Glühende Rüstung", "Ice Armor", "Frost Armor", "Mage Armor", "Molten Armor" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Frost_FrostArmor02",
        },
    },
    PALADIN = {
        {
            id = 19740,
            name = "Segen der Macht",
            altNames = { "Segen der Macht", "Großer Segen der Macht", "Blessing of Might", "Greater Blessing of Might" },
            defaultTarget = "MELEE",
            iconPath = "Interface\\Icons\\Spell_Holy_FistOfJustice",
        },
        {
            id = 19742,
            name = "Segen der Weisheit",
            altNames = { "Segen der Weisheit", "Großer Segen der Weisheit", "Blessing of Wisdom", "Greater Blessing of Wisdom" },
            defaultTarget = "MANA",
            iconPath = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
        },
        {
            id = 20217,
            name = "Segen der Könige",
            altNames = { "Segen der Könige", "Großer Segen der Könige", "Blessing of Kings", "Greater Blessing of Kings" },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Magic_MageArmor",
        },
        {
            id = 25780,
            name = "Zorn der Gerechtigkeit",
            altNames = { "Zorn der Gerechtigkeit", "Rechtschaffene Zorn", "Righteous Fury" },
            defaultTarget = "TANK",
            iconPath = "Interface\\Icons\\Spell_Holy_SealOfFury",
        },
    },
    SHAMAN = {
        {
            id = 52127,
            name = "Wasserschild",
            altNames = { "Wasserschild", "Blitzschlagschild", "Water Shield", "Lightning Shield" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Shaman_WaterShield",
        },
    },
    WARLOCK = {
        {
            id = 687,
            name = "Dämonenrüstung",
            altNames = { "Dämonenhaut", "Dämonenrüstung", "Teufelsrüstung", "Demon Skin", "Demon Armor", "Fel Armor" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Shadow_RagingScream",
        },
        {
            id = 19028,
            name = "Seelenverbindung",
            altNames = { "Seelenverbindung", "Soul Link" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Shadow_SoulLeech_3",
        },
    },
    WARRIOR = {
        {
            id = 6673,
            name = "Schlachtruf",
            altNames = { "Schlachtruf", "Battle Shout" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Warrior_BattleShout",
        },
        {
            id = 469,
            name = "Befehlsruf",
            altNames = { "Befehlsruf", "Commanding Shout" },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Warrior_RallyingCry",
        },
    },
}

-- Bereinigt Zaubernamen von Rang-Zusätzen
local function CleanSpellName(name)
    if not name then return "" end
    local base = name:match("^(.-)%s*%(")
    return base or name
end

-- Prüft sicher mit pcall, ob der Spieler den Zauber beherrscht
local function PlayerKnowsSpell(spellDef)
    if not spellDef then return false end

    -- 1. Check IsPlayerSpell / IsSpellKnown (Modern Retail & neuere Classic Clients)
    if spellDef.id then
        local ok, known = pcall(function()
            if C_Spell and C_Spell.IsSpellKnown and C_Spell.IsSpellKnown(spellDef.id) then return true end
            if IsPlayerSpell and IsPlayerSpell(spellDef.id) then return true end
            if IsSpellKnown and IsSpellKnown(spellDef.id) then return true end
            return false
        end)
        if ok and known == true then return true end
    end

    -- 2. Zauberbuch-Prüfung über Tabs (100% kompatibel mit Classic, WotLK 3.3.5, Vanilla)
    local okBook, knownBook = pcall(function()
        local spellBank = (BOOKTYPE_SPELL ~= nil) and BOOKTYPE_SPELL or "spell"
        local numTabs = (GetNumSpellTabs and GetNumSpellTabs()) or 0

        if numTabs > 0 and GetSpellTabInfo then
            for t = 1, numTabs do
                local _, _, offset, numSpells = GetSpellTabInfo(t)
                if offset and numSpells then
                    for s = offset + 1, offset + numSpells do
                        local bookName = GetSpellBookItemName(s, spellBank)
                        if bookName then
                            local clean = CleanSpellName(bookName)
                            for _, alt in ipairs(spellDef.altNames or {}) do
                                if clean == alt or bookName == alt then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        else
            -- Fallback wenn GetNumSpellTabs nicht verfügbar ist
            for i = 1, 300 do
                local bookName = GetSpellBookItemName(i, spellBank)
                if bookName then
                    local clean = CleanSpellName(bookName)
                    for _, alt in ipairs(spellDef.altNames or {}) do
                        if clean == alt or bookName == alt then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end)
    if okBook and knownBook == true then return true end

    -- 3. Zauber ist weder erlernt noch geskillt
    return false
end

-- Prüft, ob eine Zieleinheit zur eingestellten Zielgruppe passt
local function UnitMatchesFilter(unit, targetFilter)
    if targetFilter == "OFF" then return false end
    if targetFilter == "ALL" then return true end

    if targetFilter == "SELF" then
        return UnitIsUnit(unit, "player")
    end

    if targetFilter == "TANK" then
        if UnitGroupRolesAssigned then
            local ok, role = pcall(UnitGroupRolesAssigned, unit)
            if ok and role == "TANK" then return true end
        end
        if GetPartyAssignment then
            local ok, isTank = pcall(function() return GetPartyAssignment("MAINTANK", unit) or GetPartyAssignment("MAINASSIST", unit) end)
            if ok and isTank then return true end
        end
        -- In einer Gruppe oder Raid: Suche nach Krieger, Bär, Paladin
        if IsInGroup() or IsInRaid() then
            local _, uClass = UnitClass(unit)
            if (uClass == "WARRIOR" or uClass == "PALADIN" or uClass == "DEATHKNIGHT") and not UnitIsUnit(unit, "player") then
                return true
            end
            return false
        else
            -- Wenn solo: Spieler selbst als Ziel für Dornen erlauben
            return true
        end
    end

    if targetFilter == "MANA" then
        local pType = UnitPowerType(unit)
        return (pType == 0)
    end

    if targetFilter == "MELEE" then
        local _, uClass = UnitClass(unit)
        if uClass == "WARRIOR" or uClass == "ROGUE" or uClass == "DEATHKNIGHT" or uClass == "DEMONHUNTER" then
            return true
        end
        if UnitGroupRolesAssigned then
            local role = UnitGroupRolesAssigned(unit)
            if role == "DAMAGER" and (uClass == "PALADIN" or uClass == "SHAMAN" or uClass == "DRUID") then
                return (UnitPowerType(unit) ~= 0)
            end
        end
        return false
    end

    return true
end

-- Prüft, ob eine Einheit den Buff bereits aktiv hat
local function UnitHasBuff(unit, spellDef)
    if not unit or not UnitExists(unit) then return false end

    for i = 1, 40 do
        local buffName = nil
        local auraSpellId = nil

        -- 1. Modern C_UnitAuras
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if ok and data and type(data) == "table" and data.name then
                buffName = data.name
                auraSpellId = data.spellId
            end
        end

        -- 2. Classic UnitAura
        if not buffName and UnitAura then
            local ok, name, _, _, _, _, _, _, _, _, spellId = pcall(UnitAura, unit, i, "HELPFUL")
            if ok and name then
                buffName = name
                auraSpellId = spellId
            end
        end

        -- 3. Älteres UnitBuff
        if not buffName and UnitBuff then
            local ok, name = pcall(UnitBuff, unit, i)
            if ok and name then
                buffName = name
            end
        end

        if not buffName then break end

        -- Prüfe Spell-ID Treffer
        if auraSpellId and auraSpellId == spellDef.id then
            return true
        end

        -- Prüfe Namens-Treffer
        local clean = CleanSpellName(buffName)
        for _, alt in ipairs(spellDef.altNames or {}) do
            if clean == alt or buffName == alt then
                return true
            end
        end
    end

    return false
end

-- Liefert alle relevanten Gruppen-Einheiten
local function GetRosterUnits()
    local units = {}
    table.insert(units, "player")

    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                table.insert(units, u)
            end
        end
    else
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                table.insert(units, u)
            end
        end
    end

    return units
end

-- Ermittelt die Priorität einer fehlenden Einheit (niedriger = dringender)
-- 1. Tank -> 2. Heiler (Spieler selbst) -> 3. Nahkämpfer -> 4. Fernkämpfer/Rest
local function GetUnitPriority(unit)
    if UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(unit)
        if role == "TANK" then return 1 end
    end
    if GetPartyAssignment and (GetPartyAssignment("MAINTANK", unit) or GetPartyAssignment("MAINASSIST", unit)) then
        return 1
    end
    if UnitIsUnit(unit, "player") then return 2 end

    local _, uClass = UnitClass(unit)
    if uClass == "WARRIOR" or uClass == "ROGUE" or uClass == "DEATHKNIGHT" then
        return 3
    end

    return 4
end

-- Aktualisiert die Buff-Buttons
function BB:Update()
    if not container or not buttons then return end
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg or not cfg.buffBar or cfg.buffBar.enabled == false then
        container:Hide()
        return
    end

    container:Show()

    local units = GetRosterUnits()
    local visibleCount = 0
    local iconSize = (cfg.buffBar and cfg.buffBar.iconSize) or 22
    local spacing = (cfg.buffBar and cfg.buffBar.spacing) or 4
    local currentX = 0

    for idx, btn in ipairs(buttons) do
        local spellDef = btn.spellDef
        btn.isKnown = PlayerKnowsSpell(spellDef)
        local targetFilter = (cfg.buffBar.targets and cfg.buffBar.targets[spellDef.name]) or spellDef.defaultTarget

        if targetFilter ~= "OFF" and btn.isKnown then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", container, "LEFT", currentX, 0)
            currentX = currentX + iconSize + spacing
            visibleCount = visibleCount + 1
            btn:Show()

            local missingUnits = {}

            for _, u in ipairs(units) do
                if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) then
                    if UnitMatchesFilter(u, targetFilter) then
                        local inRange = R4L:IsUnitInRange(u)
                        if inRange then
                            if not UnitHasBuff(u, spellDef) then
                                table.insert(missingUnits, u)
                            end
                        end
                    end
                end
            end

            -- Sortiere die fehlenden Einheiten nach Priorität
            table.sort(missingUnits, function(a, b)
                return GetUnitPriority(a) < GetUnitPriority(b)
            end)

            local missingCount = #missingUnits
            local bestUnit = missingUnits[1]

            -- Visuelles Feedback
            if missingCount > 0 then
                -- Roter leuchtender Rahmen bei fehlendem Buff
                btn:SetBackdropBorderColor(1, 0, 0, 1)
                btn:SetBackdropColor(0, 0, 0, 0.7)
                btn.tex:SetVertexColor(1, 1, 1, 1)
                btn.countText:SetText(tostring(missingCount))
                btn.countText:SetTextColor(1, 0.3, 0.3, 1)
            else
                -- Schlichter schwarzer Rand wenn voll durchgebufft
                btn:SetBackdropBorderColor(0, 0, 0, 1)
                btn:SetBackdropColor(0, 0, 0, 0.6)
                btn.tex:SetVertexColor(0.8, 0.8, 0.8, 0.9)
                btn.countText:SetText("")
            end

            -- Click-to-Cast Attribut aktualisieren (nur außerhalb des Kampfes)
            if not InCombatLockdown() then
                local castSpell = spellDef.name
                if spellDef.id and GetSpellInfo then
                    local okName, realName = pcall(GetSpellInfo, spellDef.id)
                    if okName and realName and realName ~= "" then
                        castSpell = realName
                    end
                end

                if bestUnit then
                    btn:SetAttribute("type", "spell")
                    btn:SetAttribute("unit", bestUnit)
                    btn:SetAttribute("spell", castSpell)
                else
                    btn:SetAttribute("type", "spell")
                    btn:SetAttribute("unit", "player")
                    btn:SetAttribute("spell", castSpell)
                end
            end

            btn.missingUnits = missingUnits
            btn.targetFilter = targetFilter
        else
            btn:Hide()
            btn.missingUnits = {}
        end
    end

    if visibleCount == 0 then
        container:Hide()
        return
    end

    -- Container-Breite dynamisch anpassen
    local totalWidth = (visibleCount * iconSize) + (math.max(0, visibleCount - 1) * spacing)
    container:SetSize(totalWidth, iconSize)
end

-- Erstellt die Buff-Buttons für die Klasse des Spielers
function BB:Initialize()
    if container then return end

    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.buffBar then
        cfg.buffBar = {
            enabled = true,
            iconSize = 22,
            spacing = 4,
            posX = 300,
            posY = -230,
            locked = true,
            targets = {},
        }
    end

    local iconSize = cfg.buffBar.iconSize or 22
    local spacing = cfg.buffBar.spacing or 4

    container = CreateFrame("Frame", "Resto4LifeBuffBar", UIParent)
    container:SetSize(100, iconSize)
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.buffBar.posX or 300, cfg.buffBar.posY or -230)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    self.container = container

    -- Mover (für entsperrten Zustand via Minimap / /r4l unlock)
    mover = CreateFrame("Frame", "Resto4LifeBuffBarMover", container, "BackdropTemplate")
    mover:SetAllPoints(container)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0, 0.7, 0.4, 0.5)
    mover:SetBackdropBorderColor(0, 1, 0.6, 1)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetFrameLevel(container:GetFrameLevel() + 20)

    local moverText = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    moverText:SetPoint("CENTER")
    moverText:SetText(L["BUFF_BAR_TITLE"] or "Buffs")
    moverText:SetTextColor(1, 1, 1, 1)

    mover:SetScript("OnDragStart", function()
        container:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
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
            cfg.buffBar.posX = math.floor(screenLeft / cScale)
            cfg.buffBar.posY = math.floor((screenTop - parentTop) / cScale)
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.buffBar.posX, cfg.buffBar.posY)
        end
    end)

    mover:Hide()
    self.mover = mover

    -- Hole Klassen-Buffs
    local _, pClass = UnitClass("player")
    local classList = CLASS_BUFFS[pClass] or {}

    buttons = {}
    local xOffset = 0

    for i, spellDef in ipairs(classList) do
        local btn = CreateFrame("Button", "Resto4LifeBuffBtn" .. i, container, "SecureActionButtonTemplate,BackdropTemplate")
        btn:SetSize(iconSize, iconSize)
        btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)
        btn:SetFrameLevel(container:GetFrameLevel() + 5)
        btn:RegisterForClicks("AnyUp", "AnyDown")

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0, 0, 0, 0.6)
        btn:SetBackdropBorderColor(0, 0, 0, 1)

        -- Zauber-Icon
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Robuste Textur: Immer garantierten Texturpfad bevorzugen, um schwarze Icons zu vermeiden
        local texPath = spellDef.iconPath
        if not texPath or texPath == "" then
            if GetSpellTexture then
                local ok, sTex = pcall(GetSpellTexture, spellDef.name or spellDef.id)
                if ok and sTex then texPath = sTex end
            end
            if not texPath and GetSpellInfo then
                local ok, _, _, sIcon = pcall(GetSpellInfo, spellDef.id)
                if ok and sIcon then texPath = sIcon end
            end
        end
        tex:SetTexture(texPath or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.tex = tex

        -- Kleiner Zähler für fehlende Buffs (unten rechts)
        local countText = btn:CreateFontString(nil, "OVERLAY")
        if not countText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE") then
            countText:SetFontObject("GameFontHighlightSmall")
        end
        countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        countText:SetTextColor(1, 1, 1, 1)
        btn.countText = countText

        btn.spellDef = spellDef
        btn.isKnown = PlayerKnowsSpell(spellDef)

        -- Tooltip beim Hovern
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(spellDef.name, 1, 1, 1)

            local filterName = (cfg.buffBar.targets and cfg.buffBar.targets[spellDef.name]) or spellDef.defaultTarget
            local filterDesc = filterName == "ALL" and "Alle" or (filterName == "TANK" and "Nur Tank" or (filterName == "SELF" and "Nur Selbst" or (filterName == "MANA" and "Mana-Klassen" or filterName)))
            GameTooltip:AddLine("Zielgruppe: |cff00ff00" .. filterDesc .. "|r", 0.8, 0.8, 0.8)

            if self.missingUnits and #self.missingUnits > 0 then
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cffff4444Fehlt bei (" .. #self.missingUnits .. "):|r", 1, 0.3, 0.3)
                for _, u in ipairs(self.missingUnits) do
                    local uName = UnitName(u) or u
                    GameTooltip:AddLine(" • " .. uName, 1, 0.8, 0.8)
                end
                local nextTarget = UnitName(self.missingUnits[1]) or self.missingUnits[1]
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cff00ff00Linksklick: Zaubert auf " .. nextTarget .. "|r", 0, 1, 0)
            else
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cff00ff00Alle Einheiten gebufft (OK)|r", 0, 1, 0)
            end
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        table.insert(buttons, btn)
        xOffset = xOffset + iconSize + spacing
    end

    self.buttons = buttons
    self:Update()
end

-- Sperren / Entsperren des Drag-Handles (über Minimap / /r4l unlock)
function BB:ToggleLock(locked)
    if not container or not mover then return end
    local cfg = R4L.ProfileManager:GetConfig()

    if locked == nil then
        isLocked = not isLocked
    else
        isLocked = locked
    end

    cfg.buffBar.locked = isLocked

    if isLocked then
        mover:Hide()
    else
        mover:Show()
    end
end

-- Position zurücksetzen (Mitte / Standard)
function BB:ResetPosition()
    if not container then return end
    local cfg = R4L.ProfileManager:GetConfig()
    cfg.buffBar.posX = 300
    cfg.buffBar.posY = -230
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.buffBar.posX, cfg.buffBar.posY)
    R4L:Print("Buff-Bar Position zurückgesetzt.")
end

-- Events registrieren
R4L:RegisterEvent("PLAYER_LOGIN", function()
    BB:Initialize()
end)

R4L:RegisterEvent("UNIT_AURA", function()
    BB:Update()
end)

R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    BB:Update()
end)

R4L:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    BB:Update()
end)

R4L:RegisterEvent("SPELLS_CHANGED", function()
    if buttons then
        for _, btn in ipairs(buttons) do
            btn.isKnown = PlayerKnowsSpell(btn.spellDef)
        end
    end
    BB:Update()
end)
