--[[
    Resto4Life - Engine/AuraTracker.lua
    Verfolgung von HoTs (Heal over Time) und reinigbaren Debuffs (Fluch, Gift, Krankheit, Magie)
--]]

local _, R4L = ...

R4L.AuraTracker = {}
local AT = R4L.AuraTracker

-- Helper zur Erkennung von geheimen Strings / Werten in WoW Forever & 12.0
local function IsSecret(val)
    if val == nil then return false end
    if issecretvalue then
        local ok, res = pcall(issecretvalue, val)
        if ok and res then return true end
    end
    if C_Secrets then
        if C_Secrets.IsSecretValue then
            local ok, res = pcall(C_Secrets.IsSecretValue, val)
            if ok and res then return true end
        end
        if C_Secrets.IsSecret then
            local ok, res = pcall(C_Secrets.IsSecret, val)
            if ok and res then return true end
        end
    end
    -- Secret Values werfen im Kampf bei relationalen Operatoren oder Arithmetik sofort einen Fehler
    if type(val) == "number" or type(val) == "userdata" then
        local okComp = pcall(function() return val > 0 end)
        if not okComp then return true end
    end
    if type(val) == "string" then
        local okLen = pcall(function() return #val end)
        if not okLen then return true end
    end
    return false
end
R4L.IsSecret = IsSecret

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

-- Normalisiert Dispel-Typen unabhängig von Groß-/Kleinschreibung oder Client-Sprache (deDE / enUS)
local function NormalizeDispelType(dt)
    if not dt or IsSecret(dt) then return nil end
    if type(dt) ~= "string" then return nil end
    local lower = dt:lower():gsub("%s+", "")
    if lower == "curse" or lower:find("fluch") then
        return "Curse"
    elseif lower == "poison" or lower:find("gift") then
        return "Poison"
    elseif lower == "disease" or lower:find("krank") then
        return "Disease"
    elseif lower == "magic" or lower:find("magie") then
        return "Magic"
    end
    if dt == "Curse" or dt == "Poison" or dt == "Disease" or dt == "Magic" then
        return dt
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
    local playerClass = okP and (engClass or locClass) or nil
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
        local okR, rVal = pcall(IsInRaid)
        if okR and rVal then inRaid = true end
    end

    if inRaid then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, count do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                local okC, lc, ec = pcall(UnitClass, u)
                if okC then
                    ApplyClassDispels(ec or lc, groupDispels)
                end
            end
        end
    else
        local inGroup = false
        if IsInGroup then
            local okG, gVal = pcall(IsInGroup)
            if okG and gVal then inGroup = true end
        end
        if inGroup then
            for i = 1, 4 do
                local u = "party" .. i
                if UnitExists(u) then
                    local okC, lc, ec = pcall(UnitClass, u)
                    if okC then
                        ApplyClassDispels(ec or lc, groupDispels)
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
    local exp = debuffData.expirationTime
    if not exp or IsSecret(exp) or (type(exp) == "number" and exp <= 0) then
        local dur = 30
        if debuffData.duration and not IsSecret(debuffData.duration) and type(debuffData.duration) == "number" and debuffData.duration > 0 then
            dur = debuffData.duration
        end
        exp = now + dur
    end

    self.debuffCache[key] = {
        name = (debuffData.name and not IsSecret(debuffData.name)) and debuffData.name or "",
        icon = debuffData.icon or 0,
        dispelType = debuffData.dispelType,
        color = color,
        expirationTime = exp,
        duration = (debuffData.duration and not IsSecret(debuffData.duration) and type(debuffData.duration) == "number") and debuffData.duration or 0,
        lastSeen = now,
    }
end

function AT:GetCachedDebuff(unit)
    if not unit then return nil, nil end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        self:ClearDebuffCache(unit)
        return nil, nil
    end

    local key = GetUnitKey(unit)
    local cached = (key and self.debuffCache[key]) or self.debuffCache[unit]
    if not cached then return nil, nil end

    local now = GetTime()
    -- Ablaufprüfung (sicher gegen Secret Values)
    if cached.expirationTime and not IsSecret(cached.expirationTime) and type(cached.expirationTime) == "number" and cached.expirationTime > 0 then
        if now >= cached.expirationTime then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    else
        -- Ohne Ablaufzeit: maximal 20 Sekunden ohne Refresh halten
        if (now - cached.lastSeen) > 20 then
            self:ClearDebuffCache(unit)
            return nil, nil
        end
    end

    return cached, cached.color
end

-- Universeller Argument-Parser für UnitAura / UnitBuff (behandelt 3.3.5 & modernes Classic/Retail Format)
local function ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
    if a1 == nil then return nil end

    -- Erkennt ob Rückgabe das 3.3.5 / Classic-WotLK Format ist:
    -- In 3.3.5: Return 1 = name, Return 2 = rank (string z.B. "Rang 4" oder ""), Return 3 = icon (texture string oder FileID)
    -- In Modern: Return 1 = name, Return 2 = icon (FileID number oder texture path string)
    local isLegacy335 = false
    if type(a2) == "string" and not (a2:find("^Interface") or a2:find("^\\") or a2:find("^/")) then
        if type(a3) == "number" or (type(a3) == "string" and (a3:find("^Interface") or a3:find("^\\") or a3:find("^/"))) then
            isLegacy335 = true
        elseif a2 == "" or a2:find("Rang") or a2:find("Rank") then
            isLegacy335 = true
        end
    end

    local name = ""
    if not IsSecret(a1) and type(a1) == "string" then
        name = a1
    end

    if isLegacy335 then
        -- 3.3.5: name, rank, icon, count, dispelType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
        local caster = a8
        local isMine = false
        if caster and not IsSecret(caster) then
            local okP, isP = pcall(function() return caster == "player" or UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") end)
            if okP and isP then isMine = true end
        end
        local spellId = a11
        if (not name or name == "") and spellId then
            local sName = R4L:GetSpellName(spellId)
            if sName then name = sName end
        end
        return {
            name = name,
            rank = a2,
            icon = a3,
            count = (type(a4) == "number") and a4 or 0,
            dispelType = NormalizeDispelType(a5),
            duration = (type(a6) == "number" and not IsSecret(a6)) and a6 or 0,
            expirationTime = (type(a7) == "number" and not IsSecret(a7)) and a7 or 0,
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    else
        -- Modern: name, icon, count, dispelType, duration, expirationTime, sourceUnit, isStealable, nameplateShowPersonal, spellId
        local caster = a7
        local isMine = false
        if caster and not IsSecret(caster) then
            local okP, isP = pcall(function() return caster == "player" or UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet") end)
            if okP and isP then isMine = true end
        end
        local spellId = a10
        if (not name or name == "") and spellId then
            local sName = R4L:GetSpellName(spellId)
            if sName then name = sName end
        end
        return {
            name = name,
            icon = a2,
            count = (type(a3) == "number") and a3 or 0,
            dispelType = NormalizeDispelType(a4),
            duration = (type(a5) == "number" and not IsSecret(a5)) and a5 or 0,
            expirationTime = (type(a6) == "number" and not IsSecret(a6)) and a6 or 0,
            sourceUnit = caster,
            spellId = spellId,
            isFromPlayerOrPlayerPet = isMine,
        }
    end
end

-- Universeller Aura-Zugriff für moderne Retail / Forever API (abgesichert gegen Secret Auras & Taint)
local function GetUnitAuraByIndex(unit, index, filter)
    if not unit then return nil end

    -- 1. Modern C_UnitAuras
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and data and type(data) == "table" then
            local name = ""
            if data.name and not IsSecret(data.name) then
                name = data.name
            end
            local spellId = data.spellId
            if (not name or name == "") and spellId then
                local sName = R4L:GetSpellName(spellId)
                if sName then name = sName end
            end
            local rawDT = data.dispelName or data.dispelType or data.debuffType
            local dur = (data.duration and not IsSecret(data.duration) and type(data.duration) == "number") and data.duration or 0
            local exp = (data.expirationTime and not IsSecret(data.expirationTime) and type(data.expirationTime) == "number") and data.expirationTime or 0
            return {
                name = name,
                icon = data.iconFileID or data.icon,
                count = data.applications or 0,
                dispelType = NormalizeDispelType(rawDT),
                duration = dur,
                expirationTime = exp,
                sourceUnit = data.sourceUnit,
                sourceGUID = data.sourceGUID,
                spellId = spellId,
                isFromPlayerOrPlayerPet = data.isFromPlayerOrPlayerPet,
            }
        end
    end

    -- 2. Classic / Forever UnitAura mit Doppelformat-Prüfung (3.3.5 vs Modern)
    if UnitAura then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitAura, unit, index, filter)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    end

    -- 3. Älteres UnitBuff / UnitDebuff Fallback
    if filter == "HARMFUL" and UnitDebuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitDebuff, unit, index)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    elseif filter == "HELPFUL" and UnitBuff then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = pcall(UnitBuff, unit, index)
        if ok and a1 ~= nil then
            local parsed = ParseUnitAuraArgs(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
            if parsed then return parsed end
        end
    end

    return nil
end

-- Öffentlicher Zugriff auf GetUnitAuraByIndex für andere Module (z. B. BuffBar)
function AT:GetUnitAuraByIndex(unit, index, filter)
    return GetUnitAuraByIndex(unit, index, filter)
end

-- Prüft, ob eine Aura vom Spieler stammt (strikte Caster-Prüfung + Secret-Value Absicherung)
local function IsPlayerAura(aura, unit)
    if not aura then return false end

    -- 1. Blizzard Flag (C_UnitAuras / UnitAura)
    if not IsSecret(aura.isFromPlayerOrPlayerPet) and aura.isFromPlayerOrPlayerPet == true then
        return true
    end

    -- 2. sourceUnit Prüfung (gesichert gegen Secret Values / Taint)
    local sUnit = aura.sourceUnit
    if sUnit and not IsSecret(sUnit) then
        local okP, isPl = pcall(function()
            return sUnit == "player" or UnitIsUnit(sUnit, "player") or UnitIsUnit(sUnit, "pet")
        end)
        if okP and isPl then
            return true
        end
    end

    -- 3. sourceGUID Prüfung (gesichert gegen Secret Values / Taint)
    local sGUID = aura.sourceGUID
    if sGUID and not IsSecret(sGUID) then
        local okG, isMatch = pcall(function()
            local pGUID = UnitGUID("player")
            return (pGUID and not IsSecret(pGUID) and sGUID == pGUID)
        end)
        if okG and isMatch then
            return true
        end
    end

    -- 4. Wenn unit == "player" ist: Eigener Klassen-HoT auf sich selbst stammt IMMER vom Spieler
    if unit and not IsSecret(unit) then
        local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
        if okSelf and isSelf then
            return true
        end
    end

    -- 5. Fallback im Kampf: Wenn der HoT zur eigenen Klasse gehört und in der Gruppe kein zweiter Heiler dieser Klasse existiert
    local inCombat = false
    local okComb, cVal = pcall(UnitAffectingCombat, "player")
    if okComb and cVal == true then inCombat = true end
    if inCombat then
        local _, pClass = UnitClass("player")
        local otherSameClass = false
        if IsInGroup and IsInGroup() then
            local num = (GetNumGroupMembers and GetNumGroupMembers()) or 0
            for i = 1, num do
                local gUnit = (IsInRaid and IsInRaid()) and ("raid" .. i) or ("party" .. i)
                if UnitExists(gUnit) and not UnitIsUnit(gUnit, "player") then
                    local _, gClass = UnitClass(gUnit)
                    if gClass == pClass then
                        otherSameClass = true
                        break
                    end
                end
            end
        end
        if not otherSameClass then
            return true
        end
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
if GetSpellTexture then
    for cls, spells in pairs(CLASS_HOTS) do
        for sId in pairs(spells) do
            local okTex, tex = pcall(GetSpellTexture, sId)
            if okTex and tex then
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
-- Intelligenter HoT-Cache (garantiert 100% Sichtbarkeit von HoTs & Schilden im Kampf)
-- =========================================================================
AT.hotCache = {}

function AT:ClearHotCache(unit)
    if not unit then return end
    local key = GetUnitKey(unit)
    if key and self.hotCache[key] then
        self.hotCache[key] = nil
    end
    if self.hotCache[unit] then
        self.hotCache[unit] = nil
    end
end

function AT:SetCachedHot(unit, hotData)
    if not unit or not hotData or not hotData.icon then return end
    local key = GetUnitKey(unit)
    if not key then return end
    if not self.hotCache[key] then
        self.hotCache[key] = {}
    end
    local hotKey = (hotData.spellId and hotData.spellId ~= 0) and hotData.spellId or hotData.icon
    self.hotCache[key][hotKey] = {
        name = hotData.name or "",
        icon = hotData.icon,
        count = hotData.count or 0,
        duration = hotData.duration or 0,
        expirationTime = hotData.expirationTime or (GetTime() + 15),
        spellId = hotData.spellId or 0,
        isMine = hotData.isMine,
        lastSeen = GetTime(),
    }
end

-- Holt alle aktiven HoTs (eigene HoTs und fremde HoTs getrennt) auf der Zieleinheit
function AT:GetPlayerHots(unit)
    local ownHots = {}
    local otherHots = {}
    if not unit or not UnitExists(unit) then return ownHots, otherHots end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        self:ClearHotCache(unit)
        return ownHots, otherHots
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
    local now = GetTime()

    local function TryAddAura(aura)
        if not aura then return false end
        local name = (aura.name and not IsSecret(aura.name)) and aura.name or ""
        local icon = aura.icon or aura.iconFileID
        local count = aura.applications or aura.count or 0
        local duration = aura.duration or 0
        local expirationTime = aura.expirationTime or 0
        local spellId = (aura.spellId and not IsSecret(aura.spellId)) and aura.spellId or 0

        -- Falls Icon irrtümlich als Rang-String ankam, Textur über Zaubernamen auflösen
        if type(icon) == "string" and (icon:find("Rang") or icon:find("Rank")) then
            if GetSpellTexture then
                local okTex, sTex = pcall(GetSpellTexture, (spellId ~= 0 and spellId) or (name ~= "" and name))
                if okTex and sTex then icon = sTex end
            end
        end

        if not icon or IsSecret(icon) then return false end

        -- Prüfe, ob es sich um einen HoT / Schild handelt
        if not IsHotAura(name, spellId, duration, icon) then return false end

        -- Eigene HoTs MÜSSEN zwingend zur Klasse des Spielers gehören
        local isMine = false
        if IsPlayerClassSpell(name, spellId, icon) then
            isMine = IsPlayerAura(aura, unit)
        end

        -- Sichere Ablaufzeit bestimmen (100% frei von Secret Values)
        local safeExp = 0
        if expirationTime and not IsSecret(expirationTime) and type(expirationTime) == "number" and expirationTime > 0 then
            safeExp = expirationTime
        else
            local safeDur = 0
            if duration and not IsSecret(duration) and type(duration) == "number" and duration > 0 then
                safeDur = duration
            else
                safeDur = GetDefaultHotDuration(spellId, name, icon)
            end
            safeExp = now + (safeDur > 0 and safeDur or 15)
        end

        local safeDur = 0
        if duration and not IsSecret(duration) and type(duration) == "number" and duration > 0 then
            safeDur = duration
        else
            safeDur = GetDefaultHotDuration(spellId, name, icon)
        end

        local safeCount = 0
        if count and not IsSecret(count) and type(count) == "number" then
            safeCount = count
        end

        local hotKey = (spellId ~= 0) and spellId or icon
        local hotData = {
            name = name,
            icon = icon,
            count = safeCount,
            duration = safeDur,
            expirationTime = safeExp,
            spellId = spellId,
            isMine = isMine,
        }

        if isMine then
            if not seenOwn[hotKey] then
                seenOwn[hotKey] = true
                table.insert(allOwn, hotData)
            end
        else
            if not seenOther[hotKey] then
                seenOther[hotKey] = true
                table.insert(allOther, hotData)
            end
        end

        -- Im Cache sichern
        self:SetCachedHot(unit, hotData)
        return true
    end

    local function FinalizeHots()
        local fNow = GetTime()
        local function CompareHots(a, b)
            local timeA = (a.expirationTime and a.expirationTime > 0) and (a.expirationTime - fNow) or 99999
            local timeB = (b.expirationTime and b.expirationTime > 0) and (b.expirationTime - fNow) or 99999
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

    -- Methode 1: C_UnitAuras.GetUnitAuras
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local auras = nil
        local ok, res = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        if ok and res and type(res) == "table" and #res > 0 then
            auras = res
        end
        if auras then
            for _, aura in pairs(auras) do
                if type(aura) == "table" then
                    TryAddAura(aura)
                end
            end
            if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
        end
    end

    -- Methode 2: AuraUtil.ForEachAura
    if AuraUtil and AuraUtil.ForEachAura then
        pcall(AuraUtil.ForEachAura, unit, "HELPFUL", 40, function(arg1, arg2, arg3, arg4, arg5, arg6, arg7, ...)
            local aura = nil
            if type(arg1) == "table" then
                aura = arg1
            else
                aura = ParseUnitAuraArgs(arg1, arg2, arg3, arg4, arg5, arg6, arg7, ...)
            end
            if aura then
                TryAddAura(aura)
            end
            return false
        end)
        if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
    end

    -- Methode 3: C_UnitAuras.GetAuraSlots & GetAuraDataBySlot
    if C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        local token = nil
        repeat
            local okSlots, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 = pcall(C_UnitAuras.GetAuraSlots, unit, "HELPFUL", 40, token)
            if okSlots and s1 then
                local slots = { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 }
                token = table.remove(slots, 1)
                for _, slot in ipairs(slots) do
                    local okAura, aura = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slot)
                    if okAura and aura then TryAddAura(aura) end
                end
            else
                token = nil
            end
        until token == nil
        if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end
    end

    -- Methode 4: GetUnitAuraByIndex (Universeller Index-Scan)
    for i = 1, 40 do
        local aura = GetUnitAuraByIndex(unit, i, "HELPFUL")
        if not aura then break end
        TryAddAura(aura)
    end
    if #allOwn > 0 or #allOther > 0 then return FinalizeHots() end

    -- Fallback: Wenn 0 HoTs gefunden wurden, aber der Spieler/die Einheit im Kampf ist:
    -- Prüfe aktiven HoT-Cache, damit HoTs im Kampf niemals flackern oder verschwinden
    local inCombat = false
    local okComb, cVal = pcall(UnitAffectingCombat, unit)
    if okComb and cVal == true then inCombat = true end
    if not inCombat and UnitAffectingCombat then
        local okPComb, pVal = pcall(UnitAffectingCombat, "player")
        if okPComb and pVal == true then inCombat = true end
    end

    if inCombat then
        local key = GetUnitKey(unit)
        local uHots = (key and self.hotCache[key]) or self.hotCache[unit]
        if uHots then
            for hotKey, cached in pairs(uHots) do
                if cached.expirationTime and cached.expirationTime > now then
                    if cached.isMine then
                        if not seenOwn[hotKey] then
                            seenOwn[hotKey] = true
                            table.insert(allOwn, cached)
                        end
                    else
                        if not seenOther[hotKey] then
                            seenOther[hotKey] = true
                            table.insert(allOther, cached)
                        end
                    end
                else
                    uHots[hotKey] = nil
                end
            end
            if #allOwn > 0 or #allOther > 0 then
                return FinalizeHots()
            end
        end
    else
        -- Außerhalb des Kampfes sicher säubern
        self:ClearHotCache(unit)
    end

    return FinalizeHots()
end

-- Findet den wichtigsten reinigbaren Debuff auf einer Einheit (gesichert im Kampf)
function AT:GetDispellableDebuff(unit)
    local cfg = R4L.ProfileManager:GetConfig()
    if not cfg.auras or not cfg.auras.showDebuffs then return nil, nil end
    if not unit or not UnitExists(unit) then return nil, nil end

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        self:ClearDebuffCache(unit)
        return nil, nil
    end

    local combinedDispels, playerDispels, groupDispels = self:GetDispelCapabilities()

    local function EvaluateDebuff(debuffData)
        if not debuffData then return false, nil, 0 end
        local dt = debuffData.dispelType or NormalizeDispelType(debuffData.dispelName or debuffData.debuffType)
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
    local scanHadError = false
    local scanSucceeded = false

    -- Methode 0: C_UnitAuras.GetUnitAuras (Modern Retail / Forever C-Level Scan)
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL")
        if not ok then
            scanHadError = true
        elseif auras and type(auras) == "table" then
            scanSucceeded = true
            if #auras > 0 then
                for _, data in ipairs(auras) do
                    if type(data) == "table" then
                        totalHarmfulScanned = totalHarmfulScanned + 1
                        local rawDT = data.dispelName or data.dispelType or data.debuffType
                        local debuffData = {
                            name = (data.name and not IsSecret(data.name)) and data.name or "",
                            icon = data.iconFileID or data.icon,
                            dispelType = NormalizeDispelType(rawDT),
                            duration = (data.duration and not IsSecret(data.duration) and type(data.duration) == "number") and data.duration or 0,
                            expirationTime = (data.expirationTime and not IsSecret(data.expirationTime) and type(data.expirationTime) == "number") and data.expirationTime or 0,
                        }
                        local isMatch, color, prio = EvaluateDebuff(debuffData)
                        if isMatch and prio > bestPriority then
                            bestDebuff = debuffData
                            bestColor = color
                            bestPriority = prio
                            if prio == 2 then break end
                        end
                    end
                end
            end
            if bestDebuff and bestPriority == 2 then
                self:SetCachedDebuff(unit, bestDebuff, bestColor)
                return bestDebuff, bestColor
            end
        end
    end

    -- 1. Scan über AuraUtil.ForEachAura (Modern Retail / Forever)
    if AuraUtil and AuraUtil.ForEachAura then
        local okForEach = pcall(AuraUtil.ForEachAura, unit, "HARMFUL", 40, function(arg1, arg2, arg3, arg4, arg5, ...)
            totalHarmfulScanned = totalHarmfulScanned + 1
            local debuffData = nil
            if type(arg1) == "table" then
                local rawDT = arg1.dispelName or arg1.dispelType or arg1.debuffType
                debuffData = {
                    name = (arg1.name and not IsSecret(arg1.name)) and arg1.name or "",
                    icon = arg1.iconFileID or arg1.icon,
                    dispelType = NormalizeDispelType(rawDT),
                    duration = (arg1.duration and not IsSecret(arg1.duration) and type(arg1.duration) == "number") and arg1.duration or 0,
                    expirationTime = (arg1.expirationTime and not IsSecret(arg1.expirationTime) and type(arg1.expirationTime) == "number") and arg1.expirationTime or 0,
                }
            else
                local parsed = ParseUnitAuraArgs(arg1, arg2, arg3, arg4, arg5, ...)
                if parsed then
                    parsed.dispelType = NormalizeDispelType(parsed.dispelType)
                    debuffData = parsed
                end
            end

            if debuffData then
                local isMatch, color, prio = EvaluateDebuff(debuffData)
                if isMatch and prio > bestPriority then
                    bestDebuff = debuffData
                    bestColor = color
                    bestPriority = prio
                    if prio == 2 then return true end -- Höchste Priorität gefunden
                end
            end
            return false
        end)
        if okForEach then scanSucceeded = true end
        if bestDebuff and bestPriority == 2 then
            self:SetCachedDebuff(unit, bestDebuff, bestColor)
            return bestDebuff, bestColor
        end
    end

    -- 2. Scan über C_UnitAuras.GetAuraDataByIndex (Modern Retail / Forever)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local m2Error = false
        for i = 1, 40 do
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if not ok then
                scanHadError = true
                m2Error = true
                break
            elseif data and type(data) == "table" then
                totalHarmfulScanned = totalHarmfulScanned + 1
                local rawDT = data.dispelName or data.dispelType or data.debuffType
                local debuffData = {
                    name = (data.name and not IsSecret(data.name)) and data.name or "",
                    icon = data.iconFileID or data.icon,
                    dispelType = NormalizeDispelType(rawDT),
                    duration = (data.duration and not IsSecret(data.duration) and type(data.duration) == "number") and data.duration or 0,
                    expirationTime = (data.expirationTime and not IsSecret(data.expirationTime) and type(data.expirationTime) == "number") and data.expirationTime or 0,
                }
                local isMatch, color, prio = EvaluateDebuff(debuffData)
                if isMatch and prio > bestPriority then
                    bestDebuff = debuffData
                    bestColor = color
                    bestPriority = prio
                    if prio == 2 then break end
                end
            elseif ok and data == nil then
                break -- Ende der aktiven Aurenliste
            end
        end
        if not m2Error then scanSucceeded = true end
        if bestDebuff and bestPriority == 2 then
            self:SetCachedDebuff(unit, bestDebuff, bestColor)
            return bestDebuff, bestColor
        end
    end

    -- 3. Scan über GetUnitAuraByIndex (Classic 3.3.5 / Forever Fallback)
    local m3Error = false
    for i = 1, 40 do
        local okAura, aura = pcall(GetUnitAuraByIndex, unit, i, "HARMFUL")
        if not okAura then
            scanHadError = true
            m3Error = true
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
        end
    end
    if not m3Error then scanSucceeded = true end

    -- Wenn ein passender aktiver Debuff gefunden wurde -> Cache auffrischen & zurückgeben
    if bestDebuff and bestColor then
        self:SetCachedDebuff(unit, bestDebuff, bestColor)
        return bestDebuff, bestColor
    end

    -- Wenn mindestens ein Scan-Verfahren fehlerfrei lief und kein bannbarer Debuff gefunden wurde:
    -- Der Debuff existiert nicht mehr (oder wurde gebannt) -> Cache SOFORT leeren (auch im Kampf!)
    if scanSucceeded then
        self:ClearDebuffCache(unit)
        return nil, nil
    end

    -- Status ob Einheit oder Spieler im Kampf ist
    local inCombat = false
    local okComb, cVal = pcall(UnitAffectingCombat, unit)
    if okComb and cVal == true then inCombat = true end
    if not inCombat and UnitAffectingCombat then
        local okPComb, pVal = pcall(UnitAffectingCombat, "player")
        if okPComb and pVal == true then inCombat = true end
    end

    -- 4. Notfall-Kampf-Cache Fallback: NUR wenn ALLE Scans im Kampf mit Fehlern scheiterten (z.B. API im Kampf geschützt)
    if inCombat then
        local cached, cachedColor = self:GetCachedDebuff(unit)
        if cached and cachedColor then
            return cached, cachedColor
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
            if v.expirationTime and not IsSecret(v.expirationTime) and type(v.expirationTime) == "number" and v.expirationTime > 0 and now >= v.expirationTime then
                AT.debuffCache[k] = nil
            end
        end
        for uKey, uMap in pairs(AT.hotCache) do
            for hKey, hData in pairs(uMap) do
                if hData.expirationTime and not IsSecret(hData.expirationTime) and type(hData.expirationTime) == "number" and hData.expirationTime > 0 and now >= hData.expirationTime then
                    uMap[hKey] = nil
                end
            end
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
        AT._cachedCombined = nil
    end)

    R4L:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        AT._cachedCombined = nil
    end)
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
