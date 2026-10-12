--[[
    Resto4Life - Engine/AuraTracker.lua
    Verfolgung von HoTs (Heal over Time) und reinigbaren Debuffs (Fluch, Gift, Krankheit, Magie)
--]]

local _, R4L = ...

R4L.AuraTracker = {}
local AT = R4L.AuraTracker

-- Helper zur Erkennung von geheimen Werten in WoW Forever & 12.0
local function IsSecret(val)
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res == true then return true end
    end
    if issecrettable then
        local ok, res = pcall(issecrettable, val)
        if ok and res == true then return true end
    end
    if type(val) == "userdata" then
        return true
    end
    return false
end
R4L.IsSecret = IsSecret

local function IsNil(val)
    if IsSecret(val) then return false end
    local ok, res = pcall(function() return val == nil end)
    return (ok and res) or false
end

local function SafeNumber(val, defaultVal)
    if IsSecret(val) then return defaultVal end
    local ok, res = pcall(function()
        if type(val) == "number" then return val end
        return defaultVal
    end)
    if ok then return res end
    return defaultVal
end

local function SafeString(val, defaultVal)
    if IsSecret(val) then return defaultVal end
    local ok, res = pcall(function()
        if type(val) == "string" then return val end
        return defaultVal
    end)
    if ok then return res end
    return defaultVal
end

local function SafeBoolVal(val, defaultVal)
    if IsSecret(val) then return defaultVal end
    local ok, res = pcall(function()
        if type(val) == "boolean" then return val end
        return defaultVal
    end)
    if ok then return res end
    return defaultVal
end

-- Standard Blizzard Debuff-Farben (vollständig für Englisch, Deutsch und Kleinbuchstaben)
AT.DebuffColors = {
    ["Curse"]   = { r = 0.6, g = 0.0, b = 1.0 }, -- Lila
    ["Poison"]  = { r = 0.0, g = 0.7, b = 0.1 }, -- Grün
    ["Disease"] = { r = 0.6, g = 0.4, b = 0.0 }, -- Braun
    ["Magic"]   = { r = 0.2, g = 0.6, b = 1.0 }, -- Blau
    ["None"]    = { r = 0.8, g = 0.1, b = 0.1 }, -- Rot (Physisch/Bleed)
    ["curse"]   = { r = 0.6, g = 0.0, b = 1.0 },
    ["poison"]  = { r = 0.0, g = 0.7, b = 0.1 },
    ["disease"] = { r = 0.6, g = 0.4, b = 0.0 },
    ["magic"]   = { r = 0.2, g = 0.6, b = 1.0 },
    ["none"]    = { r = 0.8, g = 0.1, b = 0.1 },
}

-- Normalisiert Dispel-Typen unabhängig von Groß-/Kleinschreibung oder Client-Sprache (deDE / enUS / Enum / Zahl)
local function NormalizeDispelType(dt)
    if IsSecret(dt) or IsNil(dt) then return nil end
    local num = SafeNumber(dt, nil)
    if num then
        if num == 1 then return "Magic"
        elseif num == 2 then return "Curse"
        elseif num == 3 then return "Disease"
        elseif num == 4 then return "Poison"
        end
        return nil
    end
    local str = SafeString(dt, nil)
    if not str then return nil end
    local lower = str:lower():gsub("%s+", "")
    if lower == "curse" or lower:find("fluch") then
        return "Curse"
    elseif lower == "poison" or lower:find("gift") then
        return "Poison"
    elseif lower == "disease" or lower:find("krank") then
        return "Disease"
    elseif lower == "magic" or lower:find("magie") then
        return "Magic"
    end
    if str == "Curse" or str == "Poison" or str == "Disease" or str == "Magic" then
        return str
    end
    return nil
end

-- Bestimmt Dispel-Fähigkeiten (Spieler + gesamte Gruppe/Raid, gecacht für maximale Performance)
AT._lastDispelCheck = 0
AT._cachedCombined = nil
AT._cachedPlayer = nil
AT._cachedGroup = nil

function AT:GetDispelCapabilities()
    local now = GetTime()
    if AT._cachedCombined and (now - AT._lastDispelCheck < 2.0) then
        return AT._cachedCombined, AT._cachedPlayer, AT._cachedGroup
    end
    AT._lastDispelCheck = now

    local okP, locClass, engClass = pcall(UnitClass, "player")
    local playerClass = okP and (SafeString(engClass, nil) or SafeString(locClass, nil)) or nil
    local playerDispels = {
        Curse = false,
        Poison = false,
        Disease = false,
        Magic = false,
    }
    local groupDispels = {
        Curse = false,
        Poison = false,
        Disease = false,
        Magic = false,
    }

    local function ApplyClassDispels(cls, target)
        if not cls or type(cls) ~= "string" then return end
        local uClass = cls:upper()
        if uClass == "DRUID" or uClass == "DRUIDE" then
            target.Curse = true
            target.Poison = true
            target.Magic = true -- Typischerweise als Heiler (Wiederherstellung)
        elseif uClass == "PALADIN" then
            target.Poison = true
            target.Disease = true
            target.Magic = true -- Heilig
        elseif uClass == "PRIEST" or uClass == "PRIESTER" then
            target.Magic = true
            target.Disease = true -- Läutern / Krankheiten bannen
        elseif uClass == "SHAMAN" or uClass == "SCHAMANE" then
            target.Curse = true
            target.Magic = true -- Wiederherstellung
            target.Poison = true -- Classic / Forever (Totem der Giftreinigung / Gift heilen)
            target.Disease = true -- Classic / Forever (Krankheit heilen)
        elseif uClass == "MONK" or uClass == "MÖNCH" then
            target.Poison = true
            target.Disease = true
            target.Magic = true -- Nebelwirker
        elseif uClass == "MAGE" or uClass == "MAGIER" then
            target.Curse = true
        elseif uClass == "EVOKER" or uClass == "RUFER" then
            target.Poison = true
            target.Magic = true
            target.Curse = true -- Kauterisierende Flamme
        elseif uClass == "WARLOCK" or uClass == "HEXENMEISTER" then
            target.Magic = true -- Teufelsjäger / Wichtel (Magie verschlingen)
        end
    end

    ApplyClassDispels(playerClass, playerDispels)
    ApplyClassDispels(playerClass, groupDispels)

    -- Scanne Gruppen- und Raidmitglieder für Gruppen-Fähigkeiten
    local inRaid = false
    if IsInRaid then
        local okR, rVal = pcall(function() return IsInRaid() == true end)
        if okR and rVal then inRaid = true end
    end

    if inRaid then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, count do
            local u = "raid" .. i
            local okEx, ex = pcall(function() return UnitExists(u) == true end)
            if okEx and ex then
                local okC, lc, ec = pcall(UnitClass, u)
                if okC then
                    ApplyClassDispels(SafeString(ec, nil) or SafeString(lc, nil), groupDispels)
                end
            end
        end
    else
        local inGroup = false
        if IsInGroup then
            local okG, gVal = pcall(function() return IsInGroup() == true end)
            if okG and gVal then inGroup = true end
        end
        if inGroup then
            for i = 1, 4 do
                local u = "party" .. i
                local okEx, ex = pcall(function() return UnitExists(u) == true end)
                if okEx and ex then
                    local okC, lc, ec = pcall(UnitClass, u)
                    if okC then
                        ApplyClassDispels(SafeString(ec, nil) or SafeString(lc, nil), groupDispels)
                    end
                end
            end
        end
    end

    -- Kombiniertes Set (Abwärtskompatibel für Aufrufe wie dispels[type])
    local combined = {
        Curse = playerDispels.Curse or groupDispels.Curse,
        Poison = playerDispels.Poison or groupDispels.Poison,
        Disease = playerDispels.Disease or groupDispels.Disease,
        Magic = playerDispels.Magic or groupDispels.Magic,
    }

    AT._cachedCombined = combined
    AT._cachedPlayer = playerDispels
    AT._cachedGroup = groupDispels

    return combined, playerDispels, groupDispels
end

-- =========================================================================
-- Intelligenter Debuff-Cache (garantiert 100% Sichtbarkeit im Kampf)
-- =========================================================================
AT.debuffCache = {}

local function GetUnitKey(unit)
    local uStr = SafeString(unit, nil)
    if not uStr or uStr == "" then return nil end
    if uStr == "player" or uStr:match("^party%d+$") or uStr:match("^raid%d+$") then
        return uStr
    end
    if UnitIsUnit then
        local okP, isP = pcall(function() return UnitIsUnit(uStr, "player") == true end)
        if okP and isP then return "player" end
        for i = 1, 4 do
            local pUnit = "party" .. i
            local okU, isU = pcall(function() return UnitIsUnit(uStr, pUnit) == true end)
            if okU and isU then return pUnit end
        end
    end
    return uStr
end

function AT:ClearDebuffCache(unit)
    if not unit then return end
    local key = GetUnitKey(unit)
    if key and self.debuffCache[key] then
        self.debuffCache[key] = nil
    end
    if self.debuffCache[unit] then
        self.debuffCache[unit] = nil
    end
end

function AT:SetCachedDebuff(unit, debuffData, color)
    if not unit or not debuffData then return end
    local key = GetUnitKey(unit)
    if not key then return end

    local now = GetTime()
    local exp = SafeNumber(debuffData.expirationTime, 0)
    local dur = SafeNumber(debuffData.duration, 0)
    if exp <= 0 then
        exp = now + (dur > 0 and dur or 30)
    end

    self.debuffCache[key] = {
        name = SafeString(debuffData.name, ""),
        icon = SafeNumber(debuffData.icon, nil) or SafeString(debuffData.icon, 0),
        dispelType = debuffData.dispelType,
        color = color,
        expirationTime = exp,
        duration = dur,
        lastSeen = now,
    }
end

function AT:GetCachedDebuff(unit)
    if not unit then return nil, nil end
    if UnitIsDeadOrGhost then
        local okD, isD = pcall(function() return UnitIsDeadOrGhost(unit) == true end)
        if okD and isD then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    end

    local key = GetUnitKey(unit)
    local cached = (key and self.debuffCache[key]) or self.debuffCache[unit]
    if not cached then return nil, nil end

    local now = GetTime()
    local exp = SafeNumber(cached.expirationTime, 0)
    if exp > 0 then
        if now >= exp then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    else
        if (now - (cached.lastSeen or 0)) > 20 then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    end

    return cached, cached.color
end

-- Universeller Argument-Parser für UnitAura / UnitBuff (behandelt 3.3.5 & modernes Classic/Retail Format, 100% Secret-Safe)
local function ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
    if IsNil(a1) then return nil end

    local s2 = SafeString(a2, nil)
    local s3 = SafeString(a3, nil)
    local n3 = SafeNumber(a3, nil)

    local isLegacy335 = false
    if s2 and not (s2:find("^Interface") or s2:find("^\\") or s2:find("^/")) then
        if n3 or (s3 and (s3:find("^Interface") or s3:find("^\\") or s3:find("^/"))) then
            isLegacy335 = true
        elseif s2 == "" or s2:find("Rang") or s2:find("Rank") then
            isLegacy335 = true
        end
    end

    local name = SafeString(a1, "")
    local nameSecret = IsSecret(a1)

    if isLegacy335 then
        local caster = SafeString(a8, nil)
        local isMine = false
        if caster then
            local okP, isP = pcall(function()
                if caster == "player" or caster == "pet" then return true end
                return (UnitIsUnit(caster, "player") == true) or (UnitIsUnit(caster, "pet") == true)
            end)
            if okP and isP then isMine = true end
        end
        local spellId = SafeNumber(a11, 0)
        if name == "" and spellId ~= 0 then
            local sName = R4L:GetSpellName(spellId)
            name = SafeString(sName, "")
        end
        local iconVal = SafeNumber(a3, nil) or SafeString(a3, nil)
        local iconSecret = IsSecret(a3)
        return {
            name = name,
            nameIsSecret = nameSecret,
            rank = s2 or "",
            icon = iconVal,
            rawIcon = (not IsNil(a3)) and a3 or nil,
            iconIsSecret = iconSecret,
            count = SafeNumber(a4, 0),
            dispelType = NormalizeDispelType(a5),
            dispelTypeIsSecret = IsSecret(a5),
            duration = SafeNumber(a6, 0),
            expirationTime = SafeNumber(a7, 0),
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    else
        local caster = SafeString(a7, nil)
        local isMine = false
        if caster then
            local okP, isP = pcall(function()
                if caster == "player" or caster == "pet" then return true end
                return (UnitIsUnit(caster, "player") == true) or (UnitIsUnit(caster, "pet") == true)
            end)
            if okP and isP then isMine = true end
        end
        local spellId = SafeNumber(a10, 0)
        if name == "" and spellId ~= 0 then
            local sName = R4L:GetSpellName(spellId)
            name = SafeString(sName, "")
        end
        local iconVal = SafeNumber(a2, nil) or SafeString(a2, nil)
        local iconSecret = IsSecret(a2)
        return {
            name = name,
            nameIsSecret = nameSecret,
            icon = iconVal,
            rawIcon = (not IsNil(a2)) and a2 or nil,
            iconIsSecret = iconSecret,
            count = SafeNumber(a3, 0),
            dispelType = NormalizeDispelType(a4),
            dispelTypeIsSecret = IsSecret(a4),
            duration = SafeNumber(a5, 0),
            expirationTime = SafeNumber(a6, 0),
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    end
end

-- Sanitized eine C_UnitAuras AuraData-Tabelle sicher gegen Secret Values
local function SanitizeAuraDataTable(data)
    if not data or type(data) ~= "table" then return nil end
    local name = SafeString(data.name, "")
    local nameSecret = IsSecret(data.name)
    local spellId = SafeNumber(data.spellId, 0)
    if name == "" and spellId ~= 0 then
        local sName = R4L:GetSpellName(spellId)
        name = SafeString(sName, "")
    end
    local rawDT = SafeString(data.dispelName, nil) or SafeString(data.dispelType, nil) or SafeString(data.debuffType, nil) or SafeNumber(data.dispelType, nil)
    local dtSecret = IsSecret(data.dispelName) or IsSecret(data.dispelType) or IsSecret(data.debuffType)
    local dur = SafeNumber(data.duration, 0)
    local exp = SafeNumber(data.expirationTime, 0)
    local cnt = SafeNumber(data.applications, nil) or SafeNumber(data.count, 0)
    local sUnit = SafeString(data.sourceUnit, nil)
    local sGUID = SafeString(data.sourceGUID, nil)
    local isFromPlayer = SafeBoolVal(data.isFromPlayerOrPlayerPet, false)

    local iconVal = SafeNumber(data.icon, nil) or SafeString(data.icon, nil) or SafeNumber(data.iconFileID, nil) or SafeString(data.iconFileID, nil)
    local rawIcon = iconVal
    local iconSecret = false
    if not iconVal then
        pcall(function()
            if not IsNil(data.icon) then
                rawIcon = data.icon
                iconSecret = IsSecret(data.icon)
            elseif not IsNil(data.iconFileID) then
                rawIcon = data.iconFileID
                iconSecret = IsSecret(data.iconFileID)
            end
        end)
    end

    return {
        name = name,
        nameIsSecret = nameSecret,
        icon = iconVal,
        rawIcon = rawIcon,
        iconIsSecret = iconSecret,
        count = cnt,
        dispelType = NormalizeDispelType(rawDT),
        dispelTypeIsSecret = dtSecret,
        duration = dur,
        expirationTime = exp,
        sourceUnit = sUnit,
        sourceGUID = sGUID,
        spellId = spellId,
        isFromPlayerOrPlayerPet = isFromPlayer,
    }
end

-- Universeller Aura-Zugriff für moderne Retail / Forever API (abgesichert gegen Secret Auras & Taint)
local function GetUnitAuraByIndex(unit, index, filter)
    if not unit then return nil end

    -- 1. Modern C_UnitAuras
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and data and type(data) == "table" then
            return SanitizeAuraDataTable(data)
        end
    end

    -- 2. Classic / Forever UnitAura mit Doppelformat-Prüfung (3.3.5 vs Modern)
    if UnitAura then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitAura, unit, index, filter)
        if ok and not IsNil(a1) then
            local okP, parsed = pcall(ParseUnitAuraArgs, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if okP and parsed then return parsed end
        end
    end

    -- 3. Älteres UnitBuff / UnitDebuff Fallback (nur wenn kein spezifischer Sub-Filter wie |PLAYER oder |RAID gesetzt ist)
    if filter == "HARMFUL" and UnitDebuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitDebuff, unit, index)
        if ok and not IsNil(a1) then
            local okP, parsed = pcall(ParseUnitAuraArgs, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if okP and parsed then return parsed end
        end
    elseif filter == "HELPFUL" and UnitBuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitBuff, unit, index)
        if ok and not IsNil(a1) then
            local okP, parsed = pcall(ParseUnitAuraArgs, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if okP and parsed then return parsed end
        end
    end

    return nil
end

-- Öffentlicher Zugriff auf GetUnitAuraByIndex für andere Module (z. B. BuffBar)
function AT:GetUnitAuraByIndex(unit, index, filter)
    return GetUnitAuraByIndex(unit, index, filter)
end

-- Prüft, ob eine Aura vom Spieler stammt (strikte Caster-Prüfung + 100% Secret-Value Absicherung)
local function IsPlayerAura(aura, unit)
    if not aura then return false end

    -- 0. Direkt aus HELPFUL|PLAYER Filter gescannt
    if aura._fromPlayerFilter == true then
        return true
    end

    -- 1. Blizzard Flag (C_UnitAuras / UnitAura)
    if SafeBoolVal(aura.isFromPlayerOrPlayerPet, false) == true then
        return true
    end

    -- 2. sourceUnit Prüfung (gesichert gegen Secret Values / Taint)
    local sUnit = SafeString(aura.sourceUnit, nil)
    if sUnit then
        if sUnit == "player" or sUnit == "pet" then
            return true
        end
        local okP, isPl = pcall(function()
            return (UnitIsUnit(sUnit, "player") == true) or (UnitIsUnit(sUnit, "pet") == true)
        end)
        if okP and isPl then
            return true
        end
    end

    -- 3. sourceGUID Prüfung (gesichert gegen Secret Values / Taint)
    local sGUID = SafeString(aura.sourceGUID, nil)
    if sGUID then
        local okG, isMatch = pcall(function()
            local pGUID = SafeString(UnitGUID("player"), nil)
            return (pGUID ~= nil and sGUID == pGUID)
        end)
        if okG and isMatch then
            return true
        end
    end

    -- 4. Wenn unit == "player" ist: Eigener Klassen-HoT auf sich selbst stammt IMMER vom Spieler
    local uStr = SafeString(unit, nil)
    if uStr then
        if uStr == "player" then return true end
        local okSelf, isSelf = pcall(function() return UnitIsUnit(uStr, "player") == true end)
        if okSelf and isSelf then
            return true
        end
    end

    -- 5. Fallback (im Kampf & außerhalb, wenn sourceUnit geheim/nil ist):
    -- Wenn der HoT zur eigenen Klasse gehört und in der Gruppe kein zweiter Heiler dieser Klasse existiert
    local _, pClass = UnitClass("player")
    local otherSameClass = false
    local inGrp = false
    if IsInGroup then
        local okG, gVal = pcall(function() return IsInGroup() == true end)
        if okG and gVal then inGrp = true end
    end
    if inGrp then
        local inRd = false
        if IsInRaid then
            local okR, rVal = pcall(function() return IsInRaid() == true end)
            if okR and rVal then inRd = true end
        end
        local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        for i = 1, num do
            local gUnit = inRd and ("raid" .. i) or ("party" .. i)
            local okEx, ex = pcall(function() return UnitExists(gUnit) == true end)
            if okEx and ex then
                local okSelf, isSelf = pcall(function() return gUnit == "player" or UnitIsUnit(gUnit, "player") == true end)
                if not (okSelf and isSelf) then
                    local _, gClass = UnitClass(gUnit)
                    if gClass == pClass then
                        otherSameClass = true
                        break
                    end
                end
            end
        end
    end
    if not otherSameClass then
        return true
    end

    return false
end

-- HoT-Datenbanken nach Heiler-Klasse getrennt (verhindert Vermischung eigener & fremder HoTs)
local CLASS_HOTS = {
    DRUID = {
        [774] = true,    -- Verjüngung (Rejuvenation)
        [1058] = true, [1430] = true, [2090] = true, [2091] = true, [3627] = true, [8910] = true, [9839] = true, [9840] = true, [9841] = true, [25299] = true, [26981] = true, [26982] = true, [48440] = true, [48441] = true,
        [155777] = true, -- Verjüngung (Keimung / Germination)
        [8936] = true,   -- Nachwachsen (Regrowth)
        [8938] = true, [8939] = true, [8940] = true, [8941] = true, [9750] = true, [9856] = true, [9857] = true, [9858] = true, [26980] = true, [48442] = true, [48443] = true,
        [33763] = true,  -- Blühendes Leben (Lifebloom)
        [48450] = true, [48451] = true,
        [48438] = true,  -- Wildwuchs (Wild Growth)
        [53248] = true, [53249] = true, [53251] = true,
        [102351] = true, -- Cenarischer Zauberschutz (Cenarion Ward)
        [102352] = true, -- Cenarischer Zauberschutz HoT-Effekt
        [207386] = true, -- Frühlingsblüten (Spring Blossoms)
        [200389] = true, -- Kultivierung (Cultivation)
        [325748] = true, -- Adaptiver Schwarm (Adaptive Swarm)
        [157982] = true, -- Gelassenheit (Tranquility)
        [391888] = true, -- Überfluss (Abundance)
        [392356] = true, -- Wuchernde Wurzeln
        [22842] = true,  -- Rasende Regeneration
    },
    PRIEST = {
        [139] = true,    -- Erneuerung (Renew)
        [6074] = true, [6075] = true, [6076] = true, [6077] = true, [6078] = true, [10927] = true, [10928] = true, [10929] = true, [25315] = true, [48067] = true, [48068] = true,
        [77489] = true,  -- Echo des Lichts (Echo of Light)
        [41635] = true,  -- Gebet der Besserung (Prayer of Mending)
        [41637] = true, [28804] = true, [48113] = true, [48114] = true,
        [17] = true,     -- Machtwort: Schild (Power Word: Shield)
        [592] = true, [600] = true, [3747] = true, [6065] = true, [6066] = true, [10898] = true, [10899] = true, [10900] = true, [10901] = true, [25217] = true, [25218] = true, [48065] = true, [48066] = true,
        [194384] = true, -- Abbitte (Atonement)
        [47788] = true,  -- Schutzgeist (Guardian Spirit)
        [33206] = true,  -- Schmerzunterdrückung (Pain Suppression)
    },
    SHAMAN = {
        [61295] = true,  -- Springflut (Riptide)
        [61299] = true, [61300] = true, [61301] = true,
        [974] = true,    -- Erdschild (Earth Shield)
        [32593] = true, [32594] = true, [49283] = true, [49284] = true,
        [52073] = true,  -- Totem des heilenden Flusses
        [383648] = true, -- Urzeitliche Welle
        [382024] = true, -- Waffe der Lebensgeister
    },
    MONK = {
        [124682] = true, -- Einhüllender Nebel (Enveloping Mist)
        [119611] = true, -- Erneuernder Nebel (Renewing Mist)
        [115175] = true, -- Beruhigender Nebel (Soothing Mist)
        [191840] = true, -- Essenzborn (Essence Font)
    },
    PALADIN = {
        [53563] = true,  -- Flamme des Glaubens (Beacon of Light)
        [156910] = true, -- Flamme der Zuversicht (Beacon of Faith)
        [200025] = true, -- Flamme der Tugend (Beacon of Virtue)
        [223306] = true, -- Zuversicht verleihen (Bestow Faith)
        [156322] = true, -- Ewige Flamme (Eternal Flame)
    },
    EVOKER = {
        [364343] = true, -- Echo
        [366155] = true, -- Zurückspulen / Reversion
        [359816] = true, -- Traumflug (Dream Flight)
        [376788] = true, -- Traumatem (Dream Breath)
        [367364] = true, -- Geistblüte (Spiritbloom)
        [370960] = true, -- Zeitdilatation (Time Dilation)
    },
}

local CLASS_HOT_NAMES = {
    DRUID = {
        ["Verjüngung"] = true,
        ["Rejuvenation"] = true,
        ["Keimung"] = true,
        ["Germination"] = true,
        ["Nachwachsen"] = true,
        ["Regrowth"] = true,
        ["Blühendes Leben"] = true,
        ["Lifebloom"] = true,
        ["Wildwuchs"] = true,
        ["Wild Growth"] = true,
        ["Cenarischer Zauberschutz"] = true,
        ["Cenarion Ward"] = true,
        ["Frühlingsblüten"] = true,
        ["Spring Blossoms"] = true,
        ["Kultivierung"] = true,
        ["Cultivation"] = true,
        ["Adaptiver Schwarm"] = true,
        ["Adaptive Swarm"] = true,
        ["Gelassenheit"] = true,
        ["Tranquility"] = true,
        ["Rasende Regeneration"] = true,
        ["Frenzied Regeneration"] = true,
    },
    PRIEST = {
        ["Erneuerung"] = true,
        ["Renew"] = true,
        ["Echo des Lichts"] = true,
        ["Echo of Light"] = true,
        ["Gebet der Besserung"] = true,
        ["Prayer of Mending"] = true,
        ["Machtwort: Schild"] = true,
        ["Power Word: Shield"] = true,
        ["Abbitte"] = true,
        ["Atonement"] = true,
        ["Schutzgeist"] = true,
        ["Guardian Spirit"] = true,
        ["Schmerzunterdrückung"] = true,
        ["Pain Suppression"] = true,
    },
    SHAMAN = {
        ["Springflut"] = true,
        ["Riptide"] = true,
        ["Erdschild"] = true,
        ["Earth Shield"] = true,
        ["Totem des heilenden Flusses"] = true,
        ["Healing Stream Totem"] = true,
        ["Urzeitliche Welle"] = true,
        ["Primordial Wave"] = true,
        ["Waffe der Lebensgeister"] = true,
        ["Earthliving Weapon"] = true,
    },
    MONK = {
        ["Einhüllender Nebel"] = true,
        ["Enveloping Mist"] = true,
        ["Erneuernder Nebel"] = true,
        ["Renewing Mist"] = true,
        ["Beruhigender Nebel"] = true,
        ["Soothing Mist"] = true,
        ["Essenzborn"] = true,
        ["Essence Font"] = true,
    },
    PALADIN = {
        ["Flamme des Glaubens"] = true,
        ["Beacon of Light"] = true,
        ["Flamme der Zuversicht"] = true,
        ["Beacon of Faith"] = true,
        ["Flamme der Tugend"] = true,
        ["Beacon of Virtue"] = true,
        ["Zuversicht verleihen"] = true,
        ["Bestow Faith"] = true,
        ["Ewige Flamme"] = true,
        ["Eternal Flame"] = true,
    },
    EVOKER = {
        ["Echo"] = true,
        ["Zurückspulen"] = true,
        ["Reversion"] = true,
        ["Traumflug"] = true,
        ["Dream Flight"] = true,
        ["Traumatem"] = true,
        ["Dream Breath"] = true,
        ["Geistblüte"] = true,
        ["Spiritbloom"] = true,
        ["Zeitdilatation"] = true,
        ["Time Dilation"] = true,
    },
}

-- Bereinigt Zaubernamen von Rang-Zusätzen (z.B. "Verjüngung (Rang 4)" -> "Verjüngung")
local function GetCleanSpellName(name)
    if not name or IsSecret(name) then return "" end
    local base = name:match("^(.-)%s*%(")
    if base and base ~= "" then
        return base
    end
    return name
end

-- Texture-Datenbanken nach Heiler-Klasse (ermöglicht 100% Erkennung im Kampf trotz Secret Values)
local CLASS_HOT_TEXTURES = {
    DRUID = {
        [136081] = true,   -- Verjüngung (Spell_Nature_Rejuvenation)
        [1033479] = true,  -- Keimung (spell_druid_germination)
        [136085] = true,   -- Nachwachsen (Spell_Nature_ResistNature)
        [134400] = true,   -- Blühendes Leben (INV_Misc_Herb_Felblossom)
        [236153] = true,   -- Wildwuchs (Ability_Druid_Flourish)
        [538745] = true,   -- Cenarischer Zauberschutz (ability_druid_naturalperfection)
        [1392631] = true,  -- Frühlingsblüten (inv_misc_herb_nightshade)
        [1392632] = true,  -- Kultivierung (ability_druid_cultivation)
        [3578230] = true,  -- Adaptiver Schwarm (ability_maldraxxus_druid)
        [136107] = true,   -- Gelassenheit (Spell_Nature_Tranquility)
        [132256] = true,   -- Rasende Regeneration (Ability_BullRush)
    },
    PRIEST = {
        [135953] = true,   -- Erneuerung (Spell_Holy_Renew)
        [135940] = true,   -- Machtwort: Schild (Spell_Holy_PowerWordShield)
        [135944] = true,   -- Gebet der Besserung (Spell_Holy_PrayerOfMendingtga)
        [237537] = true,   -- Echo des Lichts (spell_holy_ashestoashes)
        [458224] = true,   -- Abbitte (spell_holy_atonement)
        [237542] = true,   -- Schutzgeist (spell_holy_guardianspirit)
        [135936] = true,   -- Schmerzunterdrückung (Spell_Holy_PainSupression)
    },
    SHAMAN = {
        [252995] = true,   -- Springflut (spell_nature_riptide)
        [136089] = true,   -- Erdschild (Spell_Nature_SkinofEarth)
        [136053] = true,   -- Totem des heilenden Flusses (INV_Spear_04)
        [3565449] = true,  -- Urzeitliche Welle (ability_maldraxxus_shaman)
        [236848] = true,   -- Waffe der Lebensgeister (spell_shaman_earthlivingweapon)
    },
    MONK = {
        [606549] = true,   -- Einhüllender Nebel (spell_monk_envelopingmist)
        [627487] = true,   -- Erneuernder Nebel (ability_monk_renewingmists)
        [606550] = true,   -- Beruhigender Nebel (spell_monk_soothingmists)
        [1360978] = true,  -- Essenzborn (ability_monk_essencefont)
    },
    PALADIN = {
        [236247] = true,   -- Flamme des Glaubens (ability_paladin_beaconoflight)
        [1030094] = true,  -- Flamme der Zuversicht (ability_paladin_beaconsoflight)
        [1360762] = true,  -- Flamme der Tugend (ability_paladin_beaconofvirtue)
        [135919] = true,   -- Zuversicht verleihen (spell_holy_blessingofprotection)
        [642416] = true,   -- Ewige Flamme (inv_torch_lit)
        [2065624] = true,  -- Lichtfunke (ability_paladin_glimmeroflight)
    },
    EVOKER = {
        [4622459] = true,  -- Echo (ability_evoker_echo)
        [4622474] = true,  -- Zurückspulen / Reversion (ability_evoker_reversion)
        [4622453] = true,  -- Traumatem (ability_evoker_dreambreath)
        [4622476] = true,  -- Geistblüte (ability_evoker_spiritbloom)
        [4622477] = true,  -- Zeitdilatation (ability_evoker_timedilation)
        [4622454] = true,  -- Traumflug (ability_evoker_dreamflight)
    },
}

local CLASS_HOT_PATTERNS = {
    DRUID = {
        "rejuvenation", "germination", "resistnature", "felblossom",
        "flourish", "naturalperfection", "nightshade", "cultivation",
        "maldraxxus_druid", "tranquility", "bullrush",
    },
    PRIEST = {
        "renew", "powerwordshield", "prayerofmending", "ashestoashes",
        "atonement", "guardianspirit", "painsupression", "painsuppression",
    },
    SHAMAN = {
        "riptide", "skinofearth", "spear_04", "maldraxxus_shaman", "earthlivingweapon",
    },
    MONK = {
        "envelopingmist", "renewingmist", "soothingmist", "essencefont",
    },
    PALADIN = {
        "beaconoflight", "beaconsoflight", "beaconofvirtue", "torch_lit", "glimmeroflight",
    },
    EVOKER = {
        "evoker_echo", "reversion", "dreambreath", "spiritbloom", "timedilation", "dreamflight",
    },
}

local DEFAULT_HOT_DURATIONS = {
    -- Druid
    [136081] = 12,  -- Rejuvenation
    [1033479] = 12, -- Germination
    [136085] = 12,  -- Regrowth
    [134400] = 15,  -- Lifebloom
    [236153] = 7,   -- Wild Growth
    [538745] = 30,  -- Cenarion Ward
    [1392631] = 6,  -- Spring Blossoms
    [1392632] = 6,  -- Cultivation
    [3578230] = 12, -- Adaptive Swarm
    [136107] = 8,   -- Tranquility
    [132256] = 3,   -- Frenzied Regeneration
    -- Priest
    [135953] = 15,  -- Renew
    [135940] = 30,  -- Power Word: Shield
    [135944] = 30,  -- Prayer of Mending
    [237537] = 6,   -- Echo of Light
    [458224] = 15,  -- Atonement
    [237542] = 10,  -- Guardian Spirit
    [135936] = 8,   -- Pain Suppression
    -- Shaman
    [252995] = 18,  -- Riptide
    [136089] = 600, -- Earth Shield
    [136053] = 15,  -- Healing Stream Totem
    [3565449] = 45, -- Primordial Wave
    [236848] = 12,  -- Earthliving Weapon
    -- Monk
    [606549] = 6,   -- Enveloping Mist
    [627487] = 20,  -- Renewing Mist
    [606550] = 8,   -- Soothing Mist
    [1360978] = 8,  -- Essence Font
    -- Paladin
    [236247] = 3600,-- Beacon of Light
    [1030094] = 3600,-- Beacon of Faith
    [1360762] = 8,  -- Beacon of Virtue
    [135919] = 5,   -- Bestow Faith
    [642416] = 30,  -- Eternal Flame
    [2065624] = 30, -- Glimmer of Light
    -- Evoker
    [4622459] = 15, -- Echo
    [4622474] = 12, -- Reversion
    [4622453] = 16, -- Dream Breath
    [4622476] = 10, -- Spiritbloom
    [4622477] = 8,  -- Time Dilation
    [4622454] = 15, -- Dream Flight
}

-- Dynamische Textur-Vorinitialisierung über Client Spell-DBC
local function SafeGetSpellTexture(spellIdentifier)
    if not spellIdentifier or IsSecret(spellIdentifier) then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellIdentifier)
        if ok and tex and not IsSecret(tex) then return tex end
    end
    if GetSpellTexture then
        local ok, tex = pcall(GetSpellTexture, spellIdentifier)
        if ok and tex and not IsSecret(tex) then return tex end
    end
    return nil
end

for cls, spells in pairs(CLASS_HOTS) do
    for sId in pairs(spells) do
        local tex = SafeGetSpellTexture(sId)
        if tex then
            if type(tex) == "number" then
                CLASS_HOT_TEXTURES[cls][tex] = true
            elseif type(tex) == "string" then
                CLASS_HOT_TEXTURES[cls][tex:lower()] = true
                local sub = tex:match("[^\\]+$") or tex:match("[^/]+$")
                if sub then CLASS_HOT_TEXTURES[cls][sub:lower()] = true end
            end
        end
    end
end

-- Identifiziert die Heiler-Klasse einer Aura anhand ihres Icons/ihrer Textur
local function GetHotClassFromIcon(icon)
    if not icon or IsSecret(icon) then return nil end

    -- 1. Numerischer Match (FileDataID)
    local num = nil
    if type(icon) == "number" then
        num = icon
    elseif type(icon) == "string" then
        num = tonumber(icon)
    end

    if num then
        for cls, texMap in pairs(CLASS_HOT_TEXTURES) do
            if texMap[num] then return cls end
        end
    end

    -- 2. String Match (Pfad / Texturname)
    if type(icon) == "string" then
        local lower = icon:lower()
        for cls, texMap in pairs(CLASS_HOT_TEXTURES) do
            if texMap[lower] then return cls end
        end
        for cls, patterns in pairs(CLASS_HOT_PATTERNS) do
            for _, pat in ipairs(patterns) do
                if lower:find(pat, 1, true) then
                    return cls
                end
            end
        end
    end

    return nil
end

-- Bestimmt Standard-Dauer eines HoTs als Fallback bei Secret Values
local function GetDefaultHotDuration(spellId, name, icon)
    if icon then
        local num = (type(icon) == "number") and icon or tonumber(icon)
        if num and DEFAULT_HOT_DURATIONS[num] then
            return DEFAULT_HOT_DURATIONS[num]
        end
    end
    if spellId and not IsSecret(spellId) and type(spellId) == "number" then
        if DEFAULT_HOT_DURATIONS[spellId] then
            return DEFAULT_HOT_DURATIONS[spellId]
        end
    end
    return 15
end

-- Prüft, ob ein Zauber zur Heiler-Klasse des aktiven Spielers gehört (strikte Trennung!)
local function IsPlayerClassSpell(name, spellId, icon)
    local _, pClass = UnitClass("player")
    if not pClass then return false end

    -- 1. Prüfe über Icon / Textur (funktioniert 100% im Kampf bei geheimen Namen/IDs!)
    if icon then
        local hotClass = GetHotClassFromIcon(icon)
        if hotClass then
            return hotClass == pClass
        end
    end

    -- 2. Prüfe über Spell-ID in CLASS_HOTS[pClass]
    if spellId and not IsSecret(spellId) and type(spellId) == "number" and CLASS_HOTS[pClass] and CLASS_HOTS[pClass][spellId] then
        return true
    end

    -- 3. Prüfe über Zaubernamen in CLASS_HOT_NAMES[pClass]
    if name and not IsSecret(name) and type(name) == "string" and name ~= "" then
        local clean = GetCleanSpellName(name)
        if clean and clean ~= "" and CLASS_HOT_NAMES[pClass] and CLASS_HOT_NAMES[pClass][clean] then
            return true
        end
        if CLASS_HOT_NAMES[pClass] and CLASS_HOT_NAMES[pClass][name] then
            return true
        end
    end

    -- 4. Prüfe über Config trackedHots der eigenen Klasse
    if spellId and not IsSecret(spellId) and R4L.Config and R4L.Config.ClassDefaults and R4L.Config.ClassDefaults[pClass] then
        local cDef = R4L.Config.ClassDefaults[pClass]
        if cDef.trackedHots then
            for _, id in ipairs(cDef.trackedHots) do
                if spellId == id then return true end
            end
        end
    end

    return false
end

-- Prüft, ob eine Aura ein HoT (Heal over Time) oder Schild irgendeiner Heiler-Klasse ist
local function IsHotAura(name, spellId, duration, icon)
    -- 1. Prüfe Icon / Textur (funktioniert IMMER, auch im Kampf mit geheimen Werten!)
    if icon then
        local cls = GetHotClassFromIcon(icon)
        if cls then return true end
    end

    -- 2. Prüfe SpellId (falls vorhanden und nicht geheim)
    if spellId and not IsSecret(spellId) and type(spellId) == "number" then
        for _, hots in pairs(CLASS_HOTS) do
            if hots[spellId] then return true end
        end
    end

    -- 3. Prüfe Zaubername (falls vorhanden und nicht geheim)
    if name and not IsSecret(name) and type(name) == "string" and name ~= "" then
        local cleanName = GetCleanSpellName(name)
        for _, names in pairs(CLASS_HOT_NAMES) do
            if cleanName and cleanName ~= "" and names[cleanName] then return true end
            if names[name] then return true end
        end
    end

    return false
end

-- =========================================================================
-- Intelligenter HoT-, Schild- & Heal-Prediction-Cache (100% Sichtbarkeit in & out of combat)
-- =========================================================================
AT.hotCache = {}
AT.incomingHealCache = {}
AT._lastClickCastTime = {}

-- Bekannte Schilde (Icons & Spell-IDs) für die Schild-/Absorb-Balkenanzeige
local SHIELD_ICONS = {
    [135940] = true, -- Machtwort: Schild (Power Word: Shield)
    [136089] = true, -- Erdschild (Earth Shield)
    [538745] = true, -- Cenarischer Zauberschutz (Cenarion Ward)
    [237542] = true, -- Schutzgeist (Guardian Spirit)
    [135936] = true, -- Schmerzunterdrückung (Pain Suppression)
    [236249] = true, -- Geheiligter Schild (Sacred Shield)
    [135843] = true, -- Eisbarriere (Ice Barrier)
}

-- Vollständige Metadaten für alle Heiler-HoTs, Schilde und direkte Heilzauber (DE & EN)
local SPELL_CAST_META_LIST = {
    -- DRUIDE
    { names = { "verjüngung", "rejuvenation" }, spellId = 774, icon = 136081, duration = 12, castTime = 0, isHot = true },
    { names = { "keimung", "germination" }, spellId = 155777, icon = 1033479, duration = 12, castTime = 0, isHot = true },
    { names = { "nachwachsen", "regrowth" }, spellId = 8936, icon = 136085, duration = 21, castTime = 1.5, isHot = true, isDirectHeal = true },
    { names = { "blühendes leben", "lifebloom" }, spellId = 33763, icon = 134400, duration = 7, castTime = 0, isHot = true, stacks = true, maxStacks = 3 },
    { names = { "wildwuchs", "wild growth" }, spellId = 48438, icon = 236153, duration = 7, castTime = 0, isHot = true, isAoE = true },
    { names = { "cenarischer zauberschutz", "cenarion ward" }, spellId = 102351, icon = 538745, duration = 30, castTime = 0, isHot = true, isShield = true },
    { names = { "gelassenheit", "tranquility" }, spellId = 157982, icon = 136107, duration = 8, castTime = 8, isHot = true, isDirectHeal = true, isAoE = true },
    { names = { "pflege", "nourish" }, spellId = 50464, icon = 236162, duration = 0, castTime = 1.5, isDirectHeal = true },
    { names = { "heilende berührung", "healing touch" }, spellId = 5185, icon = 136041, duration = 0, castTime = 2.5, isDirectHeal = true },
    -- PRIESTER
    { names = { "erneuerung", "renew" }, spellId = 139, icon = 135953, duration = 15, castTime = 0, isHot = true },
    { names = { "machtwort: schild", "power word: shield" }, spellId = 17, icon = 135940, duration = 30, castTime = 0, isHot = true, isShield = true },
    { names = { "gebet der besserung", "prayer of mending" }, spellId = 41635, icon = 135944, duration = 30, castTime = 0, isHot = true, defaultCount = 5 },
    { names = { "schutzgeist", "guardian spirit" }, spellId = 47788, icon = 237542, duration = 10, castTime = 0, isHot = true, isShield = true },
    { names = { "schmerzunterdrückung", "pain suppression" }, spellId = 33206, icon = 135936, duration = 8, castTime = 0, isHot = true, isShield = true },
    { names = { "abbitte", "atonement" }, spellId = 194384, icon = 458224, duration = 15, castTime = 0, isHot = true },
    { names = { "blitzheilung", "flash heal" }, spellId = 2061, icon = 135907, duration = 0, castTime = 1.5, isDirectHeal = true },
    { names = { "große heilung", "greater heal" }, spellId = 2060, icon = 135913, duration = 0, castTime = 2.5, isDirectHeal = true },
    { names = { "heilung", "heal" }, spellId = 2054, icon = 135913, duration = 0, castTime = 2.5, isDirectHeal = true },
    { names = { "geringes heilen", "lesser heal" }, spellId = 2050, icon = 135929, duration = 0, castTime = 2.0, isDirectHeal = true },
    { names = { "verbindende heilung", "binding heal" }, spellId = 32546, icon = 135883, duration = 0, castTime = 1.5, isDirectHeal = true },
    { names = { "gebet der heilung", "prayer of healing" }, spellId = 596, icon = 135943, duration = 0, castTime = 2.5, isDirectHeal = true, isAoE = true },
    { names = { "sühne", "penance" }, spellId = 47540, icon = 237545, duration = 0, castTime = 2.0, isDirectHeal = true },
    -- SCHAMANE
    { names = { "springflut", "riptide" }, spellId = 61295, icon = 252995, duration = 15, castTime = 0, isHot = true },
    { names = { "erdschild", "earth shield" }, spellId = 974, icon = 136089, duration = 600, castTime = 0, isHot = true, isShield = true, defaultCount = 6 },
    { names = { "welle der heilung", "healing wave" }, spellId = 331, icon = 136052, duration = 0, castTime = 2.5, isDirectHeal = true },
    { names = { "geringe welle der heilung", "lesser healing wave", "heilende woge", "healing surge" }, spellId = 8004, icon = 136043, duration = 0, castTime = 1.5, isDirectHeal = true },
    { names = { "kettenheilung", "chain heal" }, spellId = 1064, icon = 136042, duration = 0, castTime = 2.5, isDirectHeal = true, isAoE = true },
    -- PALADIN
    { names = { "flamme des glaubens", "beacon of light" }, spellId = 53563, icon = 236247, duration = 300, castTime = 0, isHot = true },
    { names = { "flamme der zuversicht", "beacon of faith" }, spellId = 156910, icon = 1030094, duration = 300, castTime = 0, isHot = true },
    { names = { "flamme der tugend", "beacon of virtue" }, spellId = 200025, icon = 1360762, duration = 8, castTime = 0, isHot = true, isAoE = true },
    { names = { "ewige flamme", "eternal flame" }, spellId = 156322, icon = 642416, duration = 30, castTime = 0, isHot = true },
    { names = { "geheiligter schild", "sacred shield" }, spellId = 53601, icon = 236249, duration = 30, castTime = 0, isHot = true, isShield = true },
    { names = { "heiliges licht", "holy light" }, spellId = 635, icon = 135920, duration = 0, castTime = 2.5, isDirectHeal = true },
    { names = { "lichtblitz", "flash of light" }, spellId = 19750, icon = 135907, duration = 0, castTime = 1.5, isDirectHeal = true },
    -- MÖNCH
    { names = { "erneuernder nebel", "renewing mist" }, spellId = 119611, icon = 627487, duration = 20, castTime = 0, isHot = true },
    { names = { "einhüllender nebel", "enveloping mist" }, spellId = 124682, icon = 606549, duration = 6, castTime = 1.5, isHot = true, isDirectHeal = true },
    { names = { "beruhigender nebel", "soothing mist" }, spellId = 115175, icon = 606550, duration = 8, castTime = 0, isHot = true },
    { names = { "belebung", "vivify" }, spellId = 116670, icon = 1360980, duration = 0, castTime = 1.5, isDirectHeal = true },
    -- RUFER (EVOKER)
    { names = { "echo" }, spellId = 364343, icon = 4622459, duration = 15, castTime = 0, isHot = true },
    { names = { "zurückspulen", "reversion" }, spellId = 366155, icon = 4622474, duration = 12, castTime = 0, isHot = true },
    { names = { "traumatem", "dream breath" }, spellId = 355936, icon = 4622453, duration = 16, castTime = 1.5, isHot = true, isDirectHeal = true, isAoE = true },
    { names = { "lebende flamme", "living flame" }, spellId = 361469, icon = 4622464, duration = 0, castTime = 2.0, isDirectHeal = true },
}

local SPELL_META_BY_NAME = {}
local SPELL_META_BY_ID = {}
for _, meta in ipairs(SPELL_CAST_META_LIST) do
    if meta.spellId then
        SPELL_META_BY_ID[meta.spellId] = meta
    end
    for _, n in ipairs(meta.names) do
        SPELL_META_BY_NAME[n:lower()] = meta
    end
end

local ICON_PATTERN_TO_CANONICAL = {
    { pat = "rejuvenation",      icon = 136081 },
    { pat = "germination",       icon = 1033479 },
    { pat = "resistnature",      icon = 136085 },
    { pat = "felblossom",        icon = 134400 },
    { pat = "flourish",          icon = 236153 },
    { pat = "naturalperfection", icon = 538745 },
    { pat = "tranquility",       icon = 136107 },
    { pat = "bullrush",          icon = 132256 },
    { pat = "renew",             icon = 135953 },
    { pat = "powerwordshield",   icon = 135940 },
    { pat = "prayerofmending",   icon = 135944 },
    { pat = "ashestoashes",      icon = 237537 },
    { pat = "atonement",         icon = 458224 },
    { pat = "guardianspirit",    icon = 237542 },
    { pat = "painsupression",    icon = 135936 },
    { pat = "painsuppression",   icon = 135936 },
    { pat = "riptide",           icon = 252995 },
    { pat = "skinofearth",       icon = 136089 },
    { pat = "spear_04",          icon = 136053 },
    { pat = "earthlivingweapon", icon = 236848 },
    { pat = "envelopingmist",    icon = 606549 },
    { pat = "renewingmist",      icon = 627487 },
    { pat = "soothingmist",      icon = 606550 },
    { pat = "essencefont",       icon = 1360978 },
    { pat = "beaconoflight",     icon = 236247 },
    { pat = "beaconsoflight",    icon = 1030094 },
    { pat = "beaconofvirtue",    icon = 1360762 },
    { pat = "torch_lit",         icon = 642416 },
    { pat = "glimmeroflight",    icon = 2065624 },
}

local function FindSpellMeta(spell)
    if IsSecret(spell) or IsNil(spell) then return nil end
    local num = SafeNumber(spell, nil)
    if num then
        if SPELL_META_BY_ID[num] then return SPELL_META_BY_ID[num] end
        local sName = R4L.GetSpellName and R4L:GetSpellName(num)
        spell = SafeString(sName, nil)
        if not spell then return nil end
    end
    local str = SafeString(spell, nil)
    if str then
        local clean = GetCleanSpellName(str):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if SPELL_META_BY_NAME[clean] then return SPELL_META_BY_NAME[clean] end
        for k, meta in pairs(SPELL_META_BY_NAME) do
            if clean:find(k, 1, true) then
                return meta
            end
        end
    end
    return nil
end

local function NormalizeHotIcon(name, spellId, icon)
    local meta = (spellId and spellId ~= 0 and FindSpellMeta(spellId)) or (name and name ~= "" and FindSpellMeta(name))
    if meta and meta.icon then
        return meta.icon
    end
    local num = SafeNumber(icon, nil)
    if num then return num end
    local str = SafeString(icon, nil)
    if str then
        local asNum = tonumber(str)
        if asNum then return asNum end
        local lower = str:lower()
        for _, entry in ipairs(ICON_PATTERN_TO_CANONICAL) do
            if lower:find(entry.pat, 1, true) then
                return entry.icon
            end
        end
        return str
    end
    return nil
end

AT.baselineOwnNonHot = {}
AT.baselineOtherNonHot = {}
AT.combatSlotTimers = {}
AT._lastHelpfulCount = {}

-- Bestimmt ein Standard-HoT-Icon für eine Klasse (als Fallback für geheime Combat-Auren)
local DEFAULT_CLASS_HOT_ICON = {
    DRUID   = 136081, -- Verjüngung
    PRIEST  = 135953, -- Erneuerung
    SHAMAN  = 252995, -- Springflut
    PALADIN = 236247, -- Flamme des Glaubens
    MONK    = 627487, -- Erneuernder Nebel
    EVOKER  = 4622459,-- Echo
}

local function GetPartyHealerDefaultIcon()
    local _, pClass = UnitClass("player")
    for i = 1, 4 do
        local u = "party" .. i
        local okEx, ex = pcall(function() return UnitExists(u) == true end)
        if okEx and ex then
            local _, uClass = UnitClass(u)
            if uClass and DEFAULT_CLASS_HOT_ICON[uClass] and uClass ~= pClass then
                return DEFAULT_CLASS_HOT_ICON[uClass]
            end
        end
    end
    for i = 1, 4 do
        local u = "party" .. i
        local okEx, ex = pcall(function() return UnitExists(u) == true end)
        if okEx and ex then
            local _, uClass = UnitClass(u)
            if uClass and DEFAULT_CLASS_HOT_ICON[uClass] then
                return DEFAULT_CLASS_HOT_ICON[uClass]
            end
        end
    end
    return 135953 -- Standard Erneuerung
end

function AT:ClearHotCache(unit)
    if not unit then return end
    local key = GetUnitKey(unit)
    if key and self.hotCache[key] then
        self.hotCache[key] = nil
    end
    if self.hotCache[unit] then
        self.hotCache[unit] = nil
    end
    if key and self.combatSlotTimers[key] then
        self.combatSlotTimers[key] = nil
    end
end

function AT:SetCachedHot(unit, hotData)
    if not unit or not hotData then return end
    local nameVal = SafeString(hotData.name, "")
    local spellIdVal = SafeNumber(hotData.spellId, 0)
    local iconVal = NormalizeHotIcon(nameVal, spellIdVal, hotData.icon)
    if not iconVal then return end
    local key = GetUnitKey(unit)
    if not key then return end
    if not self.hotCache[key] then
        self.hotCache[key] = {}
    end
    -- Nutze kanonisches Icon als Key, damit String-Pfade, FileDataIDs & ClickCast immer denselben Slot teilen
    local hotKey = iconVal
    local now = GetTime()
    local existing = self.hotCache[key][hotKey]

    if nameVal == "" and existing then
        nameVal = SafeString(existing.name, "")
    end
    if spellIdVal == 0 and existing then
        spellIdVal = SafeNumber(existing.spellId, 0)
    end

    local durVal = SafeNumber(hotData.duration, nil) or (existing and SafeNumber(existing.duration, nil)) or 15
    local expTime = SafeNumber(hotData.expirationTime, nil) or (now + durVal)
    if existing and existing.expirationTime and existing.expirationTime > now and not hotData.hasRealExpiration and not hotData.forceRefresh then
        expTime = existing.expirationTime
    end

    local cnt = SafeNumber(hotData.count, 0)
    if hotData.stacks and existing and existing.expirationTime and existing.expirationTime > now then
        cnt = math.min(hotData.maxStacks or 3, (existing.count or 1) + 1)
    elseif hotData.stacks and cnt == 0 then
        cnt = 1
    end

    -- WICHTIG: Niemals Lua-Ternary "and false or true" für Booleans verwenden!
    local isMineVal = false
    if hotData.isMine ~= nil then
        isMineVal = (hotData.isMine == true)
    elseif existing and existing.isMine ~= nil then
        isMineVal = (existing.isMine == true)
    end
    -- Ein fremder Klassen-HoT (z. B. Priester-Erneuerung auf Druiden-Client) darf NIEMALS isMine = true sein!
    if isMineVal and not IsPlayerClassSpell(nameVal, spellIdVal, iconVal) then
        isMineVal = false
    end

    self.hotCache[key][hotKey] = {
        name = nameVal,
        icon = iconVal,
        rawIcon = hotData.rawIcon or iconVal,
        count = cnt,
        duration = durVal,
        expirationTime = expTime,
        spellId = spellIdVal,
        isMine = isMineVal,
        isShield = (hotData.isShield == true) or (SHIELD_ICONS[iconVal] == true) or false,
        lastSeen = now,
        castTime = hotData.forceRefresh and now or (existing and existing.castTime) or now,
    }
end

-- Setzt eine eingehende Heilung für die Dauer der Zauberzeit
function AT:SetIncomingHeal(unit, castTime)
    if not unit then return end
    local key = GetUnitKey(unit)
    if not key then return end
    local dur = (castTime and castTime > 0) and castTime or 2.0
    self.incomingHealCache[key] = {
        expirationTime = GetTime() + dur,
        duration = dur,
    }
end

-- Prüft, ob auf der Einheit aktuell eine eingehende Heilung gecastet wird
function AT:HasIncomingHeal(unit)
    if not unit then return false end
    local key = GetUnitKey(unit)
    if not key then return false end
    local now = GetTime()
    local entry = self.incomingHealCache[key]
    if entry then
        if entry.expirationTime and entry.expirationTime > now then
            return true
        else
            self.incomingHealCache[key] = nil
        end
    end
    return false
end

-- Prüft, ob auf der Einheit ein aktives Schild (z.B. Machtwort: Schild, Erdschild) liegt
function AT:HasActiveShield(unit)
    if not unit then return false end
    local key = GetUnitKey(unit)
    local uHots = (key and self.hotCache[key]) or self.hotCache[unit]
    local now = GetTime()
    if uHots then
        for _, cached in pairs(uHots) do
            if cached.expirationTime and cached.expirationTime > now then
                if cached.isShield or SHIELD_ICONS[cached.icon] then
                    return true
                end
            end
        end
    end
    return false
end

function AT:ApplyMetaHotToUnit(unit, meta, isMineOverride)
    if not unit or not meta or not meta.isHot then return end
    local okEx, exists = pcall(function() return UnitExists(unit) == true end)
    if not okEx or not exists then return end
    if UnitIsDeadOrGhost then
        local okD, isD = pcall(function() return UnitIsDeadOrGhost(unit) == true end)
        if okD and isD then return end
    end

    local isMine = false
    if isMineOverride ~= nil then
        isMine = (isMineOverride == true) and IsPlayerClassSpell(meta.names[1], meta.spellId, meta.icon)
    else
        isMine = IsPlayerClassSpell(meta.names[1], meta.spellId, meta.icon)
    end

    local now = GetTime()
    local dur = meta.duration or 15
    self:SetCachedHot(unit, {
        name = meta.names[1] or "",
        icon = meta.icon,
        count = meta.defaultCount or (meta.stacks and 1 or 0),
        stacks = meta.stacks,
        maxStacks = meta.maxStacks,
        duration = dur,
        expirationTime = now + dur,
        spellId = meta.spellId or 0,
        isMine = isMine,
        isShield = meta.isShield,
        forceRefresh = true,
    })
end

-- Wird von ClickCast (PreClick) und UNIT_SPELLCAST_SENT / SUCCEEDED aufgerufen
function AT:OnPlayerClickCast(unit, spell, isMineOverride)
    if not unit or unit == "OUTSIDER" or not spell then return end
    local okEx, exists = pcall(function() return UnitExists(unit) == true end)
    if not okEx or not exists then return end
    if UnitIsDeadOrGhost then
        local okD, isD = pcall(function() return UnitIsDeadOrGhost(unit) == true end)
        if okD and isD then return end
    end

    local meta = FindSpellMeta(spell)
    if not meta then return end

    local key = GetUnitKey(unit) or tostring(unit)
    local debounceKey = key .. ":" .. tostring(meta.icon) .. ":" .. tostring(isMineOverride ~= false)
    local now = GetTime()
    if self._lastClickCastTime[debounceKey] and (now - self._lastClickCastTime[debounceKey]) < 0.20 then
        return
    end
    self._lastClickCastTime[debounceKey] = now

    if meta.castTime and meta.castTime > 0 then
        -- Zauber mit Zauberzeit (z. B. Nachwachsen, Blitzheilung, Große Heilung, Heilende Berührung)
        if meta.isDirectHeal then
            if meta.isAoE then
                self:SetIncomingHeal("player", meta.castTime)
                for i = 1, 4 do
                    local pU = "party" .. i
                    local okP, exP = pcall(function() return UnitExists(pU) == true end)
                    if okP and exP then
                        self:SetIncomingHeal(pU, meta.castTime)
                    end
                end
            else
                self:SetIncomingHeal(unit, meta.castTime)
            end
        end
        self._pendingCast = {
            unit = unit,
            meta = meta,
            isMine = isMineOverride,
            endTime = now + meta.castTime,
        }
        if C_Timer and C_Timer.After and meta.isHot then
            local expectedCast = self._pendingCast
            C_Timer.After(meta.castTime, function()
                if AT._pendingCast == expectedCast then
                    AT._pendingCast = nil
                    AT:ApplyMetaHotToUnit(unit, meta, isMineOverride)
                end
            end)
        end
    else
        -- Sofortzauber HoT oder Schild (Verjüngung, Erneuerung, Machtwort: Schild, Blühendes Leben, Wildwuchs, Springflut, Erdschild)
        if meta.isAoE then
            self:ApplyMetaHotToUnit("player", meta, isMineOverride)
            for i = 1, 4 do
                local pU = "party" .. i
                local okP, exP = pcall(function() return UnitExists(pU) == true end)
                if okP and exP then
                    self:ApplyMetaHotToUnit(pU, meta, isMineOverride)
                end
            end
        else
            self:ApplyMetaHotToUnit(unit, meta, isMineOverride)
        end
    end
end

-- Holt alle aktiven HoTs (eigene HoTs und fremde HoTs getrennt) auf der Zieleinheit
function AT:GetPlayerHots(unit)
    local ownHots = {}
    local otherHots = {}
    if not unit or IsSecret(unit) then return ownHots, otherHots end
    local okEx, exists = pcall(function() return UnitExists(unit) == true end)
    if not okEx or not exists then return ownHots, otherHots end

    if UnitIsDeadOrGhost then
        local okDead, isDead = pcall(function() return UnitIsDeadOrGhost(unit) == true end)
        if okDead and isDead then
            self:ClearHotCache(unit)
            return ownHots, otherHots
        end
    end

    local maxOwnHots = 4
    local maxOtherHots = 3
    if R4L.ProfileManager then
        local cfg = R4L.ProfileManager:GetConfig()
        if cfg and cfg.auras then
            if cfg.auras.maxHots then maxOwnHots = cfg.auras.maxHots end
            if cfg.auras.maxOtherHots then maxOtherHots = cfg.auras.maxOtherHots end
        end
    end

    local allOwn = {}
    local allOther = {}
    local seenOwn = {}
    local seenOther = {}
    local secretPlayerAuras = {}
    local secretAllAuras = {}
    local totalPlayerHelpful = 0
    local totalAllHelpful = 0
    local now = GetTime()
    local key = GetUnitKey(unit)

    local inCombat = false
    if InCombatLockdown and InCombatLockdown() then
        inCombat = true
    end
    if not inCombat and UnitAffectingCombat then
        local okC1, c1 = pcall(function() return UnitAffectingCombat(unit) == true end)
        local okC2, c2 = pcall(function() return UnitAffectingCombat("player") == true end)
        if (okC1 and c1) or (okC2 and c2) then
            inCombat = true
        end
    end

    local function TryAddAura(rawAura, fromPlayerFilter, slotIdx)
        if not rawAura or type(rawAura) ~= "table" then return false end
        local aura = rawAura
        if aura.iconIsSecret == nil then
            aura = SanitizeAuraDataTable(rawAura)
            if not aura then return false end
        end
        if fromPlayerFilter then
            aura._fromPlayerFilter = true
        end

        local name = SafeString(aura.name, "")
        local rawIconVal = SafeNumber(aura.icon, nil) or SafeString(aura.icon, nil)
        local count = SafeNumber(aura.count, 0)
        local duration = SafeNumber(aura.duration, 0)
        local expirationTime = SafeNumber(aura.expirationTime, 0)
        local spellId = SafeNumber(aura.spellId, 0)

        -- Falls Icon irrtümlich als Rang-String ankam, Textur über Zaubernamen auflösen
        if type(rawIconVal) == "string" and (rawIconVal:find("Rang") or rawIconVal:find("Rank")) then
            local sTex = SafeGetSpellTexture((spellId ~= 0 and spellId) or (name ~= "" and name))
            if sTex then rawIconVal = sTex end
        end

        local icon = NormalizeHotIcon(name, spellId, rawIconVal)

        if not icon then
            if aura.iconIsSecret and aura.rawIcon then
                if fromPlayerFilter then
                    table.insert(secretPlayerAuras, { slot = slotIdx or (#secretPlayerAuras + 1), rawIcon = aura.rawIcon })
                else
                    table.insert(secretAllAuras, { slot = slotIdx or (#secretAllAuras + 1), rawIcon = aura.rawIcon })
                end
            end
            return false
        end

        -- Prüfe, ob es sich um einen HoT / Schild handelt
        if not IsHotAura(name, spellId, duration, icon) then return false end

        -- Eigene HoTs MÜSSEN zwingend zur Klasse des Spielers gehören
        local isMine = false
        if IsPlayerClassSpell(name, spellId, icon) then
            if fromPlayerFilter then
                isMine = true
            else
                isMine = IsPlayerAura(aura, unit)
            end
        end

        local hasRealExp = (expirationTime > 0)
        local safeDur = (duration > 0) and duration or GetDefaultHotDuration(spellId, name, icon)

        local safeExp = 0
        if hasRealExp then
            safeExp = expirationTime
        else
            local existing = key and self.hotCache[key] and self.hotCache[key][icon]
            if existing and existing.expirationTime and existing.expirationTime > now then
                safeExp = existing.expirationTime
            else
                safeExp = now + (safeDur > 0 and safeDur or 15)
            end
        end

        local hotKey = icon
        local hotData = {
            name = name,
            icon = icon,
            rawIcon = aura.rawIcon or icon,
            count = count,
            duration = safeDur,
            expirationTime = safeExp,
            hasRealExpiration = hasRealExp,
            spellId = spellId,
            isMine = isMine,
            isShield = SHIELD_ICONS[icon] or false,
        }

        if isMine then
            if not seenOwn[hotKey] and not seenOther[hotKey] then
                seenOwn[hotKey] = true
                table.insert(allOwn, hotData)
            end
        else
            if not seenOther[hotKey] and not seenOwn[hotKey] then
                seenOther[hotKey] = true
                table.insert(allOther, hotData)
            end
        end

        -- Im Cache sichern
        self:SetCachedHot(unit, hotData)
        return true
    end

    -- Pass 1: Direkter Index-Scan für eigene Auren mit "HELPFUL|PLAYER" Filter
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then break end
        totalPlayerHelpful = totalPlayerHelpful + 1
        pcall(TryAddAura, aura, true, i)
    end

    -- Pass 2: Direkter Index-Scan für alle "HELPFUL" Auren
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HELPFUL")
        if not aura then break end
        totalAllHelpful = totalAllHelpful + 1
        pcall(TryAddAura, aura, false, i)
    end

    -- Falls GetUnitAuraByIndex 0 Auren fand, probiere C_UnitAuras.GetUnitAuras als Fallback
    if totalAllHelpful == 0 and C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL", 40, 0, 0)
        if not ok or not res or type(res) ~= "table" then
            ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        end
        if ok and res and type(res) == "table" then
            for idx, rawAura in ipairs(res) do
                totalAllHelpful = totalAllHelpful + 1
                pcall(TryAddAura, rawAura, false, idx)
            end
        end
    end

    local prevHelpful = key and self._lastHelpfulCount[key] or totalAllHelpful
    if key then
        self._lastHelpfulCount[key] = totalAllHelpful
    end

    -- Prüfe ob UnitGetTotalAbsorbs eindeutig 0 liefert (Schild wurde gebrochen!)
    local unitHasZeroAbsorbs = false
    if UnitGetTotalAbsorbs then
        local okAbs, aVal = pcall(UnitGetTotalAbsorbs, unit)
        if okAbs and not IsSecret(aVal) and type(aVal) == "number" and aVal == 0 then
            unitHasZeroAbsorbs = true
        end
    end

    if key and self.hotCache[key] then
        local allIconsReadable = (#secretAllAuras == 0 and #secretPlayerAuras == 0)
        local buffsDropped = (totalAllHelpful < prevHelpful)
        for hotKey, cached in pairs(self.hotCache[key]) do
            if not seenOwn[hotKey] and not seenOther[hotKey] then
                local age = now - (cached.castTime or 0)
                if not inCombat and age > 0.6 then
                    -- Außerhalb des Kampfes: Nicht mehr vorhandene HoTs / Schilde sofort aus dem Cache entfernen!
                    self.hotCache[key][hotKey] = nil
                elseif inCombat and age > 0.8 then
                    -- Im Kampf: Wenn die Einheit 0 Buffs hat, alle Icons lesbar waren und der Buff fehlt, oder ein Schild gebrochen wurde
                    if totalAllHelpful == 0 or allIconsReadable then
                        self.hotCache[key][hotKey] = nil
                    elseif (cached.isShield or SHIELD_ICONS[hotKey]) and (unitHasZeroAbsorbs or buffsDropped) then
                        self.hotCache[key][hotKey] = nil
                    end
                end
            end
        end
    end

    -- Außerhalb des Kampfes: Aktualisiere Baseline für Nicht-HoT-Buffs
    if not inCombat and key then
        self.baselineOwnNonHot[key] = math.max(0, totalPlayerHelpful - #allOwn)
        local otherTotal = math.max(0, totalAllHelpful - totalPlayerHelpful)
        self.baselineOtherNonHot[key] = math.max(0, otherTotal - #allOther)
        self.combatSlotTimers[key] = nil
    end

    -- Merge aktive HoTs aus dem Cache (z. B. durch ClickCast / Spellcast oder Vor-Kampf-HoTs)
    local uHots = (key and self.hotCache[key]) or self.hotCache[unit]
    if uHots then
        for hotKey, cached in pairs(uHots) do
            if cached.expirationTime and cached.expirationTime > now then
                local isReallyMine = (cached.isMine == true) and IsPlayerClassSpell(cached.name, cached.spellId, cached.icon)
                if isReallyMine then
                    if not seenOwn[hotKey] and not seenOther[hotKey] then
                        seenOwn[hotKey] = true
                        table.insert(allOwn, cached)
                    end
                else
                    if not seenOther[hotKey] and not seenOwn[hotKey] then
                        seenOther[hotKey] = true
                        table.insert(allOther, cached)
                    end
                end
            else
                uHots[hotKey] = nil
            end
        end
    end

    -- Im Kampf: Falls fremde Gruppenheiler-Auren geheime Icons liefern (#secretAllAuras > 0), zeige neue fremde Kampf-HoTs LINKS oben an
    if inCombat and key and #secretAllAuras > 0 then
        if not self.combatSlotTimers[key] then
            self.combatSlotTimers[key] = {}
        end
        local slotTimers = self.combatSlotTimers[key]

        local otherTotal = math.max(0, totalAllHelpful - totalPlayerHelpful)
        local baseOther = self.baselineOtherNonHot[key] or 0
        local extraOther = (otherTotal - baseOther) - #allOther
        if extraOther > 0 then
            local fallbackIcon = GetPartyHealerDefaultIcon()
            local dur = 15
            local isSh = false
            if self._lastPartyHealerMeta and (now - (self._lastPartyHealerMeta.time or 0)) < 2.0 then
                fallbackIcon = self._lastPartyHealerMeta.meta.icon or fallbackIcon
                dur = self._lastPartyHealerMeta.meta.duration or 15
                isSh = self._lastPartyHealerMeta.meta.isShield or false
            end
            local startIdx = math.max(1, #secretAllAuras - extraOther + 1)
            for idx = startIdx, #secretAllAuras do
                local sEntry = secretAllAuras[idx]
                if sEntry then
                    local tKey = "other_" .. tostring(sEntry.slot)
                    local timer = slotTimers[tKey]
                    if not timer or timer.expirationTime <= now then
                        timer = { expirationTime = now + dur, duration = dur, icon = fallbackIcon, isShield = isSh }
                        slotTimers[tKey] = timer
                    end
                    table.insert(allOther, {
                        name = "",
                        icon = timer.icon or fallbackIcon,
                        rawIcon = sEntry.rawIcon,
                        count = 0,
                        duration = timer.duration,
                        expirationTime = timer.expirationTime,
                        isMine = false,
                        isShield = timer.isShield or false,
                    })
                end
            end
        else
            for kSlot in pairs(slotTimers) do
                slotTimers[kSlot] = nil
            end
        end
    end

    local function CompareHots(a, b)
        local timeA = (a.expirationTime and a.expirationTime > 0) and (a.expirationTime - now) or 99999
        local timeB = (b.expirationTime and b.expirationTime > 0) and (b.expirationTime - now) or 99999
        return timeA < timeB
    end
    pcall(table.sort, allOwn, CompareHots)
    pcall(table.sort, allOther, CompareHots)

    for i = 1, math.min(#allOwn, maxOwnHots) do
        table.insert(ownHots, allOwn[i])
    end
    for i = 1, math.min(#allOther, maxOtherHots) do
        table.insert(otherHots, allOther[i])
    end
    return ownHots, otherHots
end

-- Ermittelt den primären Dispel-Typ des Spielers/der Gruppe als Fallback für geheime Kampf-Debuffs
local function GetPrimaryDispelTypeForCombat(playerDispels, groupDispels, cfgAuras)
    local order = { "Poison", "Curse", "Magic", "Disease" }
    for _, dt in ipairs(order) do
        local allowed = (dt == "Poison" and cfgAuras.showPoison ~= false)
            or (dt == "Curse" and cfgAuras.showCurse ~= false)
            or (dt == "Magic" and cfgAuras.showMagic ~= false)
            or (dt == "Disease" and cfgAuras.showDisease ~= false)
        if allowed and playerDispels and playerDispels[dt] then
            return dt
        end
    end
    for _, dt in ipairs(order) do
        local allowed = (dt == "Poison" and cfgAuras.showPoison ~= false)
            or (dt == "Curse" and cfgAuras.showCurse ~= false)
            or (dt == "Magic" and cfgAuras.showMagic ~= false)
            or (dt == "Disease" and cfgAuras.showDisease ~= false)
        if allowed and groupDispels and groupDispels[dt] then
            return dt
        end
    end
    return "Poison"
end

-- Findet den wichtigsten reinigbaren Debuff auf einer Einheit (gesichert im Kampf)
function AT:GetDispellableDebuff(unit)
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.auras or not cfg.auras.showDebuffs then return nil, nil end
    if not unit or IsSecret(unit) then return nil, nil end
    local okEx, exists = pcall(function() return UnitExists(unit) == true end)
    if not okEx or not exists then return nil, nil end

    if UnitIsDeadOrGhost then
        local okD, isD = pcall(function() return UnitIsDeadOrGhost(unit) == true end)
        if okD and isD then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    end

    local combinedDispels, playerDispels, groupDispels = self:GetDispelCapabilities()

    local function EvaluateDebuff(debuffData)
        if not debuffData then return false, nil, 0 end
        local dt = debuffData.dispelType
        if not dt or IsSecret(dt) then return false, nil, 0 end

        local showFilter = false
        if dt == "Curse" and cfg.auras.showCurse then showFilter = true end
        if dt == "Poison" and cfg.auras.showPoison then showFilter = true end
        if dt == "Disease" and cfg.auras.showDisease then showFilter = true end
        if dt == "Magic" and cfg.auras.showMagic then showFilter = true end

        if not showFilter then return false, nil, 0 end

        local canPlayerDispel = (playerDispels and playerDispels[dt] == true)
        local canGroupDispel = (groupDispels and groupDispels[dt] == true)

        -- Wenn "Nur bannbare anzeigen" aktiv ist:
        if cfg.auras.highlightDispellableOnly then
            local canDispel = canPlayerDispel
            if cfg.auras.includeGroupDispels and canGroupDispel then
                canDispel = true
            end
            if not canDispel then
                return false, nil, 0
            end
        end

        local color = self.DebuffColors[dt] or self.DebuffColors["None"]
        -- Priorität: 2 = Eigene Klasse kann bannen, 1 = Gruppe kann bannen, 0 = Allgemeiner Debuff
        local priority = canPlayerDispel and 2 or (canGroupDispel and 1 or 0)
        return true, color, priority
    end

    local bestDebuff, bestColor, bestPriority = nil, nil, -1
    local totalHarmfulScanned = 0
    local secretHarmfulAura = nil
    local scanSucceeded = false

    -- 1. Direkter Scan über GetUnitAuraByIndex (nutzt SanitizeAuraDataTable & ParseUnitAuraArgs 100% Secret-Safe)
    local mError = false
    for i = 1, 40 do
        local okAura, aura = pcall(GetUnitAuraByIndex, unit, i, "HARMFUL")
        if not okAura then
            mError = true
            break
        end
        if not aura then break end
        totalHarmfulScanned = totalHarmfulScanned + 1

        local isMatch, color, prio = EvaluateDebuff(aura)
        if isMatch and prio > bestPriority then
            bestDebuff = aura
            bestColor = color
            bestPriority = prio
            if prio == 2 then break end
        elseif not aura.dispelType and (aura.dispelTypeIsSecret or aura.nameIsSecret or aura.iconIsSecret) then
            secretHarmfulAura = aura
        end
    end
    if not mError then scanSucceeded = true end

    -- Wenn ein passender aktiver Debuff mit lesbarem DispelType gefunden wurde -> Cache auffrischen & zurückgeben
    if bestDebuff and bestColor then
        self:SetCachedDebuff(unit, bestDebuff, bestColor)
        return bestDebuff, bestColor
    end

    -- Status ob Einheit oder Spieler im Kampf ist
    local inCombat = false
    if InCombatLockdown and InCombatLockdown() then
        inCombat = true
    end
    if not inCombat and UnitAffectingCombat then
        local okComb, cVal = pcall(function() return UnitAffectingCombat(unit) == true end)
        if okComb and cVal then inCombat = true end
        if not inCombat then
            local okPComb, pVal = pcall(function() return UnitAffectingCombat("player") == true end)
            if okPComb and pVal then inCombat = true end
        end
    end

    -- 2. Im Kampf: Wenn Debuff-Felder (dispelName / name) als Secret Value maskiert sind, prüfe C++ Filter HARMFUL|RAID_PLAYER_DISPELLABLE & secretHarmfulAura!
    if inCombat and totalHarmfulScanned > 0 then
        local dispellableSecretAura = nil
        local okRaidP, auraRaidP = pcall(GetUnitAuraByIndex, unit, 1, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        if okRaidP and auraRaidP then
            dispellableSecretAura = auraRaidP
        end
        if not dispellableSecretAura then
            local okRaid, auraRaid = pcall(GetUnitAuraByIndex, unit, 1, "HARMFUL|RAID")
            if okRaid and auraRaid then
                dispellableSecretAura = auraRaid
            end
        end
        if not dispellableSecretAura and secretHarmfulAura and secretHarmfulAura.dispelTypeIsSecret then
            -- In WoW 12.0 ist data.dispelName nur dann ein Secret String (nicht nil!), wenn der Debuff tatsächlich einen DispelType besitzt!
            dispellableSecretAura = secretHarmfulAura
        end

        if dispellableSecretAura then
            local fallbackDT = GetPrimaryDispelTypeForCombat(playerDispels, groupDispels, cfg.auras)
            local fallbackColor = self.DebuffColors[fallbackDT] or self.DebuffColors["Poison"]
            local synDebuff = {
                name = dispellableSecretAura.name or "Debuff",
                icon = dispellableSecretAura.icon or 0,
                dispelType = fallbackDT,
                duration = dispellableSecretAura.duration or 15,
                expirationTime = dispellableSecretAura.expirationTime or 0,
            }
            self:SetCachedDebuff(unit, synDebuff, fallbackColor)
            return synDebuff, fallbackColor
        end
    end

    if not inCombat and scanSucceeded then
        self:ClearDebuffCache(unit)
        return nil, nil
    end

    if inCombat then
        if scanSucceeded and totalHarmfulScanned == 0 then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
        local cached, cachedColor = self:GetCachedDebuff(unit)
        if cached and cachedColor then
            local now = GetTime()
            local exp = SafeNumber(cached.expirationTime, 0)
            if exp <= 0 or exp > now then
                return cached, cachedColor
            end
        end
    else
        self:ClearDebuffCache(unit)
    end

    return nil, nil
end

-- =========================================================================
-- Sichere Event-Registrierung für Cache-Management (ohne CLEU / Taint-frei)
-- =========================================================================
if R4L and R4L.RegisterEvent then
    R4L:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        -- Kampf beendet: Säubere abgelaufene Debuffs und HoTs
        local now = GetTime()
        for k, v in pairs(AT.debuffCache) do
            local exp = SafeNumber(v.expirationTime, 0)
            if exp > 0 and now >= exp then
                AT.debuffCache[k] = nil
            end
        end
        for uKey, uMap in pairs(AT.hotCache) do
            for hKey, hData in pairs(uMap) do
                local exp = SafeNumber(hData.expirationTime, 0)
                if exp > 0 and now >= exp then
                    uMap[hKey] = nil
                end
            end
        end
        for k in pairs(AT.combatSlotTimers) do
            AT.combatSlotTimers[k] = nil
        end
        AT._cachedCombined = nil
    end)

    R4L:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        for k in pairs(AT.debuffCache) do
            AT.debuffCache[k] = nil
        end
        for k in pairs(AT.hotCache) do
            AT.hotCache[k] = nil
        end
        for k in pairs(AT.combatSlotTimers) do
            AT.combatSlotTimers[k] = nil
        end
        AT._cachedCombined = nil
    end)

    R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        AT._cachedCombined = nil
    end)

    -- Hilfsfunktion: Löst Gruppen-Unit aus Zielname oder aktuellem Hover/Target auf.
    -- Gibt "OUTSIDER" zurück, wenn das Ziel ein freundlicher Spieler/NPC außerhalb der eigenen Gruppe ist!
    local function ResolveGroupUnitFromTargetName(targetName)
        local tStr = SafeString(targetName, nil)
        if tStr and tStr ~= "" then
            local cleanTarget = tStr:match("^([^%-]+)") or tStr
            local pName = SafeString(UnitName("player"), nil)
            if pName and (pName == tStr or pName == cleanTarget) then
                return "player"
            end
            for i = 1, 4 do
                local u = "party" .. i
                local okEx, ex = pcall(function() return UnitExists(u) == true end)
                if okEx and ex then
                    local uName = SafeString(UnitName(u), nil)
                    if uName and (uName == tStr or uName == cleanTarget) then
                        return u
                    end
                end
            end
            local inRd = false
            if IsInRaid then
                local okR, rVal = pcall(function() return IsInRaid() == true end)
                if okR and rVal then inRd = true end
            end
            if inRd then
                local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
                for i = 1, num do
                    local u = "raid" .. i
                    local okEx, ex = pcall(function() return UnitExists(u) == true end)
                    if okEx and ex then
                        local uName = SafeString(UnitName(u), nil)
                        if uName and (uName == tStr or uName == cleanTarget) then
                            return u
                        end
                    end
                end
            end
            -- Zielname war angegeben, gehört aber zu keinem Gruppen-/Raidmitglied!
            return "OUTSIDER"
        end

        if AT.hoveredUnit then
            local okH, exH = pcall(function() return UnitExists(AT.hoveredUnit) == true end)
            if okH and exH then return AT.hoveredUnit end
        end

        local okMO, moUnit = pcall(function()
            if UnitExists("mouseover") == true and UnitIsFriend("player", "mouseover") == true then
                if UnitIsUnit("mouseover", "player") == true then return "player" end
                for i = 1, 4 do
                    local pU = "party" .. i
                    if UnitExists(pU) == true and UnitIsUnit("mouseover", pU) == true then
                        return pU
                    end
                end
                if IsInRaid and IsInRaid() == true then
                    local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
                    for i = 1, num do
                        local rU = "raid" .. i
                        if UnitExists(rU) == true and UnitIsUnit("mouseover", rU) == true then
                            return rU
                        end
                    end
                end
                return "OUTSIDER"
            end
            return nil
        end)
        if okMO and moUnit then return moUnit end

        local okTgt, tgtUnit = pcall(function()
            if UnitExists("target") == true and UnitIsFriend("player", "target") == true then
                if UnitIsUnit("target", "player") == true then return "player" end
                for i = 1, 4 do
                    local pU = "party" .. i
                    if UnitExists(pU) == true and UnitIsUnit("target", pU) == true then
                        return pU
                    end
                end
                if IsInRaid and IsInRaid() == true then
                    local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
                    for i = 1, num do
                        local rU = "raid" .. i
                        if UnitExists(rU) == true and UnitIsUnit("target", rU) == true then
                            return rU
                        end
                    end
                end
                -- Freundliches Ziel ist NICHT in unserer Gruppe/Raid!
                return "OUTSIDER"
            end
            return nil
        end)
        if okTgt and tgtUnit then return tgtUnit end

        return "player"
    end

    R4L:RegisterEvent("UNIT_SPELLCAST_SENT", function(_, unit, arg2, arg3, arg4)
        local uStr = SafeString(unit, nil)
        if uStr ~= "player" then return end
        -- Prüfe flexibel sowohl Retail/Forever (unit, target, castGUID, spellID) als auch 3.3.5 (unit, spell, rank, target)
        local meta = FindSpellMeta(arg4)
        local targetName = nil
        local spellIdentifier = nil
        if meta then
            spellIdentifier = arg4
            targetName = arg2
        else
            meta = FindSpellMeta(arg2)
            if meta then
                spellIdentifier = arg2
                targetName = arg4
            end
        end
        if spellIdentifier then
            local targetUnit = ResolveGroupUnitFromTargetName(targetName)
            AT._lastSentTargetUnit = targetUnit
            AT._lastSentTime = GetTime()
            if targetUnit and targetUnit ~= "OUTSIDER" then
                AT:OnPlayerClickCast(targetUnit, spellIdentifier, true)
            end
        end
    end)

    R4L:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, arg2, arg3, arg4, arg5)
        local uStr = SafeString(unit, nil)
        if not uStr then return end
        local meta = FindSpellMeta(arg3) or FindSpellMeta(arg2) or FindSpellMeta(arg5) or FindSpellMeta(arg4)
        if not meta then return end

        if uStr == "player" then
            local now = GetTime()
            local targetUnit = nil
            if AT._lastSentTime and (now - AT._lastSentTime) < 4.0 and AT._lastSentTargetUnit ~= nil then
                targetUnit = AT._lastSentTargetUnit
            else
                targetUnit = ResolveGroupUnitFromTargetName(nil)
            end
            if targetUnit and targetUnit ~= "OUTSIDER" then
                AT:OnPlayerClickCast(targetUnit, meta.spellId or meta.names[1], true)
            end
        elseif uStr:match("^party%d+$") then
            AT._lastPartyHealerMeta = {
                meta = meta,
                time = GetTime(),
                caster = uStr,
            }
        end
    end)

    local function OnSpellcastCancelled(_, unit)
        local uStr = SafeString(unit, nil)
        if uStr ~= "player" then return end
        local now = GetTime()
        if AT._pendingCast and AT._pendingCast.endTime and (now < AT._pendingCast.endTime - 0.15) then
            local u = AT._pendingCast.unit
            AT._pendingCast = nil
            if u then
                local key = GetUnitKey(u)
                if key then AT.incomingHealCache[key] = nil end
            end
            for k in pairs(AT.incomingHealCache) do
                AT.incomingHealCache[k] = nil
            end
        end
    end

    R4L:RegisterEvent("UNIT_SPELLCAST_FAILED", OnSpellcastCancelled)
    R4L:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", OnSpellcastCancelled)
    R4L:RegisterEvent("UNIT_SPELLCAST_STOP", OnSpellcastCancelled)
end

-- =========================================================================
-- Diagnose-Funktion für Debuffs (/r4l debufftest)
-- =========================================================================
function AT:RunDiagnostic()
    local _, playerClass = UnitClass("player")
    local combined, playerDispels, groupDispels = self:GetDispelCapabilities()
    local cfg = R4L.ProfileManager:GetConfig()

    print("|cff00ff00=== [Resto4Life Debuff-Diagnose] ===|r")
    print(string.format("Spieler-Klasse: |cffffff00%s|r", tostring(playerClass)))

    local function FormatDispels(t)
        if not t then return "|cff888888Keine|r" end
        local parts = {}
        if t.Curse then table.insert(parts, "|cffaa00ffFluch|r") end
        if t.Poison then table.insert(parts, "|cff00ff00Gift|r") end
        if t.Disease then table.insert(parts, "|cff996600Krankheit|r") end
        if t.Magic then table.insert(parts, "|cff00aaffMagie|r") end
        return #parts > 0 and table.concat(parts, ", ") or "|cff888888Keine|r"
    end

    print("Eigene Dispel-Fähigkeiten: " .. FormatDispels(playerDispels))
    print("Gruppen-Dispel-Fähigkeiten: " .. FormatDispels(groupDispels))

    if cfg.auras then
        print(string.format("Auren-Konfig: showDebuffs=%s, highlightDispellableOnly=%s, Fluch=%s, Gift=%s, Krankheit=%s, Magie=%s",
            tostring(cfg.auras.showDebuffs), tostring(cfg.auras.highlightDispellableOnly),
            tostring(cfg.auras.showCurse), tostring(cfg.auras.showPoison),
            tostring(cfg.auras.showDisease), tostring(cfg.auras.showMagic)))
    end

    local units = { "player", "target" }
    for i = 1, 4 do
        if UnitExists("party" .. i) then table.insert(units, "party" .. i) end
    end

    print("--- Aktuelle Einheiten & Debuffs ---")
    for _, u in ipairs(units) do
        local name = UnitName(u) or u
        local _, uClass = UnitClass(u)
        local debuff, color = self:GetDispellableDebuff(u)
        local debuffStr = debuff and string.format("|cffffff00%s|r (Typ: %s)", tostring(debuff.name), tostring(debuff.dispelType)) or "|cff888888Kein bannbarer Debuff|r"
        local key = GetUnitKey(u)
        local isCached = (key and self.debuffCache[key]) and "|cff00ff00[Im Cache]|r" or ""
        print(string.format("[%s - %s (%s)]: %s %s", u, name, tostring(uClass), debuffStr, isCached))
    end
    print("|cff00ff00======================================|r")
end
