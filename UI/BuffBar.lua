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
            allSpellIds = { [1126]=true, [5232]=true, [6756]=true, [5234]=true, [8907]=true, [9884]=true, [9885]=true, [26990]=true, [48469]=true, [16908]=true, [21849]=true, [21850]=true, [26991]=true, [48470]=true },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Nature_Regeneration",
            iconFileID = 136076,
            minDuration = 60, -- Verhindert Verwechslung mit Verjüngung (HoT, 12s)
        },
        {
            id = 467,
            name = "Dornen",
            altNames = { "Dornen", "Thorns" },
            allSpellIds = { [467]=true, [782]=true, [1075]=true, [8914]=true, [9756]=true, [9910]=true, [26992]=true, [48471]=true, [53307]=true },
            defaultTarget = "TANK",
            iconPath = "Interface\\Icons\\Spell_Nature_Thorns",
            iconFileID = 136104,
        },
    },
    PRIEST = {
        {
            id = 1243,
            name = "Machtwort: Seelenstärke",
            altNames = { "Machtwort: Seelenstärke", "Gebet der Seelenstärke", "Power Word: Fortitude", "Prayer of Fortitude" },
            allSpellIds = { [1243]=true, [1244]=true, [1245]=true, [2791]=true, [10937]=true, [10938]=true, [25389]=true, [48161]=true, [21562]=true, [21564]=true, [48162]=true },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Holy_WordFortitude",
            iconFileID = 135987,
        },
        {
            id = 14752,
            name = "Göttlicher Wille",
            altNames = { "Göttlicher Wille", "Gebet der Willenskraft", "Divine Spirit", "Prayer of Spirit" },
            allSpellIds = { [14752]=true, [14818]=true, [14819]=true, [27841]=true, [32999]=true, [48073]=true, [27681]=true, [48074]=true },
            defaultTarget = "MANA",
            iconPath = "Interface\\Icons\\Spell_Holy_DivineSpirit",
            iconFileID = 135899,
        },
        {
            id = 588,
            name = "Inneres Feuer",
            altNames = { "Inneres Feuer", "Inner Fire" },
            allSpellIds = { [588]=true, [7128]=true, [602]=true, [1006]=true, [10951]=true, [10952]=true, [25431]=true, [48040]=true, [48168]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Holy_InnerFire",
            iconFileID = 135926,
        },
        {
            id = 976,
            name = "Schattenschutz",
            altNames = { "Schattenschutz", "Gebet des Schattenschutzes", "Shadow Protection", "Prayer of Shadow Protection" },
            allSpellIds = { [976]=true, [10957]=true, [10958]=true, [25433]=true, [48169]=true, [48170]=true, [27683]=true, [39374]=true },
            defaultTarget = "OFF",
            iconPath = "Interface\\Icons\\Spell_Shadow_AntiShadow",
            iconFileID = 136121,
        },
    },
    MAGE = {
        {
            id = 1459,
            name = "Arkane Intelligenz",
            altNames = { "Arkane Intelligenz", "Arkane Brillanz", "Arcane Intellect", "Arcane Brilliance" },
            allSpellIds = { [1459]=true, [1460]=true, [1461]=true, [10156]=true, [10157]=true, [27126]=true, [42995]=true, [23028]=true, [27127]=true, [43002]=true },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Holy_MagicalSentry",
            iconFileID = 135932,
        },
        {
            id = 7302,
            name = "Eisrüstung",
            altNames = { "Eisrüstung", "Frostrüstung", "Magische Rüstung", "Glühende Rüstung", "Ice Armor", "Frost Armor", "Mage Armor", "Molten Armor" },
            allSpellIds = { [7302]=true, [7300]=true, [7301]=true, [12544]=true, [6143]=true, [8494]=true, [8495]=true, [10173]=true, [10174]=true, [27124]=true, [43008]=true, [6117]=true, [22782]=true, [22783]=true, [27125]=true, [43023]=true, [43024]=true, [30482]=true, [43046]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Frost_FrostArmor02",
            iconFileID = 135843,
        },
    },
    PALADIN = {
        {
            id = 19740,
            name = "Segen der Macht",
            altNames = { "Segen der Macht", "Großer Segen der Macht", "Blessing of Might", "Greater Blessing of Might" },
            allSpellIds = { [19740]=true, [19834]=true, [19835]=true, [19836]=true, [19837]=true, [19838]=true, [25782]=true, [27140]=true, [48931]=true, [48932]=true, [25898]=true, [25916]=true, [27141]=true, [48933]=true, [48934]=true },
            defaultTarget = "MELEE",
            iconPath = "Interface\\Icons\\Spell_Holy_FistOfJustice",
            iconFileID = 135906,
        },
        {
            id = 19742,
            name = "Segen der Weisheit",
            altNames = { "Segen der Weisheit", "Großer Segen der Weisheit", "Blessing of Wisdom", "Greater Blessing of Wisdom" },
            allSpellIds = { [19742]=true, [19850]=true, [19852]=true, [19853]=true, [19854]=true, [25290]=true, [27142]=true, [48935]=true, [48936]=true, [25894]=true, [25918]=true, [27143]=true, [48937]=true, [48938]=true },
            defaultTarget = "MANA",
            iconPath = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
            iconFileID = 135968,
        },
        {
            id = 20217,
            name = "Segen der Könige",
            altNames = { "Segen der Könige", "Großer Segen der Könige", "Blessing of Kings", "Greater Blessing of Kings" },
            allSpellIds = { [20217]=true, [25898]=true, [25899]=true },
            defaultTarget = "ALL",
            iconPath = "Interface\\Icons\\Spell_Magic_MageArmor",
            iconFileID = 136157,
        },
        {
            id = 25780,
            name = "Zorn der Gerechtigkeit",
            altNames = { "Zorn der Gerechtigkeit", "Rechtschaffene Zorn", "Righteous Fury" },
            allSpellIds = { [25780]=true },
            defaultTarget = "TANK",
            iconPath = "Interface\\Icons\\Spell_Holy_SealOfFury",
            iconFileID = 135965,
        },
    },
    SHAMAN = {
        {
            id = 52127,
            name = "Wasserschild",
            altNames = { "Wasserschild", "Blitzschlagschild", "Water Shield", "Lightning Shield" },
            allSpellIds = { [52127]=true, [52128]=true, [52129]=true, [52130]=true, [52131]=true, [52132]=true, [52133]=true, [52134]=true, [52136]=true, [52138]=true, [24398]=true, [33736]=true, [324]=true, [325]=true, [905]=true, [945]=true, [8134]=true, [10431]=true, [10432]=true, [25464]=true, [25472]=true, [49280]=true, [49281]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Shaman_WaterShield",
            iconFileID = 132315,
        },
    },
    WARLOCK = {
        {
            id = 687,
            name = "Dämonenrüstung",
            altNames = { "Dämonenhaut", "Dämonenrüstung", "Teufelsrüstung", "Demon Skin", "Demon Armor", "Fel Armor" },
            allSpellIds = { [687]=true, [696]=true, [706]=true, [1086]=true, [2828]=true, [2829]=true, [2830]=true, [11733]=true, [11734]=true, [11735]=true, [27260]=true, [47793]=true, [47889]=true, [47855]=true, [47856]=true, [47857]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Spell_Shadow_RagingScream",
            iconFileID = 136185,
        },
    },
    WARRIOR = {
        {
            id = 6673,
            name = "Schlachtruf",
            altNames = { "Schlachtruf", "Battle Shout" },
            allSpellIds = { [6673]=true, [5242]=true, [6192]=true, [11549]=true, [11550]=true, [11551]=true, [25289]=true, [47436]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Warrior_BattleShout",
            iconFileID = 132333,
        },
        {
            id = 469,
            name = "Befehlsruf",
            altNames = { "Befehlsruf", "Commanding Shout" },
            allSpellIds = { [469]=true, [47440]=true },
            defaultTarget = "SELF",
            iconPath = "Interface\\Icons\\Ability_Warrior_RallyingCry",
            iconFileID = 132349,
        },
    },
}

-- Helper zur Erkennung von geheimen Strings / Werten in WoW Forever & 12.0
local function IsSecret(val)
    if val == nil then return false end
    if R4L.IsSecret then return R4L.IsSecret(val) end
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res == true then return true end
    end
    if issecrettable and type(val) == "table" then
        local ok, res = pcall(issecrettable, val)
        if ok and res == true then return true end
    end
    if type(val) == "userdata" then return true end
    return false
end

-- Bereinigt Zaubernamen von Rang-Zusätzen
local function CleanSpellName(name)
    if not name or IsSecret(name) then return "" end
    local base = name:match("^(.-)%s*%(")
    return base or name
end

-- Prüft, ob ein Zauber eine passive Fähigkeit ist (kann nicht aktiv gebufft werden)
local function IsPassiveSpellCheck(spellId, slotIndex, spellBank)
    if slotIndex then
        local bank = spellBank or ((BOOKTYPE_SPELL ~= nil) and BOOKTYPE_SPELL or "spell")
        if GetSpellBookItemInfo then
            local okInfo, skillType = pcall(GetSpellBookItemInfo, slotIndex, bank)
            if okInfo and skillType and skillType:upper() == "PASSIVE" then
                return true
            end
        end
        if IsPassiveSpell then
            local ok, p = pcall(IsPassiveSpell, slotIndex, bank)
            if ok and p and p ~= 0 and p ~= false then return true end
        end
    end
    if spellId then
        if C_Spell and C_Spell.IsSpellPassive then
            local ok, p = pcall(C_Spell.IsSpellPassive, spellId)
            if ok and p and p ~= 0 and p ~= false then return true end
        end
        if IsSpellPassive then
            local ok, p = pcall(IsSpellPassive, spellId)
            if ok and p and p ~= 0 and p ~= false then return true end
        end
        if IsPassiveSpell then
            local ok, p = pcall(IsPassiveSpell, spellId)
            if ok and p and p ~= 0 and p ~= false then return true end
        end
    end
    return false
end

-- Prüft sicher mit pcall, ob der Spieler den Zauber beherrscht
local function PlayerKnowsSpell(spellDef)
    if not spellDef then return false end

    -- Passive Fähigkeiten komplett ignorieren (sind keine aktiven Buffs)
    if spellDef.id and IsPassiveSpellCheck(spellDef.id) then return false end

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
                        if not IsPassiveSpellCheck(nil, s, spellBank) then
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
            end
        else
            -- Fallback wenn GetNumSpellTabs nicht verfügbar ist
            for i = 1, 300 do
                if not IsPassiveSpellCheck(nil, i, spellBank) then
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

-- Initialisiert und cacht alle Textur- und Icon-Zuordnungen für jeden Klassen-Buff
function BB:InitSpellTextures()
    for _, classList in pairs(CLASS_BUFFS) do
        for _, def in ipairs(classList) do
            if not def.matchIcons then def.matchIcons = {} end

            -- 1. Hardcoded iconFileID
            if def.iconFileID then
                def.matchIcons[def.iconFileID] = true
                def.matchIcons[tostring(def.iconFileID)] = true
            end

            -- 2. Hardcoded iconPath
            if def.iconPath then
                def.matchIcons[def.iconPath:lower()] = true
                local sub = def.iconPath:match("[^\\]+$") or def.iconPath:match("[^/]+$")
                if sub then def.matchIcons[sub:lower()] = true end
            end

            -- 3. Dynamisch über Client DBC auflösen (holt exakte Client-ID / Textur)
            if def.id then
                local tex = R4L:GetSpellTexture(def.id)
                if tex then
                    def.matchIcons[tex] = true
                    if type(tex) == "number" then
                        def.matchIcons[tostring(tex)] = true
                    elseif type(tex) == "string" then
                        def.matchIcons[tex:lower()] = true
                        local sub = tex:match("[^\\]+$") or tex:match("[^/]+$")
                        if sub then def.matchIcons[sub:lower()] = true end
                    end
                end
            end

            if def.allSpellIds then
                for sId in pairs(def.allSpellIds) do
                    local tex = R4L:GetSpellTexture(sId)
                    if tex then
                        def.matchIcons[tex] = true
                        if type(tex) == "number" then
                            def.matchIcons[tostring(tex)] = true
                        elseif type(tex) == "string" then
                            def.matchIcons[tex:lower()] = true
                            local sub = tex:match("[^\\]+$") or tex:match("[^/]+$")
                            if sub then def.matchIcons[sub:lower()] = true end
                        end
                    end
                end
            end
        end
    end
end

-- Sofortige Vorinitialisierung der Icons
BB:InitSpellTextures()

-- =========================================================================
-- Intelligenter Buff-Cache (garantiert 100% Sichtbarkeit im Kampf)
-- =========================================================================
BB.activeBuffCache = {}

local function GetUnitKey(unit)
    if not unit then return nil end
    local guid = nil
    if UnitGUID then
        local okG, gVal = pcall(UnitGUID, unit)
        if okG and gVal and not IsSecret(gVal) then
            guid = gVal
        end
    end
    return guid or unit
end

local function ClearUnitCache(unit)
    if not unit then return end
    local key = GetUnitKey(unit)
    if key and BB.activeBuffCache[key] then
        BB.activeBuffCache[key] = nil
    end
    if BB.activeBuffCache[unit] then
        BB.activeBuffCache[unit] = nil
    end
end

local function ClearBuffCached(unit, spellDef)
    if not unit or not spellDef then return end
    local key = GetUnitKey(unit)
    local uCache = (key and BB.activeBuffCache[key]) or BB.activeBuffCache[unit]
    if uCache then
        if spellDef.name then
            uCache[spellDef.name] = nil
        end
        if spellDef.altNames then
            for _, alt in ipairs(spellDef.altNames) do
                uCache[alt] = nil
            end
        end
    end
    if key and BB.activeBuffCache[unit] and BB.activeBuffCache[unit] ~= uCache then
        if spellDef.name then
            BB.activeBuffCache[unit][spellDef.name] = nil
        end
        if spellDef.altNames then
            for _, alt in ipairs(spellDef.altNames) do
                BB.activeBuffCache[unit][alt] = nil
            end
        end
    end
end

local function SetBuffCached(unit, spellName, duration, expirationTime)
    if not unit or not spellName then return end
    local key = GetUnitKey(unit)
    if not key then return end
    if not BB.activeBuffCache[key] then
        BB.activeBuffCache[key] = {}
    end
    local exp = expirationTime
    if not exp or exp <= 0 then
        local dur = (duration and duration > 0) and duration or 1800
        exp = GetTime() + dur
    end
    BB.activeBuffCache[key][spellName] = exp
end

local function IsBuffCached(unit, spellDef)
    if not unit or not spellDef then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        ClearUnitCache(unit)
        return false
    end
    local key = GetUnitKey(unit)
    local uCache = (key and BB.activeBuffCache[key]) or BB.activeBuffCache[unit]
    if not uCache then return false end

    local now = GetTime()
    for _, alt in ipairs(spellDef.altNames or { spellDef.name }) do
        local exp = uCache[alt] or uCache[spellDef.name]
        if exp and type(exp) == "number" and exp > now then
            return true
        end
    end
    return false
end

-- Prüft, ob eine gefundene Aura zum gesuchten Klassen-Buff passt (vollständig geschützt gegen Secret Values)
local function AuraMatchesSpellDef(auraName, auraSpellId, auraIcon, auraDuration, spellDef)
    if not spellDef then return false end

    -- 1. Spell-ID Treffer (geschützt gegen Secret Values)
    if auraSpellId and type(auraSpellId) == "number" and not IsSecret(auraSpellId) then
        if spellDef.id and auraSpellId == spellDef.id then
            return true
        end
        local okAll, isAll = pcall(function()
            return spellDef.allSpellIds and spellDef.allSpellIds[auraSpellId]
        end)
        if okAll and isAll then
            return true
        end

        local okName, sName = pcall(R4L.GetSpellName, R4L, auraSpellId)
        if okName and sName and not IsSecret(sName) then
            local cleanS = CleanSpellName(sName)
            for _, alt in ipairs(spellDef.altNames or {}) do
                if cleanS == alt or sName == alt then
                    return true
                end
            end
        end
    end

    -- 2. Namens-Treffer (nur wenn unmaskierter Text & mit pcall gesichert)
    if auraName and not IsSecret(auraName) and type(auraName) == "string" then
        local clean = CleanSpellName(auraName)
        if clean and clean ~= "" then
            for _, alt in ipairs(spellDef.altNames or {}) do
                local okEq, isEq = pcall(function() return clean == alt or auraName == alt end)
                if okEq and isEq then
                    return true
                end
            end
        end
    end

    -- 3. Icon / Textur-Treffer (100% kampfsicher mit pcall)
    if auraIcon and not IsSecret(auraIcon) then
        -- Falls der Zauber eine Mindestdauer vorschreibt (z. B. Mal der Wildnis vs Verjüngung)
        if spellDef.minDuration and auraDuration and type(auraDuration) == "number" and not IsSecret(auraDuration) then
            if auraDuration > 0 and auraDuration < spellDef.minDuration then
                return false
            end
        end

        -- A. Numerischer FileDataID-Treffer
        if type(auraIcon) == "number" then
            if spellDef.iconFileID and auraIcon == spellDef.iconFileID then
                return true
            end
            local okMatch, isMatch = pcall(function()
                return spellDef.matchIcons and (spellDef.matchIcons[auraIcon] or spellDef.matchIcons[tostring(auraIcon)])
            end)
            if okMatch and isMatch then
                return true
            end
        end

        -- B. String-Treffer (Pfad, FileID als String oder Substring)
        if type(auraIcon) == "string" then
            local okStr, matchStr = pcall(function()
                local iconStr = auraIcon:lower()
                local num = tonumber(auraIcon)
                if num then
                    if spellDef.iconFileID and num == spellDef.iconFileID then
                        return true
                    end
                    if spellDef.matchIcons and (spellDef.matchIcons[num] or spellDef.matchIcons[auraIcon]) then
                        return true
                    end
                end

                if spellDef.matchIcons and spellDef.matchIcons[iconStr] then
                    return true
                end

                local iconFile = iconStr:match("[^\\]+$") or iconStr:match("[^/]+$") or iconStr
                if iconFile and spellDef.matchIcons and spellDef.matchIcons[iconFile] then
                    return true
                end

                if spellDef.iconPath then
                    local defFile = (spellDef.iconPath:match("[^\\]+$") or spellDef.iconPath):lower()
                    if iconStr:find(defFile, 1, true) or (iconFile and iconFile == defFile) then
                        return true
                    end
                end
                return false
            end)
            if okStr and matchStr then
                return true
            end
        end
    end

    return false
end

-- Prüft, ob eine Einheit den Buff bereits aktiv hat (mehrstufige Erkennung + intelligenter Cache)
local function UnitHasBuff(unit, spellDef)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        ClearUnitCache(unit)
        return false
    end

    local scanSucceeded = false

    -- 0. Modern C_UnitAuras.GetUnitAuras (C-Level Batch Scan)
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL", 40, 0, 0)
        if not ok or not auras or type(auras) ~= "table" then
            ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        end
        if ok and auras and type(auras) == "table" and #auras > 0 then
            scanSucceeded = true
            for _, data in ipairs(auras) do
                if type(data) == "table" then
                    local aName = data.name
                    local aId = data.spellId
                    local aIcon = data.iconFileID or data.icon
                    local aDur = data.duration
                    local okMatch, isMatch = pcall(AuraMatchesSpellDef, aName, aId, aIcon, aDur, spellDef)
                    if okMatch and isMatch then
                        SetBuffCached(unit, spellDef.name, data.duration, data.expirationTime)
                        return true
                    end
                end
            end
        end
    end

    -- 1. Schnell-Check per Name über Blizzard API (C++ Lookup) - IMMER versuchen (auch im Kampf)
    if AuraUtil and AuraUtil.FindAuraByName then
        for _, alt in ipairs(spellDef.altNames or { spellDef.name }) do
            local ok, f1, _, _, _, fDuration, fExpiration = pcall(AuraUtil.FindAuraByName, alt, unit, "HELPFUL")
            if ok and f1 then
                SetBuffCached(unit, spellDef.name, fDuration, fExpiration)
                return true
            end
        end
    end
    if UnitBuff then
        for _, alt in ipairs(spellDef.altNames or { spellDef.name }) do
            local ok, f1, _, _, _, _, fDuration, fExpiration = pcall(UnitBuff, unit, alt)
            if ok and f1 then
                SetBuffCached(unit, spellDef.name, fDuration, fExpiration)
                return true
            end
        end
    end
    if UnitAura then
        for _, alt in ipairs(spellDef.altNames or { spellDef.name }) do
            local ok, f1, _, _, _, _, fDuration, fExpiration = pcall(UnitAura, unit, alt, nil, "HELPFUL")
            if ok and f1 then
                SetBuffCached(unit, spellDef.name, fDuration, fExpiration)
                return true
            end
        end
    end

    -- 2. Geprüfter AuraTracker Index-Scan (battle-tested mit Doppelformat 3.3.5 / Modern)
    if R4L.AuraTracker and R4L.AuraTracker.GetUnitAuraByIndex then
        for i = 1, 40 do
            local aura = R4L.AuraTracker:GetUnitAuraByIndex(unit, i, "HELPFUL")
            if not aura then break end
            local okMatch, isMatch = pcall(AuraMatchesSpellDef, aura.name, aura.spellId, aura.icon, aura.duration, spellDef)
            if okMatch and isMatch then
                SetBuffCached(unit, spellDef.name, aura.duration, aura.expirationTime)
                return true
            end
        end
        scanSucceeded = true
    end

    -- 3. C_UnitAuras.GetAuraDataByIndex (Modern / Retail / 12.0 / Forever)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local cScanOk = true
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok then
                cScanOk = false
                break
            end
            if data and type(data) == "table" then
                local aName = data.name
                local aId = data.spellId
                local aIcon = data.iconFileID or data.icon
                local aDur = data.duration
                local okMatch, isMatch = pcall(AuraMatchesSpellDef, aName, aId, aIcon, aDur, spellDef)
                if okMatch and isMatch then
                    SetBuffCached(unit, spellDef.name, data.duration, data.expirationTime)
                    return true
                end
            elseif data == nil then
                break
            end
        end
        if cScanOk then scanSucceeded = true end
    end

    -- 4. AuraUtil.ForEachAura (Modern)
    if AuraUtil and AuraUtil.ForEachAura then
        local found = false
        local okForEach = pcall(AuraUtil.ForEachAura, unit, "HELPFUL", 40, function(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11)
            local aName, aId, aIcon, aDur, aExp = nil, nil, nil, nil, nil
            if type(arg1) == "table" then
                aName = arg1.name
                aId = arg1.spellId
                aIcon = arg1.iconFileID or arg1.icon
                aDur = arg1.duration
                aExp = arg1.expirationTime
            else
                aName = arg1
                if type(arg2) == "string" and not (arg2:find("^Interface") or arg2:find("^\\") or arg2:find("^/")) then
                    aIcon = arg3
                    aDur = (type(arg6) == "number") and arg6 or nil
                    aExp = (type(arg7) == "number") and arg7 or nil
                    aId = (type(arg11) == "number") and arg11 or nil
                else
                    aIcon = arg2
                    aDur = (type(arg5) == "number") and arg5 or nil
                    aExp = (type(arg6) == "number") and arg6 or nil
                    aId = (type(arg10) == "number") and arg10 or nil
                end
            end
            local okMatch, isMatch = pcall(AuraMatchesSpellDef, aName, aId, aIcon, aDur, spellDef)
            if okMatch and isMatch then
                SetBuffCached(unit, spellDef.name, aDur, aExp)
                found = true
                return true
            end
            return false
        end)
        if okForEach then
            scanSucceeded = true
            if found then return true end
        end
    end

    -- 5. Classic UnitAura Index-Scan
    if UnitAura then
        local uScanOk = true
        for i = 1, 40 do
            local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitAura, unit, i, "HELPFUL")
            if not ok then
                uScanOk = false
                break
            end
            if a1 ~= nil then
                local aName = a1
                local aIcon = nil
                local aId = nil
                local aDur = nil
                local aExp = nil
                if type(a2) == "string" and not (a2:find("^Interface") or a2:find("^\\") or a2:find("^/")) then
                    aIcon = a3
                    aDur = (type(a6) == "number") and a6 or nil
                    aExp = (type(a7) == "number") and a7 or nil
                    aId = (type(a11) == "number") and a11 or nil
                else
                    aIcon = a2
                    aDur = (type(a5) == "number") and a5 or nil
                    aExp = (type(a6) == "number") and a6 or nil
                    aId = (type(a10) == "number") and a10 or nil
                end
                local okMatch, isMatch = pcall(AuraMatchesSpellDef, aName, aId, aIcon, aDur, spellDef)
                if okMatch and isMatch then
                    SetBuffCached(unit, spellDef.name, aDur, aExp)
                    return true
                end
            else
                break
            end
        end
        if uScanOk then scanSucceeded = true end
    end

    -- 6. UnitBuff Fallback
    if UnitBuff then
        local bScanOk = true
        for i = 1, 40 do
            local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitBuff, unit, i)
            if not ok then
                bScanOk = false
                break
            end
            if a1 ~= nil then
                local aName = a1
                local aIcon = nil
                local aId = nil
                local aDur = nil
                local aExp = nil
                if type(a2) == "string" and not (a2:find("^Interface") or a2:find("^\\") or a2:find("^/")) then
                    aIcon = a3
                    aDur = (type(a6) == "number") and a6 or nil
                    aExp = (type(a7) == "number") and a7 or nil
                    aId = (type(a11) == "number") and a11 or nil
                else
                    aIcon = a2
                    aDur = (type(a5) == "number") and a5 or nil
                    aExp = (type(a6) == "number") and a6 or nil
                    aId = (type(a10) == "number") and a10 or nil
                end
                local okMatch, isMatch = pcall(AuraMatchesSpellDef, aName, aId, aIcon, aDur, spellDef)
                if okMatch and isMatch then
                    SetBuffCached(unit, spellDef.name, aDur, aExp)
                    return true
                end
            else
                break
            end
        end
        if bScanOk then scanSucceeded = true end
    end

    -- 7. Ergebnis-Auswertung:
    -- Wenn im Kampf der Buff im Cache als noch aktiv vermerkt ist:
    -- Niemals im Kampf leeren! Der Klassen-Buff läuft noch (z.B. 30min Mal der Wildnis).
    if InCombatLockdown() then
        if IsBuffCached(unit, spellDef) then
            return true
        end
        return false
    end

    -- Außerhalb des Kampfes: Wenn mindestens ein Scan-Verfahren fehlerfrei lief und der Buff nicht gefunden wurde:
    -- Der Buff ist definitiv nicht mehr aktiv (z.B. aktiv weggeklickt) -> Cache sofort leeren!
    if scanSucceeded then
        ClearBuffCached(unit, spellDef)
        return false
    end

    return false
end

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

-- Aktualisiert das statische Layout der Buttons (ausschließlich außerhalb des Kampfes erlaubt!)
function BB:UpdateLayout()
    if not container or not buttons then return end
    if InCombatLockdown() then
        self.needsLayoutUpdate = true
        return
    end

    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg or not cfg.buffBar or cfg.buffBar.enabled == false then
        container:Hide()
        return
    end

    container:Show()

    local iconSize = (cfg.buffBar and cfg.buffBar.iconSize) or 22
    local spacing = (cfg.buffBar and cfg.buffBar.spacing) or 4
    local visibleCount = 0
    local currentX = 0

    for idx, btn in ipairs(buttons) do
        local spellDef = btn.spellDef
        btn.isKnown = PlayerKnowsSpell(spellDef)
        local targetFilter = (cfg.buffBar.targets and cfg.buffBar.targets[spellDef.name]) or spellDef.defaultTarget

        if targetFilter ~= "OFF" and btn.isKnown then
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", container, "LEFT", currentX, 0)
            btn:SetSize(iconSize, iconSize)
            currentX = currentX + iconSize + spacing
            visibleCount = visibleCount + 1
            btn:Show()
            btn.targetFilter = targetFilter
        else
            btn:Hide()
            btn.targetFilter = "OFF"
            btn.missingUnits = {}
            btn:SetAttribute("*type1", nil)
            btn:SetAttribute("*macrotext1", nil)
            btn:SetAttribute("type1", nil)
            btn:SetAttribute("macrotext1", nil)
            btn:SetAttribute("*type", nil)
            btn:SetAttribute("*macrotext", nil)
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
            btn:SetAttribute("spell", nil)
            btn:SetAttribute("unit", nil)
        end
    end

    if visibleCount == 0 then
        if not isLocked and mover then
            container:Show()
            container:SetSize(math.max(60, iconSize * 2), iconSize)
            mover:Show()
        else
            container:Hide()
        end
        return
    end

    local totalWidth = (visibleCount * iconSize) + (math.max(0, visibleCount - 1) * spacing)
    container:SetSize(math.max(iconSize, totalWidth), iconSize)
    if mover then mover:SetAllPoints(container) end
end

-- Aktualisiert Status, Rahmenfarben und Fehlende-Buffs (100% kampfsicher & ohne Taint!)
function BB:Update()
    if not container or not buttons then return end
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg or not cfg.buffBar or cfg.buffBar.enabled == false then
        if not InCombatLockdown() then container:Hide() end
        return
    end

    -- Falls außerhalb des Kampfes ein Layout-Update ansteht, jetzt ausführen
    if not InCombatLockdown() then
        if self.needsLayoutUpdate then
            self.needsLayoutUpdate = false
            self:UpdateLayout()
        end
    end

    local units = GetRosterUnits()

    for idx, btn in ipairs(buttons) do
        if btn:IsShown() then
            local spellDef = btn.spellDef
            local targetFilter = btn.targetFilter or ((cfg.buffBar.targets and cfg.buffBar.targets[spellDef.name]) or spellDef.defaultTarget)

            if targetFilter ~= "OFF" then
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

                -- Sortiere die fehlenden Einheiten nach Priorität (Tank > Heiler > Melee > Rest)
                table.sort(missingUnits, function(a, b)
                    return GetUnitPriority(a) < GetUnitPriority(b)
                end)

                local missingCount = #missingUnits
                local bestUnit = missingUnits[1]

                -- Visuelles Feedback (ohne Taint, nur Backdrop & Font)
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

                -- Click-to-Cast Attribut aktualisieren (ausschließlich außerhalb des Kampfes erlaubt!)
                if not InCombatLockdown() then
                    local castSpell = spellDef.name
                    if spellDef.id then
                        local realName = R4L:GetSpellName(spellDef.id)
                        if realName and realName ~= "" then
                            castSpell = realName
                        end
                    end

                    if bestUnit then
                        local macro = "/cast [@" .. bestUnit .. "] " .. castSpell
                        if cfg.general and cfg.general.targetOnCast then
                            macro = "/target [@" .. bestUnit .. "]\n" .. macro
                        end
                        btn:SetAttribute("*type1", "macro")
                        btn:SetAttribute("*macrotext1", macro)
                        btn:SetAttribute("type1", "macro")
                        btn:SetAttribute("macrotext1", macro)
                        btn:SetAttribute("*type", "macro")
                        btn:SetAttribute("*macrotext", macro)
                        btn:SetAttribute("type", "macro")
                        btn:SetAttribute("macrotext", macro)
                    else
                        btn:SetAttribute("*type1", nil)
                        btn:SetAttribute("*macrotext1", nil)
                        btn:SetAttribute("type1", nil)
                        btn:SetAttribute("macrotext1", nil)
                        btn:SetAttribute("*type", nil)
                        btn:SetAttribute("*macrotext", nil)
                        btn:SetAttribute("type", nil)
                        btn:SetAttribute("macrotext", nil)
                    end
                    btn:SetAttribute("spell", nil)
                    btn:SetAttribute("unit", nil)
                else
                    self.needsAttributeUpdate = true
                end

                btn.missingUnits = missingUnits
            end
        end
    end
end

-- Erstellt die Buff-Buttons für die Klasse des Spielers
function BB:Initialize()
    if container then return end

    self:InitSpellTextures()

    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.buffBar then
        cfg.buffBar = {
            enabled = true,
            scale = 1.0,
            iconSize = 22,
            spacing = 4,
            posX = 300,
            posY = -230,
            locked = true,
            targets = {},
        }
    end

    local iconSize = cfg.buffBar.iconSize or 22
    local spacing = (cfg.buffBar.spacing ~= nil) and cfg.buffBar.spacing or 4
    local scale = cfg.buffBar.scale or 1.0

    container = CreateFrame("Frame", "Resto4LifeBuffBar", UIParent)
    container:SetSize(100, iconSize)
    container:SetScale(scale)
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.buffBar.posX or 300, cfg.buffBar.posY or -230)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    self.container = container

    -- Kontinuierlicher Timer für regelmäßige Buff- und Reichweiten-Aktualisierung (alle 0.5s)
    local buffUpdateTimer = 0
    container:SetScript("OnUpdate", function(self, elapsed)
        buffUpdateTimer = buffUpdateTimer + elapsed
        if buffUpdateTimer >= 0.5 then
            buffUpdateTimer = 0
            BB:Update()
        end
    end)

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
    mover:EnableMouseWheel(true)
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

    -- Mausrad-Skalierung auf dem Mover (5% Schritte)
    mover:SetScript("OnMouseWheel", function(self, delta)
        local curScale = cfg.buffBar.scale or 1.0
        if delta > 0 then
            curScale = math.min(2.0, curScale + 0.05)
        else
            curScale = math.max(0.5, curScale - 0.05)
        end
        curScale = math.floor(curScale * 100 + 0.5) / 100
        BB:SetScale(curScale)
    end)

    -- Resizer-Handle (untere rechte Ecke zum Groß-/Kleinziehen)
    local resizer = CreateFrame("Frame", "Resto4LifeBuffBarResizer", mover, "BackdropTemplate")
    resizer:SetSize(12, 12)
    resizer:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, 0)
    resizer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resizer:SetBackdropColor(0, 1, 0.6, 0.7)
    resizer:SetBackdropBorderColor(1, 1, 1, 0.9)
    resizer:EnableMouse(true)
    resizer:SetFrameLevel(mover:GetFrameLevel() + 5)

    resizer:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0, 1, 0.8, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_TITLE"] or "Größe anpassen", 0, 1, 0.6)
        GameTooltip:AddLine(L["RESIZER_TOOLTIP_DESC"] or "Linke Maustaste gedrückt halten und ziehen, um die Skalierung zu ändern.", 1, 1, 1)
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
            self.startScale = cfg.buffBar.scale or 1.0
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

            local newScale = self.startScale + (delta / 120)
            newScale = math.max(0.5, math.min(2.0, newScale))
            newScale = math.floor(newScale * 100 + 0.5) / 100

            if newScale ~= cfg.buffBar.scale then
                BB:SetScale(newScale, true)
            end
        end
    end)

    resizer:SetScript("OnMouseUp", function(self)
        if self.isScaling then
            self.isScaling = false
            R4L:Print(L["BUFF_BAR_SCALE_CHAT"] or "Buff-Bar Skalierung: %d%%", math.floor((cfg.buffBar.scale or 1.0) * 100))
        end
    end)
    self.resizer = resizer

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
        btn:SetAttribute("checkselfcast", false)
        btn:SetAttribute("checkfocuscast", false)

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
    self:UpdateLayout()
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

-- Skalierung setzen & anwenden (Position bleibt pixelgenau erhalten)
function BB:SetScale(newScale, silent)
    local cfg = R4L.ProfileManager:GetConfig()
    newScale = math.max(0.5, math.min(2.0, newScale))
    cfg.buffBar.scale = newScale

    if container then
        local cScale = container:GetEffectiveScale()
        local uScale = UIParent:GetEffectiveScale()
        local left = container:GetLeft()
        local top = container:GetTop()
        local uTop = UIParent:GetTop() or 768

        container:SetScale(newScale)

        if left and top and cScale and uScale and cScale > 0 then
            local newCScale = container:GetEffectiveScale()
            if newCScale > 0 then
                local screenLeft = left * cScale
                local screenTop = top * cScale
                local parentTop = uTop * uScale
                cfg.buffBar.posX = math.floor(screenLeft / newCScale)
                cfg.buffBar.posY = math.floor((screenTop - parentTop) / newCScale)
                container:ClearAllPoints()
                container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", cfg.buffBar.posX, cfg.buffBar.posY)
            end
        end
    end

    if not silent then
        R4L:Print(L["BUFF_BAR_SCALE_CHAT"] or "Buff-Bar Skalierung: %d%%", math.floor(newScale * 100))
    end
end

-- Button-Abstand setzen & Layout sofort anpassen (z. B. 0 oder 4 Pixel)
function BB:SetSpacing(newSpacing, silent)
    local cfg = R4L.ProfileManager:GetConfig()
    newSpacing = math.max(0, math.min(20, newSpacing))
    cfg.buffBar.spacing = newSpacing
    self:UpdateLayout()

    if not silent then
        R4L:Print(L["BUFF_BAR_SPACING_CHAT"] or "Buff-Bar Button-Abstand: %d px", newSpacing)
    end
end

-- In-Game Diagnose-Kommando (/r4l bufftest)
function BB:RunDiagnostic()
    R4L:Print("|cff00ff00=== Resto4Life Buff Diagnostic ===|r")
    R4L:Print("InCombatLockdown: %s", tostring(InCombatLockdown()))
    R4L:Print("issecretvalue: %s", tostring(issecretvalue ~= nil))
    R4L:Print("APIs -> C_UnitAuras: %s, UnitAura: %s, UnitBuff: %s, AuraUtil: %s",
        tostring(C_UnitAuras ~= nil), tostring(UnitAura ~= nil), tostring(UnitBuff ~= nil), tostring(AuraUtil ~= nil))

    local units = GetRosterUnits()
    local _, pClass = UnitClass("player")
    local classList = CLASS_BUFFS[pClass] or {}

    for _, u in ipairs(units) do
        local uName = UnitName(u) or u
        R4L:Print("|cffffff00Einheit: %s (%s)|r", u, uName)

        local auraCount = 0
        for i = 1, 40 do
            local a = R4L.AuraTracker and R4L.AuraTracker:GetUnitAuraByIndex(u, i, "HELPFUL")
            if not a then break end
            auraCount = auraCount + 1
            if auraCount <= 6 then
                R4L:Print("  [%d] %s (ID: %s, Icon: %s, Dur: %s)", i, tostring(a.name), tostring(a.spellId), tostring(a.icon), tostring(a.duration))
            end
        end
        R4L:Print("  Gesamt gefundene Buffs: %d", auraCount)

        for _, def in ipairs(classList) do
            local has = UnitHasBuff(u, def)
            local cached = IsBuffCached(u, def)
            R4L:Print("  -> '%s': UnitHasBuff = %s, Cached = %s", def.name, tostring(has), tostring(cached))
        end
    end
    R4L:Print("|cff00ff00====================================|r")
end

-- Events registrieren
R4L:RegisterEvent("PLAYER_LOGIN", function()
    BB:Initialize()
end)

R4L:RegisterEvent("UNIT_AURA", function()
    BB:Update()
end)

R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    local validKeys = {}
    for _, u in ipairs(GetRosterUnits()) do
        local k = GetUnitKey(u)
        if k then validKeys[k] = true end
        validKeys[u] = true
    end
    for k in pairs(BB.activeBuffCache) do
        if not validKeys[k] then
            BB.activeBuffCache[k] = nil
        end
    end
    BB:UpdateLayout()
    BB:Update()
end)

R4L:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    local now = GetTime()
    for uKey, uMap in pairs(BB.activeBuffCache) do
        if type(uMap) == "table" then
            for sName, exp in pairs(uMap) do
                if type(exp) == "number" and now >= exp then
                    uMap[sName] = nil
                end
            end
        end
    end
    BB:UpdateLayout()
    BB:Update()
end)

R4L:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    -- Beim Eintritt in den Kampf: Cache sofort für alle Einheiten mit Live-Daten auffrischen
    local units = GetRosterUnits()
    local _, pClass = UnitClass("player")
    local classList = CLASS_BUFFS[pClass] or {}
    for _, u in ipairs(units) do
        for _, def in ipairs(classList) do
            UnitHasBuff(u, def)
        end
    end
    BB:Update()
end)

R4L:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit, castGUID, spellID)
    if unit == "player" and spellID then
        local _, pClass = UnitClass("player")
        local classList = CLASS_BUFFS[pClass] or {}
        for _, def in ipairs(classList) do
            if (def.id and def.id == spellID) or (def.allSpellIds and def.allSpellIds[spellID]) then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.05, function() BB:Update() end)
                else
                    BB:Update()
                end
                return
            end
        end
    end
end)

R4L:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    BB.activeBuffCache = {}
    BB:InitSpellTextures()
    BB:UpdateLayout()
    BB:Update()
end)

R4L:RegisterEvent("SPELLS_CHANGED", function()
    if buttons then
        for _, btn in ipairs(buttons) do
            btn.isKnown = PlayerKnowsSpell(btn.spellDef)
        end
    end
    BB:InitSpellTextures()
    BB:UpdateLayout()
    BB:Update()
end)
